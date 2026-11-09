"""Background task: warn, block and unblock drivers over their insurance.

Runs every hour, though each step is due at most once a day: a small server can
sleep through any one run, and repeating a check that's already done does
nothing. Each driver has their own transaction, so one failure can't hold up
the others.
"""

from __future__ import annotations

from collections import Counter

from app.core.database import transactional_session
from app.core.logging import get_logger
from app.repositories.insurance_repository import InsuranceRepository
from app.services.insurance_service import InsuranceService
from app.workers.celery_app import celery_app
from app.workers.loop import run_task

logger = get_logger(__name__)


async def _check_driver_insurance_async() -> dict[str, int]:
    async with transactional_session() as session:
        driver_ids = list(await InsuranceRepository(session).latest_expiries())
    outcomes: Counter[str] = Counter()
    for driver_id in driver_ids:
        try:
            async with transactional_session() as session:
                outcomes[await InsuranceService(session).check_driver(driver_id)] += 1
        except Exception:
            outcomes["failed"] += 1
            logger.exception("insurance_check_failed", driver_id=str(driver_id))
    return dict(outcomes)


@celery_app.task(name="app.workers.tasks.insurance.check_driver_insurance")
def check_driver_insurance() -> dict[str, int]:
    outcomes = run_task(_check_driver_insurance_async())
    logger.info("check_driver_insurance_task_complete", **outcomes)
    return outcomes
