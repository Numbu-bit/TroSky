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
from collections.abc import Collection, Sequence
from datetime import UTC, date, datetime, time, timedelta
from decimal import Decimal

from redis.asyncio import Redis
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings, get_settings
from app.core.exceptions import ConflictError, NoPickupNearbyError, NotFoundError
from app.models.routes import DayOfWeek, Route, RouteSchedule, Stop
from app.models.trips import Trip, TripStatus
from app.models.vehicles import Vehicle, VehicleSeat
from app.repositories.booking_repository import BookingRepository
from app.repositories.route_repository import RouteRepository, StopRepository
from app.repositories.trip_repository import TripRepository
from app.repositories.vehicle_repository import VehicleRepository
from app.services.trip_service import TripService
from app.utilities.geo import stop_offsets_km, wkb_to_latlng

_SEARCH_CACHE_TTL_SECONDS = 60


class RouteService:
    def __init__(
        self, session: AsyncSession, redis: Redis | None = None, settings: Settings | None = None
    ) -> None:
        self._session = session
        self._redis = redis
        self._settings = settings or get_settings()
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

    async def find_stop(self, stop_id: uuid.UUID) -> Stop | None:
        return await self._stops.get_by_id(stop_id)

    async def list_stops(self, *, limit: int, offset: int) -> tuple[list[Stop], int]:
        return await self._stops.list_all(limit=limit, offset=offset)

    async def search_stops(self, query: str, *, limit: int) -> list[Stop]:
        """Name search -- the passenger's way to choose a pickup by hand
        instead of accepting the one resolved from their location."""
        return await self._stops.search_by_name(query.strip(), limit=limit)

    async def find_nearby_stops(
        self,
        *,
        latitude: float,
        longitude: float,
        radius_m: int | None = None,
        limit: int | None = None,
    ) -> list[tuple[Stop, float]]:
        return await self._stops.find_nearby(
            latitude=latitude,
            longitude=longitude,
            radius_m=radius_m or self._settings.PICKUP_MAX_WALK_METERS,
            limit=limit or self._settings.PICKUP_NEARBY_LIMIT,
        )

    async def pickup_candidates(
        self, *, latitude: float, longitude: float
    ) -> list[tuple[Stop, float]]:
        """Stops the passenger could walk to from where they stand.

        Raises rather than returning nothing: an empty result would read as
        "no trips today" when the real answer is "you are not near a stop",
        and those need different next steps in the app.
        """
        candidates = await self.find_nearby_stops(latitude=latitude, longitude=longitude)
        if not candidates:
            raise NoPickupNearbyError(
                details={
                    "max_walk_meters": self._settings.PICKUP_MAX_WALK_METERS,
                    "hint": "Search for a pickup point by name instead.",
                }
            )
        return candidates

    async def pickup_for_trip(
        self,
        trip: Trip,
        candidates: Sequence[tuple[Stop, float]],
        destination_stop_id: uuid.UUID | None,
    ) -> tuple[Stop, float] | None:
        """The nearest of ``candidates`` this trip can actually pick up at.

        Candidates arrive nearest first, but the nearest stop may not be on
        this trip's route, or may come after the passenger's destination,
        so each is checked against the route's stop order.
        """
        route = await self._routes.get_by_id(trip.route_id)
        if route is None:
            return None
        order = await self._routes.stop_order(route)
        last = max(order.values())
        alight_at = order.get(destination_stop_id) if destination_stop_id else last
        if alight_at is None:
            return None
        for stop, distance in candidates:
            board_at = order.get(stop.id)
            if board_at is not None and board_at < alight_at and stop.id != destination_stop_id:
                return stop, distance
        return None

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

        stop_sequence = [origin_stop_id, *intermediate_stop_ids, destination_stop_id]
        stops = []
        for stop_id in stop_sequence:
            stop = await self._stops.get_by_id(stop_id)
            if stop is None:
                raise NotFoundError("Stop not found.", details={"stop_id": str(stop_id)})
            stops.append(stop)
        # How far along the route each stop is: what prices a ride between
        # two stops as its share of the route (see FareService). Without it
        # every rider would pay the full fare.
        offsets = stop_offsets_km(
            [wkb_to_latlng(stop.location) for stop in stops], route_km=distance_km
        )
        if distance_km is None and offsets is not None:
            distance_km = offsets[-1]

        route = await self._routes.create(
            name=name,
            origin_stop_id=origin_stop_id,
            destination_stop_id=destination_stop_id,
            distance_km=distance_km,
            estimated_duration_minutes=estimated_duration_minutes,
            created_by=created_by,
        )

        for sequence_number, stop_id in enumerate(stop_sequence):
            offset = offsets[sequence_number] if offsets is not None else None
            await self._routes.add_route_stop(
                route_id=route.id,
                stop_id=stop_id,
                sequence_number=sequence_number,
                distance_from_origin_km=offset,
                estimated_offset_minutes=(
                    round(estimated_duration_minutes * offset / distance_km)
                    if offset is not None and estimated_duration_minutes and distance_km
                    else None
                ),
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
        """The route's stops in travel order.

        A route with no ``route_stops`` rows still serves its origin and
        destination -- search and booking treat it that way (see
        ``RouteRepository.stop_order``) -- so the detail view shows those
        two rather than an empty list that contradicts them.
        """
        route_stops = await self._routes.list_route_stops(route_id)
        stop_ids = [rs.stop_id for rs in route_stops]
        if not stop_ids:
            route = await self._routes.get_by_id(route_id)
            if route is not None:
                stop_ids = [route.origin_stop_id, route.destination_stop_id]
        stops = []
        for stop_id in stop_ids:
            stop = await self._stops.get_by_id(stop_id)
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
        origin_stop_ids: Collection[uuid.UUID] | None,
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
            origin_stop_ids, destination_stop_id, window_start, window_end, limit, offset
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
            origin_stop_ids=origin_stop_ids,
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
        origin_stop_ids: Collection[uuid.UUID] | None,
        destination_stop_id: uuid.UUID | None,
        window_start: datetime,
        window_end: datetime,
        limit: int,
        offset: int,
    ) -> str:
        # Keyed on the resolved stops, never the raw coordinates: two people
        # standing near the same stops share a cache entry, and no location
        # is written into Redis.
        origins = ",".join(sorted(str(i) for i in origin_stop_ids)) if origin_stop_ids else None
        raw = f"{origins}:{destination_stop_id}:{window_start}:{window_end}:{limit}:{offset}"
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
