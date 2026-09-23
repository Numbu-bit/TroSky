"""Blocks until Postgres and Redis are reachable, or exits non-zero on timeout.

Used by the container entrypoint so the API/worker/scheduler never start
handling traffic (or, worse, run migrations) against a database that is
still coming up.
"""

from __future__ import annotations

import asyncio
import sys
import time

from app.core.config import get_settings
from app.core.logging import configure_logging, get_logger

logger = get_logger(__name__)

MAX_WAIT_SECONDS = 60
POLL_INTERVAL_SECONDS = 2


async def _wait_for_postgres() -> bool:
    import asyncpg

    settings = get_settings()
    dsn = settings.DATABASE_URL.replace("postgresql+asyncpg", "postgresql")
    deadline = time.monotonic() + MAX_WAIT_SECONDS
    while time.monotonic() < deadline:
        try:
            conn = await asyncpg.connect(dsn, timeout=5)
            await conn.close()
            return True
        except Exception as exc:  # retry loop, not a handler
            logger.info("waiting_for_postgres", error=str(exc))
            await asyncio.sleep(POLL_INTERVAL_SECONDS)
    return False


async def _wait_for_redis() -> bool:
    import redis.asyncio as redis_asyncio

    settings = get_settings()
    deadline = time.monotonic() + MAX_WAIT_SECONDS
    while time.monotonic() < deadline:
        client = redis_asyncio.Redis.from_url(settings.REDIS_URL)
        try:
            if await client.ping():
                return True
        except Exception as exc:  # retry loop, not a handler
            logger.info("waiting_for_redis", error=str(exc))
        finally:
            await client.aclose()
        await asyncio.sleep(POLL_INTERVAL_SECONDS)
    return False


async def main() -> int:
    configure_logging(log_level="INFO", json_logs=False)
    postgres_ok = await _wait_for_postgres()
    if not postgres_ok:
        logger.error("postgres_unreachable", timeout_seconds=MAX_WAIT_SECONDS)
        return 1
    logger.info("postgres_ready")

    redis_ok = await _wait_for_redis()
    if not redis_ok:
        logger.error("redis_unreachable", timeout_seconds=MAX_WAIT_SECONDS)
        return 1
    logger.info("redis_ready")
    return 0


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
