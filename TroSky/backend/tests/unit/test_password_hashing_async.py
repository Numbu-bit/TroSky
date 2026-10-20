"""Hashing and checking passwords off the event loop: the server keeps
answering while a password is checked, and only a few are checked at once."""

from __future__ import annotations

import asyncio
import threading
import time
from collections.abc import Iterator
from concurrent.futures import ThreadPoolExecutor

import pytest

from app.core import security

pytestmark = pytest.mark.asyncio


@pytest.fixture
def pool_of(monkeypatch: pytest.MonkeyPatch) -> Iterator[object]:
    """Swap in a pool of ``n`` threads, as PASSWORD_HASH_CONCURRENCY=n would."""
    pools: list[ThreadPoolExecutor] = []

    def make(n: int) -> None:
        pool = ThreadPoolExecutor(max_workers=n)
        pools.append(pool)
        monkeypatch.setattr(security, "_hash_pool", pool)

    yield make
    for pool in pools:
        pool.shutdown(wait=True)


async def test_a_password_hashed_off_the_loop_still_checks() -> None:
    hashed = await security.hash_password_async("Str0ngPass")
    assert await security.verify_password_async("Str0ngPass", hashed)
    assert not await security.verify_password_async("wrong", hashed)


async def test_the_server_keeps_answering_while_a_password_is_checked(
    monkeypatch: pytest.MonkeyPatch, pool_of
) -> None:
    pool_of(2)

    def slow_check(plain: str, hashed: str) -> bool:
        time.sleep(0.3)  # a slow server's Argon2
        return True

    monkeypatch.setattr(security, "verify_password", slow_check)
    ticks = 0

    async def health_checks() -> None:
        nonlocal ticks
        while True:
            await asyncio.sleep(0.01)
            ticks += 1

    ticker = asyncio.create_task(health_checks())
    assert await security.verify_password_async("Str0ngPass", "hash")
    ticker.cancel()

    # Run in the loop, a 0.3 s check would have let none through.
    assert ticks >= 10


async def test_only_a_few_are_checked_at_once(monkeypatch: pytest.MonkeyPatch, pool_of) -> None:
    pool_of(2)
    running = most = 0
    lock = threading.Lock()

    def counted_check(plain: str, hashed: str) -> bool:
        nonlocal running, most
        with lock:
            running += 1
            most = max(most, running)
        time.sleep(0.05)
        with lock:
            running -= 1
        return True

    monkeypatch.setattr(security, "verify_password", counted_check)

    results = await asyncio.gather(
        *(security.verify_password_async("Str0ngPass", "hash") for _ in range(6))
    )

    assert all(results)
    assert most == 2
