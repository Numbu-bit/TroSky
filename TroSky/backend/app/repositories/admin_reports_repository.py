"""Queries behind ``/admin/reports/{report}``.

Time-series reports reuse the dashboard's ``DailyFigure`` definitions, so a
report and the analytics agree to the cedi. Here they are counted per day,
week or month (Ghana calendar), and can be narrowed to a city (where the
trip starts), a route or a fleet; a figure that cannot be tied to a trip is
left out when any of those is chosen. Every figure goes in one round trip.
"""

from __future__ import annotations

import uuid
from collections import defaultdict
from collections.abc import Sequence
from dataclasses import dataclass
from datetime import date, datetime
from decimal import Decimal
from typing import Any, Literal

from sqlalchemy import (
    ColumnElement,
    String,
    cast,
    distinct,
    exists,
    func,
    literal,
    select,
    union_all,
)
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import aliased

from app.models.analytics import SearchEvent
from app.models.bookings import Booking, BookingStatus
from app.models.routes import Route, Stop
from app.models.tickets import Ticket, TicketStatus
from app.models.trips import Trip, TripStatus, TripVehicleAssignment
from app.models.vehicles import Vehicle
from app.repositories.admin_analytics_repository import TIMEZONE, DailyFigure

Granularity = Literal["day", "week", "month"]

PAID_BOOKINGS = (
    BookingStatus.CONFIRMED,
    BookingStatus.COMPLETED,
    BookingStatus.REFUND_PENDING,
    BookingStatus.REFUNDED,
)


@dataclass(frozen=True, slots=True)
class Scope:
    city: str | None = None
    route_id: uuid.UUID | None = None
    fleet_id: uuid.UUID | None = None

    @property
    def narrowed(self) -> bool:
        return self.city is not None or self.route_id is not None or self.fleet_id is not None


def ghana(column: Any) -> Any:
    return func.timezone(TIMEZONE, column)


def bucket(column: Any, granularity: Granularity) -> Any:
    """The day, or first day of the week (Monday) or month, holding
    ``column`` in Ghana."""
    return func.date(func.date_trunc(granularity, ghana(column)))


def in_scope(trip_id: Any, scope: Scope) -> list[ColumnElement[bool]]:
    """Conditions tying ``trip_id`` to the scope's city, route and fleet."""
    trip, route, origin = aliased(Trip), aliased(Route), aliased(Stop)
    conditions: list[ColumnElement[bool]] = []
    if scope.route_id is not None or scope.city is not None:
        routed = select(trip.id).join(route, route.id == trip.route_id).where(trip.id == trip_id)
        if scope.route_id is not None:
            routed = routed.where(trip.route_id == scope.route_id)
        if scope.city is not None:
            routed = routed.join(origin, origin.id == route.origin_stop_id).where(
                func.lower(origin.city) == scope.city.strip().lower()
            )
        conditions.append(exists(routed))
    if scope.fleet_id is not None:
        conditions.append(
            exists(
                select(TripVehicleAssignment.id)
                .join(Vehicle, Vehicle.id == TripVehicleAssignment.vehicle_id)
                .where(
                    TripVehicleAssignment.trip_id == trip_id,
                    TripVehicleAssignment.is_active.is_(True),
                    Vehicle.fleet_id == scope.fleet_id,
                )
            )
        )
    return conditions


class AdminReportsRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def series(
        self,
        figures: Sequence[DailyFigure],
        *,
        start: datetime,
        end: datetime,
        granularity: Granularity,
        scope: Scope,
    ) -> dict[str, dict[date, Decimal]]:
        """``{figure: {bucket: value}}`` for rows dated in ``[start, end)``.
        A figure missing from the result does not apply to the scope."""
        selects = []
        for figure in figures:
            if scope.narrowed and figure.trip_id is None:
                continue
            when = bucket(figure.timestamp, granularity).label("bucket")
            name: Any = literal(figure.name)
            if figure.group is not None:
                name = func.concat(figure.name, ":", cast(figure.group, String))
            stmt = figure.base.with_only_columns(
                name.label("figure"), when, figure.value.label("value")
            ).where(figure.timestamp >= start, figure.timestamp < end, *figure.conditions)
            if scope.narrowed:
                stmt = stmt.where(*in_scope(figure.trip_id, scope))
            group = (when, figure.group) if figure.group is not None else (when,)
            selects.append(stmt.group_by(*group))
        out: dict[str, dict[date, Decimal]] = defaultdict(dict)
        if selects:
            for name, day, value in await self._session.execute(union_all(*selects)):
                out[name][day] = Decimal(str(value or 0))
        for figure in figures:
            if figure.group is None and (not scope.narrowed or figure.trip_id is not None):
                out.setdefault(figure.name, {})
        return out

    async def count_before(self, figure: DailyFigure, moment: datetime) -> int:
        """All of ``figure`` before ``moment``: where a cumulative count starts."""
        stmt = figure.base.with_only_columns(figure.value).where(
            figure.timestamp < moment, *figure.conditions
        )
        return int(await self._session.scalar(stmt) or 0)

    # ------------------------------------------------------------ peak hours
    async def by_hour(
        self, *, start: datetime, end: datetime, scope: Scope
    ) -> dict[str, dict[int, int]]:
        """Per Ghana hour of the day: trips departing (not cancelled), seats
        booked on them, passengers boarded, bookings made, searches."""
        hour = func.extract("hour", ghana(Trip.scheduled_departure_at))
        trips = (
            select(
                hour.label("hour"),
                func.count(distinct(Trip.id)).label("trips"),
            )
            .where(
                Trip.scheduled_departure_at >= start,
                Trip.scheduled_departure_at < end,
                Trip.status != TripStatus.CANCELLED,
                *in_scope(Trip.id, scope),
            )
            .group_by(hour)
        )
        seats = (
            select(hour.label("hour"), func.coalesce(func.sum(Booking.passenger_count), 0))
            .select_from(Booking)
            .join(Trip, Trip.id == Booking.trip_id)
            .where(
                Trip.scheduled_departure_at >= start,
                Trip.scheduled_departure_at < end,
                Trip.status != TripStatus.CANCELLED,
                Booking.status.in_(PAID_BOOKINGS),
                *in_scope(Trip.id, scope),
            )
            .group_by(hour)
        )
        boarded = (
            select(hour.label("hour"), func.count(Ticket.id))
            .select_from(Ticket)
            .join(Trip, Trip.id == Ticket.trip_id)
            .where(
                Trip.scheduled_departure_at >= start,
                Trip.scheduled_departure_at < end,
                Ticket.status == TicketStatus.VALIDATED,
                *in_scope(Trip.id, scope),
            )
            .group_by(hour)
        )
        booked_at = func.extract("hour", ghana(Booking.created_at))
        bookings = (
            select(booked_at.label("hour"), func.count(Booking.id))
            .where(
                Booking.created_at >= start,
                Booking.created_at < end,
                *in_scope(Booking.trip_id, scope),
            )
            .group_by(booked_at)
        )
        out: dict[str, dict[int, int]] = {}
        for name, stmt in (
            ("trips", trips),
            ("seats_booked", seats),
            ("passengers_boarded", boarded),
            ("bookings_made", bookings),
        ):
            out[name] = {int(h): int(n) for h, n in (await self._session.execute(stmt)).all()}
        if not scope.narrowed:
            searched_at = func.extract("hour", ghana(SearchEvent.searched_at))
            searches = (
                select(searched_at, func.count())
                .where(SearchEvent.searched_at >= start, SearchEvent.searched_at < end)
                .group_by(searched_at)
            )
            out["searches"] = {
                int(h): int(n) for h, n in (await self._session.execute(searches)).all()
            }
        return out

    # ------------------------------------------------------ route popularity
    async def by_route(
        self, *, start: datetime, end: datetime, scope: Scope
    ) -> list[dict[str, Any]]:
        """Per route, for trips departing in ``[start, end)``: trips run and
        cancelled, seats offered and booked, passengers boarded, fares and
        cancelled bookings."""
        departing = (
            Trip.scheduled_departure_at >= start,
            Trip.scheduled_departure_at < end,
            *in_scope(Trip.id, scope),
        )
        origin, destination = aliased(Stop), aliased(Stop)
        trips = (
            select(
                Trip.route_id,
                func.count().filter(Trip.status == TripStatus.COMPLETED).label("completed"),
                func.count().filter(Trip.status == TripStatus.CANCELLED).label("cancelled"),
            )
            .where(*departing)
            .group_by(Trip.route_id)
            .subquery()
        )
        offered = (
            select(Trip.route_id, func.sum(Vehicle.capacity).label("seats"))
            .join(
                TripVehicleAssignment,
                (TripVehicleAssignment.trip_id == Trip.id)
                & TripVehicleAssignment.is_active.is_(True),
            )
            .join(Vehicle, Vehicle.id == TripVehicleAssignment.vehicle_id)
            .where(*departing, Trip.status == TripStatus.COMPLETED)
            .group_by(Trip.route_id)
            .subquery()
        )
        booked = (
            select(
                Trip.route_id,
                func.coalesce(
                    func.sum(Booking.passenger_count).filter(Booking.status.in_(PAID_BOOKINGS)), 0
                ).label("seats"),
                func.coalesce(
                    func.sum(Booking.fare_amount).filter(Booking.status.in_(PAID_BOOKINGS)), 0
                ).label("fares"),
                func.count()
                .filter(
                    Booking.status.in_(
                        (
                            BookingStatus.CANCELLED,
                            BookingStatus.REFUND_PENDING,
                            BookingStatus.REFUNDED,
                        )
                    )
                )
                .label("cancelled"),
            )
            .join(Trip, Trip.id == Booking.trip_id)
            .where(*departing)
            .group_by(Trip.route_id)
            .subquery()
        )
        boarded = (
            select(Trip.route_id, func.count(Ticket.id).label("passengers"))
            .join(Trip, Trip.id == Ticket.trip_id)
            .where(*departing, Ticket.status == TicketStatus.VALIDATED)
            .group_by(Trip.route_id)
            .subquery()
        )
        rows = await self._session.execute(
            select(
                Route.id,
                Route.name,
                origin.name,
                destination.name,
                trips.c.completed,
                trips.c.cancelled,
                func.coalesce(offered.c.seats, 0),
                func.coalesce(booked.c.seats, 0),
                func.coalesce(boarded.c.passengers, 0),
                func.coalesce(booked.c.fares, 0),
                func.coalesce(booked.c.cancelled, 0),
            )
            .join(trips, trips.c.route_id == Route.id)
            .join(origin, origin.id == Route.origin_stop_id)
            .join(destination, destination.id == Route.destination_stop_id)
            .outerjoin(offered, offered.c.route_id == Route.id)
            .outerjoin(booked, booked.c.route_id == Route.id)
            .outerjoin(boarded, boarded.c.route_id == Route.id)
        )
        return [
            {
                "route_id": route_id,
                "route_name": name,
                "origin": origin_name,
                "destination": destination_name,
                "trips_completed": int(completed),
                "trips_cancelled": int(cancelled),
                "seats_offered": int(seats_offered),
                "seats_booked": int(seats_booked),
                "passengers_boarded": int(passengers),
                "fares": Decimal(fares),
                "bookings_cancelled": int(bookings_cancelled),
            }
            for (
                route_id,
                name,
                origin_name,
                destination_name,
                completed,
                cancelled,
                seats_offered,
                seats_booked,
                passengers,
                fares,
                bookings_cancelled,
            ) in rows.all()
        ]
