"""In-app notification inbox endpoints."""

from __future__ import annotations

import uuid

from fastapi import APIRouter

from app.api.dependencies import CurrentPrincipal, NotificationServiceDep, Pagination
from app.models.notifications import Notification
from app.schemas.common import PaginatedResponse
from app.schemas.notification import (
    MarkAllReadResponse,
    NotificationResponse,
    UnreadCountResponse,
)
from app.services.notification_links import deep_link_for

router = APIRouter()


def _response(notification: Notification) -> NotificationResponse:
    return NotificationResponse.model_validate(notification).model_copy(
        update={"deep_link": deep_link_for(notification.data)}
    )


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
        items=[_response(n) for n in notifications],
        total=total,
        limit=pagination.limit,
        offset=pagination.offset,
    )


@router.get("/unread-count", response_model=UnreadCountResponse)
async def get_unread_count(
    principal: CurrentPrincipal, service: NotificationServiceDep
) -> UnreadCountResponse:
    """For the badge on the bell icon."""
    return UnreadCountResponse(unread_count=await service.count_unread(principal.user_id))


@router.post("/read-all", response_model=MarkAllReadResponse)
async def mark_all_notifications_read(
    principal: CurrentPrincipal, service: NotificationServiceDep
) -> MarkAllReadResponse:
    return MarkAllReadResponse(marked_read=await service.mark_all_read(principal.user_id))


@router.post("/{notification_id}/read", response_model=NotificationResponse)
async def mark_notification_read(
    notification_id: uuid.UUID, principal: CurrentPrincipal, service: NotificationServiceDep
) -> NotificationResponse:
    notification = await service.mark_read(notification_id, principal.user_id)
    return _response(notification)
