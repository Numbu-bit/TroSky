"""Background task: reconcile payments stuck pending/processing.

The safety net for a lost or delayed webhook — polls each real provider
directly for any non-wallet payment that's been pending too long. Runs less
frequently than the seat-hold expiry sweep since it's a fallback path, not
the primary confirmation mechanism (the webhook is).
"""

from __future__ import annotations

import asyncio

from app.core.database import transactional_session
from app.core.logging import get_logger
from app.services.payment_service import PaymentService
from app.workers.celery_app import celery_app

logger = get_logger(__name__)


async def _reconcile_pending_payments_async() -> int:
    async with transactional_session() as session:
        service = PaymentService(session)
        return await service.reconcile_pending_payments()


@celery_app.task(name="app.workers.tasks.payments.reconcile_pending_payments")
def reconcile_pending_payments() -> int:
    count = asyncio.run(_reconcile_pending_payments_async())
    logger.info("reconcile_pending_payments_task_complete", reconciled_count=count)
    return count
