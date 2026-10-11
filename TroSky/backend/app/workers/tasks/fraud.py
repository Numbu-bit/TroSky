"""Background task: run the fraud rules (``app.services.fraud_rules``).

Scheduled every 15 minutes. A run that finds a lock held -- another run, or
one an admin started from ``POST /admin/fraud/scan`` -- skips; the next one
picks up whatever it would have found.
"""

from __future__ import annotations

from app.api.v1.admin_fraud import DETECTION_LOCK, DETECTION_LOCK_SECONDS
from app.core.database import transactional_session
from app.core.logging import get_logger
from app.core.redis import RedisLock, get_redis_client
from app.services.fraud_service import FraudService
from app.workers.celery_app import celery_app
from app.workers.loop import run_task

logger = get_logger(__name__)


async def _detect_fraud_async() -> int | None:
    lock = RedisLock(get_redis_client(), DETECTION_LOCK, ttl_seconds=DETECTION_LOCK_SECONDS)
    if not await lock.acquire():
        logger.info("fraud_detection_skipped_lock_held")
        return None
    try:
        async with transactional_session() as session:
            result = await FraudService(session).detect()
        return result.raised
    finally:
        await lock.release()


@celery_app.task(name="app.workers.tasks.fraud.detect_fraud")
def detect_fraud() -> int | None:
    raised = run_task(_detect_fraud_async())
    logger.info("detect_fraud_task_complete", raised=raised)
    return raised
