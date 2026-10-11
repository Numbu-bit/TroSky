"""Database access for booking offers: a booking put to a trip's driver,
waiting to be accepted or declined (see ``BookingAcceptanceService``)."""

from __future__ import annotations

import uuid
from collections.abc import Collection
from dataclasses import dataclass
from datetime import UTC, datetime
from decimal import Decimal

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import aliased

from app.models.bookings import Booking, BookingOffer, BookingPassenger, OfferStatus
from app.models.routes import Stop
from app.models.trips import Trip, TripDriverAssignment
from app.models.vehicles import VehicleSeat


@dataclass(frozen=True, slots=True)
class BookingRequest:
    """A booking waiting for an answer, as the driver or an admin sees it."""

    offer_id: uuid.UUID
    booking_id: uuid.UUID
    booking_reference: str
    trip_id: uuid.UUID
    trip_departure_at: datetime
    driver_id: uuid.UUID | None
    expires_at: datetime
    passenger_count: int
    passenger_name: str | None
    seat_numbers: list[str]
    origin_stop_id: uuid.UUID | None
    origin_stop_name: str | None
    destination_stop_id: uuid.UUID | None
    destination_stop_name: str | None
    fare_amount: Decimal
    # 1 for the trip the passenger chose; 2 or more once moved to another.
    attempt: int


class BookingOfferRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def create(
        self,
        *,
        booking_id: uuid.UUID,
        trip_id: uuid.UUID,
        driver_id: uuid.UUID | None,
        expires_at: datetime,
    ) -> BookingOffer:
        offer = BookingOffer(
            # The moment it was made, not the transaction's start (``now()``):
            # a booking moved twice in one transaction keeps its offers in order.
            created_at=datetime.now(UTC),
            booking_id=booking_id,
            trip_id=trip_id,
            driver_id=driver_id,
            status=OfferStatus.PENDING,
            expires_at=expires_at,
        )
        self._session.add(offer)
        await self._session.flush()
        return offer

    async def pending_for_booking(self, booking_id: uuid.UUID) -> BookingOffer | None:
        result = await self._session.execute(
            select(BookingOffer)
            .where(
                BookingOffer.booking_id == booking_id, BookingOffer.status == OfferStatus.PENDING
            )
            .with_for_update()
        )
        return result.scalar_one_or_none()

    async def list_for_booking(self, booking_id: uuid.UUID) -> list[BookingOffer]:
        result = await self._session.execute(
            select(BookingOffer)
            .where(BookingOffer.booking_id == booking_id)
            .order_by(BookingOffer.created_at)
        )
        return list(result.scalars().all())

    async def decide(
        self,
        offer: BookingOffer,
        *,
        status: OfferStatus,
        decided_by: uuid.UUID | None,
        reason: str | None,
    ) -> None:
        offer.status = status
        offer.decided_at = datetime.now(UTC)
        offer.decided_by = decided_by
        offer.reason = reason
        await self._session.flush()

    async def withdraw_pending(self, booking_id: uuid.UUID, *, reason: str | None) -> None:
        offer = await self.pending_for_booking(booking_id)
        if offer is not None:
            await self.decide(offer, status=OfferStatus.WITHDRAWN, decided_by=None, reason=reason)

    async def unanswered_booking_ids(self, *, limit: int) -> list[uuid.UUID]:
        """Bookings whose offer ran out of time unanswered. Not locked: the
        caller locks each booking, then re-reads its offer."""
        result = await self._session.execute(
            select(BookingOffer.booking_id)
            .where(
                BookingOffer.status == OfferStatus.PENDING,
                BookingOffer.expires_at < datetime.now(UTC),
            )
            .order_by(BookingOffer.expires_at)
            .limit(limit)
        )
        return list(result.scalars().all())

    async def list_requests(
        self,
        *,
        driver_id: uuid.UUID | None = None,
        trip_id: uuid.UUID | None = None,
        limit: int = 100,
        offset: int = 0,
    ) -> tuple[list[BookingRequest], int]:
        """Bookings waiting for an answer, soonest deadline first. With
        ``driver_id``: only those on trips that driver is assigned to now."""
        origin = aliased(Stop)
        destination = aliased(Stop)
        conditions = [BookingOffer.status == OfferStatus.PENDING]
        if trip_id is not None:
            conditions.append(BookingOffer.trip_id == trip_id)
        if driver_id is not None:
            conditions.append(
                BookingOffer.trip_id.in_(
                    select(TripDriverAssignment.trip_id).where(
                        TripDriverAssignment.driver_id == driver_id,
                        TripDriverAssignment.is_active.is_(True),
                    )
                )
            )
        total = (
            await self._session.execute(
                select(func.count()).select_from(BookingOffer).where(*conditions)
            )
        ).scalar_one()
        earlier = aliased(BookingOffer, name="earlier")
        attempts = (
            select(func.count(earlier.id))
            .where(earlier.booking_id == BookingOffer.booking_id)
            .scalar_subquery()
        )
        rows = await self._session.execute(
            select(
                BookingOffer,
                Booking,
                Trip.scheduled_departure_at,
                TripDriverAssignment.driver_id,
                origin.name,
                destination.name,
                attempts,
            )
            .join(Booking, Booking.id == BookingOffer.booking_id)
            .join(Trip, Trip.id == BookingOffer.trip_id)
            .outerjoin(
                TripDriverAssignment,
                (TripDriverAssignment.trip_id == BookingOffer.trip_id)
                & TripDriverAssignment.is_active.is_(True),
            )
            .outerjoin(origin, origin.id == Booking.origin_stop_id)
            .outerjoin(destination, destination.id == Booking.destination_stop_id)
            .where(*conditions)
            .order_by(BookingOffer.expires_at, BookingOffer.id)
            .limit(limit)
            .offset(offset)
        )
        found = rows.all()
        seats = await self._seats_and_names([booking.id for _, booking, *_ in found])
        requests = [
            BookingRequest(
                offer_id=offer.id,
                booking_id=booking.id,
                booking_reference=booking.booking_reference,
                trip_id=offer.trip_id,
                trip_departure_at=departure,
                driver_id=assigned_driver_id,
                expires_at=offer.expires_at,
                passenger_count=booking.passenger_count,
                passenger_name=seats.get(booking.id, (None, []))[0],
                seat_numbers=seats.get(booking.id, (None, []))[1],
                origin_stop_id=booking.origin_stop_id,
                origin_stop_name=origin_name,
                destination_stop_id=booking.destination_stop_id,
                destination_stop_name=destination_name,
                fare_amount=booking.fare_amount,
                attempt=attempt,
            )
            for (
                offer,
                booking,
                departure,
                assigned_driver_id,
                origin_name,
                destination_name,
                attempt,
            ) in found
        ]
        return requests, total

    async def _seats_and_names(
        self, booking_ids: Collection[uuid.UUID]
    ) -> dict[uuid.UUID, tuple[str | None, list[str]]]:
        """Per booking: the first passenger's name and the seat numbers."""
        found: dict[uuid.UUID, tuple[str | None, list[str]]] = {}
        if not booking_ids:
            return found
        rows = await self._session.execute(
            select(BookingPassenger.booking_id, BookingPassenger.full_name, VehicleSeat.seat_number)
            .join(VehicleSeat, VehicleSeat.id == BookingPassenger.seat_id)
            .where(BookingPassenger.booking_id.in_(list(booking_ids)))
            .order_by(BookingPassenger.created_at, BookingPassenger.id)
        )
        for booking_id, name, seat_number in rows:
            first_name, numbers = found.get(booking_id, (name, []))
            found[booking_id] = (first_name, [*numbers, seat_number])
        return found
