"""Background task: expire stale seat-hold bookings.

Runs on a short interval (see ``celery_app.beat_schedule``) so a passenger
who abandons checkout doesn't hold a seat indefinitely. Uses
``SELECT ... FOR UPDATE SKIP LOCKED`` under the hood (see
``BookingRepository.find_expirable_bookings``) so multiple worker replicas
never double-process the same booking.
"""

from __future__ import annotations

import asyncio

from app.core.database import transactional_session
from app.core.logging import get_logger
from app.core.redis import get_redis_client
from app.services.booking_service import BookingService
from app.workers.celery_app import celery_app

logger = get_logger(__name__)


async def _expire_stale_bookings_async() -> int:
    # The Redis client/connection pool is process-wide and intentionally
    # left open across task runs (reused, not torn down here) — see
    # app.core.redis for the pooling model.
    redis = get_redis_client()
    async with transactional_session() as session:
        service = BookingService(session, redis)
        return await service.expire_stale_bookings()


@celery_app.task(name="app.workers.tasks.bookings.expire_stale_bookings")
def expire_stale_bookings() -> int:
    count = asyncio.run(_expire_stale_bookings_async())
    logger.info("expire_stale_bookings_task_complete", expired_count=count)
    return count
