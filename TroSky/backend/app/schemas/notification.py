"""Request/response schemas for notifications and device registration."""

from __future__ import annotations

import uuid
from datetime import datetime
from typing import Any

from pydantic import Field

from app.models.identity import DevicePlatform
from app.models.notifications import NotificationCategory
from app.schemas.common import ApiModel, RequestModel


class NotificationResponse(ApiModel):
    id: uuid.UUID
    category: NotificationCategory
    title: str
    body: str
    data: dict[str, Any]
    channel_results: dict[str, Any]
    is_read: bool
    read_at: datetime | None
    created_at: datetime


class UnreadCountResponse(ApiModel):
    unread_count: int


class MarkAllReadResponse(ApiModel):
    marked_read: int = Field(..., description="How many notifications were unread until now.")


class DeviceRegisterRequest(RequestModel):
    device_id: str = Field(..., min_length=1, max_length=255)
    platform: DevicePlatform
    push_token: str | None = Field(default=None, max_length=500)


class DeviceResponse(ApiModel):
    id: uuid.UUID
    device_id: str
    platform: DevicePlatform
    is_active: bool
