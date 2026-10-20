"""Background task: purge raw GPS pings older than ``GPS_RAW_RETENTION_DAYS``.

Runs daily — the raw ``trip_locations`` log is a high-volume table and has
no unbounded-retention requirement (live tracking reads from Redis, not
this table, once a ping is fresh); history beyond the retention window
serves no product purpose this codebase implements.
"""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

from app.core.config import get_settings
from app.core.database import transactional_session
from app.core.logging import get_logger
from app.repositories.tracking_repository import TripLocationRepository
from app.workers.celery_app import celery_app
from app.workers.loop import run_task

logger = get_logger(__name__)


async def _purge_old_trip_locations_async() -> int:
    settings = get_settings()
    cutoff = datetime.now(UTC) - timedelta(days=settings.GPS_RAW_RETENTION_DAYS)
    total_purged = 0
    while True:
        # A fresh transaction per batch — a purge spanning millions of rows
        # must not hold one long-running transaction against a table this
        # write-heavy the whole time.
        async with transactional_session() as session:
            purged = await TripLocationRepository(session).purge_older_than(cutoff)
        total_purged += purged
        if purged == 0:
            break
    return total_purged


@celery_app.task(name="app.workers.tasks.tracking.purge_old_trip_locations")
def purge_old_trip_locations() -> int:
    count = run_task(_purge_old_trip_locations_async())
    logger.info("purge_old_trip_locations_task_complete", purged_count=count)
    return count
