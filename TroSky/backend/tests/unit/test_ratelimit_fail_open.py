"""Unit tests for the rate-limit dependency's Redis-outage behavior.

This exercises exactly the bug fixed in this phase: wiring
``Depends(rate_limit(...))`` onto routes surfaced a case where a Redis
outage made ``RateLimiter.hit`` raise ``redis.exceptions.RedisError``,
which propagated out of the dependency as an unhandled exception (a 500)
*before* FastAPI ever got to resolve the endpoint's own auth dependency —
turning "Redis is down" into "every rate-limited endpoint, including
login and SOS, is unusable" instead of the intended "rate limiting is
temporarily disabled, everything else still works" degradation. See
``app.core.ratelimit._dependency`` and ``docs/adr/`` for the broader
Redis-is-never-load-bearing-for-correctness principle this restates.

These tests mock ``RateLimiter.hit`` directly rather than going through a
real/fake Redis client, because ``fakeredis`` (this project's only
in-memory Redis substitute) does not support ``EVAL``/Lua scripting
without the optional ``lupa`` C-extension, which isn't installed — the
fixed-window counter itself is only exercised against real Redis via the
existing `require_redis`-gated integration tests. What's being verified
here is purely the dependency's own exception-handling contract, which
doesn't need a working Lua interpreter to test.
"""

from __future__ import annotations

import uuid
from types import SimpleNamespace
from typing import Any

import pytest
from redis.exceptions import ConnectionError as RedisConnectionError

from app.core.exceptions import RateLimitExceededError
from app.core.ratelimit import RateLimiter, rate_limit


def _fake_request(user_id: uuid.UUID | None = None) -> Any:
    principal = SimpleNamespace(user_id=user_id) if user_id else None
    return SimpleNamespace(
        state=SimpleNamespace(principal=principal),
        headers={},
        client=SimpleNamespace(host="203.0.113.7"),
    )


class TestRateLimitFailsOpenOnRedisOutage:
    async def test_redis_outage_does_not_raise(self, mocker: Any) -> None:
        mocker.patch.object(
            RateLimiter, "hit", side_effect=RedisConnectionError("connection refused")
        )
        dependency = rate_limit("sos:trigger")

        # Must return cleanly (fail OPEN) rather than propagate the Redis
        # error — a Redis outage must never turn into a 500 on a
        # rate-limited route. Success is simply not raising.
        await dependency(_fake_request(), client=object())

    async def test_redis_outage_logs_a_warning(self, mocker: Any) -> None:
        mocker.patch.object(
            RateLimiter, "hit", side_effect=RedisConnectionError("connection refused")
        )
        warning = mocker.patch("app.core.ratelimit.logger.warning")
        dependency = rate_limit("sos:trigger")

        await dependency(_fake_request(), client=object())

        warning.assert_called_once()
        assert warning.call_args.args[0] == "ratelimit_check_failed_open"

    async def test_within_limit_allows_request(self, mocker: Any) -> None:
        mocker.patch.object(RateLimiter, "hit", return_value=(True, 1))
        dependency = rate_limit("sos:trigger")

        await dependency(_fake_request(), client=object())

    async def test_over_limit_raises_rate_limit_exceeded(self, mocker: Any) -> None:
        mocker.patch.object(RateLimiter, "hit", return_value=(False, 999))
        dependency = rate_limit("sos:trigger")

        with pytest.raises(RateLimitExceededError):
            await dependency(_fake_request(), client=object())
