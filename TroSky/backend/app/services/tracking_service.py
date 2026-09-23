"""Live GPS tracking: ingestion, Redis-backed live-location state, pub/sub
fan-out for WebSocket subscribers, and ETA.

Redis is the read path for "where is this trip right now" — a plain hash
per trip (``trip:{id}:live``), refreshed on every accepted ping, with a
generous TTL as a garbage-collection safety net (staleness itself is
computed from ``recorded_at``, not from key expiry). Postgres
(``trip_locations``) is the durable, replayable history and the fallback
read path if Redis is cold (a restart, an evicted key) — never the other
way around, consistent with every other Redis-vs-Postgres split in this
codebase (see ``app.repositories.booking_repository`` for the canonical
statement of that principle).

Every ping is sanity-checked against the previous known position before
being trusted: an implied speed above ``GPS_MAX_PLAUSIBLE_SPEED_KMH`` is
rejected outright (a spoofed or corrupted reading), and pings arriving
faster than ``GPS_UPDATE_MIN_INTERVAL_SECONDS`` still update the live
cache (so tracking stays responsive) but are not all persisted to Postgres
(so a high-frequency GPS stream doesn't translate 1:1 into row-volume).
"""

from __future__ import annotations

import json
import uuid
from collections.abc import Awaitable
from dataclasses import dataclass
from datetime import UTC, datetime
from decimal import Decimal
from typing import cast

from redis.asyncio import Redis
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings, get_settings
from app.core.exceptions import ConflictError, NotFoundError
from app.core.logging import get_logger
from app.core.permissions import Permission, Principal
from app.core.telemetry import GPS_INGEST_TOTAL
from app.models.bookings import Booking, BookingStatus
from app.models.trips import TripStatus
from app.providers.maps.base import EtaResult, MapsProvider
from app.providers.maps.factory import get_maps_provider
from app.repositories.driver_repository import DriverRepository
from app.repositories.route_repository import RouteRepository, StopRepository
from app.repositories.tracking_repository import TripLocationRepository
from app.repositories.trip_repository import TripRepository
from app.utilities.geo import haversine_distance_km, wkb_to_latlng

logger = get_logger(__name__)

_GEO_SET_KEY = "trips:live-geo"
# Generous relative to GPS_STALE_THRESHOLD_SECONDS — a garbage-collection
# safety net for abandoned trips, not the staleness signal itself.
_LIVE_KEY_TTL_MULTIPLIER = 20

_ACTIVE_BOOKING_STATUSES = (
    BookingStatus.PENDING,
    BookingStatus.PAYMENT_PENDING,
    BookingStatus.CONFIRMED,
)


def _live_key(trip_id: uuid.UUID) -> str:
    return f"trip:{trip_id}:live"


def channel_name(trip_id: uuid.UUID) -> str:
    """Public: the Redis pub/sub channel a trip's live-location updates are
    published to — also subscribed to directly by the WebSocket route
    (``app.api.v1.tracking``), which lives outside this service."""
    return f"trip:{trip_id}:live-updates"


@dataclass(frozen=True, slots=True)
class LiveLocation:
    trip_id: uuid.UUID
    latitude: float
    longitude: float
    speed_kmh: Decimal | None
    heading_degrees: Decimal | None
    recorded_at: datetime
    is_stale: bool

    def to_publish_payload(self) -> str:
        return json.dumps(
            {
                "trip_id": str(self.trip_id),
                "latitude": self.latitude,
                "longitude": self.longitude,
                "speed_kmh": str(self.speed_kmh) if self.speed_kmh is not None else None,
                "heading_degrees": (
                    str(self.heading_degrees) if self.heading_degrees is not None else None
                ),
                "recorded_at": self.recorded_at.isoformat(),
            }
        )


class TrackingService:
    def __init__(
        self, session: AsyncSession, redis: Redis, settings: Settings | None = None
    ) -> None:
        self._session = session
        self._redis = redis
        self._settings = settings or get_settings()
        self._trips = TripRepository(session)
        self._routes = RouteRepository(session)
        self._stops = StopRepository(session)
        self._drivers = DriverRepository(session)
        self._locations = TripLocationRepository(session)
        self._maps: MapsProvider = get_maps_provider(self._settings)

    # ------------------------------------------------------------------
    # Ingestion
    # ------------------------------------------------------------------
    async def record_location(
        self,
        trip_id: uuid.UUID,
        *,
        latitude: float,
        longitude: float,
        speed_kmh: Decimal | None,
        heading_degrees: Decimal | None,
        accuracy_meters: Decimal | None,
        recorded_at: datetime,
    ) -> LiveLocation:
        trip = await self._trips.get_by_id(trip_id)
        if trip is None:
            raise NotFoundError("Trip not found.")
        if trip.status != TripStatus.IN_PROGRESS:
            raise ConflictError(
                "Location updates are only accepted while a trip is in progress.",
                code="TRIP_NOT_IN_PROGRESS",
            )

        previous = await self._get_cached_location(trip_id)
        should_persist = previous is None
        if previous is not None:
            elapsed_seconds = (recorded_at - previous.recorded_at).total_seconds()
            if elapsed_seconds < 0:
                # A late-arriving, out-of-order ping on a lossy mobile
                # network — not an error, just not the newest truth.
                return previous
            if elapsed_seconds > 0:
                distance_km = haversine_distance_km(
                    previous.latitude, previous.longitude, latitude, longitude
                )
                implied_speed_kmh = distance_km / (elapsed_seconds / 3600)
                if implied_speed_kmh > self._settings.GPS_MAX_PLAUSIBLE_SPEED_KMH:
                    GPS_INGEST_TOTAL.labels(result="rejected_implausible").inc()
                    logger.warning(
                        "gps_ping_rejected_implausible",
                        trip_id=str(trip_id),
                        implied_speed_kmh=round(implied_speed_kmh, 1),
                    )
                    raise ConflictError(
                        "This location update implies an implausible speed and was rejected.",
                        code="GPS_IMPLAUSIBLE_JUMP",
                    )
            should_persist = elapsed_seconds >= self._settings.GPS_UPDATE_MIN_INTERVAL_SECONDS

        if should_persist:
            await self._locations.create(
                trip_id=trip_id,
                latitude=latitude,
                longitude=longitude,
                speed_kmh=speed_kmh,
                heading_degrees=heading_degrees,
                accuracy_meters=accuracy_meters,
                recorded_at=recorded_at,
            )

        live = LiveLocation(
            trip_id=trip_id,
            latitude=latitude,
            longitude=longitude,
            speed_kmh=speed_kmh,
            heading_degrees=heading_degrees,
            recorded_at=recorded_at,
            is_stale=False,
        )
        await self._cache_location(live)
        await self._redis.publish(channel_name(trip_id), live.to_publish_payload())
        GPS_INGEST_TOTAL.labels(result="accepted").inc()
        return live

    async def _cache_location(self, live: LiveLocation) -> None:
        key = _live_key(live.trip_id)
        mapping = {
            "latitude": str(live.latitude),
            "longitude": str(live.longitude),
            "speed_kmh": str(live.speed_kmh) if live.speed_kmh is not None else "",
            "heading_degrees": (
                str(live.heading_degrees) if live.heading_degrees is not None else ""
            ),
            "recorded_at": live.recorded_at.isoformat(),
        }
        await cast(Awaitable[object], self._redis.hset(key, mapping=mapping))
        await self._redis.expire(
            key, self._settings.GPS_STALE_THRESHOLD_SECONDS * _LIVE_KEY_TTL_MULTIPLIER
        )
        await cast(
            Awaitable[object],
            self._redis.geoadd(_GEO_SET_KEY, (live.longitude, live.latitude, str(live.trip_id))),
        )

    async def _get_cached_location(self, trip_id: uuid.UUID) -> LiveLocation | None:
        data = await cast(Awaitable[dict[str, str]], self._redis.hgetall(_live_key(trip_id)))
        if not data:
            return None
        recorded_at = datetime.fromisoformat(data["recorded_at"])
        return LiveLocation(
            trip_id=trip_id,
            latitude=float(data["latitude"]),
            longitude=float(data["longitude"]),
            speed_kmh=Decimal(data["speed_kmh"]) if data.get("speed_kmh") else None,
            heading_degrees=(
                Decimal(data["heading_degrees"]) if data.get("heading_degrees") else None
            ),
            recorded_at=recorded_at,
            is_stale=self._is_stale(recorded_at),
        )

    def _is_stale(self, recorded_at: datetime) -> bool:
        age_seconds = (datetime.now(UTC) - recorded_at).total_seconds()
        return age_seconds > self._settings.GPS_STALE_THRESHOLD_SECONDS

    # ------------------------------------------------------------------
    # Reads
    # ------------------------------------------------------------------
    async def get_live_location(self, trip_id: uuid.UUID) -> LiveLocation | None:
        cached = await self._get_cached_location(trip_id)
        if cached is not None:
            return cached

        # Redis miss (cold cache, restart, TTL expiry) — durable fallback.
        latest = await self._locations.get_latest_for_trip(trip_id)
        if latest is None:
            return None
        latlng = wkb_to_latlng(latest.location)
        if latlng is None:
            return None
        latitude, longitude = latlng
        return LiveLocation(
            trip_id=trip_id,
            latitude=latitude,
            longitude=longitude,
            speed_kmh=latest.speed_kmh,
            heading_degrees=latest.heading_degrees,
            recorded_at=latest.recorded_at,
            is_stale=self._is_stale(latest.recorded_at),
        )

    async def get_eta(
        self, trip_id: uuid.UUID, *, destination_stop_id: uuid.UUID | None = None
    ) -> EtaResult:
        trip = await self._trips.get_by_id(trip_id)
        if trip is None:
            raise NotFoundError("Trip not found.")
        route = await self._routes.get_by_id(trip.route_id)
        if route is None:
            raise NotFoundError("Route not found.")

        stop_id = destination_stop_id or route.destination_stop_id
        stop = await self._stops.get_by_id(stop_id)
        if stop is None:
            raise NotFoundError("Destination stop not found.")
        destination = wkb_to_latlng(stop.location)
        if destination is None:
            raise NotFoundError("Destination stop has no location on record.")

        live = await self.get_live_location(trip_id)
        if live is None:
            raise NotFoundError("No location has been reported for this trip yet.")

        return await self._maps.estimate_eta(
            origin=(live.latitude, live.longitude),
            destination=destination,
            current_speed_kmh=live.speed_kmh,
        )

    # ------------------------------------------------------------------
    # Authorization — who may watch a trip's live location (REST poll or
    # WebSocket stream): ops/admin roles, the trip's assigned driver, or a
    # passenger with an active (non-cancelled/expired) booking on it.
    # ------------------------------------------------------------------
    async def can_watch_trip(self, trip_id: uuid.UUID, principal: Principal) -> bool:
        if principal.has_permission(Permission.TRIPS_MONITOR_LIVE):
            return True

        driver = await self._drivers.get_by_user_id(principal.user_id)
        if driver is not None:
            assignment = await self._trips.get_active_driver_assignment(trip_id)
            if assignment is not None and assignment.driver_id == driver.id:
                return True

        result = await self._session.execute(
            select(Booking.id).where(
                Booking.trip_id == trip_id,
                Booking.passenger_id == principal.user_id,
                Booking.status.in_(_ACTIVE_BOOKING_STATUSES),
            )
        )
        return result.scalar_one_or_none() is not None
