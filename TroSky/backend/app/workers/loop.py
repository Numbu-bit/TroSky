"""One event loop per worker process, shared by every task it runs.

The database engine and the Redis client are process-wide, and a pooled
connection belongs to the event loop that opened it. Each task used to run
in a loop of its own (``asyncio.run``), closed when the task finished: the
next task in the process then took a pooled connection from that closed
loop and failed ("attached to a different loop", "Event loop is closed").
Most seat-hold sweeps did. Tasks now run on one loop, kept for the life of
the worker process, so pooled connections stay usable from one task to the
next. ``--max-tasks-per-child 1`` is no longer needed to work around it.

Prefork (each child has its own loop) and solo pools both work. With a
threads pool, tasks in one process take turns on the loop.
"""

from __future__ import annotations

import asyncio
import threading
from collections.abc import Coroutine
from typing import Any, TypeVar

from celery.signals import worker_process_shutdown

from app.core.logging import get_logger

logger = get_logger(__name__)

T = TypeVar("T")

_runner: asyncio.Runner | None = None
_turn = threading.Lock()


def run_task(coroutine: Coroutine[Any, Any, T]) -> T:
    """Run a task's coroutine on this process's event loop."""
    global _runner
    with _turn:
        if _runner is None:
            _runner = asyncio.Runner()
        return _runner.run(coroutine)


def close_loop(**_: object) -> None:
    """Close the pools on the loop their connections belong to, then the
    loop itself."""
    global _runner
    from app.core.database import dispose_engine
    from app.core.redis import close_redis

    with _turn:
        if _runner is None:
            return
        try:
            _runner.run(dispose_engine())
            _runner.run(close_redis())
        except Exception:  # shutting down: log, never block the exit
            logger.warning("worker_loop_close_failed", exc_info=True)
        finally:
            _runner.close()
            _runner = None


worker_process_shutdown.connect(close_loop, weak=False)
