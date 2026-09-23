"""Live GPS tracking endpoints: current location, ETA, and the WebSocket
live-update stream.

Unlike ``app.api.v1.routes`` (intentionally public trip search/browse),
every endpoint here requires authentication *and* passes
``TrackingService.can_watch_trip`` — a trip's live position is only
visible to its assigned driver, a passenger with an active booking on it,
or a holder of ``Permission.TRIPS_MONITOR_LIVE`` (ops/admin).
"""

from __future__ import annotations

import uuid

from fastapi import APIRouter, WebSocket, WebSocketDisconnect, WebSocketException, status

from app.api.dependencies import CurrentPrincipal, TrackingServiceDep
from app.core.config import get_settings
from app.core.database import get_session_factory
from app.core.exceptions import ForbiddenError, NotFoundError
from app.core.logging import get_logger
from app.core.permissions import Principal
from app.core.redis import get_redis_client
from app.core.security import TokenError, TokenType, decode_token
from app.core.telemetry import ACTIVE_WEBSOCKET_CONNECTIONS
from app.schemas.tracking import EtaResponse, LiveLocationResponse
from app.services.tracking_service import TrackingService, channel_name

logger = get_logger(__name__)

router = APIRouter()


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


@router.websocket("/ws/trips/{trip_id}/track")
async def track_trip(websocket: WebSocket, trip_id: uuid.UUID) -> None:
    """Streams live-location updates for one trip as they're published by
    ``TrackingService.record_location``.

    Browsers can't attach an ``Authorization`` header to a WebSocket
    handshake, so the access token is passed as ``?token=...`` instead —
    the standard fallback for this transport; the same JWT validation and
    ``can_watch_trip`` authorization check apply as on the REST endpoints
    above, just performed before ``accept()`` rather than via a FastAPI
    dependency (which doesn't run for WebSocket routes).
    """
    token = websocket.query_params.get("token")
    if not token:
        raise WebSocketException(code=status.WS_1008_POLICY_VIOLATION, reason="Missing token")
    try:
        claims = decode_token(token, expected_type=TokenType.ACCESS)
    except TokenError as exc:
        raise WebSocketException(
            code=status.WS_1008_POLICY_VIOLATION, reason="Invalid token"
        ) from exc

    session_factory = get_session_factory()
    redis = get_redis_client()
    async with session_factory() as session:
        # A minimal, session-only Principal: WebSocket auth intentionally
        # skips the full session-revocation/role-refresh lookup
        # `get_current_principal` does for HTTP requests (no per-message
        # request cycle to hang that check off of) — acceptable for a
        # read-only location stream gated additionally by
        # `can_watch_trip`, which re-checks booking/driver ownership
        # against the database on every connection.
        principal = Principal(
            user_id=claims.subject_user_id, session_id=claims.session_id, roles=frozenset()
        )
        service = TrackingService(session, redis, get_settings())
        allowed = await service.can_watch_trip(trip_id, principal)

    if not allowed:
        raise WebSocketException(code=status.WS_1008_POLICY_VIOLATION, reason="Forbidden")

    await websocket.accept()
    ACTIVE_WEBSOCKET_CONNECTIONS.labels(event="connected").inc()
    pubsub = redis.pubsub()
    try:
        await pubsub.subscribe(channel_name(trip_id))
        async for message in pubsub.listen():
            if message["type"] != "message":
                continue
            await websocket.send_text(message["data"])
    except WebSocketDisconnect:
        pass
    finally:
        ACTIVE_WEBSOCKET_CONNECTIONS.labels(event="disconnected").inc()
        await pubsub.unsubscribe(channel_name(trip_id))
        # redis-py's own inline types omit a signature for aclose().
        await pubsub.aclose()  # type: ignore[no-untyped-call]
