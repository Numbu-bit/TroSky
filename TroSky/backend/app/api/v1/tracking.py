"""Live GPS tracking endpoints: current location, ETA, and the WebSocket
live-update stream.

Unlike ``app.api.v1.routes`` (intentionally public trip search/browse),
every endpoint here requires authentication *and* passes
``TrackingService.can_watch_trip`` — a trip's live position is only
visible to its assigned driver, a passenger with an active booking on it,
or a holder of ``Permission.TRIPS_MONITOR_LIVE`` (ops/admin).
"""

from __future__ import annotations

import asyncio
import time
import uuid
from collections.abc import Awaitable, Callable
from typing import Annotated

from fastapi import (
    APIRouter,
    Depends,
    Query,
    WebSocket,
    WebSocketDisconnect,
    WebSocketException,
    status,
)
from redis.asyncio.client import PubSub

from app.api.dependencies import CurrentPrincipal, TrackingServiceDep, resolve_principal
from app.core.config import get_settings
from app.core.database import get_session_factory
from app.core.exceptions import AppError, ForbiddenError, NotFoundError
from app.core.logging import get_logger
from app.core.permissions import Principal
from app.core.ratelimit import rate_limit
from app.core.redis import close_pubsub, get_redis_client
from app.core.telemetry import ACTIVE_WEBSOCKET_CONNECTIONS
from app.schemas.tracking import EtaResponse, LiveLocationResponse, NearbyVehicleResponse
from app.services.tracking_service import TrackingService, channel_name

logger = get_logger(__name__)

router = APIRouter()
# Mounted before the fleet routes: their fleet-owner-only
# /vehicles/{vehicle_id} would otherwise take "nearby" for a vehicle id.
vehicles_router = APIRouter()

# RFC 6455 caps a close frame's reason at 123 bytes.
_MAX_CLOSE_REASON = 120


@router.get("/trips/{trip_id}/location", response_model=LiveLocationResponse)
async def get_trip_location(
    trip_id: uuid.UUID, principal: CurrentPrincipal, service: TrackingServiceDep
) -> LiveLocationResponse:
    if not await service.can_watch_trip(trip_id, principal):
        raise ForbiddenError("You do not have access to this trip's location.")
    live = await service.get_live_location(trip_id)
    if live is None:
        raise NotFoundError("No location has been reported for this trip yet.")
    return LiveLocationResponse(
        trip_id=live.trip_id,
        latitude=live.latitude,
        longitude=live.longitude,
        speed_kmh=live.speed_kmh,
        heading_degrees=live.heading_degrees,
        recorded_at=live.recorded_at,
        is_stale=live.is_stale,
    )


@router.get("/trips/{trip_id}/eta", response_model=EtaResponse)
async def get_trip_eta(
    trip_id: uuid.UUID,
    principal: CurrentPrincipal,
    service: TrackingServiceDep,
    destination_stop_id: uuid.UUID | None = None,
) -> EtaResponse:
    if not await service.can_watch_trip(trip_id, principal):
        raise ForbiddenError("You do not have access to this trip's location.")
    eta = await service.get_eta(trip_id, destination_stop_id=destination_stop_id)
    return EtaResponse(
        distance_km=eta.distance_km, duration_minutes=eta.duration_minutes, eta_at=eta.eta_at
    )


async def authorize_trip_watcher(token: str | None, trip_id: uuid.UUID) -> Principal:
    """Decide whether ``token`` may watch ``trip_id`` right now.

    Runs exactly the check HTTP requests get (``resolve_principal``: token
    signature and expiry, session revocation, account suspension) followed
    by ``can_watch_trip``. Called at the handshake and again periodically
    while the socket is open. Raises ``WebSocketException`` (1008) on refusal.
    """
    if not token:
        raise WebSocketException(code=status.WS_1008_POLICY_VIOLATION, reason="Missing token")
    session_factory = get_session_factory()
    async with session_factory() as session:
        try:
            principal = await resolve_principal(session, token)
        except AppError as exc:
            raise WebSocketException(
                code=status.WS_1008_POLICY_VIOLATION, reason=exc.message[:_MAX_CLOSE_REASON]
            ) from exc
        service = TrackingService(session, get_redis_client(), get_settings())
        if not await service.can_watch_trip(trip_id, principal):
            raise WebSocketException(code=status.WS_1008_POLICY_VIOLATION, reason="Forbidden")
    return principal


async def relay_while_authorized(
    websocket: WebSocket,
    pubsub: PubSub,
    *,
    reauthorize: Callable[[], Awaitable[object]],
    recheck_seconds: float,
    poll_seconds: float = 1.0,
) -> None:
    """Forward published updates until the client leaves or loses access.

    An HTTP request is re-authorized every time it is made; an open socket
    never is, so without this loop a connection accepted once would stream
    indefinitely -- past its token's expiry, a logout, or a suspension.
    ``reauthorize`` runs every ``recheck_seconds`` and closes the socket
    with its 1008 reason when it refuses.

    A pending ``receive()`` watches for the client disconnecting, so a
    silent drop ends the loop promptly rather than re-checking the database
    on behalf of a connection that is already gone.
    """
    next_check = time.monotonic() + recheck_seconds
    client = asyncio.ensure_future(websocket.receive())
    try:
        while True:
            if client.done():
                if client.exception() is not None:
                    return
                if client.result()["type"] == "websocket.disconnect":
                    return
                client = asyncio.ensure_future(websocket.receive())  # ignore client chatter
            message = await pubsub.get_message(ignore_subscribe_messages=True, timeout=poll_seconds)
            if message is not None and message.get("type") == "message":
                await websocket.send_text(message["data"])
            if time.monotonic() >= next_check:
                try:
                    await reauthorize()
                except WebSocketException as exc:
                    await websocket.close(code=exc.code, reason=exc.reason)
                    return
                next_check = time.monotonic() + recheck_seconds
    finally:
        client.cancel()


@router.websocket("/ws/trips/{trip_id}/track")
async def track_trip(websocket: WebSocket, trip_id: uuid.UUID) -> None:
    """Streams live-location updates for one trip as they're published by
    ``TrackingService.record_location``.

    Browsers can't attach an ``Authorization`` header to a WebSocket
    handshake, so the access token is passed as ``?token=...`` instead --
    the standard fallback for this transport. FastAPI dependencies don't run
    for WebSocket routes, so ``authorize_trip_watcher`` applies the same
    checks as ``get_current_principal`` plus ``can_watch_trip``: before
    ``accept()``, and then every ``WS_AUTH_RECHECK_SECONDS`` for as long as
    the socket stays open.
    """
    token = websocket.query_params.get("token")
    await authorize_trip_watcher(token, trip_id)

    redis = get_redis_client()
    await websocket.accept()
    ACTIVE_WEBSOCKET_CONNECTIONS.labels(event="connected").inc()
    pubsub = redis.pubsub()
    try:
        await pubsub.subscribe(channel_name(trip_id))
        await relay_while_authorized(
            websocket,
            pubsub,
            reauthorize=lambda: authorize_trip_watcher(token, trip_id),
            recheck_seconds=get_settings().WS_AUTH_RECHECK_SECONDS,
        )
    except WebSocketDisconnect:
        pass
    finally:
        ACTIVE_WEBSOCKET_CONNECTIONS.labels(event="disconnected").inc()
        await close_pubsub(pubsub)


@vehicles_router.get(
    "/vehicles/nearby",
    response_model=list[NearbyVehicleResponse],
    dependencies=[Depends(rate_limit("tracking:nearby"))],
)
async def list_nearby_vehicles(
    principal: CurrentPrincipal,
    tracking: TrackingServiceDep,
    latitude: Annotated[float, Query(ge=-90, le=90)],
    longitude: Annotated[float, Query(ge=-180, le=180)],
    radius_m: Annotated[int, Query(ge=50, le=20_000)] = 2_000,
    limit: Annotated[int, Query(ge=1, le=50)] = 20,
) -> list[NearbyVehicleResponse]:
    """Vehicles out on a trip within ``radius_m`` of the point, nearest
    first, with their route and free seats -- for the Home map. Based on
    each vehicle's last GPS ping; pings more than a few minutes old are
    left out."""
    nearby = await tracking.find_nearby_vehicles(
        latitude=latitude, longitude=longitude, radius_m=radius_m, limit=limit
    )
    return [
        NearbyVehicleResponse(
            trip_id=vehicle.summary.trip_id,
            vehicle_id=vehicle.summary.vehicle_id,
            vehicle_registration_number=vehicle.summary.vehicle_registration_number,
            vehicle_type=vehicle.summary.vehicle_type,
            route_id=vehicle.summary.route_id,
            route_name=vehicle.summary.route_name,
            latitude=vehicle.location.latitude,
            longitude=vehicle.location.longitude,
            heading=vehicle.location.heading_degrees,
            distance_m=round(vehicle.distance_m, 1),
            available_seats=vehicle.summary.available_seats,
            updated_at=vehicle.location.recorded_at,
        )
        for vehicle in nearby
    ]
