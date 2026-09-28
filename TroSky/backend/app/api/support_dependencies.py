"""Talking to people: notifications out, complaints in."""

from __future__ import annotations

from typing import Annotated

from fastapi import Depends

from app.api.common_dependencies import DbSession
from app.services.complaint_service import ComplaintService
from app.services.notification_service import NotificationService


def get_notification_service(db: DbSession) -> NotificationService:
    return NotificationService(db)


def get_complaint_service(db: DbSession) -> ComplaintService:
    return ComplaintService(db)


NotificationServiceDep = Annotated[NotificationService, Depends(get_notification_service)]
ComplaintServiceDep = Annotated[ComplaintService, Depends(get_complaint_service)]
