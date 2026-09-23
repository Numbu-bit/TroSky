"""Celery application factory: background jobs + scheduled (beat) tasks.

Task modules are imported explicitly in ``include=`` below so Celery can
discover them; new task modules are appended here as later phases introduce
them (reservation expiry, notification dispatch, GPS archival, settlement,
webhook outbox relay, report exports, etc.).
"""

from __future__ import annotations

from celery import Celery
from celery.schedules import crontab

from app.core.config import get_settings

settings = get_settings()

celery_app = Celery(
    "trosky",
    broker=settings.CELERY_BROKER_URL,
    backend=settings.CELERY_RESULT_BACKEND,
    include=[
        "app.workers.tasks.health",
        "app.workers.tasks.bookings",
        "app.workers.tasks.payments",
        "app.workers.tasks.tracking",
        # Phase 9+: "app.workers.tasks.notifications",
    ],
)

celery_app.conf.update(
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    timezone="UTC",
    enable_utc=True,
    task_track_started=True,
    task_acks_late=True,
    worker_prefetch_multiplier=1,
    task_default_retry_delay=10,
    task_reject_on_worker_lost=True,
    broker_connection_retry_on_startup=True,
    result_expires=3600,
)

# Scheduled (beat) jobs. Each phase that introduces a periodic task appends
# its entry here rather than creating a second scheduler.
celery_app.conf.beat_schedule = {
    "worker-heartbeat": {
        "task": "app.workers.tasks.health.heartbeat",
        "schedule": crontab(minute="*/5"),
    },
    "expire-stale-bookings": {
        "task": "app.workers.tasks.bookings.expire_stale_bookings",
        "schedule": 30.0,  # seconds — seat holds must release promptly
    },
    "reconcile-pending-payments": {
        "task": "app.workers.tasks.payments.reconcile_pending_payments",
        "schedule": 120.0,  # seconds — a fallback path, not the primary one
    },
    "purge-old-trip-locations": {
        "task": "app.workers.tasks.tracking.purge_old_trip_locations",
        "schedule": crontab(hour=3, minute=0),  # once daily, off-peak
    },
}
