"""Where and when people want to travel, for the demand heat maps.

Demand is one of:

* ``searches`` -- every trip search (``search_events``);
* ``unmet`` -- searches that found no bus with a free seat to catch;
* ``bookings`` -- paid bookings, weighted by seats.

Each is placed on the ~550 m search grid (``SEARCH_GRID_DEGREES``): a GPS
search by the cell it was made from, which is all that was kept; a search by
stop, or a booking, by its pickup stop. Only totals per cell leave the
database, never a position, and cells with fewer than ``MIN_EVENTS_PER_CELL``
searches are withheld so no one person's searches can be picked out.
"""

from __future__ import annotations

import uuid
from collections.abc import Collection
from dataclasses import dataclass
from datetime import datetime
from decimal import Decimal
from typing import Any, Literal

from geoalchemy2 import Geometry
from sqlalchemy import (
    ColumnElement,
    Numeric,
    Select,
    and_,
    cast,
    extract,
    func,
    literal,
    or_,
    select,
)
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import aliased
from sqlalchemy.sql.expression import Subquery

from app.models.analytics import SEARCH_GRID_DEGREES, SearchEvent
from app.models.bookings import Booking, BookingStatus
from app.models.routes import Route, Stop
from app.models.trips import Trip
from app.repositories.admin_analytics_repository import TIMEZONE

DemandKind = Literal["searches", "unmet", "bookings"]

MIN_EVENTS_PER_CELL = 3
MAX_CELLS = 2000
TOP = 10

_PAID = (
    BookingStatus.CONFIRMED,
    BookingStatus.COMPLETED,
    BookingStatus.REFUND_PENDING,
    BookingStatus.REFUNDED,
)


@dataclass(frozen=True, slots=True)
class DemandFilters:
    since: datetime
    until: datetime
    city: str | None = None
    # ISO days of the week, 1 = Monday ... 7 = Sunday.
    days: Collection[int] | None = None
    # Ghana hours, inclusive; hour_from > hour_to wraps past midnight.
    hour_from: int | None = None
    hour_to: int | None = None


@dataclass(frozen=True, slots=True)
class Cell:
    latitude: Decimal
    longitude: Decimal
    weight: int


@dataclass(frozen=True, slots=True)
class StopDemand:
    stop_id: uuid.UUID
    name: str
    city: str | None
    weight: int


@dataclass(frozen=True, slots=True)
class PairDemand:
    origin_stop_id: uuid.UUID
    origin_name: str
    destination_stop_id: uuid.UUID
    destination_name: str
    weight: int


@dataclass(frozen=True, slots=True)
class SupplyGap:
    stop_id: uuid.UUID
    name: str
    city: str | None
    searches: int
    unmet: int


def _snapped(coordinate: Any) -> Any:
    """A coordinate on the search grid, as ``search_events`` stores it."""
    grid = SEARCH_GRID_DEGREES
    return func.round(func.round(cast(coordinate, Numeric) / grid) * grid, 3)


def _in_window(moment: Any, filters: DemandFilters) -> list[ColumnElement[bool]]:
    local = func.timezone(TIMEZONE, moment)
    conditions: list[ColumnElement[bool]] = [moment >= filters.since, moment < filters.until]
    if filters.days:
        conditions.append(extract("isodow", local).in_(sorted(filters.days)))
    if filters.hour_from is not None or filters.hour_to is not None:
        start = filters.hour_from if filters.hour_from is not None else 0
        end = filters.hour_to if filters.hour_to is not None else 23
        hour = extract("hour", local)
        if start <= end:
            conditions.append(and_(hour >= start, hour <= end))
        else:  # e.g. 22 to 5: late evening and early morning
            conditions.append(or_(hour >= start, hour <= end))
    return conditions


class AdminDemandRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    def events(self, kind: DemandKind, filters: DemandFilters) -> Subquery:
        """One row per search or booking: its cell, stops, Ghana day of the
        week and hour, and weight."""
        origin = aliased(Stop)
        point = cast(origin.location, Geometry)
        stmt: Select[Any]
        if kind == "bookings":
            route = aliased(Route)
            origin_id = func.coalesce(Booking.origin_stop_id, route.origin_stop_id)
            destination_id = func.coalesce(Booking.destination_stop_id, route.destination_stop_id)
            moment: Any = Booking.created_at
            stmt = (
                select(
                    _snapped(func.ST_Y(point)).label("cell_latitude"),
                    _snapped(func.ST_X(point)).label("cell_longitude"),
                    origin_id.label("origin_stop_id"),
                    destination_id.label("destination_stop_id"),
                    Booking.passenger_count.label("weight"),
                )
                .select_from(Booking)
                .join(Trip, Trip.id == Booking.trip_id)
                .join(route, route.id == Trip.route_id)
                .join(origin, origin.id == origin_id)
                .where(Booking.status.in_(_PAID))
            )
        else:
            moment = SearchEvent.searched_at
            stmt = (
                select(
                    func.coalesce(SearchEvent.cell_latitude, _snapped(func.ST_Y(point))).label(
                        "cell_latitude"
                    ),
                    func.coalesce(SearchEvent.cell_longitude, _snapped(func.ST_X(point))).label(
                        "cell_longitude"
                    ),
                    SearchEvent.origin_stop_id.label("origin_stop_id"),
                    SearchEvent.destination_stop_id.label("destination_stop_id"),
                    literal(1).label("weight"),
                )
                .select_from(SearchEvent)
                .outerjoin(origin, origin.id == SearchEvent.origin_stop_id)
            )
            if kind == "unmet":
                stmt = stmt.where(SearchEvent.bookable_count == 0)
        local = func.timezone(TIMEZONE, moment)
        stmt = stmt.add_columns(
            extract("isodow", local).label("day"), extract("hour", local).label("hour")
        ).where(*_in_window(moment, filters))
        if filters.city is not None:
            stmt = stmt.where(func.lower(origin.city) == filters.city.strip().lower())
        return stmt.subquery("demand")

    async def total(self, kind: DemandKind, filters: DemandFilters) -> int:
        events = self.events(kind, filters)
        total = await self._session.scalar(select(func.coalesce(func.sum(events.c.weight), 0)))
        return int(total or 0)

    async def cells(self, kind: DemandKind, filters: DemandFilters) -> tuple[list[Cell], int]:
        """Weight per grid cell, heaviest first, and the weight withheld in
        cells too small to show (searches only: a booking is placed at a
        stop, a public place)."""
        events = self.events(kind, filters)
        weight = func.sum(events.c.weight).label("weight")
        searches = func.count().label("searches")
        rows = (
            await self._session.execute(
                select(events.c.cell_latitude, events.c.cell_longitude, weight, searches)
                .where(events.c.cell_latitude.is_not(None), events.c.cell_longitude.is_not(None))
                .group_by(events.c.cell_latitude, events.c.cell_longitude)
                .order_by(weight.desc(), events.c.cell_latitude, events.c.cell_longitude)
            )
        ).all()
        shown: list[Cell] = []
        withheld = 0
        for latitude, longitude, total, count in rows:
            if kind != "bookings" and count < MIN_EVENTS_PER_CELL:
                withheld += int(total)
            elif len(shown) < MAX_CELLS:
                shown.append(Cell(Decimal(latitude), Decimal(longitude), int(total)))
        return shown, withheld

    async def top_origins(self, kind: DemandKind, filters: DemandFilters) -> list[StopDemand]:
        events = self.events(kind, filters)
        weight = func.sum(events.c.weight).label("weight")
        rows = await self._session.execute(
            select(Stop.id, Stop.name, Stop.city, weight)
            .select_from(events)
            .join(Stop, Stop.id == events.c.origin_stop_id)
            .group_by(Stop.id, Stop.name, Stop.city)
            .order_by(weight.desc(), Stop.name)
            .limit(TOP)
        )
        return [
            StopDemand(stop_id=stop_id, name=name, city=city, weight=int(total))
            for stop_id, name, city, total in rows.all()
        ]

    async def top_pairs(self, kind: DemandKind, filters: DemandFilters) -> list[PairDemand]:
        events = self.events(kind, filters)
        origin, destination = aliased(Stop), aliased(Stop)
        weight = func.sum(events.c.weight).label("weight")
        rows = await self._session.execute(
            select(origin.id, origin.name, destination.id, destination.name, weight)
            .select_from(events)
            .join(origin, origin.id == events.c.origin_stop_id)
            .join(destination, destination.id == events.c.destination_stop_id)
            .group_by(origin.id, origin.name, destination.id, destination.name)
            .order_by(weight.desc(), origin.name, destination.name)
            .limit(TOP)
        )
        return [
            PairDemand(
                origin_stop_id=origin_id,
                origin_name=origin_name,
                destination_stop_id=destination_id,
                destination_name=destination_name,
                weight=int(total),
            )
            for origin_id, origin_name, destination_id, destination_name, total in rows.all()
        ]

    async def by_day_and_hour(
        self, kind: DemandKind, filters: DemandFilters
    ) -> dict[tuple[int, int], int]:
        """``{(ISO day, hour): weight}``."""
        events = self.events(kind, filters)
        rows = await self._session.execute(
            select(events.c.day, events.c.hour, func.sum(events.c.weight)).group_by(
                events.c.day, events.c.hour
            )
        )
        return {(int(day), int(hour)): int(weight) for day, hour, weight in rows.all()}

    async def supply_gaps(self, filters: DemandFilters) -> list[SupplyGap]:
        """Where searches most often found no bus with a free seat: by
        pickup stop, the most unmet first."""
        events = self.events("searches", filters)
        unmet_rows = self.events("unmet", filters)
        unmet = (
            select(unmet_rows.c.origin_stop_id, func.count().label("unmet"))
            .group_by(unmet_rows.c.origin_stop_id)
            .subquery("unmet_by_stop")
        )
        searches = func.count().label("searches")
        missed = func.coalesce(func.max(unmet.c.unmet), 0).label("missed")
        rows = await self._session.execute(
            select(Stop.id, Stop.name, Stop.city, searches, missed)
            .select_from(events)
            .join(Stop, Stop.id == events.c.origin_stop_id)
            .outerjoin(unmet, unmet.c.origin_stop_id == events.c.origin_stop_id)
            .group_by(Stop.id, Stop.name, Stop.city)
            .having(func.coalesce(func.max(unmet.c.unmet), 0) > 0)
            .order_by(missed.desc(), searches.desc(), Stop.name)
            .limit(TOP)
        )
        return [
            SupplyGap(stop_id, name, city, int(total), int(not_met))
            for stop_id, name, city, total, not_met in rows.all()
        ]
