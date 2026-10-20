"""Async Redis client management and reusable primitives.

Redis is used for: caching, OTP storage, rate limiting, temporary seat-hold
acceleration, distributed locks, and live GPS/location state + pub/sub. It is
never the sole authority for financial or capacity-critical data — Postgres
always is (see :mod:`app.core.database`).
"""

from __future__ import annotations

import uuid
from collections.abc import AsyncGenerator, Awaitable
from types import TracebackType
from typing import Self, cast

import anyio
import redis.asyncio as redis_asyncio
from redis.asyncio import Redis
from redis.asyncio.client import PubSub
from redis.asyncio.connection import ConnectionPool

from app.core.config import get_settings
from app.core.logging import get_logger

logger = get_logger(__name__)

_pool: ConnectionPool | None = None
_client: Redis | None = None

# Lua script for a safe "compare-and-delete" unlock: only release the lock
# if it is still held by the caller (prevents releasing another holder's
# lock after expiry + re-acquisition by someone else).
_UNLOCK_SCRIPT = """
if redis.call("get", KEYS[1]) == ARGV[1] then
    return redis.call("del", KEYS[1])
else
    return 0
end
"""


def get_redis_pool() -> ConnectionPool:
    global _pool
    if _pool is None:
        settings = get_settings()
        _pool = redis_asyncio.ConnectionPool.from_url(
            settings.REDIS_URL,
            max_connections=settings.REDIS_MAX_CONNECTIONS,
            decode_responses=True,
        )
    return _pool


def get_redis_client() -> Redis:
    global _client
    if _client is None:
        _client = redis_asyncio.Redis(connection_pool=get_redis_pool())
    return _client


async def get_redis() -> AsyncGenerator[Redis, None]:
    """FastAPI dependency yielding the shared Redis client."""
    yield get_redis_client()


async def close_redis() -> None:
    global _client, _pool
    if _client is not None:
        await _client.aclose()
    if _pool is not None:
        await _pool.disconnect()
    _client = None
    _pool = None
    logger.info("redis_connection_closed")


async def close_pubsub(pubsub: PubSub) -> None:
    """Gives a subscription's connection back to the pool, even from a task
    that is being cancelled.

    A browser that leaves a stream cancels it, and Starlette's cancellation
    hits every await until the task ends. Unshielded, the close is cancelled
    while the socket shuts, before the connection goes back: the pool loses
    it for good, and once ``REDIS_MAX_CONNECTIONS`` are lost every Redis
    call fails with "Too many connections". Closing ends the subscriptions
    too, so nothing needs unsubscribing first."""
    with anyio.CancelScope(shield=True):
        # redis-py's own inline types omit a signature for aclose().
        await pubsub.aclose()  # type: ignore[no-untyped-call]


async def check_redis_connection() -> bool:
    try:
        client = get_redis_client()
        return bool(await client.ping())
    except Exception:  # health check must never raise
        logger.warning("redis_health_check_failed", exc_info=True)
        return False


class RedisLock:
    """A simple, safe distributed lock built on ``SET NX PX`` + Lua-guarded unlock.

    This is an *acceleration / stampede-prevention* mechanism only. Any
    operation that must be correct under concurrency (seat holds, wallet
    debits, ticket scans) is additionally protected by a database-level
    constraint or row lock — this class alone must never be trusted as the
    final word on correctness.
    """

    def __init__(self, client: Redis, key: str, *, ttl_seconds: int = 10) -> None:
        self._client = client
        self._key = f"lock:{key}"
        self._ttl_seconds = ttl_seconds
        self._token = uuid.uuid4().hex
        self._acquired = False

    async def acquire(self) -> bool:
        acquired = await self._client.set(self._key, self._token, nx=True, ex=self._ttl_seconds)
        self._acquired = bool(acquired)
        return self._acquired

    async def release(self) -> None:
        if not self._acquired:
            return
        # redis-py's sync/async `eval` share a signature typed for the sync
        # client; the awaitable return type must be asserted explicitly here.
        result = self._client.eval(_UNLOCK_SCRIPT, 1, self._key, self._token)
        await cast(Awaitable[object], result)
        self._acquired = False

    async def __aenter__(self) -> Self:
        acquired = await self.acquire()
        if not acquired:
            raise TimeoutError(f"Could not acquire lock: {self._key}")
        return self

    async def __aexit__(
        self,
        exc_type: type[BaseException] | None,
        exc_val: BaseException | None,
        exc_tb: TracebackType | None,
    ) -> None:
        await self.release()


def redis_lock(client: Redis, key: str, *, ttl_seconds: int = 10) -> RedisLock:
    return RedisLock(client, key, ttl_seconds=ttl_seconds)
