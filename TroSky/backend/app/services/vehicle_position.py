"""Where a trip's vehicle is along its route: shared by booking (is the
pickup still ahead?), moving a booking to another trip (the same question
for each candidate) and passengers' arrival (has it reached their stop?)."""

from __future__ import annotations

import uuid

from redis.asyncio import Redis
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings
from app.models.trips import Trip, TripStatus
from app.repositories.route_geometry import PASSED_STOP_TOLERANCE_KM, RouteGeometry
from app.repositories.tracking_repository import TripLocationRepository
from app.services.tracking_service import TrackingService
from app.utilities.geo import wkb_to_latlng


async def latest_position(
    session: AsyncSession, redis: Redis | None, settings: Settings, trip_id: uuid.UUID
) -> tuple[float, float] | None:
    """Where the vehicle last reported itself: the live cache first, as
    search reads it, so both agree on whether a stop has been passed (the
    database keeps a position only every few seconds)."""
    if redis is not None:
        live = await TrackingService(session, redis, settings).get_live_location(trip_id)
        return (live.latitude, live.longitude) if live is not None else None
    latest = await TripLocationRepository(session).get_latest_for_trip(trip_id)
    return wkb_to_latlng(latest.location) if latest is not None else None


def pickup_passed(
    trip: Trip,
    geometry: RouteGeometry,
    stop_id: uuid.UUID | None,
    where: tuple[float, float] | None,
) -> bool:
    """Whether a vehicle on ``trip`` is too far along to pick someone up at
    ``stop_id`` (None: the route's first stop)."""
    if trip.status != TripStatus.IN_PROGRESS:
        return False
    if stop_id is None or stop_id == geometry.origin_stop_id:
        return True  # it has left its first stop
    if where is None:
        return False  # no position reported yet: nothing says it is behind
    km = geometry.km_until(stop_id, *where)
    return km is not None and km < -PASSED_STOP_TOLERANCE_KM


def has_reached(geometry: RouteGeometry, stop_id: uuid.UUID, where: tuple[float, float]) -> bool:
    """Whether a vehicle at ``where`` is at ``stop_id`` or beyond it."""
    km = geometry.km_until(stop_id, *where)
    return km is not None and km <= PASSED_STOP_TOLERANCE_KM
