"""Events for the admin stream, against a real Redis: published only after
a commit, and relayed to each admin as their permissions allow.

Other tests publish too, so each test looks for its own events (by a
marker) rather than for the next event that arrives.
"""

from __future__ import annotations

import asyncio
import json
import uuid
from collections.abc import AsyncIterator, Awaitable, Callable
from datetime import UTC, datetime
from decimal import Decimal
from typing import Any

import pytest

from app.api.v1.admin_stream import admin_events, permitted_topics, sse
from app.core import admin_events as events_module
from app.core.admin_events import STREAM_KEY, announce, publish_announced
from app.core.database import get_db, get_session_factory
from app.core.exceptions import UnauthorizedError
from app.core.permissions import Permission, Principal
from app.core.redis import get_redis_client

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]


def _principal(*permissions: Permission) -> Principal:
    return Principal(
        user_id=uuid.uuid4(),
        session_id=uuid.uuid4(),
        roles=frozenset({"admin"}),
        permissions=frozenset(permission.value for permission in permissions),
    )


async def _publish(event_type: str, **data: object) -> None:
    async with get_session_factory()() as session:
        announce(session, event_type, **data)
        await publish_announced(session)


async def _recent(count: int = 50) -> list[dict[str, Any]]:
    entries = await get_redis_client().xrevrange(STREAM_KEY, count=count)
    return [json.loads(fields["event"]) for _, fields in entries]


async def _next(chunks: AsyncIterator[str], *, seconds: float = 10) -> str:
    """The next chunk that is not a keep-alive comment."""
    while True:
        chunk = await asyncio.wait_for(anext(chunks), seconds)
        if not chunk.startswith(":"):
            return chunk


async def _until(chunks: AsyncIterator[str], marker: str) -> list[str]:
    """Every chunk up to and including the one that mentions ``marker``."""
    seen = []
    while True:
        seen.append(await _next(chunks))
        if marker in seen[-1]:
            return seen


def _stream(
    principal: Principal,
    *,
    last_event_id: str | None = None,
    reauthorize: Callable[[], Awaitable[Principal]] | None = None,
    recheck_seconds: float = 300,
    position_interval: float = 5,
) -> AsyncIterator[str]:
    async def unchanged() -> Principal:
        return principal

    return admin_events(
        get_redis_client(),
        principal=principal,
        topics=permitted_topics(principal),
        last_event_id=last_event_id,
        reauthorize=reauthorize or unchanged,
        recheck_seconds=recheck_seconds,
        position_interval=position_interval,
        poll_seconds=0.05,
    )


class TestPublishing:
    async def test_an_announcement_reaches_the_stream(self, require_redis: None) -> None:
        marker = str(uuid.uuid4())

        await _publish(
            "complaint.created", complaint_id=marker, amount=Decimal("1.50"), at=datetime.now(UTC)
        )

        [event] = [e for e in await _recent() if e["data"].get("complaint_id") == marker]
        assert event["type"] == "complaint.created"
        assert event["data"]["amount"] == "1.50"

    async def test_after_a_commit_and_never_after_a_rollback(self, require_redis: None) -> None:
        committed, failed = str(uuid.uuid4()), str(uuid.uuid4())

        ok = get_db()
        announce(await anext(ok), "complaint.created", complaint_id=committed)
        with pytest.raises(StopAsyncIteration):
            await anext(ok)
        bad = get_db()
        announce(await anext(bad), "complaint.created", complaint_id=failed)
        with pytest.raises(RuntimeError):
            await bad.athrow(RuntimeError("the request failed"))

        published = {e["data"].get("complaint_id") for e in await _recent()}
        assert committed in published
        assert failed not in published

    async def test_redis_down_does_not_fail_what_was_committed(
        self, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        class Down:
            def pipeline(self, **_: object) -> object:
                raise ConnectionError("Redis is down")

        monkeypatch.setattr(events_module, "get_redis_client", lambda: Down())
        async with get_session_factory()() as session:
            announce(session, "sos.created", alert_id=uuid.uuid4())

            await publish_announced(session)  # logged, not raised

            assert "trosky.admin_events" not in session.info


class TestTheStream:
    async def test_each_admin_gets_what_they_may_see(self, require_redis: None) -> None:
        chunks = _stream(_principal(Permission.SOS_REVIEW, Permission.VEHICLES_APPROVE))
        assert (await _next(chunks)).startswith("retry:")
        complaint, driver, vehicle, alert = (str(uuid.uuid4()) for _ in range(4))

        await _publish("complaint.created", complaint_id=complaint)
        await _publish("approval.requested", kind="driver", driver_id=driver)
        await _publish("approval.requested", kind="vehicle", vehicle_id=vehicle)
        await _publish("sos.created", alert_id=alert)
        seen = await _until(chunks, alert)
        await chunks.aclose()

        everything = "".join(seen)
        assert vehicle in everything
        assert complaint not in everything  # no complaints:manage
        assert driver not in everything  # vehicles:approve, not drivers:approve
        assert seen[-1].startswith("id: ")
        assert "\nevent: sos.created\n" in seen[-1]

    async def test_fraud_flags_to_fraud_reviewers(self, require_redis: None) -> None:
        reviewer = _stream(_principal(Permission.FRAUD_VIEW))
        other = _stream(_principal(Permission.SOS_REVIEW))
        await _next(reviewer)
        await _next(other)
        flagged, sentinel = str(uuid.uuid4()), str(uuid.uuid4())

        await _publish("fraud.flagged", flag_id=flagged, risk_score=80)
        await _publish("sos.created", alert_id=sentinel)
        seen_by_reviewer = "".join(await _until(reviewer, flagged))
        seen_by_other = "".join(await _until(other, sentinel))
        await reviewer.aclose()
        await other.aclose()

        assert "event: fraud.flagged" in seen_by_reviewer
        assert flagged not in seen_by_other

    async def test_a_reconnection_catches_up(self, require_redis: None) -> None:
        await _publish("sos.updated", alert_id=str(uuid.uuid4()))
        [(last_seen, _)] = await get_redis_client().xrevrange(STREAM_KEY, count=1)
        missed = str(uuid.uuid4())
        await _publish("sos.updated", alert_id=missed)

        chunks = _stream(_principal(Permission.SOS_REVIEW), last_event_id=last_seen)
        await _next(chunks)  # retry
        seen = await _until(chunks, missed)
        await chunks.aclose()

        assert "event: sos.updated" in seen[-1]

    async def test_bus_positions_at_most_every_few_seconds(self, require_redis: None) -> None:
        chunks = _stream(_principal(Permission.TRIPS_MONITOR_LIVE), position_interval=60)
        await _next(chunks)  # retry: subscribed by now
        moving, other = str(uuid.uuid4()), str(uuid.uuid4())
        redis = get_redis_client()

        for trip_id, latitude in ((moving, 5.6), (moving, 5.61), (other, 5.7)):
            await redis.publish(
                f"trip:{trip_id}:live-updates",
                json.dumps({"trip_id": trip_id, "latitude": latitude, "longitude": -0.2}),
            )
        seen = [chunk for chunk in await _until(chunks, other) if moving in chunk]
        await chunks.aclose()

        assert len(seen) == 1  # the second ping came too soon after the first
        assert seen[0].startswith("event: position")
        assert '"latitude": 5.6,' in seen[0]

    async def test_withdrawn_access_ends_it(self, require_redis: None) -> None:
        async def refused() -> Principal:
            raise UnauthorizedError("This session has been revoked.")

        chunks = _stream(_principal(Permission.SOS_REVIEW), reauthorize=refused, recheck_seconds=0)
        await _next(chunks)  # retry
        ending = await _next(chunks)

        assert ending.startswith("event: end")
        assert "revoked" in ending
        with pytest.raises(StopAsyncIteration):
            await anext(chunks)

    async def test_permissions_taken_away_end_it(self, require_redis: None) -> None:
        async def demoted() -> Principal:
            return _principal(Permission.REPORTS_VIEW)

        chunks = _stream(_principal(Permission.SOS_REVIEW), reauthorize=demoted, recheck_seconds=0)
        await _next(chunks)  # retry

        assert (await _next(chunks)).startswith("event: end")


class TestTheFormat:
    async def test_an_event(self) -> None:
        assert sse("sos.created", '{"a": 1}', event_id="1-0") == (
            'id: 1-0\nevent: sos.created\ndata: {"a": 1}\n\n'
        )

    async def test_several_lines_of_data(self) -> None:
        assert sse("end", "one\ntwo") == "event: end\ndata: one\ndata: two\n\n"
