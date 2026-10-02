"""Read models for trip lists: one query per page, not several per trip.

A list screen shows each trip with its route and end stops, its vehicle and
how full it is, and its driver. Looking those up trip by trip costs several
database round trips per row -- each ~0.2 s from Ghana to the cloud
database -- so these queries fetch a whole page at once. Used by the
driver's trip list, the admin and fleet trip lists and live maps, nearby
vehicles, and the trip summary embedded in bookings.
"""

from __future__ import annotations

import uuid
from collections.abc import Collection
from dataclasses import dataclass
from datetime import UTC, date, datetime, time, timedelta
from decimal import Decimal
from typing import Any

from sqlalchemy import ColumnElement, Select, and_, func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import aliased

from app.models.bookings import (
    Booking,
    BookingPassenger,
    BookingStatus,
    ReservationStatus,
    SeatReservation,
)
from app.models.drivers import Driver
from app.models.identity import User, UserProfile
from app.models.payments import Payment, PaymentStatus
from app.models.routes import Route, RouteStop, Stop
from app.models.tickets import Ticket, TicketStatus
from app.models.trips import Trip, TripDriverAssignment, TripStatus, TripVehicleAssignment
from app.models.vehicles import Vehicle, VehicleSeat, VehicleSeatLayout, VehicleType
from app.providers.payments.base import PaymentChannel

# Trips a vehicle is out on: what the live maps and "near me" show.
ACTIVE_TRIP_STATUSES = (TripStatus.BOARDING, TripStatus.IN_PROGRESS, TripStatus.PAUSED)


@dataclass(frozen=True, slots=True)
class TripSummary:
    trip_id: uuid.UUID
    route_id: uuid.UUID
    route_name: str
    origin_stop_id: uuid.UUID
    origin_stop_name: str
    destination_stop_id: uuid.UUID
    destination_stop_name: str
    scheduled_departure_at: datetime
    scheduled_arrival_at: datetime | None
    status: TripStatus
    # The operator's fare for the whole route, per seat.
    fare_amount: Decimal
    vehicle_id: uuid.UUID | None
    vehicle_registration_number: str | None
    vehicle_type: VehicleType | None
    vehicle_make: str | None
    vehicle_model: str | None
    vehicle_capacity: int | None
    fleet_id: uuid.UUID | None
    seats_total: int
    # Paid seats -- the passengers on the driver's manifest.
    seats_booked: int
    # Paid seats plus seats held for bookings awaiting payment: what nobody
    # else can book right now.
    seats_taken: int
    boarded_count: int
    driver_id: uuid.UUID | None
    driver_name: str | None
    driver_user_id: uuid.UUID | None

    @property
    def available_seats(self) -> int:
        return max(self.seats_total - self.seats_taken, 0)

    @property
    def vehicle_make_model(self) -> str | None:
        """ "Toyota Hiace", or whichever half is known."""
        return " ".join(part for part in (self.vehicle_make, self.vehicle_model) if part) or None


@dataclass(frozen=True, slots=True)
class ManifestEntry:
    ticket_id: uuid.UUID
    booking_reference: str
    seat_id: uuid.UUID
    seat_label: str
    passenger_full_name: str
    # The passenger's own number if one was given at booking, otherwise the
    # number of the account that booked the seat.
    phone_number: str
    pickup_stop_name: str
    dropoff_stop_name: str
    boarded: bool
    boarded_at: datetime | None


@dataclass(frozen=True, slots=True)
class PaidSeat:
    """One seat of a paid booking on a trip, with how it was paid."""

    booking_id: uuid.UUID
    booking_reference: str
    passenger_count: int
    booking_fare: Decimal
    channel: PaymentChannel
    paid_at: datetime | None
    passenger_name: str
    seat_label: str


def day_window(on_date: date | None) -> tuple[datetime | None, datetime | None]:
    """Departures on ``on_date`` (UTC, which is Ghana time), as a
    ``[start, end)`` pair; ``(None, None)`` for no date filter."""
    if on_date is None:
        return None, None
    start = datetime.combine(on_date, time.min, tzinfo=UTC)
    return start, start + timedelta(days=1)


_origin = aliased(Stop, name="origin_stop")
_destination = aliased(Stop, name="destination_stop")
_pickup = aliased(Stop, name="pickup_stop")
_dropoff = aliased(Stop, name="dropoff_stop")


def _reservations(*statuses: ReservationStatus) -> Any:
    return (
        select(func.count())
        .select_from(SeatReservation)
        .where(SeatReservation.trip_id == Trip.id, SeatReservation.status.in_(statuses))
        .correlate(Trip)
        .scalar_subquery()
    )


def _summary_columns() -> tuple[Any, ...]:
    layout_seats = (
        select(VehicleSeatLayout.total_seats)
        .where(VehicleSeatLayout.vehicle_id == Vehicle.id)
        .correlate(Vehicle)
        .scalar_subquery()
    )
    boarded = (
        select(func.count())
        .select_from(Ticket)
        .where(Ticket.trip_id == Trip.id, Ticket.status == TicketStatus.VALIDATED)
        .correlate(Trip)
        .scalar_subquery()
    )
    return (
        Trip.id,
        Trip.route_id,
        Route.name.label("route_name"),
        Route.origin_stop_id,
        Route.destination_stop_id,
        _origin.name.label("origin_stop_name"),
        _destination.name.label("destination_stop_name"),
        Trip.scheduled_departure_at,
        Trip.scheduled_arrival_at,
        Trip.status,
        Trip.fare_amount,
        Vehicle.id.label("vehicle_id"),
        Vehicle.registration_number,
        Vehicle.vehicle_type,
        Vehicle.make.label("vehicle_make"),
        Vehicle.model.label("vehicle_model"),
        Vehicle.capacity.label("vehicle_capacity"),
        Vehicle.fleet_id,
        # Seats configured on the layout, else the vehicle's rated capacity.
        func.coalesce(layout_seats, Vehicle.capacity, 0).label("seats_total"),
        _reservations(ReservationStatus.CONFIRMED).label("seats_booked"),
        _reservations(ReservationStatus.HELD, ReservationStatus.CONFIRMED).label("seats_taken"),
        boarded.label("boarded_count"),
        Driver.id.label("driver_id"),
        UserProfile.full_name.label("driver_name"),
        Driver.user_id.label("driver_user_id"),
    )


def _joined(*columns: Any) -> Select[Any]:
    # A trip has at most one active vehicle and one active driver assignment
    # (partial unique indexes), so these joins never multiply rows.
    return (
        select(*columns)
        .select_from(Trip)
        .join(Route, Route.id == Trip.route_id)
        .join(_origin, _origin.id == Route.origin_stop_id)
        .join(_destination, _destination.id == Route.destination_stop_id)
        .outerjoin(
            TripVehicleAssignment,
            and_(
                TripVehicleAssignment.trip_id == Trip.id,
                TripVehicleAssignment.is_active.is_(True),
            ),
        )
        .outerjoin(Vehicle, Vehicle.id == TripVehicleAssignment.vehicle_id)
        .outerjoin(
            TripDriverAssignment,
            and_(
                TripDriverAssignment.trip_id == Trip.id,
                TripDriverAssignment.is_active.is_(True),
            ),
        )
        .outerjoin(Driver, Driver.id == TripDriverAssignment.driver_id)
        .outerjoin(UserProfile, UserProfile.user_id == Driver.user_id)
    )


def _to_summary(row: Any) -> TripSummary:
    return TripSummary(
        trip_id=row.id,
        route_id=row.route_id,
        route_name=row.route_name,
        origin_stop_id=row.origin_stop_id,
        origin_stop_name=row.origin_stop_name,
        destination_stop_id=row.destination_stop_id,
        destination_stop_name=row.destination_stop_name,
        scheduled_departure_at=row.scheduled_departure_at,
        scheduled_arrival_at=row.scheduled_arrival_at,
        status=row.status,
        fare_amount=row.fare_amount,
        vehicle_id=row.vehicle_id,
        vehicle_registration_number=row.registration_number,
        vehicle_type=row.vehicle_type,
        vehicle_make=row.vehicle_make,
        vehicle_model=row.vehicle_model,
        vehicle_capacity=row.vehicle_capacity,
        fleet_id=row.fleet_id,
        seats_total=row.seats_total,
        seats_booked=row.seats_booked,
        seats_taken=row.seats_taken,
        boarded_count=row.boarded_count,
        driver_id=row.driver_id,
        driver_name=row.driver_name,
        driver_user_id=row.driver_user_id,
    )


class TripViewRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def list_summaries(
        self,
        *,
        driver_id: uuid.UUID | None = None,
        route_id: uuid.UUID | None = None,
        fleet_id: uuid.UUID | None = None,
        statuses: Collection[TripStatus] | None = None,
        departure_from: datetime | None = None,
        departure_before: datetime | None = None,
        limit: int,
        offset: int,
    ) -> tuple[list[TripSummary], int]:
        """Trips matching every given filter, soonest departure first."""
        conditions: list[ColumnElement[bool]] = []
        if driver_id is not None:
            conditions.append(TripDriverAssignment.driver_id == driver_id)
        if route_id is not None:
            conditions.append(Trip.route_id == route_id)
        if fleet_id is not None:
            conditions.append(Vehicle.fleet_id == fleet_id)
        if statuses:
            conditions.append(Trip.status.in_(list(statuses)))
        if departure_from is not None:
            conditions.append(Trip.scheduled_departure_at >= departure_from)
        if departure_before is not None:
            conditions.append(Trip.scheduled_departure_at < departure_before)

        total = (
            await self._session.execute(_joined(func.count(Trip.id)).where(*conditions))
        ).scalar_one()
        rows = (
            await self._session.execute(
                _joined(*_summary_columns())
                .where(*conditions)
                .order_by(Trip.scheduled_departure_at, Trip.id)
                .limit(limit)
                .offset(offset)
            )
        ).all()
        return [_to_summary(row) for row in rows], total

    async def summaries_by_ids(
        self, trip_ids: Collection[uuid.UUID]
    ) -> dict[uuid.UUID, TripSummary]:
        if not trip_ids:
            return {}
        rows = (
            await self._session.execute(
                _joined(*_summary_columns()).where(Trip.id.in_(list(trip_ids)))
            )
        ).all()
        return {row.id: _to_summary(row) for row in rows}

    async def list_paid_seats(self, trip_id: uuid.UUID) -> list[PaidSeat]:
        """Every seat on the trip that has been paid for and not refunded or
        cancelled since, in seat order."""
        rows = (
            await self._session.execute(
                select(
                    Booking.id,
                    Booking.booking_reference,
                    Booking.passenger_count,
                    Booking.fare_amount,
                    Payment.channel,
                    Payment.completed_at,
                    BookingPassenger.full_name,
                    VehicleSeat.seat_number,
                )
                .select_from(Booking)
                .join(
                    Payment,
                    and_(
                        Payment.booking_id == Booking.id,
                        Payment.status == PaymentStatus.SUCCESSFUL,
                    ),
                )
                .join(BookingPassenger, BookingPassenger.booking_id == Booking.id)
                .join(VehicleSeat, VehicleSeat.id == BookingPassenger.seat_id)
                .where(
                    Booking.trip_id == trip_id,
                    Booking.status.in_([BookingStatus.CONFIRMED, BookingStatus.COMPLETED]),
                )
                .order_by(VehicleSeat.row_number, VehicleSeat.column_number)
            )
        ).all()
        return [
            PaidSeat(
                booking_id=row.id,
                booking_reference=row.booking_reference,
                passenger_count=row.passenger_count,
                booking_fare=row.fare_amount,
                channel=row.channel,
                paid_at=row.completed_at,
                passenger_name=row.full_name,
                seat_label=row.seat_number,
            )
            for row in rows
        ]

    async def list_manifest(self, trip_id: uuid.UUID) -> list[ManifestEntry]:
        """Everyone holding a ticket for the trip, in pickup order along the
        route. Revoked tickets (cancelled bookings) are left out."""
        rows = (
            await self._session.execute(
                select(
                    Ticket.id,
                    Booking.booking_reference,
                    BookingPassenger.seat_id,
                    VehicleSeat.seat_number,
                    BookingPassenger.full_name,
                    func.coalesce(BookingPassenger.phone_number, User.phone_number).label(
                        "phone_number"
                    ),
                    _pickup.name.label("pickup_stop_name"),
                    _dropoff.name.label("dropoff_stop_name"),
                    Ticket.status,
                    Ticket.validated_at,
                )
                .select_from(Ticket)
                .join(Booking, Booking.id == Ticket.booking_id)
                .join(BookingPassenger, BookingPassenger.id == Ticket.booking_passenger_id)
                .join(VehicleSeat, VehicleSeat.id == BookingPassenger.seat_id)
                .join(User, User.id == Booking.passenger_id)
                .join(Trip, Trip.id == Ticket.trip_id)
                .join(Route, Route.id == Trip.route_id)
                # A booking with no boarding stop rides from the route's start,
                # one with no destination to its end.
                .join(
                    _pickup,
                    _pickup.id == func.coalesce(Booking.origin_stop_id, Route.origin_stop_id),
                )
                .join(
                    _dropoff,
                    _dropoff.id
                    == func.coalesce(Booking.destination_stop_id, Route.destination_stop_id),
                )
                .outerjoin(
                    RouteStop, and_(RouteStop.route_id == Route.id, RouteStop.stop_id == _pickup.id)
                )
                .where(Ticket.trip_id == trip_id, Ticket.status != TicketStatus.REVOKED)
                .order_by(
                    RouteStop.sequence_number.nulls_first(),
                    VehicleSeat.row_number,
                    VehicleSeat.column_number,
                )
            )
        ).all()
        return [
            ManifestEntry(
                ticket_id=row.id,
                booking_reference=row.booking_reference,
                seat_id=row.seat_id,
                seat_label=row.seat_number,
                passenger_full_name=row.full_name,
                phone_number=row.phone_number,
                pickup_stop_name=row.pickup_stop_name,
                dropoff_stop_name=row.dropoff_stop_name,
                boarded=row.status == TicketStatus.VALIDATED,
                boarded_at=row.validated_at,
            )
            for row in rows
        ]
