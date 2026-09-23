"""In-app notification inbox endpoints."""

from __future__ import annotations

import uuid

from fastapi import APIRouter

from app.api.dependencies import CurrentPrincipal, NotificationServiceDep, Pagination
from app.schemas.common import PaginatedResponse
from app.schemas.notification import NotificationResponse

router = APIRouter()


@router.get("", response_model=PaginatedResponse[NotificationResponse])
async def list_notifications(
    principal: CurrentPrincipal,
    service: NotificationServiceDep,
    pagination: Pagination,
    unread_only: bool = False,
) -> PaginatedResponse[NotificationResponse]:
    notifications, total = await service.list_notifications(
        principal.user_id, unread_only=unread_only, limit=pagination.limit, offset=pagination.offset
    )
    return PaginatedResponse(
        items=[NotificationResponse.model_validate(n) for n in notifications],
        total=total,
        limit=pagination.limit,
        offset=pagination.offset,
    )


@router.post("/{notification_id}/read", response_model=NotificationResponse)
async def mark_notification_read(
    notification_id: uuid.UUID, principal: CurrentPrincipal, service: NotificationServiceDep
) -> NotificationResponse:
    notification = await service.mark_read(notification_id, principal.user_id)
    return NotificationResponse.model_validate(notification)
