"""A route's stops in order, with how far along the route each one sits.

Pricing a segment, choosing a pickup, telling whether a vehicle has passed
a stop and sorting trips by ride time all need the same few facts about a
route. Search needs them for every route in a result page, so they are
read for many routes in two queries rather than per trip.
"""

from __future__ import annotations

import uuid
from collections.abc import Collection, Sequence
from dataclasses import dataclass
from decimal import Decimal

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.routes import Route, RouteStop, Stop
from app.utilities.geo import progress_along_route_km, wkb_to_latlng

# A vehicle this far beyond a stop (along the route) has passed it. Leaves
# room for GPS error and for a bus that stopped a little past the sign.
PASSED_STOP_TOLERANCE_KM = 0.15


@dataclass(frozen=True, slots=True)
class RoutePoint:
    stop_id: uuid.UUID
    name: str
    # Distance from the route's start, and minutes after departure, as
    # measured when the route was saved. None when never measured.
    offset_km: Decimal | None
    offset_minutes: int | None
    latitude: float | None
    longitude: float | None


@dataclass(frozen=True, slots=True)
class RouteGeometry:
    route_id: uuid.UUID
    route_name: str
    origin_stop_id: uuid.UUID
    destination_stop_id: uuid.UUID
    route_km: Decimal | None
    duration_minutes: int | None
    # Start to end. The route's own end stops are always included, even on
    # a route whose stop list was never filled in.
    points: tuple[RoutePoint, ...]
    # Offsets exactly as stored on route_stops: what fares are priced from.
    # Kept separate from ``points`` because an end stop missing from
    # route_stops has no stored offset, and the fare engine treats that as
    # "charge the whole route" rather than as zero.
    fare_distances: dict[uuid.UUID, Decimal | None]

    @property
    def order(self) -> dict[uuid.UUID, int]:
        return {point.stop_id: position for position, point in enumerate(self.points)}

    def point(self, stop_id: uuid.UUID) -> RoutePoint | None:
        return next((p for p in self.points if p.stop_id == stop_id), None)

    def ride_minutes(self, origin: uuid.UUID, destination: uuid.UUID) -> int | None:
        """Scheduled minutes between two stops, else the whole route's."""
        start, end = self.point(origin), self.point(destination)
        if (
            start is not None
            and end is not None
            and start.offset_minutes is not None
            and end.offset_minutes is not None
        ):
            return max(end.offset_minutes - start.offset_minutes, 0)
        return self.duration_minutes

    def km_until(self, stop_id: uuid.UUID, latitude: float, longitude: float) -> float | None:
        """Kilometres along the route from a vehicle at this position to
        ``stop_id``: negative once it has gone past. None when the route's
        stops are not located and measured well enough to tell."""
        point = self.point(stop_id)
        if point is None or point.offset_km is None:
            return None
        progress = progress_along_route_km(self.polyline(), latitude, longitude)
        return None if progress is None else float(point.offset_km) - progress

    def polyline(self) -> list[tuple[float, float, float]]:
        """``(latitude, longitude, offset_km)`` for each located, measured stop."""
        return [
            (p.latitude, p.longitude, float(p.offset_km))
            for p in self.points
            if p.latitude is not None and p.longitude is not None and p.offset_km is not None
        ]


class RouteGeometryRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def for_routes(self, route_ids: Collection[uuid.UUID]) -> dict[uuid.UUID, RouteGeometry]:
        ids = list(set(route_ids))
        if not ids:
            return {}
        routes = (await self._session.execute(select(Route).where(Route.id.in_(ids)))).scalars()
        by_id = {route.id: route for route in routes}
        rows = (
            await self._session.execute(
                select(
                    RouteStop.route_id,
                    RouteStop.stop_id,
                    RouteStop.distance_from_origin_km,
                    RouteStop.estimated_offset_minutes,
                    Stop.name,
                    Stop.location,
                )
                .join(Stop, Stop.id == RouteStop.stop_id)
                .where(RouteStop.route_id.in_(ids))
                .order_by(RouteStop.route_id, RouteStop.sequence_number)
            )
        ).all()
        listed: dict[uuid.UUID, list[RoutePoint]] = {route_id: [] for route_id in by_id}
        for row in rows:
            latlng = wkb_to_latlng(row.location)
            listed[row.route_id].append(
                RoutePoint(
                    stop_id=row.stop_id,
                    name=row.name,
                    offset_km=row.distance_from_origin_km,
                    offset_minutes=row.estimated_offset_minutes,
                    latitude=latlng[0] if latlng else None,
                    longitude=latlng[1] if latlng else None,
                )
            )

        missing_ends = {
            end
            for route in by_id.values()
            for end in (route.origin_stop_id, route.destination_stop_id)
            if all(point.stop_id != end for point in listed[route.id])
        }
        end_stops: dict[uuid.UUID, Stop] = {}
        if missing_ends:
            found = await self._session.execute(select(Stop).where(Stop.id.in_(missing_ends)))
            end_stops = {stop.id: stop for stop in found.scalars()}

        geometries: dict[uuid.UUID, RouteGeometry] = {}
        for route in by_id.values():
            points = listed[route.id]
            fare_distances = {point.stop_id: point.offset_km for point in points}
            origin = end_stops.get(route.origin_stop_id)
            if origin is not None:
                points.insert(0, _end_point(origin, Decimal("0"), 0))
            destination = end_stops.get(route.destination_stop_id)
            if destination is not None:
                points.append(
                    _end_point(destination, route.distance_km, route.estimated_duration_minutes)
                )
            geometries[route.id] = RouteGeometry(
                route_id=route.id,
                route_name=route.name,
                origin_stop_id=route.origin_stop_id,
                destination_stop_id=route.destination_stop_id,
                route_km=route.distance_km,
                duration_minutes=route.estimated_duration_minutes,
                points=tuple(points),
                fare_distances=fare_distances,
            )
        return geometries


def _end_point(stop: Stop, offset_km: Decimal | None, minutes: int | None) -> RoutePoint:
    latlng = wkb_to_latlng(stop.location)
    return RoutePoint(
        stop_id=stop.id,
        name=stop.name,
        offset_km=offset_km,
        offset_minutes=minutes,
        latitude=latlng[0] if latlng else None,
        longitude=latlng[1] if latlng else None,
    )


def nearest_pickup(
    geometry: RouteGeometry,
    candidates: Sequence[tuple[Stop, float]],
    destination_stop_id: uuid.UUID | None,
) -> tuple[Stop, float] | None:
    """The nearest of ``candidates`` this route can actually pick up at.

    Candidates arrive nearest first, but the nearest stop may not be on
    this route, or may come after the passenger's destination, so each is
    checked against the route's stop order.
    """
    order = geometry.order
    alight_at = order.get(destination_stop_id) if destination_stop_id else len(order) - 1
    if alight_at is None:
        return None
    for stop, distance in candidates:
        board_at = order.get(stop.id)
        if board_at is not None and board_at < alight_at and stop.id != destination_stop_id:
            return stop, distance
    return None
