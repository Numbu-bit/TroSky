"""Events for the admin dashboard's live stream (``GET /admin/stream``).

Services ``announce`` what the operations team should see at once: an SOS
raised or updated, a complaint filed or changed, a driver or vehicle waiting
for approval. An announcement waits on the database session and is added to
the Redis stream ``STREAM_KEY`` only after the transaction commits, so
admins are never shown something that was rolled back.

The stream keeps the most recent ``MAX_EVENTS``. Each event's stream id is
its SSE id, so a dashboard that reconnects (``Last-Event-ID``) catches up on
what it missed instead of losing it. Bus positions are not stored here; the
stream relays them from the trips' own live channels.
"""

from __future__ import annotations

import json
from datetime import UTC, datetime
from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.logging import get_logger
from app.core.redis import get_redis_client

logger = get_logger(__name__)

STREAM_KEY = "admin:events"
MAX_EVENTS = 1000
_PENDING = "trosky.admin_events"


def _plain(value: Any) -> Any:
    """JSON-safe: ids, money and times as strings."""
    if value is None or isinstance(value, bool | int | float | str):
        return value
    if isinstance(value, datetime):
        return value.isoformat()
    if isinstance(value, dict):
        return {str(k): _plain(v) for k, v in value.items()}
    if isinstance(value, list | tuple):
        return [_plain(item) for item in value]
    return str(value)


def announce(session: AsyncSession, event_type: str, **data: Any) -> None:
    """Queue ``event_type`` (e.g. ``"sos.created"``) for the admin stream,
    to be published when ``session`` commits."""
    pending: list[dict[str, Any]] = session.info.setdefault(_PENDING, [])
    pending.append({"type": event_type, "at": datetime.now(UTC).isoformat(), "data": _plain(data)})


async def publish_announced(session: AsyncSession) -> None:
    """After the commit: add what ``session`` announced to the stream.

    Best effort. The change itself is committed whatever happens here, and
    ``/admin/alerts`` lists anything still needing attention, so a Redis
    failure is logged rather than failing a request that succeeded."""
    events: list[dict[str, Any]] = session.info.pop(_PENDING, [])
    if not events:
        return
    try:
        async with get_redis_client().pipeline(transaction=False) as pipe:
            for event in events:
                pipe.xadd(
                    STREAM_KEY, {"event": json.dumps(event)}, maxlen=MAX_EVENTS, approximate=True
                )
            await pipe.execute()
    except Exception:
        logger.warning(
            "admin_events_not_published", events=[event["type"] for event in events], exc_info=True
        )
