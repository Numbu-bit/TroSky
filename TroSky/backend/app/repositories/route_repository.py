"""Database access for stops, routes, route stops, and route schedules."""

from __future__ import annotations

import uuid
from collections.abc import Collection
from datetime import time
from decimal import Decimal

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.routes import DayOfWeek, Route, RouteSchedule, RouteStop, Stop
from app.utilities.geo import latlng_to_wkt


class StopRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get_by_id(self, stop_id: uuid.UUID) -> Stop | None:
        result = await self._session.execute(
            select(Stop).where(Stop.id == stop_id, Stop.is_active.is_(True))
        )
        return result.scalar_one_or_none()

    async def list_all(self, *, limit: int, offset: int) -> tuple[list[Stop], int]:
        count_result = await self._session.execute(select(Stop.id).where(Stop.is_active.is_(True)))
        total = len(count_result.scalars().all())
        result = await self._session.execute(
            select(Stop)
            .where(Stop.is_active.is_(True))
            .order_by(Stop.name)
            .limit(limit)
            .offset(offset)
        )
        return list(result.scalars().all()), total

    async def search_by_name(self, query: str, *, limit: int = 20) -> list[Stop]:
        result = await self._session.execute(
            select(Stop)
            .where(Stop.is_active.is_(True), Stop.name.ilike(f"%{query}%"))
            .order_by(Stop.name)
            .limit(limit)
        )
        return list(result.scalars().all())

    async def find_nearby(
        self,
        *,
        latitude: float,
        longitude: float,
        radius_m: int,
        limit: int,
        stop_ids: Collection[uuid.UUID] | None = None,
    ) -> list[tuple[Stop, float]]:
        """Active stops within ``radius_m`` metres, nearest first.

        ``ST_DWithin`` on the geography column uses the ``ix_stops_location``
        GIST index, so this stays cheap however many stops exist. Distances
        are true metres along the earth's surface, not planar degrees.
        ``stop_ids`` restricts the candidates, e.g. to one route's stops.
        """
        point = func.ST_GeogFromText(latlng_to_wkt(latitude, longitude))
        distance = func.ST_Distance(Stop.location, point).label("distance_m")
        stmt = (
            select(Stop, distance)
            .where(Stop.is_active.is_(True), func.ST_DWithin(Stop.location, point, radius_m))
            .order_by(distance)
            .limit(limit)
        )
        if stop_ids is not None:
            stmt = stmt.where(Stop.id.in_(list(stop_ids)))
        rows = (await self._session.execute(stmt)).all()
        return [(row[0], float(row[1])) for row in rows]

    async def create(
        self,
        *,
        name: str,
        code: str | None,
        latitude: float,
        longitude: float,
        address: str | None,
        city: str | None,
        region: str | None,
    ) -> Stop:
        stop = Stop(
            name=name,
            code=code,
            location=latlng_to_wkt(latitude, longitude),
            address=address,
            city=city,
            region=region,
        )
        self._session.add(stop)
        await self._session.flush()
        return stop


class RouteRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get_by_id(self, route_id: uuid.UUID) -> Route | None:
        result = await self._session.execute(
            select(Route).where(Route.id == route_id, Route.is_active.is_(True))
        )
        return result.scalar_one_or_none()

    async def list_all(self, *, limit: int, offset: int) -> tuple[list[Route], int]:
        count_result = await self._session.execute(
            select(Route.id).where(Route.is_active.is_(True))
        )
        total = len(count_result.scalars().all())
        result = await self._session.execute(
            select(Route)
            .where(Route.is_active.is_(True))
            .order_by(Route.name)
            .limit(limit)
            .offset(offset)
        )
        return list(result.scalars().all()), total

    async def search_by_stops(
        self, *, origin_stop_id: uuid.UUID, destination_stop_id: uuid.UUID
    ) -> list[Route]:
        result = await self._session.execute(
            select(Route).where(
                Route.origin_stop_id == origin_stop_id,
                Route.destination_stop_id == destination_stop_id,
                Route.is_active.is_(True),
            )
        )
        return list(result.scalars().all())

    async def create(
        self,
        *,
        name: str,
        origin_stop_id: uuid.UUID,
        destination_stop_id: uuid.UUID,
        distance_km: Decimal | None,
        estimated_duration_minutes: int | None,
        created_by: uuid.UUID | None,
    ) -> Route:
        route = Route(
            name=name,
            origin_stop_id=origin_stop_id,
            destination_stop_id=destination_stop_id,
            distance_km=distance_km,
            estimated_duration_minutes=estimated_duration_minutes,
            created_by=created_by,
        )
        self._session.add(route)
        await self._session.flush()
        return route

    async def add_route_stop(
        self,
        *,
        route_id: uuid.UUID,
        stop_id: uuid.UUID,
        sequence_number: int,
        distance_from_origin_km: Decimal | None,
        estimated_offset_minutes: int | None,
    ) -> RouteStop:
        route_stop = RouteStop(
            route_id=route_id,
            stop_id=stop_id,
            sequence_number=sequence_number,
            distance_from_origin_km=distance_from_origin_km,
            estimated_offset_minutes=estimated_offset_minutes,
        )
        self._session.add(route_stop)
        await self._session.flush()
        return route_stop

    async def stop_order(self, route: Route) -> dict[uuid.UUID, int]:
        """Each stop the route serves, mapped to its position along it.

        The origin sorts first and the destination last even for a route
        whose ``route_stops`` were never filled in, so every route has at
        least a two-stop order to validate against.
        """
        order: dict[uuid.UUID, int] = {route.origin_stop_id: -1}
        for route_stop in await self.list_route_stops(route.id):
            order[route_stop.stop_id] = route_stop.sequence_number
        order.setdefault(route.destination_stop_id, max(order.values()) + 1)
        return order

    async def list_route_stops(self, route_id: uuid.UUID) -> list[RouteStop]:
        result = await self._session.execute(
            select(RouteStop)
            .where(RouteStop.route_id == route_id)
            .order_by(RouteStop.sequence_number)
        )
        return list(result.scalars().all())

    async def create_schedule(
        self,
        *,
        route_id: uuid.UUID,
        departure_time: time,
        days_of_week: list[DayOfWeek],
        fare_amount: Decimal,
    ) -> RouteSchedule:
        schedule = RouteSchedule(
            route_id=route_id,
            departure_time=departure_time,
            days_of_week=days_of_week,
            fare_amount=fare_amount,
        )
        self._session.add(schedule)
        await self._session.flush()
        return schedule

    async def get_schedule(self, schedule_id: uuid.UUID) -> RouteSchedule | None:
        result = await self._session.execute(
            select(RouteSchedule).where(RouteSchedule.id == schedule_id)
        )
        return result.scalar_one_or_none()

    async def list_schedules_for_route(self, route_id: uuid.UUID) -> list[RouteSchedule]:
        result = await self._session.execute(
            select(RouteSchedule).where(
                RouteSchedule.route_id == route_id, RouteSchedule.is_active.is_(True)
            )
        )
        return list(result.scalars().all())
