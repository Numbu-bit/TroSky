"""Work that must not hold up an HTTP response -- sending an email, say.

A job runs as an asyncio task on the server's event loop after the caller
has moved on. Nobody awaits it, so a failure is logged here rather than
raised; the application drains outstanding jobs on shutdown so a restart
does not silently drop an email halfway through sending.
"""

from __future__ import annotations

import asyncio
from collections.abc import Coroutine
from typing import Any

from app.core.logging import get_logger

logger = get_logger(__name__)

# The event loop only holds weak references to tasks; this keeps each job
# alive until it finishes.
_jobs: set[asyncio.Task[None]] = set()


def run_in_background(job: Coroutine[Any, Any, None], *, name: str) -> None:
    """Start ``job`` without waiting for it."""
    task = asyncio.get_running_loop().create_task(job, name=name)
    _jobs.add(task)
    task.add_done_callback(_finished)


def _finished(task: asyncio.Task[None]) -> None:
    _jobs.discard(task)
    if not task.cancelled() and (error := task.exception()) is not None:
        logger.error("background_job_failed", job=task.get_name(), exc_info=error)


async def drain_background_jobs(timeout_seconds: float) -> None:
    """Wait up to ``timeout_seconds`` for outstanding jobs to finish."""
    if not _jobs:
        return
    _, pending = await asyncio.wait(set(_jobs), timeout=timeout_seconds)
    if pending:
        logger.warning("background_jobs_abandoned", count=len(pending))
