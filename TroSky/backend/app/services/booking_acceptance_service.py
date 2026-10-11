"""Bookings wait for the trip's driver, or an admin, to accept them before
the passenger pays.

A new booking is put to its trip (a ``BookingOffer``) for
``BOOKING_ACCEPT_TIMEOUT_SECONDS``, holding its seats. Accepted, it can be
paid for, with the usual ``SEAT_RESERVATION_HOLD_SECONDS`` to do it.

Declined by the driver, or not answered in time, it is moved -- passengers
and price as booked -- to another trip from the same pickup to the same
destination that has a driver and seats free, leaving within
``BOOKING_MOVE_WINDOW_MINUTES``, and put to that driver. With no such trip,
or after ``BOOKING_MAX_MOVES`` moves, it ends unpaid and the passenger is
told. An admin may accept or decline any booking waiting, for the driver,
choosing when declining whether it is moved or ends; or move it to a trip
of their choosing.
"""

from __future__ import annotations

import uuid
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta

from redis.asyncio import Redis
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.admin_events import announce
from app.core.config import Settings, get_settings
from app.core.exceptions import (
    ConflictError,
    ForbiddenError,
    InvalidStateTransitionError,
    NotFoundError,
)
from app.core.logging import get_logger
from app.models.bookings import (
    Booking,
    BookingOffer,
    BookingPassenger,
    BookingStatus,
    OfferStatus,
    ReservationStatus,
)
from app.models.driver_actions import ActedAs, DriverActionKind
from app.models.notifications import NotificationCategory
from app.models.trips import AssignmentResponse, Trip, TripStatus
from app.repositories.booking_offer_repository import BookingOfferRepository, BookingRequest
from app.repositories.booking_repository import BookingRepository, SeatAlreadyReservedError
from app.repositories.driver_action_repository import DriverActionRepository
from app.repositories.driver_repository import DriverRepository
from app.repositories.route_geometry import RouteGeometryRepository
from app.repositories.trip_repository import TripRepository
from app.repositories.vehicle_repository import VehicleRepository
from app.services.notification_service import NotificationService
from app.services.vehicle_position import latest_position, pickup_passed

logger = get_logger(__name__)

# Trips looked at when moving a booking: the nearest in departure time first.
_MOVE_CANDIDATES = 20


def _held_seats_key(trip_id: uuid.UUID) -> str:
    # The booking service's seat-hold hint (see ``booking_service``).
    return f"trip:{trip_id}:held_seats"


@dataclass(frozen=True, slots=True)
class _Ending:
    """How a booking that cannot be moved ends, and what the passenger is told."""

    status: BookingStatus
    reason: str
    told: str


class BookingAcceptanceService:
    def __init__(
        self, session: AsyncSession, redis: Redis | None = None, settings: Settings | None = None
    ) -> None:
        self._session = session
        self._redis = redis
        self._settings = settings or get_settings()
        self._bookings = BookingRepository(session)
        self._offers = BookingOfferRepository(session)
        self._trips = TripRepository(session)
        self._drivers = DriverRepository(session)
        self._vehicles = VehicleRepository(session)
        self._geometries = RouteGeometryRepository(session)
        self._actions = DriverActionRepository(session)
        self._notifications = NotificationService(session, self._settings)

    # ------------------------------------------------------------------
    # Putting a booking to a trip
    # ------------------------------------------------------------------
    async def open(self, booking: Booking) -> BookingOffer:
        """Put a booking just made to its trip's driver."""
        return await self._offer(booking, moved=False)

    async def _offer(self, booking: Booking, *, moved: bool) -> BookingOffer:
        driver = await self._trips.get_driver_for_trip(booking.trip_id)
        timeout = self._settings.BOOKING_ACCEPT_TIMEOUT_SECONDS
        expires_at = datetime.now(UTC) + timedelta(seconds=timeout)
        offer = await self._offers.create(
            booking_id=booking.id,
            trip_id=booking.trip_id,
            driver_id=driver.id if driver is not None else None,
            expires_at=expires_at,
        )
        booking.expires_at = expires_at
        await self._bookings.set_reservation_expiry(booking.id, expires_at)
        if driver is not None:
            seats = booking.passenger_count
            await self._notifications.notify(
                driver.user_id,
                category=NotificationCategory.TRANSACTIONAL,
                title="New booking request",
                body=(
                    f"{seats} seat{'s' if seats > 1 else ''} requested "
                    f"(booking {booking.booking_reference}). Accept or decline within "
                    f"{_minutes(timeout)}."
                ),
                data={
                    "booking_id": str(booking.id),
                    "trip_id": str(booking.trip_id),
                    "action": "booking_request",
                },
            )
        announce(
            self._session,
            "booking.awaiting_acceptance",
            booking_id=booking.id,
            booking_reference=booking.booking_reference,
            trip_id=booking.trip_id,
            driver_id=driver.id if driver is not None else None,
            seats=booking.passenger_count,
            expires_at=expires_at,
            moved=moved,
        )
        return offer

    # ------------------------------------------------------------------
    # Answers
    # ------------------------------------------------------------------
    async def accept(
        self,
        booking_id: uuid.UUID,
        *,
        actor_id: uuid.UUID,
        as_admin: bool,
        trip_id: uuid.UUID | None = None,
    ) -> Booking:
        """Accept a booking waiting on its trip: the passenger may now pay.
        ``trip_id`` (the driver's route) must be the booking's trip."""
        booking = await self._locked_booking(booking_id, trip_id)
        if not as_admin:
            await self._assert_assigned_driver(booking.trip_id, actor_id)
        offer = await self._offers.pending_for_booking(booking.id)
        if booking.status != BookingStatus.AWAITING_ACCEPTANCE or offer is None:
            if await self._already_accepted(booking):
                return booking  # a second tap
            raise _not_waiting(booking)

        await self._offers.decide(
            offer, status=OfferStatus.ACCEPTED, decided_by=actor_id, reason=None
        )
        assignment = await self._trips.get_active_driver_assignment(booking.trip_id)
        if (
            assignment is not None
            and not as_admin
            and assignment.response == AssignmentResponse.PENDING
        ):
            # Taking a passenger on the trip is taking the trip.
            await self._trips.record_response(
                assignment,
                response=AssignmentResponse.ACCEPTED,
                responded_by=actor_id,
                reason=None,
            )
            await self._actions.record(
                kind=DriverActionKind.TRIP_ACCEPTED,
                trip_id=booking.trip_id,
                driver_id=assignment.driver_id,
                acted_as=ActedAs.DRIVER,
                actor_id=actor_id,
                reason="Accepted a booking on it",
            )

        hold = self._settings.SEAT_RESERVATION_HOLD_SECONDS
        pay_by = datetime.now(UTC) + timedelta(seconds=hold)
        booking.expires_at = pay_by
        await self._bookings.set_reservation_expiry(booking.id, pay_by)
        await self._bookings.set_status(
            booking,
            new_status=BookingStatus.PENDING,
            changed_by=actor_id,
            reason="Accepted by an admin" if as_admin else "Accepted by the driver",
        )
        await self._actions.record(
            kind=DriverActionKind.BOOKING_ACCEPTED,
            trip_id=booking.trip_id,
            driver_id=assignment.driver_id if assignment is not None else None,
            acted_as=ActedAs.ADMIN if as_admin else ActedAs.DRIVER,
            actor_id=actor_id,
            booking_id=booking.id,
        )
        await self._notifications.notify(
            booking.passenger_id,
            category=NotificationCategory.TRANSACTIONAL,
            title="Booking accepted",
            body=(
                f"Your booking {booking.booking_reference} was accepted. Pay within "
                f"{_minutes(hold)} to keep your seat."
            ),
            data={"booking_id": str(booking.id), "action": "pay"},
        )
        announce(
            self._session,
            "booking.accepted",
            booking_id=booking.id,
            trip_id=booking.trip_id,
            by="admin" if as_admin else "driver",
        )
        logger.info("booking_accepted", booking_id=str(booking.id), as_admin=as_admin)
        return booking

    async def decline(
        self,
        booking_id: uuid.UUID,
        *,
        actor_id: uuid.UUID,
        as_admin: bool,
        reason: str | None,
        move: bool = True,
        trip_id: uuid.UUID | None = None,
    ) -> Booking:
        """Turn a booking down on its trip. ``move``: put it to another trip
        going the same way, if there is one; otherwise it ends. An admin may
        also turn down a booking accepted but not yet paid for."""
        booking = await self._locked_booking(booking_id, trip_id)
        if not as_admin:
            await self._assert_assigned_driver(booking.trip_id, actor_id)
        offer = await self._offers.pending_for_booking(booking.id)
        if booking.status == BookingStatus.AWAITING_ACCEPTANCE and offer is not None:
            await self._offers.decide(
                offer, status=OfferStatus.DECLINED, decided_by=actor_id, reason=reason
            )
        elif not (as_admin and booking.status == BookingStatus.PENDING):
            raise _not_waiting(booking)

        assignment = await self._trips.get_active_driver_assignment(booking.trip_id)
        await self._actions.record(
            kind=DriverActionKind.BOOKING_DECLINED,
            trip_id=booking.trip_id,
            driver_id=assignment.driver_id if assignment is not None else None,
            acted_as=ActedAs.ADMIN if as_admin else ActedAs.DRIVER,
            actor_id=actor_id,
            booking_id=booking.id,
            reason=reason,
            details={"move": move},
        )
        ending = _Ending(
            status=BookingStatus.CANCELLED,
            reason=f"Declined: {reason}" if reason else "Declined",
            told="It could not be accepted",
        )
        if move:
            await self._move_or_end(
                booking, actor_id=actor_id, why="the driver could not take it", ending=ending
            )
        else:
            await self._end(booking, actor_id=actor_id, ending=ending)
        logger.info("booking_declined", booking_id=str(booking.id), as_admin=as_admin, move=move)
        return booking

    async def move_to(
        self, booking_id: uuid.UUID, trip_id: uuid.UUID, *, actor_id: uuid.UUID
    ) -> Booking:
        """An admin puts a booking not yet paid for to a trip of their choice
        (from the same pickup to the same destination)."""
        booking = await self._locked_booking(booking_id, None)
        if booking.status not in (BookingStatus.AWAITING_ACCEPTANCE, BookingStatus.PENDING):
            raise _not_waiting(booking)
        if booking.trip_id == trip_id:
            raise ConflictError("The booking is already on this trip.", code="SAME_TRIP")
        target = await self._trips.get_by_id(trip_id)
        current = await self._trips.get_by_id(booking.trip_id)
        if target is None or current is None:
            raise NotFoundError("Trip not found.")
        boards_at, alights_at = await self._segment(booking, current)
        if target.status not in self._bookable_statuses():
            raise ConflictError(
                "This trip is not currently open for booking.", code="TRIP_NOT_BOOKABLE"
            )
        if not await self._serves(target, boards_at, alights_at):
            raise ConflictError(
                "This trip does not go from the booking's pickup to its destination.",
                code="TRIP_DOES_NOT_SERVE_SEGMENT",
            )
        offer = await self._offers.pending_for_booking(booking.id)
        if offer is not None:
            await self._offers.decide(
                offer, status=OfferStatus.WITHDRAWN, decided_by=actor_id, reason="Moved by an admin"
            )
        await self._bookings.release_reservations_for_booking(
            booking.id, new_status=ReservationStatus.RELEASED
        )
        why = "our operations team moved it"
        if not await self._take(booking, target, boards_at, alights_at, actor_id, why):
            raise ConflictError(
                "That trip has no driver, or not enough seats free, for this booking.",
                code="TRIP_CANNOT_TAKE_BOOKING",
            )
        return booking

    # ------------------------------------------------------------------
    # Nobody answered
    # ------------------------------------------------------------------
    async def expire_unanswered(self, *, batch_size: int = 100) -> int:
        """Move (or end) bookings whose driver did not answer in time."""
        handled = 0
        for booking_id in await self._offers.unanswered_booking_ids(limit=batch_size):
            # Booking, then offer: the order every answer takes them in.
            booking = await self._bookings.get_for_update(booking_id)
            offer = await self._offers.pending_for_booking(booking_id)
            if booking is None or offer is None or offer.expires_at > datetime.now(UTC):
                continue  # answered meanwhile
            if booking.status != BookingStatus.AWAITING_ACCEPTANCE:
                await self._offers.decide(
                    offer, status=OfferStatus.WITHDRAWN, decided_by=None, reason="Already ended"
                )
                continue
            await self._offers.decide(
                offer, status=OfferStatus.EXPIRED, decided_by=None, reason="Not answered in time"
            )
            await self._actions.record(
                kind=DriverActionKind.BOOKING_UNANSWERED,
                trip_id=offer.trip_id,
                driver_id=offer.driver_id,
                acted_as=ActedAs.SYSTEM,
                actor_id=None,
                booking_id=booking.id,
            )
            await self._move_or_end(
                booking,
                actor_id=None,
                why="the driver did not answer in time",
                ending=_Ending(
                    status=BookingStatus.EXPIRED,
                    reason="No driver accepted it in time",
                    told="No driver accepted it in time",
                ),
            )
            handled += 1
        if handled:
            logger.info("unanswered_bookings_handled", count=handled)
        return handled

    # ------------------------------------------------------------------
    # Lists
    # ------------------------------------------------------------------
    async def requests_for_driver(
        self, user_id: uuid.UUID, *, trip_id: uuid.UUID | None, limit: int, offset: int
    ) -> tuple[list[BookingRequest], int]:
        driver = await self._drivers.get_by_user_id(user_id)
        if driver is None:
            raise ForbiddenError("No driver profile is associated with this account.")
        return await self._offers.list_requests(
            driver_id=driver.id, trip_id=trip_id, limit=limit, offset=offset
        )

    async def requests(
        self,
        *,
        driver_id: uuid.UUID | None,
        trip_id: uuid.UUID | None,
        limit: int,
        offset: int,
    ) -> tuple[list[BookingRequest], int]:
        return await self._offers.list_requests(
            driver_id=driver_id, trip_id=trip_id, limit=limit, offset=offset
        )

    # ------------------------------------------------------------------
    # Moving
    # ------------------------------------------------------------------
    async def _move_or_end(
        self, booking: Booking, *, actor_id: uuid.UUID | None, why: str, ending: _Ending
    ) -> None:
        # Its seats here are given up whatever happens next.
        await self._bookings.release_reservations_for_booking(
            booking.id, new_status=ReservationStatus.RELEASED
        )
        await self._forget_held_seats(booking.trip_id)
        offers = await self._offers.list_for_booking(booking.id)
        current = await self._trips.get_by_id(booking.trip_id)
        if current is not None and len(offers) - 1 < self._settings.BOOKING_MAX_MOVES:
            boards_at, alights_at = await self._segment(booking, current)
            tried = {offer.trip_id for offer in offers}
            for trip in await self._other_trips(current, boards_at, alights_at, tried):
                if await self._take(booking, trip, boards_at, alights_at, actor_id, why):
                    return
        await self._end(booking, actor_id=actor_id, ending=ending)

    async def _segment(self, booking: Booking, trip: Trip) -> tuple[uuid.UUID, uuid.UUID]:
        """Where the booking boards and alights, as stops (a booking for the
        whole route rides from its first stop to its last)."""
        geometry = (await self._geometries.for_routes([trip.route_id]))[trip.route_id]
        return (
            booking.origin_stop_id or geometry.origin_stop_id,
            booking.destination_stop_id or geometry.destination_stop_id,
        )

    def _bookable_statuses(self) -> tuple[TripStatus, ...]:
        if self._settings.BOOK_MOVING_TRIPS_ENABLED:
            return (TripStatus.SCHEDULED, TripStatus.BOARDING, TripStatus.IN_PROGRESS)
        return (TripStatus.SCHEDULED, TripStatus.BOARDING)

    async def _other_trips(
        self, current: Trip, boards_at: uuid.UUID, alights_at: uuid.UUID, tried: set[uuid.UUID]
    ) -> list[Trip]:
        """Trips from the same pickup to the same destination leaving near
        when ``current`` does, nearest first, not yet tried."""
        now = datetime.now(UTC)
        window = timedelta(minutes=self._settings.BOOKING_MOVE_WINDOW_MINUTES)
        departs = current.scheduled_departure_at
        trips, _ = await self._trips.search(
            origin_stop_ids=[boards_at],
            destination_stop_id=alights_at,
            departure_after=min(departs, now) - window,
            departure_before=max(departs, now) + window,
            statuses=list(self._bookable_statuses()),
            limit=_MOVE_CANDIDATES,
            offset=0,
            with_total=False,
        )
        return sorted(
            (trip for trip in trips if trip.id not in tried),
            key=lambda trip: abs(trip.scheduled_departure_at - departs),
        )

    async def _serves(self, trip: Trip, boards_at: uuid.UUID, alights_at: uuid.UUID) -> bool:
        order = (await self._geometries.for_routes([trip.route_id]))[trip.route_id].order
        return boards_at in order and alights_at in order and order[boards_at] < order[alights_at]

    async def _take(
        self,
        booking: Booking,
        trip: Trip,
        boards_at: uuid.UUID,
        alights_at: uuid.UUID,
        actor_id: uuid.UUID | None,
        why: str,
    ) -> bool:
        """Move the booking onto ``trip`` if it can take it: a driver, seats
        free for everyone on the booking, and the pickup still ahead."""
        if await self._trips.get_active_driver_assignment(trip.id) is None:
            return False
        if trip.status == TripStatus.IN_PROGRESS:
            geometry = (await self._geometries.for_routes([trip.route_id]))[trip.route_id]
            where = await latest_position(self._session, self._redis, self._settings, trip.id)
            if pickup_passed(trip, geometry, boards_at, where):
                return False
        passengers = await self._bookings.list_passengers(booking.id)
        seat_ids = await self._free_seats(trip, len(passengers))
        if seat_ids is None:
            return False
        claimed = await self._claim(trip, seat_ids, booking.id)
        if claimed is None:
            return False

        from_trip_id = booking.trip_id
        booking.trip_id = trip.id
        booking.origin_stop_id = boards_at
        booking.destination_stop_id = alights_at
        await self._seat(passengers, claimed)
        await self._bookings.set_status(
            booking,
            new_status=BookingStatus.AWAITING_ACCEPTANCE,
            changed_by=actor_id,
            reason=f"Moved to another vehicle: {why}",
        )
        await self._forget_held_seats(trip.id)
        leaves = (
            "already on its way"
            if trip.status == TripStatus.IN_PROGRESS
            else f"leaving at {trip.scheduled_departure_at:%H:%M}"
        )
        await self._notifications.notify(
            booking.passenger_id,
            category=NotificationCategory.TRANSACTIONAL,
            title="Moved to another vehicle",
            body=(
                f"Booking {booking.booking_reference} is now on another vehicle, {leaves}, "
                f"because {why}. It is waiting for that driver to accept. You have not been "
                "charged."
            ),
            data={"booking_id": str(booking.id), "trip_id": str(trip.id), "action": "moved"},
        )
        announce(
            self._session,
            "booking.moved",
            booking_id=booking.id,
            from_trip_id=from_trip_id,
            to_trip_id=trip.id,
            why=why,
        )
        await self._offer(booking, moved=True)
        logger.info(
            "booking_moved",
            booking_id=str(booking.id),
            from_trip_id=str(from_trip_id),
            to_trip_id=str(trip.id),
        )
        return True

    async def _free_seats(self, trip: Trip, count: int) -> list[uuid.UUID] | None:
        vehicle = await self._trips.get_vehicle_for_trip(trip.id)
        if vehicle is None:
            return None
        layout = await self._vehicles.get_seat_layout(vehicle.id)
        if layout is None:
            return None
        taken = await self._bookings.list_active_seat_ids_for_trip(trip.id)
        free = [
            seat.id
            for seat in await self._vehicles.list_seats(layout.id)
            if seat.is_active and seat.id not in taken
        ]
        return free if len(free) >= count else None

    async def _claim(
        self, trip: Trip, seat_ids: list[uuid.UUID], booking_id: uuid.UUID
    ) -> list[uuid.UUID] | None:
        """Reserve seats on ``trip`` for the booking, taking another free one
        when someone else gets there first. None: not enough left."""
        claimed: list[uuid.UUID] = []
        needed = len(await self._bookings.list_passengers(booking_id))
        for seat_id in seat_ids:
            if len(claimed) == needed:
                break
            try:
                await self._bookings.create_seat_reservation(
                    trip_id=trip.id, seat_id=seat_id, booking_id=booking_id, expires_at=None
                )
            except SeatAlreadyReservedError:
                continue
            claimed.append(seat_id)
        if len(claimed) < needed:
            await self._bookings.release_reservations_for_booking(
                booking_id, new_status=ReservationStatus.RELEASED
            )
            return None
        return claimed

    async def _seat(self, passengers: list[BookingPassenger], seat_ids: list[uuid.UUID]) -> None:
        """Give each passenger one of ``seat_ids``. Anyone already in one of
        them keeps it (the same vehicle can serve both trips), so no two
        passengers on the booking are ever in the same seat."""
        current = {passenger.seat_id for passenger in passengers}
        remaining = [seat_id for seat_id in seat_ids if seat_id not in current]
        for passenger in passengers:
            if passenger.seat_id not in seat_ids:
                passenger.seat_id = remaining.pop(0)
        await self._session.flush()

    async def _end(self, booking: Booking, *, actor_id: uuid.UUID | None, ending: _Ending) -> None:
        await self._bookings.release_reservations_for_booking(
            booking.id, new_status=ReservationStatus.RELEASED
        )
        await self._bookings.set_status(
            booking, new_status=ending.status, changed_by=actor_id, reason=ending.reason
        )
        await self._forget_held_seats(booking.trip_id)
        await self._notifications.notify(
            booking.passenger_id,
            category=NotificationCategory.TRANSACTIONAL,
            title="Booking not accepted",
            body=(
                f"Booking {booking.booking_reference}: {ending.told}, and no other vehicle "
                "going your way had a seat. You have not been charged. Please search again."
            ),
            data={"booking_id": str(booking.id), "action": "search_again"},
        )
        announce(
            self._session,
            "booking.not_accepted",
            booking_id=booking.id,
            trip_id=booking.trip_id,
            reason=ending.reason,
        )

    async def _forget_held_seats(self, trip_id: uuid.UUID) -> None:
        if self._redis is not None:
            await self._redis.delete(_held_seats_key(trip_id))

    # ------------------------------------------------------------------
    # Guards
    # ------------------------------------------------------------------
    async def _locked_booking(self, booking_id: uuid.UUID, trip_id: uuid.UUID | None) -> Booking:
        booking = await self._bookings.get_for_update(booking_id)
        if booking is None or (trip_id is not None and booking.trip_id != trip_id):
            raise NotFoundError("Booking not found.")
        return booking

    async def _assert_assigned_driver(self, trip_id: uuid.UUID, user_id: uuid.UUID) -> None:
        driver = await self._drivers.get_by_user_id(user_id)
        if driver is None:
            raise ForbiddenError("No driver profile is associated with this account.")
        assignment = await self._trips.get_active_driver_assignment(trip_id)
        if assignment is None or assignment.driver_id != driver.id:
            raise ForbiddenError("You are not the assigned driver for this trip.")

    async def _already_accepted(self, booking: Booking) -> bool:
        if booking.status not in (
            BookingStatus.PENDING,
            BookingStatus.PAYMENT_PENDING,
            BookingStatus.CONFIRMED,
        ):
            return False
        offers = await self._offers.list_for_booking(booking.id)
        return bool(offers) and offers[-1].status == OfferStatus.ACCEPTED


def _not_waiting(booking: Booking) -> InvalidStateTransitionError:
    return InvalidStateTransitionError(
        "This booking is not waiting to be accepted.",
        code="BOOKING_NOT_AWAITING_ACCEPTANCE",
        details={"status": booking.status.value},
    )


def _minutes(seconds: int) -> str:
    minutes = max(round(seconds / 60), 1)
    return f"{minutes} minute{'s' if minutes > 1 else ''}"
