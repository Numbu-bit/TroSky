"""The admin dashboard's live feed, ``GET /admin/stream``: Server-Sent Events
in place of polling.

Events (the SSE ``event:`` name; ``data:`` is JSON):

* ``sos.created``, ``sos.updated`` -- for ``sos:review``
* ``complaint.created``, ``complaint.updated`` -- for ``complaints:manage``
* ``approval.requested``, ``approval.document_uploaded`` -- a driver or
  vehicle, for ``drivers:approve`` or ``vehicles:approve`` respectively
* ``position`` -- a bus moved (at most every few seconds per trip), for
  ``trips:monitor_live``
* ``fraud.flagged``, ``fraud.updated`` -- for ``fraud:view`` or
  ``fraud:manage``
* ``booking.*``, ``trip.*``, ``passenger.*`` -- drivers' answers and what
  followed (``booking.awaiting_acceptance``, ``booking.accepted``,
  ``booking.moved``, ``booking.not_accepted``, ``trip.accepted``,
  ``trip.declined``, ``passenger.alighted``), for ``trips:manage`` or
  ``trips:monitor_live`` (topic ``dispatch``)
* ``end`` -- access was withdrawn (logout, suspension, permissions taken
  away); the server then closes the stream

Every event but ``position`` carries an SSE id. A browser's ``EventSource``
sends the last one back when it reconnects (``Last-Event-ID``), and the
stream replays what was missed from the last ``MAX_EVENTS`` events.
``EventSource`` cannot send an ``Authorization`` header, so the access token
may come as ``?token=`` instead, as for the tracking WebSocket. Access is
re-checked every ``WS_AUTH_RECHECK_SECONDS`` while the stream is open.
"""

from __future__ import annotations

import asyncio
import json
import re
import time
from collections.abc import AsyncIterator, Awaitable, Callable
from typing import Annotated, Any

from fastapi import APIRouter, Depends, Header, Query, Request
from fastapi.responses import StreamingResponse
from fastapi.security import HTTPAuthorizationCredentials
from redis.asyncio import Redis

from app.api.auth_dependencies import resolve_principal
from app.core.admin_events import STREAM_KEY
from app.core.config import get_settings
from app.core.database import get_session_factory
from app.core.exceptions import (
    AppError,
    ExternalServiceUnavailableError,
    ForbiddenError,
    UnauthorizedError,
    ValidationAppError,
)
from app.core.logging import get_logger
from app.core.permissions import Permission, Principal, bearer_scheme
from app.core.redis import get_redis_client

logger = get_logger(__name__)

router = APIRouter()

# Who may follow what.
TOPICS: dict[str, tuple[Permission, ...]] = {
    "sos": (Permission.SOS_REVIEW,),
    "complaints": (Permission.COMPLAINTS_MANAGE,),
    "approvals": (Permission.DRIVERS_APPROVE, Permission.VEHICLES_APPROVE),
    "positions": (Permission.TRIPS_MONITOR_LIVE,),
    "fraud": (Permission.FRAUD_VIEW, Permission.FRAUD_MANAGE),
    "dispatch": (Permission.TRIPS_MANAGE, Permission.TRIPS_MONITOR_LIVE),
}
_EVENT_TOPICS = {
    "sos": "sos",
    "complaint": "complaints",
    "approval": "approvals",
    "fraud": "fraud",
    "booking": "dispatch",
    "trip": "dispatch",
    "passenger": "dispatch",
}
_APPROVAL_PERMISSIONS = {
    "driver": Permission.DRIVERS_APPROVE,
    "vehicle": Permission.VEHICLES_APPROVE,
}
POSITIONS_PATTERN = "trip:*:live-updates"
POSITION_INTERVAL_SECONDS = 5.0
HEARTBEAT_SECONDS = 15.0
RECONNECT_MILLISECONDS = 5000
# Each open stream holds a Redis connection for bus positions; this keeps
# enough of the pool for everything else.
MAX_OPEN_STREAMS = 20
_STREAM_ID = re.compile(r"^\d{1,20}-\d{1,20}$")
_open_streams = 0


def permitted_topics(principal: Principal) -> frozenset[str]:
    return frozenset(
        topic for topic, permissions in TOPICS.items() if principal.has_permission(*permissions)
    )


def _may_see(principal: Principal, topics: frozenset[str], event: dict[str, Any]) -> bool:
    topic = _EVENT_TOPICS.get(str(event.get("type", "")).split(".", 1)[0])
    if topic is None or topic not in topics:
        return False
    if topic == "approvals":
        permission = _APPROVAL_PERMISSIONS.get(str(event.get("data", {}).get("kind")))
        return permission is not None and principal.has_permission(permission)
    return True


def sse(event: str, data: str, *, event_id: str | None = None) -> str:
    lines = [f"id: {event_id}"] if event_id else []
    lines.append(f"event: {event}")
    lines.extend(f"data: {line}" for line in data.splitlines() or [""])
    return "\n".join(lines) + "\n\n"


async def _newest_id(redis: Redis) -> str:
    newest = await redis.xrevrange(STREAM_KEY, count=1)
    return str(newest[0][0]) if newest else "0-0"


async def admin_events(
    redis: Redis,
    *,
    principal: Principal,
    topics: frozenset[str],
    last_event_id: str | None,
    reauthorize: Callable[[], Awaitable[Principal]],
    recheck_seconds: float,
    heartbeat_seconds: float = HEARTBEAT_SECONDS,
    position_interval: float = POSITION_INTERVAL_SECONDS,
    poll_seconds: float = 1.0,
) -> AsyncIterator[str]:
    """The stream's body. Ends by itself only when access is withdrawn; a
    client that disconnects cancels it.

    Where to start reading, and the subscription to positions, are settled
    before the first line is sent: once a client sees the stream open,
    nothing that happens afterwards is missed."""
    if last_event_id and _STREAM_ID.match(last_event_id):
        last_id = last_event_id
    else:
        last_id = await _newest_id(redis)
    pubsub = redis.pubsub() if "positions" in topics else None
    position_sent: dict[str, float] = {}
    now = time.monotonic()
    next_heartbeat, next_check = now + heartbeat_seconds, now + recheck_seconds
    try:
        if pubsub is not None:
            await pubsub.psubscribe(POSITIONS_PATTERN)
        yield f"retry: {RECONNECT_MILLISECONDS}\n\n"
        while True:
            for _stream, entries in await redis.xread({STREAM_KEY: last_id}, count=100):
                for entry_id, fields in entries:
                    last_id = entry_id
                    event = json.loads(fields["event"])
                    if _may_see(principal, topics, event):
                        yield sse(event["type"], json.dumps(event), event_id=entry_id)
            if pubsub is None:
                await asyncio.sleep(poll_seconds)
            else:
                message = await pubsub.get_message(
                    ignore_subscribe_messages=True, timeout=poll_seconds
                )
                while message is not None:
                    if message.get("type") == "pmessage" and "positions" in topics:
                        payload = str(message["data"])
                        trip_id = str(json.loads(payload).get("trip_id"))
                        moment = time.monotonic()
                        if moment - position_sent.get(trip_id, float("-inf")) >= position_interval:
                            position_sent[trip_id] = moment
                            yield sse("position", payload)
                    message = await pubsub.get_message(ignore_subscribe_messages=True, timeout=0)
            now = time.monotonic()
            if now >= next_check:
                try:
                    principal = await reauthorize()
                except AppError as exc:
                    yield sse("end", json.dumps({"reason": exc.message}))
                    return
                topics &= permitted_topics(principal)
                if not topics:
                    reason = "This account may no longer follow the live feed."
                    yield sse("end", json.dumps({"reason": reason}))
                    return
                next_check = now + recheck_seconds
            if now >= next_heartbeat:
                yield ": keep-alive\n\n"
                next_heartbeat = now + heartbeat_seconds
    finally:
        if pubsub is not None:
            await pubsub.punsubscribe(POSITIONS_PATTERN)
            # redis-py's own inline types omit a signature for aclose().
            await pubsub.aclose()  # type: ignore[no-untyped-call]


async def _principal(token: str) -> Principal:
    """The same checks as every HTTP request, in a session of its own: the
    stream outlives the request's."""
    async with get_session_factory()() as session:
        return await resolve_principal(session, token)


async def _counted(events: AsyncIterator[str]) -> AsyncIterator[str]:
    global _open_streams
    _open_streams += 1
    try:
        async for chunk in events:
            yield chunk
    finally:
        _open_streams -= 1


@router.get(
    "/stream",
    response_class=StreamingResponse,
    responses={
        200: {
            "content": {"text/event-stream": {}},
            "description": "Server-Sent Events; see the event list above.",
        }
    },
)
async def admin_stream(
    request: Request,
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer_scheme)],
    token: Annotated[
        str | None, Query(description="The access token, for EventSource (no headers).")
    ] = None,
    topics: Annotated[
        str | None,
        Query(
            description="Comma-separated: sos, complaints, approvals, positions, fraud. "
            "Default: all the caller's permissions allow."
        ),
    ] = None,
    last_event_id: Annotated[str | None, Header(alias="Last-Event-ID")] = None,
) -> StreamingResponse:
    """SOS alerts, complaints, approvals and bus positions as they happen.

    Events: ``sos.created``, ``sos.updated``, ``complaint.created``,
    ``complaint.updated``, ``approval.requested``,
    ``approval.document_uploaded``, ``position``, ``fraud.flagged``,
    ``fraud.updated`` and ``end``. Each but
    ``position`` has an id; reconnecting with ``Last-Event-ID`` replays what
    was missed. A comment line every 15 seconds keeps idle connections
    open."""
    access_token = credentials.credentials if credentials is not None else token
    if not access_token:
        raise UnauthorizedError("Authentication is required.")
    principal = await _principal(access_token)
    request.state.principal = principal
    permitted = permitted_topics(principal)
    chosen = permitted
    if topics:
        wanted = {topic.strip() for topic in topics.split(",") if topic.strip()}
        unknown = wanted - set(TOPICS)
        if unknown:
            raise ValidationAppError(
                f"Unknown topics: {', '.join(sorted(unknown))}.",
                details={"param": "topics", "allowed": sorted(TOPICS)},
            )
        chosen = permitted & wanted
    if not chosen:
        raise ForbiddenError("This account may not follow the live feed.")
    if _open_streams >= MAX_OPEN_STREAMS:
        raise ExternalServiceUnavailableError("Too many live connections; try again shortly.")
    events = admin_events(
        get_redis_client(),
        principal=principal,
        topics=chosen,
        last_event_id=last_event_id,
        reauthorize=lambda: _principal(access_token),
        recheck_seconds=get_settings().WS_AUTH_RECHECK_SECONDS,
    )
    return StreamingResponse(
        _counted(events),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )
