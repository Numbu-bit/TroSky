"""Booking lifecycle business logic: concurrency-safe seat reservation,
idempotent creation, cancellation (with a simple MVP refund-eligibility
policy), and the expiration sweep.

Concurrency model (see the module docstring in ``app.models.bookings`` and
``app.repositories.booking_repository`` for the database-level guarantee):
Postgres — via a partial unique index — is the sole authority on seat
ownership. Redis is used only to short-circuit an obviously-taken seat
before a database round trip; every write still goes through the database
constraint, so a Redis outage degrades performance, never correctness.
"""

from __future__ import annotations

import hashlib
import uuid
from collections.abc import Awaitable
from datetime import UTC, datetime, timedelta
from decimal import ROUND_HALF_UP, Decimal
from typing import cast

from redis.asyncio import Redis
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings, get_settings
from app.core.exceptions import (
    AccountNotVerifiedError,
    ConflictError,
    IdempotencyConflictError,
    InvalidStateTransitionError,
    NoPickupNearbyError,
    NotFoundError,
    SeatNotAvailableError,
    StopNotOnRouteError,
)
from app.core.logging import get_logger
from app.core.telemetry import BOOKING_EVENTS_TOTAL, RESERVATION_EXPIRATIONS_TOTAL
from app.models.bookings import (
    Booking,
    BookingPassenger,
    BookingStatus,
    CancellationRequest,
    CancellationStatus,
    ReservationStatus,
)
from app.models.notifications import NotificationCategory
from app.models.trips import Trip, TripStatus
from app.repositories.booking_repository import BookingRepository, SeatAlreadyReservedError
from app.repositories.route_repository import RouteRepository, StopRepository
from app.repositories.trip_repository import TripRepository
from app.repositories.user_repository import UserRepository
from app.repositories.vehicle_repository import VehicleRepository
from app.schemas.booking import BookingCreateRequest
from app.services.fare_service import FareBreakdown, FareService, segment_distance_km
from app.services.notification_service import NotificationService
from app.services.ticket_service import TicketService

logger = get_logger(__name__)

_TERMINAL_BOOKING_STATUSES = frozenset(
    {
        BookingStatus.CANCELLED,
        BookingStatus.EXPIRED,
        BookingStatus.COMPLETED,
        BookingStatus.REFUNDED,
    }
)


def _held_seats_key(trip_id: uuid.UUID) -> str:
    return f"trip:{trip_id}:held_seats"


class BookingService:
    def __init__(
        self, session: AsyncSession, redis: Redis | None = None, settings: Settings | None = None
    ) -> None:
        self._session = session
        self._redis = redis
        self._settings = settings or get_settings()
        self._bookings = BookingRepository(session)
        self._trips = TripRepository(session)
        self._routes = RouteRepository(session)
        self._stops = StopRepository(session)
        self._fares = FareService(self._settings)
        self._vehicles = VehicleRepository(session)
        self._users = UserRepository(session)
        self._tickets = TicketService(session, self._settings)
        self._notifications = NotificationService(session, self._settings)

    @staticmethod
    def _hash_request(request: BookingCreateRequest) -> str:
        seat_ids = sorted(str(p.seat_id) for p in request.passengers)
        raw = f"{request.trip_id}:{','.join(seat_ids)}"
        return hashlib.sha256(raw.encode("utf-8")).hexdigest()

    async def _resolve_segment(
        self, trip: Trip, request: BookingCreateRequest
    ) -> tuple[uuid.UUID | None, uuid.UUID | None]:
        """Where this booking boards and alights, as stops on the trip's route.

        Pickup precedence: a stop the passenger chose by hand, then the
        device's GPS position, then (neither given) the whole route. GPS is
        snapped to the nearest stop *this trip serves* within walking
        distance, so the price is always for a real segment of the route.

        Named stops are checked against the route here because the fare
        engine would otherwise price a stop it cannot place as the whole
        route, charging a full fare without telling anyone why.
        """
        route = await self._routes.get_by_id(trip.route_id)
        if route is None:
            raise NotFoundError("Route not found.")
        order = await self._routes.stop_order(route)

        destination = request.destination_stop_id
        if destination is not None and destination not in order:
            raise StopNotOnRouteError(details={"stop_id": str(destination), "role": "destination"})
        alight_at = order[destination] if destination is not None else max(order.values())

        origin: uuid.UUID | None = None
        if request.origin_stop_id is not None:
            origin = request.origin_stop_id
            if origin not in order:
                raise StopNotOnRouteError(details={"stop_id": str(origin), "role": "origin"})
        elif request.pickup_latitude is not None and request.pickup_longitude is not None:
            candidates = await self._stops.find_nearby(
                latitude=request.pickup_latitude,
                longitude=request.pickup_longitude,
                radius_m=self._settings.PICKUP_MAX_WALK_METERS,
                limit=self._settings.PICKUP_NEARBY_LIMIT,
                stop_ids=order.keys(),
            )
            origin = next(
                (
                    stop.id
                    for stop, _ in candidates
                    if order[stop.id] < alight_at and stop.id != destination
                ),
                None,
            )
            if origin is None:
                raise NoPickupNearbyError(
                    "None of this trip's stops is within walking distance of your location.",
                    details={
                        "max_walk_meters": self._settings.PICKUP_MAX_WALK_METERS,
                        "hint": "Choose a pickup stop on this route instead.",
                    },
                )

        if origin is not None and order[origin] >= alight_at:
            raise StopNotOnRouteError(
                "The pickup must come before the destination on this route.",
                details={"origin_stop_id": str(origin), "destination_stop_id": str(destination)},
            )
        return origin, destination

    async def _quote_segment(
        self,
        *,
        trip: Trip,
        origin_stop_id: uuid.UUID | None,
        destination_stop_id: uuid.UUID | None,
        seat_count: int,
    ) -> FareBreakdown:
        """Price one seat on the part of the route this booking rides.

        The trip's cost is divided between everyone aboard in proportion to
        the distance each rides, so the divisor is the sum of every seat's
        distance — those already booked plus the ones being booked now.

        Sharing is priced from the passengers aboard at the moment of
        booking: someone boarding later gets their own, cheaper quote, but
        nobody is re-billed for a bus that filled up after they paid.
        """
        route_stops = await self._routes.list_route_stops(trip.route_id)
        distances = {rs.stop_id: rs.distance_from_origin_km for rs in route_stops}
        route = await self._routes.get_by_id(trip.route_id)
        route_km = route.distance_km if route is not None else None

        segment_km = route_km
        if origin_stop_id is not None and destination_stop_id is not None:
            segment_km = segment_distance_km(
                origin_distance_km=distances.get(origin_stop_id),
                destination_distance_km=distances.get(destination_stop_id),
                route_km=route_km,
            )

        committed_km = await self._bookings.sum_passenger_km_for_trip(
            trip.id, stop_distances=distances, route_km=route_km
        )
        own_km = (segment_km or route_km or Decimal("0")) * seat_count
        return self._fares.quote(
            full_route_fare=trip.fare_amount,
            segment_km=segment_km,
            route_km=route_km,
            total_passenger_km=committed_km + own_km,
        )

    def _platform_fee(self, fare_amount: Decimal, seat_count: int) -> Decimal:
        """TroSky's cut, charged on top of the operator's fare.

        Flat component is per seat, percentage applies to the fare. Rounded
        half-up to the currency's minor unit so the three stored amounts
        always satisfy fare + fee == total exactly (a banker's-rounding
        default would break that invariant on .x5 boundaries).
        """
        fee = (self._settings.PLATFORM_FEE_FLAT_PER_SEAT * seat_count) + (
            fare_amount * self._settings.PLATFORM_FEE_PERCENT / Decimal("100")
        )
        exponent = Decimal(1).scaleb(-self._settings.payments_default_currency_minor_unit)
        return fee.quantize(exponent, rounding=ROUND_HALF_UP)

    async def create_booking(
        self,
        passenger_id: uuid.UUID,
        request: BookingCreateRequest,
        *,
        idempotency_key: uuid.UUID | None,
    ) -> Booking:
        if self._settings.REQUIRE_VERIFIED_ACCOUNT:
            account = await self._users.get_by_id(passenger_id)
            if account is not None and not account.is_verified:
                raise AccountNotVerifiedError(
                    "Verify your account with the code sent to you before booking."
                )
        request_hash = self._hash_request(request)

        if idempotency_key is not None:
            existing = await self._bookings.get_by_idempotency_key(passenger_id, idempotency_key)
            if existing is not None:
                if existing.idempotency_request_hash != request_hash:
                    raise IdempotencyConflictError()
                return existing

        trip = await self._trips.get_by_id(request.trip_id)
        if trip is None:
            raise NotFoundError("Trip not found.")
        if trip.status not in (TripStatus.SCHEDULED, TripStatus.BOARDING):
            raise ConflictError(
                "This trip is not currently open for booking.", code="TRIP_NOT_BOOKABLE"
            )

        vehicle = await self._trips.get_vehicle_for_trip(trip.id)
        if vehicle is None:
            raise ConflictError("This trip has no vehicle assigned yet.")
        layout = await self._vehicles.get_seat_layout(vehicle.id)
        if layout is None:
            raise ConflictError("No seat layout has been configured for this trip's vehicle.")
        valid_seats = {s.id: s for s in await self._vehicles.list_seats(layout.id)}

        requested_seat_ids = [p.seat_id for p in request.passengers]
        for seat_id in requested_seat_ids:
            if seat_id not in valid_seats:
                raise NotFoundError(f"Seat {seat_id} does not belong to this trip's vehicle.")

        # Redis pre-check: an acceleration/stampede-reduction hint only —
        # a miss here does NOT mean the seat is available (the database
        # constraint below is what actually decides that).
        if self._redis is not None:
            held_key = _held_seats_key(trip.id)
            for seat_id in requested_seat_ids:
                is_held = await cast(
                    Awaitable[object], self._redis.sismember(held_key, str(seat_id))
                )
                if is_held:
                    raise SeatNotAvailableError(details={"seat_id": str(seat_id)})

        hold_seconds = self._settings.SEAT_RESERVATION_HOLD_SECONDS
        expires_at = datetime.now(UTC) + timedelta(seconds=hold_seconds)
        seat_count = len(request.passengers)
        origin_stop_id, destination_stop_id = await self._resolve_segment(trip, request)
        quote = await self._quote_segment(
            trip=trip,
            origin_stop_id=origin_stop_id,
            destination_stop_id=destination_stop_id,
            seat_count=seat_count,
        )
        fare_amount: Decimal = quote.per_seat_fare * seat_count
        platform_fee = self._platform_fee(fare_amount, seat_count)
        total_amount: Decimal = fare_amount + platform_fee

        booking = await self._bookings.create_booking(
            passenger_id=passenger_id,
            trip_id=trip.id,
            passenger_count=seat_count,
            origin_stop_id=origin_stop_id,
            destination_stop_id=destination_stop_id,
            fare_amount=fare_amount,
            platform_fee=platform_fee,
            total_amount=total_amount,
            expires_at=expires_at,
            idempotency_key=idempotency_key,
            idempotency_request_hash=request_hash,
        )
        await self._bookings.record_creation(booking, created_by=passenger_id)

        try:
            for passenger in request.passengers:
                await self._bookings.create_seat_reservation(
                    trip_id=trip.id,
                    seat_id=passenger.seat_id,
                    booking_id=booking.id,
                    expires_at=expires_at,
                )
                await self._bookings.add_passenger(
                    booking_id=booking.id,
                    seat_id=passenger.seat_id,
                    full_name=passenger.full_name,
                    phone_number=passenger.phone_number,
                )
        except SeatAlreadyReservedError as exc:
            # Raising here lets the request-scoped session roll back the
            # *entire* transaction (the booking row included) — all-or-
            # nothing, per the spec's booking-concurrency requirement.
            logger.info("seat_reservation_conflict", trip_id=str(trip.id), seat_id=str(exc))
            raise SeatNotAvailableError(details={"seat_id": str(exc)}) from exc

        if self._redis is not None:
            held_key = _held_seats_key(trip.id)
            for seat_id in requested_seat_ids:
                await cast(Awaitable[object], self._redis.sadd(held_key, str(seat_id)))
            await self._redis.expire(held_key, hold_seconds)

        BOOKING_EVENTS_TOTAL.labels(outcome="created").inc()
        logger.info(
            "booking_created",
            booking_id=str(booking.id),
            trip_id=str(trip.id),
            passenger_id=str(passenger_id),
            seat_count=len(requested_seat_ids),
        )
        return booking

    async def get_booking(
        self, booking_id: uuid.UUID, *, requesting_user_id: uuid.UUID, is_privileged: bool = False
    ) -> Booking:
        booking = await self._bookings.get_by_id(booking_id)
        if booking is None:
            raise NotFoundError("Booking not found.")
        if not is_privileged and booking.passenger_id != requesting_user_id:
            raise NotFoundError("Booking not found.")
        return booking

    async def list_own_bookings(
        self, passenger_id: uuid.UUID, *, limit: int, offset: int
    ) -> tuple[list[Booking], int]:
        return await self._bookings.list_for_passenger(passenger_id, limit=limit, offset=offset)

    async def list_all_bookings(
        self, *, status: BookingStatus | None, limit: int, offset: int
    ) -> tuple[list[Booking], int]:
        return await self._bookings.list_all(status=status, limit=limit, offset=offset)

    async def get_booking_passengers(self, booking_id: uuid.UUID) -> list[BookingPassenger]:
        return await self._bookings.list_passengers(booking_id)

    # ------------------------------------------------------------------
    # Confirmation — called by Phase 6's payment-success handler, never
    # exposed directly over the API (a client can never self-report
    # "payment succeeded").
    # ------------------------------------------------------------------
    async def confirm_booking(self, booking_id: uuid.UUID) -> Booking:
        booking = await self._bookings.get_for_update(booking_id)
        if booking is None:
            raise NotFoundError("Booking not found.")
        if booking.status == BookingStatus.CONFIRMED:
            await self._tickets.issue_tickets_for_booking(booking)  # idempotent, belt-and-braces
            return booking  # idempotent
        if booking.status not in (BookingStatus.PENDING, BookingStatus.PAYMENT_PENDING):
            raise InvalidStateTransitionError(
                f"Cannot confirm a booking in status '{booking.status.value}'."
            )
        await self._bookings.confirm_reservations_for_booking(booking.id)
        await self._bookings.set_status(
            booking, new_status=BookingStatus.CONFIRMED, changed_by=None, reason="Payment verified"
        )
        await self._tickets.issue_tickets_for_booking(booking)
        if self._redis is not None:
            await self._redis.delete(_held_seats_key(booking.trip_id))
        await self._notifications.notify(
            booking.passenger_id,
            category=NotificationCategory.TRANSACTIONAL,
            title="Booking confirmed",
            body=f"Your booking {booking.booking_reference} is confirmed. Have a safe trip!",
            data={"booking_id": str(booking.id)},
        )
        BOOKING_EVENTS_TOTAL.labels(outcome="confirmed").inc()
        logger.info("booking_confirmed", booking_id=str(booking.id))
        return booking

    # ------------------------------------------------------------------
    # Cancellation
    # ------------------------------------------------------------------
    async def cancel_booking(
        self,
        booking_id: uuid.UUID,
        *,
        requesting_user_id: uuid.UUID,
        reason: str | None,
        is_privileged: bool = False,
    ) -> Booking:
        booking = await self._bookings.get_for_update(booking_id)
        if booking is None:
            raise NotFoundError("Booking not found.")
        if not is_privileged and booking.passenger_id != requesting_user_id:
            raise NotFoundError("Booking not found.")
        if booking.status in _TERMINAL_BOOKING_STATUSES:
            raise InvalidStateTransitionError(
                f"A booking in status '{booking.status.value}' cannot be cancelled."
            )

        trip = await self._trips.get_by_id(booking.trip_id)
        trip_not_started = trip is not None and trip.status == TripStatus.SCHEDULED
        was_paid = booking.status == BookingStatus.CONFIRMED
        refund_eligible = was_paid and trip_not_started

        # MVP cancellation policy: auto-approve while the trip hasn't
        # started; anything after boarding/departure needs admin review.
        auto_decide = trip_not_started
        now = datetime.now(UTC)
        await self._bookings.create_cancellation_request(
            booking_id=booking.id,
            requested_by=requesting_user_id,
            reason=reason,
            status=CancellationStatus.APPROVED if auto_decide else CancellationStatus.PENDING,
            refund_eligible=refund_eligible,
            decided_by=requesting_user_id if auto_decide else None,
            decided_at=now if auto_decide else None,
        )

        if auto_decide:
            await self._bookings.release_reservations_for_booking(
                booking.id, new_status=ReservationStatus.RELEASED
            )
            new_status = (
                BookingStatus.REFUND_PENDING if refund_eligible else BookingStatus.CANCELLED
            )
            await self._bookings.set_status(
                booking, new_status=new_status, changed_by=requesting_user_id, reason=reason
            )
            await self._tickets.revoke_tickets_for_booking(booking.id, reason="Booking cancelled")
            if self._redis is not None:
                await self._redis.delete(_held_seats_key(booking.trip_id))
            BOOKING_EVENTS_TOTAL.labels(outcome="cancelled").inc()
            logger.info(
                "booking_cancelled", booking_id=str(booking.id), refund_eligible=refund_eligible
            )
        else:
            logger.info("booking_cancellation_pending_review", booking_id=str(booking.id))

        return booking

    # ------------------------------------------------------------------
    # Admin review of a post-boarding cancellation request (the ``auto_decide
    # = False`` branch of ``cancel_booking`` above leaves one of these
    # ``PENDING`` for exactly this method to resolve).
    # ------------------------------------------------------------------
    async def review_cancellation_request(
        self,
        request_id: uuid.UUID,
        *,
        reviewer_id: uuid.UUID,
        approve: bool,
        refund_eligible: bool,
        notes: str | None,
    ) -> tuple[CancellationRequest, Booking]:
        request = await self._bookings.get_cancellation_request_for_update(request_id)
        if request is None:
            raise NotFoundError("Cancellation request not found.")
        if request.status != CancellationStatus.PENDING:
            raise InvalidStateTransitionError(
                f"Cannot review a cancellation request in status '{request.status.value}'."
            )

        booking = await self._bookings.get_for_update(request.booking_id)
        if booking is None:
            raise NotFoundError("Booking not found.")

        now = datetime.now(UTC)
        # A rejected request keeps the booking exactly as it was — the
        # passenger's booking simply was not cancelled.
        effective_refund_eligible = refund_eligible if approve else False
        await self._bookings.decide_cancellation_request(
            request,
            status=CancellationStatus.APPROVED if approve else CancellationStatus.REJECTED,
            refund_eligible=effective_refund_eligible,
            decided_by=reviewer_id,
            decided_at=now,
            decision_notes=notes,
        )

        if approve:
            await self._bookings.release_reservations_for_booking(
                booking.id, new_status=ReservationStatus.RELEASED
            )
            new_status = (
                BookingStatus.REFUND_PENDING
                if effective_refund_eligible
                else BookingStatus.CANCELLED
            )
            await self._bookings.set_status(
                booking, new_status=new_status, changed_by=reviewer_id, reason=notes
            )
            await self._tickets.revoke_tickets_for_booking(
                booking.id, reason="Booking cancellation approved"
            )
            if self._redis is not None:
                await self._redis.delete(_held_seats_key(booking.trip_id))
            logger.info(
                "booking_cancellation_approved",
                booking_id=str(booking.id),
                refund_eligible=effective_refund_eligible,
            )
        else:
            logger.info("booking_cancellation_rejected", booking_id=str(booking.id))

        return request, booking

    async def list_cancellation_requests(
        self, *, status: CancellationStatus | None, limit: int, offset: int
    ) -> tuple[list[CancellationRequest], int]:
        return await self._bookings.list_cancellation_requests(
            status=status, limit=limit, offset=offset
        )

    # ------------------------------------------------------------------
    # Expiration sweep (Celery beat)
    # ------------------------------------------------------------------
    async def expire_stale_bookings(self, *, batch_size: int = 100) -> int:
        expired_count = 0
        candidates = await self._bookings.find_expirable_bookings(limit=batch_size)
        for booking in candidates:
            # Re-check under the row lock: another request may have
            # confirmed/cancelled it between the batch query and now.
            if booking.status not in (BookingStatus.PENDING, BookingStatus.PAYMENT_PENDING):
                continue
            if booking.expires_at is None or booking.expires_at > datetime.now(UTC):
                continue
            await self._bookings.release_reservations_for_booking(
                booking.id, new_status=ReservationStatus.EXPIRED
            )
            await self._bookings.set_status(
                booking,
                new_status=BookingStatus.EXPIRED,
                changed_by=None,
                reason="Reservation hold expired",
            )
            if self._redis is not None:
                await self._redis.delete(_held_seats_key(booking.trip_id))
            RESERVATION_EXPIRATIONS_TOTAL.inc()
            expired_count += 1
        if expired_count:
            logger.info("bookings_expired", count=expired_count)
        return expired_count
