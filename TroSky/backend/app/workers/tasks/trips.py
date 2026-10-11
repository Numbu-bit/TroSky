"""Background tasks for trips.

* ``apply_trip_timeouts`` -- every minute (see ``celery_app.beat_schedule``):
  what the clock decides about trips, where no position from the vehicle
  says it. A trip standing still too long is paused, one gone quiet at its
  last stop is completed, and one that never started is cancelled, its
  passengers told and refunds queued (see ``TripAutopilot.sweep``).
"""

from __future__ import annotations

import asyncio

from app.core.database import transactional_session
from app.core.logging import get_logger
from app.core.redis import get_redis_client
from app.services.system_settings_service import effective_settings
from app.services.trip_autopilot import TripAutopilot
from app.workers.celery_app import celery_app

logger = get_logger(__name__)


async def _apply_trip_timeouts_async() -> dict[str, int]:
    redis = get_redis_client()
    async with transactional_session() as session:
        settings = await effective_settings(session)
        result = await TripAutopilot(session, redis, settings).sweep()
    return {"paused": result.paused, "completed": result.completed, "cancelled": result.cancelled}


@celery_app.task(name="app.workers.tasks.trips.apply_trip_timeouts")
def apply_trip_timeouts() -> dict[str, int]:
    counts = asyncio.run(_apply_trip_timeouts_async())
    logger.info("apply_trip_timeouts_task_complete", **counts)
    return counts
