"""Database access for bookings, booking passengers, seat reservations,
status history, and cancellation requests.

``create_seat_reservation`` is the concurrency-critical operation: it
attempts the INSERT inside a ``SAVEPOINT`` (``session.begin_nested()``) so
that a unique-constraint violation — another request having already won
the same seat — can be caught and translated without poisoning the rest of
the (possibly multi-seat) booking transaction.
"""

from __future__ import annotations

import secrets
import string
import uuid
from collections.abc import Collection
from datetime import UTC, datetime
from decimal import Decimal

from sqlalchemy import func, not_, or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.bookings import (
    Booking,
    BookingPassenger,
    BookingStatus,
    BookingStatusHistory,
    CancellationRequest,
    CancellationStatus,
    ReservationStatus,
    SeatReservation,
)
from app.models.trips import Trip
from app.repositories.trip_view_repository import ACTIVE_TRIP_STATUSES

_REFERENCE_ALPHABET = string.ascii_uppercase + string.digits


# A seat is only "aboard" while the booking still holds it: pending and
# payment_pending hold a reservation that has not lapsed, confirmed and
# completed have travelled. Cancelled, expired and refunded bookings freed
# their seat, so they neither block it nor share its cost.
_OCCUPYING_STATUSES = (
    BookingStatus.PENDING,
    BookingStatus.PAYMENT_PENDING,
    BookingStatus.CONFIRMED,
    BookingStatus.COMPLETED,
)


class SeatAlreadyReservedError(Exception):
    """Raised when a seat's active reservation already exists (another
    request won the race). Caught by the service layer and translated to
    the client-facing ``SeatNotAvailableError``."""


class BookingRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    def generate_booking_reference(self) -> str:
        suffix = "".join(secrets.choice(_REFERENCE_ALPHABET) for _ in range(8))
        return f"TRK-{suffix}"

    async def create_booking(
        self,
        *,
        passenger_id: uuid.UUID,
        trip_id: uuid.UUID,
        passenger_count: int,
        origin_stop_id: uuid.UUID | None,
        destination_stop_id: uuid.UUID | None,
        fare_amount: Decimal,
        platform_fee: Decimal,
        total_amount: Decimal,
        expires_at: datetime | None,
        idempotency_key: uuid.UUID | None,
        idempotency_request_hash: str | None,
    ) -> Booking:
        booking = Booking(
            booking_reference=self.generate_booking_reference(),
            passenger_id=passenger_id,
            trip_id=trip_id,
            passenger_count=passenger_count,
            origin_stop_id=origin_stop_id,
            destination_stop_id=destination_stop_id,
            fare_amount=fare_amount,
            platform_fee=platform_fee,
            total_amount=total_amount,
            expires_at=expires_at,
            idempotency_key=idempotency_key,
            idempotency_request_hash=idempotency_request_hash,
        )
        self._session.add(booking)
        await self._session.flush()
        return booking

    async def get_by_id(self, booking_id: uuid.UUID) -> Booking | None:
        result = await self._session.execute(select(Booking).where(Booking.id == booking_id))
        return result.scalar_one_or_none()

    async def get_for_update(self, booking_id: uuid.UUID) -> Booking | None:
        result = await self._session.execute(
            select(Booking).where(Booking.id == booking_id).with_for_update()
        )
        return result.scalar_one_or_none()

    async def get_by_reference(self, booking_reference: str) -> Booking | None:
        result = await self._session.execute(
            select(Booking).where(Booking.booking_reference == booking_reference)
        )
        return result.scalar_one_or_none()

    async def get_by_idempotency_key(
        self, passenger_id: uuid.UUID, idempotency_key: uuid.UUID
    ) -> Booking | None:
        result = await self._session.execute(
            select(Booking).where(
                Booking.passenger_id == passenger_id, Booking.idempotency_key == idempotency_key
            )
        )
        return result.scalar_one_or_none()

    async def list_for_passenger(
        self,
        passenger_id: uuid.UUID,
        *,
        statuses: Collection[BookingStatus] | None = None,
        upcoming: bool | None = None,
        limit: int,
        offset: int,
    ) -> tuple[list[Booking], int]:
        """A passenger's bookings, optionally narrowed to some statuses and
        to trips still ahead (``upcoming=True``) or behind them (``False``).

        "Upcoming" means the trip has not finished: it departs now or later,
        or is under way (boarding, in progress, paused). Upcoming bookings
        come soonest first, past ones most recent first, and unfiltered ones
        newest booking first.
        """
        stmt = select(Booking).where(Booking.passenger_id == passenger_id)
        if statuses:
            stmt = stmt.where(Booking.status.in_(list(statuses)))
        order_by = [Booking.created_at.desc()]
        if upcoming is not None:
            stmt = stmt.join(Trip, Trip.id == Booking.trip_id)
            ahead = or_(
                Trip.scheduled_departure_at >= datetime.now(UTC),
                Trip.status.in_(ACTIVE_TRIP_STATUSES),
            )
            stmt = stmt.where(ahead if upcoming else not_(ahead))
            departure = Trip.scheduled_departure_at
            order_by = [departure.asc() if upcoming else departure.desc(), *order_by]
        # COUNT(*) in the database: fetching every matching id just to len()
        # them costs memory and transfer proportional to the whole history.
        total = (
            await self._session.execute(select(func.count()).select_from(stmt.subquery()))
        ).scalar_one()
        result = await self._session.execute(stmt.order_by(*order_by).limit(limit).offset(offset))
        return list(result.scalars().all()), total

    async def list_all(
        self, *, status: BookingStatus | None, limit: int, offset: int
    ) -> tuple[list[Booking], int]:
        stmt = select(Booking)
        if status is not None:
            stmt = stmt.where(Booking.status == status)
        total = (
            await self._session.execute(select(func.count()).select_from(stmt.subquery()))
        ).scalar_one()
        result = await self._session.execute(
            stmt.order_by(Booking.created_at.desc()).limit(limit).offset(offset)
        )
        return list(result.scalars().all()), total

    async def record_creation(self, booking: Booking, *, created_by: uuid.UUID | None) -> None:
        self._session.add(
            BookingStatusHistory(
                booking_id=booking.id,
                from_status=None,
                to_status=booking.status,
                changed_by=created_by,
                reason="Booking created",
            )
        )
        await self._session.flush()

    async def set_status(
        self,
        booking: Booking,
        *,
        new_status: BookingStatus,
        changed_by: uuid.UUID | None,
        reason: str | None,
    ) -> None:
        previous = booking.status
        booking.status = new_status
        self._session.add(
            BookingStatusHistory(
                booking_id=booking.id,
                from_status=previous,
                to_status=new_status,
                changed_by=changed_by,
                reason=reason,
            )
        )
        await self._session.flush()

    async def add_passenger(
        self, *, booking_id: uuid.UUID, seat_id: uuid.UUID, full_name: str, phone_number: str | None
    ) -> BookingPassenger:
        passenger = BookingPassenger(
            booking_id=booking_id, seat_id=seat_id, full_name=full_name, phone_number=phone_number
        )
        self._session.add(passenger)
        await self._session.flush()
        return passenger

    async def list_passengers(self, booking_id: uuid.UUID) -> list[BookingPassenger]:
        result = await self._session.execute(
            select(BookingPassenger).where(BookingPassenger.booking_id == booking_id)
        )
        return list(result.scalars().all())

    # ------------------------------------------------------------------
    # Seat reservations (concurrency-critical)
    # ------------------------------------------------------------------
    async def list_passengers_for_bookings(
        self, booking_ids: Collection[uuid.UUID]
    ) -> dict[uuid.UUID, list[BookingPassenger]]:
        """Passengers for a page of bookings, in one query."""
        grouped: dict[uuid.UUID, list[BookingPassenger]] = {
            booking_id: [] for booking_id in booking_ids
        }
        if not grouped:
            return grouped
        result = await self._session.execute(
            select(BookingPassenger)
            .where(BookingPassenger.booking_id.in_(list(grouped)))
            .order_by(BookingPassenger.created_at, BookingPassenger.id)
        )
        for passenger in result.scalars().all():
            grouped[passenger.booking_id].append(passenger)
        return grouped

    async def create_seat_reservation(
        self,
        *,
        trip_id: uuid.UUID,
        seat_id: uuid.UUID,
        booking_id: uuid.UUID,
        expires_at: datetime | None,
    ) -> SeatReservation:
        reservation = SeatReservation(
            trip_id=trip_id, seat_id=seat_id, booking_id=booking_id, expires_at=expires_at
        )
        try:
            async with self._session.begin_nested():
                self._session.add(reservation)
                await self._session.flush()
        except IntegrityError as exc:
            raise SeatAlreadyReservedError(str(seat_id)) from exc
        return reservation

    async def sum_passenger_km_for_trip(
        self,
        trip_id: uuid.UUID,
        *,
        stop_distances: dict[uuid.UUID, Decimal | None],
        route_km: Decimal | None,
    ) -> Decimal:
        """Total passenger-kilometres already committed on this trip.

        Every seat contributes the distance it rides, and those distances
        are the weights the trip's cost is divided by. A booking that never
        named its stops rode end to end, so it contributes the whole route;
        the same applies when a named stop has no measured offset, since
        under-counting here would silently overcharge everyone else.
        """
        result = await self._session.execute(
            select(Booking).where(
                Booking.trip_id == trip_id,
                Booking.status.in_(_OCCUPYING_STATUSES),
            )
        )
        whole_route = route_km or Decimal("0")
        total = Decimal("0")
        for booking in result.scalars().all():
            origin = stop_distances.get(booking.origin_stop_id) if booking.origin_stop_id else None
            destination = (
                stop_distances.get(booking.destination_stop_id)
                if booking.destination_stop_id
                else None
            )
            if origin is None or destination is None:
                distance = whole_route
            else:
                distance = abs(destination - origin) or whole_route
            total += distance * booking.passenger_count
        return total

    async def list_active_seat_ids_for_trip(self, trip_id: uuid.UUID) -> set[uuid.UUID]:
        result = await self._session.execute(
            select(SeatReservation.seat_id).where(
                SeatReservation.trip_id == trip_id,
                SeatReservation.status.in_([ReservationStatus.HELD, ReservationStatus.CONFIRMED]),
            )
        )
        return set(result.scalars().all())

    async def list_reservations_for_booking(self, booking_id: uuid.UUID) -> list[SeatReservation]:
        result = await self._session.execute(
            select(SeatReservation).where(SeatReservation.booking_id == booking_id)
        )
        return list(result.scalars().all())

    async def confirm_reservations_for_booking(self, booking_id: uuid.UUID) -> None:
        reservations = await self.list_reservations_for_booking(booking_id)
        now = datetime.now(UTC)
        for reservation in reservations:
            if reservation.status == ReservationStatus.HELD:
                reservation.status = ReservationStatus.CONFIRMED
                reservation.confirmed_at = now
                reservation.expires_at = None
        await self._session.flush()

    async def release_reservations_for_booking(
        self, booking_id: uuid.UUID, *, new_status: ReservationStatus
    ) -> None:
        reservations = await self.list_reservations_for_booking(booking_id)
        now = datetime.now(UTC)
        for reservation in reservations:
            if reservation.status in (ReservationStatus.HELD, ReservationStatus.CONFIRMED):
                reservation.status = new_status
                reservation.released_at = now
        await self._session.flush()

    async def list_confirmed_for_trip(self, trip_id: uuid.UUID) -> list[Booking]:
        result = await self._session.execute(
            select(Booking).where(
                Booking.trip_id == trip_id, Booking.status == BookingStatus.CONFIRMED
            )
        )
        return list(result.scalars().all())

    async def find_expirable_bookings(self, *, limit: int) -> list[Booking]:
        """Row-locks (``FOR UPDATE SKIP LOCKED``) a batch of expired,
        still-pending bookings so multiple concurrent sweep workers never
        double-process the same booking."""
        now = datetime.now(UTC)
        stmt = (
            select(Booking)
            .where(
                Booking.status.in_([BookingStatus.PENDING, BookingStatus.PAYMENT_PENDING]),
                Booking.expires_at.is_not(None),
                Booking.expires_at < now,
            )
            .limit(limit)
            .with_for_update(skip_locked=True)
        )
        result = await self._session.execute(stmt)
        return list(result.scalars().all())

    # ------------------------------------------------------------------
    # Cancellation requests
    # ------------------------------------------------------------------
    async def create_cancellation_request(
        self,
        *,
        booking_id: uuid.UUID,
        requested_by: uuid.UUID | None,
        reason: str | None,
        status: CancellationStatus,
        refund_eligible: bool,
        decided_by: uuid.UUID | None = None,
        decided_at: datetime | None = None,
        decision_notes: str | None = None,
    ) -> CancellationRequest:
        request = CancellationRequest(
            booking_id=booking_id,
            requested_by=requested_by,
            reason=reason,
            status=status,
            refund_eligible=refund_eligible,
            decided_by=decided_by,
            decided_at=decided_at,
            decision_notes=decision_notes,
        )
        self._session.add(request)
        await self._session.flush()
        return request

    async def get_cancellation_request_for_update(
        self, request_id: uuid.UUID
    ) -> CancellationRequest | None:
        result = await self._session.execute(
            select(CancellationRequest)
            .where(CancellationRequest.id == request_id)
            .with_for_update()
        )
        return result.scalar_one_or_none()

    async def list_cancellation_requests(
        self, *, status: CancellationStatus | None, limit: int, offset: int
    ) -> tuple[list[CancellationRequest], int]:
        stmt = select(CancellationRequest)
        if status is not None:
            stmt = stmt.where(CancellationRequest.status == status)
        count_result = await self._session.execute(
            select(func.count()).select_from(stmt.subquery())
        )
        total = count_result.scalar_one()
        result = await self._session.execute(
            stmt.order_by(CancellationRequest.created_at.desc()).limit(limit).offset(offset)
        )
        return list(result.scalars().all()), total

    async def decide_cancellation_request(
        self,
        request: CancellationRequest,
        *,
        status: CancellationStatus,
        refund_eligible: bool,
        decided_by: uuid.UUID | None,
        decided_at: datetime,
        decision_notes: str | None,
    ) -> None:
        request.status = status
        request.refund_eligible = refund_eligible
        request.decided_by = decided_by
        request.decided_at = decided_at
        request.decision_notes = decision_notes
        await self._session.flush()
