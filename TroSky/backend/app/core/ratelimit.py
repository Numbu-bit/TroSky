"""Redis-backed rate limiting (fixed-window counter with atomic Lua increment).

Used to protect registration, login, OTP request/verify, password reset,
token refresh, payment initiation, QR validation, SOS, and location
publishing endpoints from abuse, per the security requirements.
"""

from __future__ import annotations

from collections.abc import Awaitable, Callable, Coroutine
from dataclasses import dataclass
from typing import Any, cast

from fastapi import Depends, Request
from redis.asyncio import Redis
from redis.exceptions import RedisError

from app.core.client_ip import resolve_client_ip
from app.core.config import get_settings
from app.core.exceptions import RateLimitExceededError
from app.core.logging import get_logger
from app.core.redis import get_redis

logger = get_logger(__name__)

# Atomic "increment, set expiry on first hit" — avoids a race between two
# concurrent requests both resetting the window.
_FIXED_WINDOW_SCRIPT = """
local current = redis.call("INCR", KEYS[1])
if tonumber(current) == 1 then
    redis.call("EXPIRE", KEYS[1], ARGV[1])
end
return current
"""


@dataclass(frozen=True, slots=True)
class RateLimitRule:
    """A named limit: at most ``limit`` calls per ``window_seconds`` per key."""

    name: str
    limit: int
    window_seconds: int


# Defaults per the spec's protected-endpoint list. Overridable via
# RATE_LIMIT_DEFAULT_PER_MINUTE for anything not explicitly listed.
DEFAULT_RULES: dict[str, RateLimitRule] = {
    "auth:register": RateLimitRule("auth:register", limit=5, window_seconds=3600),
    "auth:login": RateLimitRule("auth:login", limit=10, window_seconds=300),
    "auth:otp_request": RateLimitRule("auth:otp_request", limit=5, window_seconds=300),
    "auth:otp_verify": RateLimitRule("auth:otp_verify", limit=10, window_seconds=300),
    "auth:password_reset": RateLimitRule("auth:password_reset", limit=5, window_seconds=3600),
    "auth:token_refresh": RateLimitRule("auth:token_refresh", limit=30, window_seconds=300),
    "payments:initiate": RateLimitRule("payments:initiate", limit=10, window_seconds=300),
    "tickets:validate": RateLimitRule("tickets:validate", limit=60, window_seconds=60),
    "sos:trigger": RateLimitRule("sos:trigger", limit=10, window_seconds=600),
    "tracking:location_publish": RateLimitRule(
        "tracking:location_publish", limit=30, window_seconds=60
    ),
    # Maps poll this; generous, but bounded.
    "tracking:nearby": RateLimitRule("tracking:nearby", limit=60, window_seconds=60),
    # Public: anyone with a shared link polls this, so it is limited per IP.
    "shared_trips:read": RateLimitRule("shared_trips:read", limit=120, window_seconds=60),
    "bookings:share": RateLimitRule("bookings:share", limit=20, window_seconds=3600),
    # Phone number -> driver name: slow enough that it cannot be used to
    # walk the phone-number space.
    "fleets:driver_lookup": RateLimitRule("fleets:driver_lookup", limit=30, window_seconds=300),
}


class RateLimiter:
    def __init__(self, client: Redis) -> None:
        self._client = client

    async def hit(self, rule: RateLimitRule, identifier: str) -> tuple[bool, int]:
        """Record one hit; return ``(allowed, current_count)``."""
        key = f"ratelimit:{rule.name}:{identifier}"
        # redis-py's sync/async `eval` share a signature typed for the sync
        # client; the awaitable return type must be asserted explicitly here.
        result = self._client.eval(_FIXED_WINDOW_SCRIPT, 1, key, str(rule.window_seconds))
        current = await cast(Awaitable[object], result)
        current_count = int(cast(str, current))
        return current_count <= rule.limit, current_count


def _client_identifier(request: Request) -> str:
    """Prefer an authenticated principal if resolved upstream; otherwise the
    client IP.

    ``X-Forwarded-For`` is believed only from ``TRUSTED_PROXY_CIDRS`` (see
    ``app.core.client_ip``). Taking it from anyone, as this once did, let a
    client dodge every limit by sending a fresh made-up address per request.
    """
    principal = getattr(request.state, "principal", None)
    if principal is not None:
        return f"user:{principal.user_id}"
    client_ip = resolve_client_ip(request, get_settings().trusted_proxy_networks)
    return f"ip:{client_ip or 'unknown'}"


def rate_limit(
    rule_name: str, *, limit: int | None = None, window_seconds: int | None = None
) -> Callable[..., Coroutine[Any, Any, None]]:
    """Dependency factory applying a named (or ad-hoc) rate-limit rule keyed
    by authenticated user id, falling back to client IP."""

    async def _dependency(request: Request, client: Redis = Depends(get_redis)) -> None:
        settings = get_settings()
        override = settings.rate_limit_overrides.get(rule_name)
        if override is not None:
            # RATE_LIMIT_OVERRIDES wins over both DEFAULT_RULES and any
            # ad-hoc limit passed by the caller, so an operator can loosen
            # (or tighten) a rule per environment without a code change.
            rule = RateLimitRule(rule_name, limit=override[0], window_seconds=override[1])
        else:
            rule = DEFAULT_RULES.get(rule_name) or RateLimitRule(
                rule_name,
                limit=limit or settings.RATE_LIMIT_DEFAULT_PER_MINUTE,
                window_seconds=window_seconds or 60,
            )
        limiter = RateLimiter(client)
        identifier = _client_identifier(request)
        try:
            allowed, _current = await limiter.hit(rule, identifier)
        except RedisError:
            # Fail OPEN, not closed: rate limiting is an abuse-prevention
            # acceleration layer, not a source of truth (the same
            # Redis-is-never-load-bearing-for-correctness principle this
            # codebase applies everywhere else — see e.g.
            # app.repositories.booking_repository's module docstring). A
            # Redis outage must degrade to "unlimited requests, logged,"
            # never to every rate-limited endpoint (including login,
            # payment initiation, SOS) hard-failing with a 500.
            logger.warning("ratelimit_check_failed_open", rule=rule.name)
            return
        if not allowed:
            details = {
                "rule": rule.name,
                "limit": rule.limit,
                "window_seconds": rule.window_seconds,
            }
            raise RateLimitExceededError(details=details)

    return _dependency
