"""Background tasks share one event loop per worker process, so connections
pooled by one task still work in the next (they used to fail with "attached
to a different loop" when each task ran in a loop of its own)."""

from __future__ import annotations

import asyncio
from collections.abc import Iterator

import pytest
import redis
from redis import asyncio as redis_asyncio

from app.core.config import get_settings
from app.workers import loop


@pytest.fixture(autouse=True)
def _fresh_loop(monkeypatch: pytest.MonkeyPatch) -> Iterator[None]:
    monkeypatch.setattr(loop, "_runner", None)
    yield
    if loop._runner is not None:
        loop._runner.close()


async def _current_loop() -> asyncio.AbstractEventLoop:
    return asyncio.get_running_loop()


def test_tasks_run_on_one_loop_that_stays_open() -> None:
    first = loop.run_task(_current_loop())
    second = loop.run_task(_current_loop())
    assert first is second
    assert not first.is_closed()


def test_a_pooled_connection_works_in_the_next_task() -> None:
    url = get_settings().REDIS_URL
    try:
        redis.Redis.from_url(url, socket_connect_timeout=1).ping()
    except redis.exceptions.ConnectionError:
        pytest.skip("Redis is not reachable.")
    pool = redis_asyncio.ConnectionPool.from_url(url, max_connections=1)
    client = redis_asyncio.Redis(connection_pool=pool)

    # The same pooled connection, task after task: what the seat-hold sweep
    # and the other periodic tasks do.
    for _ in range(3):
        assert loop.run_task(client.ping())

    loop.run_task(client.aclose())
    loop.run_task(pool.disconnect())


def test_shutting_down_closes_the_loop() -> None:
    used = loop.run_task(_current_loop())
    loop.close_loop()
    assert used.is_closed()
    assert loop._runner is None
    assert loop.run_task(_current_loop()) is not used  # a later task gets a new one
