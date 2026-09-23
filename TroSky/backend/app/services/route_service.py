"""Route, stop, and schedule business logic, plus trip search.

Search targets sub-2-second responses via straightforward indexed queries
(``routes(origin_stop_id, destination_stop_id)``, ``trips(status,
scheduled_departure_at)``) and a short-TTL Redis cache on the exact search
key — correct at the default page size and query patterns this MVP exposes;
if result sets grow much larger, add a covering index before reaching for
more caching.
"""

from __future__ import annotations

import hashlib
import json
import uuid
from datetime import UTC, date, datetime, time, timedelta
from decimal import Decimal

from redis.asyncio import Redis
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ConflictError, NotFoundError
from app.models.routes import DayOfWeek, Route, RouteSchedule, Stop
from app.models.trips import Trip, TripStatus
from app.models.vehicles import Vehicle, VehicleSeat
from app.repositories.booking_repository import BookingRepository
from app.repositories.route_repository import RouteRepository, StopRepository
from app.repositories.trip_repository import TripRepository
from app.repositories.vehicle_repository import VehicleRepository
from app.services.trip_service import TripService

_SEARCH_CACHE_TTL_SECONDS = 60


class RouteService:
    def __init__(self, session: AsyncSession, redis: Redis | None = None) -> None:
        self._session = session
        self._redis = redis
        self._stops = StopRepository(session)
        self._routes = RouteRepository(session)
        self._trips = TripRepository(session)
        self._vehicles = VehicleRepository(session)
        self._bookings = BookingRepository(session)

    # ------------------------------------------------------------------
    # Stops
    # ------------------------------------------------------------------
    async def create_stop(
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
        return await self._stops.create(
            name=name,
            code=code,
            latitude=latitude,
            longitude=longitude,
            address=address,
            city=city,
            region=region,
        )

    async def get_stop(self, stop_id: uuid.UUID) -> Stop:
        stop = await self._stops.get_by_id(stop_id)
        if stop is None:
            raise NotFoundError("Stop not found.")
        return stop

    async def list_stops(self, *, limit: int, offset: int) -> tuple[list[Stop], int]:
        return await self._stops.list_all(limit=limit, offset=offset)

    # ------------------------------------------------------------------
    # Routes
    # ------------------------------------------------------------------
    async def create_route(
        self,
        *,
        name: str,
        origin_stop_id: uuid.UUID,
        destination_stop_id: uuid.UUID,
        distance_km: Decimal | None,
        estimated_duration_minutes: int | None,
        intermediate_stop_ids: list[uuid.UUID],
        created_by: uuid.UUID | None,
    ) -> Route:
        if await self._stops.get_by_id(origin_stop_id) is None:
            raise NotFoundError("Origin stop not found.")
        if await self._stops.get_by_id(destination_stop_id) is None:
            raise NotFoundError("Destination stop not found.")

        route = await self._routes.create(
            name=name,
            origin_stop_id=origin_stop_id,
            destination_stop_id=destination_stop_id,
            distance_km=distance_km,
            estimated_duration_minutes=estimated_duration_minutes,
            created_by=created_by,
        )

        stop_sequence = [origin_stop_id, *intermediate_stop_ids, destination_stop_id]
        for sequence_number, stop_id in enumerate(stop_sequence):
            await self._routes.add_route_stop(
                route_id=route.id,
                stop_id=stop_id,
                sequence_number=sequence_number,
                distance_from_origin_km=None,
                estimated_offset_minutes=None,
            )
        return route

    async def get_route(self, route_id: uuid.UUID) -> Route:
        route = await self._routes.get_by_id(route_id)
        if route is None:
            raise NotFoundError("Route not found.")
        return route

    async def list_routes(self, *, limit: int, offset: int) -> tuple[list[Route], int]:
        return await self._routes.list_all(limit=limit, offset=offset)

    async def get_route_stops(self, route_id: uuid.UUID) -> list[Stop]:
        route_stops = await self._routes.list_route_stops(route_id)
        stops = []
        for route_stop in route_stops:
            stop = await self._stops.get_by_id(route_stop.stop_id)
            if stop is not None:
                stops.append(stop)
        return stops

    async def create_schedule(
        self,
        *,
        route_id: uuid.UUID,
        departure_time: time,
        days_of_week: list[DayOfWeek],
        fare_amount: Decimal,
    ) -> RouteSchedule:
        await self.get_route(route_id)
        return await self._routes.create_schedule(
            route_id=route_id,
            departure_time=departure_time,
            days_of_week=days_of_week,
            fare_amount=fare_amount,
        )

    # ------------------------------------------------------------------
    # Trip scheduling helper (creates a trip snapshotting a schedule's fare)
    # ------------------------------------------------------------------
    async def create_trip_from_schedule(
        self,
        *,
        schedule_id: uuid.UUID,
        travel_date: date,
        created_by: uuid.UUID | None,
    ) -> Trip:
        schedule = await self._routes.get_schedule(schedule_id)
        if schedule is None:
            raise NotFoundError("Route schedule not found.")
        route = await self.get_route(schedule.route_id)

        scheduled_departure_at = datetime.combine(travel_date, schedule.departure_time, tzinfo=UTC)
        scheduled_arrival_at = None
        if route.estimated_duration_minutes:
            scheduled_arrival_at = scheduled_departure_at + timedelta(
                minutes=route.estimated_duration_minutes
            )

        trip_service = TripService(self._session)
        return await trip_service.create_trip(
            route_id=route.id,
            route_schedule_id=schedule.id,
            scheduled_departure_at=scheduled_departure_at,
            scheduled_arrival_at=scheduled_arrival_at,
            fare_amount=schedule.fare_amount,
            created_by=created_by,
        )

    # ------------------------------------------------------------------
    # Search
    # ------------------------------------------------------------------
    async def search_trips(
        self,
        *,
        origin_stop_id: uuid.UUID | None,
        destination_stop_id: uuid.UUID | None,
        travel_date: date,
        departure_after: time | None,
        departure_before: time | None,
        limit: int,
        offset: int,
    ) -> tuple[list[Trip], int]:
        window_start = datetime.combine(travel_date, departure_after or time.min, tzinfo=UTC)
        window_end = datetime.combine(travel_date, departure_before or time.max, tzinfo=UTC)

        cache_key = self._search_cache_key(
            origin_stop_id, destination_stop_id, window_start, window_end, limit, offset
        )
        if self._redis is not None:
            cached = await self._redis.get(cache_key)
            if cached is not None:
                payload = json.loads(cached)
                trip_ids = [uuid.UUID(i) for i in payload["ids"]]
                cached_trips = [await self._trips.get_by_id(tid) for tid in trip_ids]
                found_trips = [t for t in cached_trips if t is not None]
                return found_trips, int(payload["total"])

        trips, total = await self._trips.search(
            origin_stop_id=origin_stop_id,
            destination_stop_id=destination_stop_id,
            departure_after=window_start,
            departure_before=window_end,
            statuses=[TripStatus.SCHEDULED, TripStatus.BOARDING],
            limit=limit,
            offset=offset,
        )

        if self._redis is not None:
            payload = json.dumps({"ids": [str(t.id) for t in trips], "total": total})
            await self._redis.set(cache_key, payload, ex=_SEARCH_CACHE_TTL_SECONDS)

        return trips, total

    @staticmethod
    def _search_cache_key(
        origin_stop_id: uuid.UUID | None,
        destination_stop_id: uuid.UUID | None,
        window_start: datetime,
        window_end: datetime,
        limit: int,
        offset: int,
    ) -> str:
        raw = f"{origin_stop_id}:{destination_stop_id}:{window_start}:{window_end}:{limit}:{offset}"
        digest = hashlib.sha256(raw.encode()).hexdigest()
        return f"trip_search:{digest}"

    # ------------------------------------------------------------------
    # Seats for a trip (Phase 5 augments availability with reservations)
    # ------------------------------------------------------------------
    async def get_trip_seats(
        self, trip_id: uuid.UUID
    ) -> tuple[Vehicle, list[VehicleSeat], set[uuid.UUID]]:
        """Returns (vehicle, all seats, taken_seat_ids) — a seat is "taken"
        if it has an active (held or confirmed) reservation for this trip."""
        vehicle = await self._trips.get_vehicle_for_trip(trip_id)
        if vehicle is None:
            raise ConflictError("This trip has no vehicle assigned yet.")
        layout = await self._vehicles.get_seat_layout(vehicle.id)
        if layout is None:
            raise NotFoundError("No seat layout has been configured for this trip's vehicle.")
        seats = await self._vehicles.list_seats(layout.id)
        taken_seat_ids = await self._bookings.list_active_seat_ids_for_trip(trip_id)
        return vehicle, seats, taken_seat_ids

    async def get_vehicle_for_trip(self, trip_id: uuid.UUID) -> Vehicle | None:
        return await self._trips.get_vehicle_for_trip(trip_id)

    async def get_available_seats_count(self, trip_id: uuid.UUID, vehicle: Vehicle) -> int:
        """Configured seat-layout total minus currently held/confirmed
        reservations for this trip — falls back to raw vehicle capacity if
        no layout has been configured yet."""
        layout = await self._vehicles.get_seat_layout(vehicle.id)
        total = layout.total_seats if layout is not None else vehicle.capacity
        taken = await self._bookings.list_active_seat_ids_for_trip(trip_id)
        return max(total - len(taken), 0)
