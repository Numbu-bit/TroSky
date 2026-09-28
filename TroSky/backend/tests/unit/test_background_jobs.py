"""``app.core.background``: jobs run after the caller moves on, failures
are contained, and shutdown can wait for what is still running."""

from __future__ import annotations

import asyncio

import pytest

from app.core import background
from app.core.background import drain_background_jobs, run_in_background

pytestmark = pytest.mark.asyncio


async def test_the_caller_does_not_wait_for_the_job() -> None:
    gate = asyncio.Event()
    finished: list[str] = []

    async def job() -> None:
        await gate.wait()
        finished.append("done")

    run_in_background(job(), name="gated")
    assert finished == []  # still waiting, and the caller carried on

    gate.set()
    await drain_background_jobs(timeout_seconds=1)
    assert finished == ["done"]
    assert not background._jobs


async def test_a_failing_job_is_contained() -> None:
    async def job() -> None:
        raise RuntimeError("mail server down")

    run_in_background(job(), name="failing")
    await drain_background_jobs(timeout_seconds=1)  # does not raise
    assert not background._jobs


async def test_draining_gives_up_after_the_timeout() -> None:
    gate = asyncio.Event()

    async def job() -> None:
        await gate.wait()

    run_in_background(job(), name="stuck")
    await drain_background_jobs(timeout_seconds=0.05)
    assert len(background._jobs) == 1  # abandoned, not waited on forever
    gate.set()
    await drain_background_jobs(timeout_seconds=1)
