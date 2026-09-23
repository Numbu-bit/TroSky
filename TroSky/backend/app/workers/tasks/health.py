"""Baseline worker health/heartbeat task.

Exists so the Celery worker and beat scheduler have at least one real,
scheduled task from Phase 1 onward — useful for confirming the broker,
worker, and beat processes are all wired correctly before any business
tasks exist.
"""

from __future__ import annotations

from app.core.logging import get_logger
from app.workers.celery_app import celery_app

logger = get_logger(__name__)


@celery_app.task(name="app.workers.tasks.health.heartbeat")
def heartbeat() -> str:
    logger.info("worker_heartbeat")
    return "ok"
