"""Request/response schemas for notifications and device registration."""

from __future__ import annotations

import uuid
from datetime import datetime
from typing import Any

from pydantic import Field

from app.models.identity import DevicePlatform
from app.models.notifications import NotificationCategory, NotificationTopic
from app.schemas.common import ApiModel, RequestModel


class NotificationResponse(ApiModel):
    id: uuid.UUID
    topic: NotificationTopic = Field(
        ...,
        description=(
            "What it is about, and so which switch in the notification "
            "preferences silences it. `safety` and `account` have no switch."
        ),
    )
    category: NotificationCategory = Field(
        ..., description="The older, coarser grouping. Use `topic` instead."
    )
    title: str
    body: str
    data: dict[str, Any] = Field(
        ...,
        description=(
            "The ids the notification is about. Its keys per notification "
            "type are listed in the backend's docs/notifications.md."
        ),
    )
    deep_link: str | None = Field(
        default=None,
        description=(
            "Where tapping it should go: a path in the app's router form, like "
            "`/bookings/{id}` or `/search?origin_stop_id={id}`. Null when there "
            "is nowhere better than the inbox. Pushes carry it too, as "
            "`data.deep_link`."
        ),
        examples=["/bookings/6f1c2d4e-0000-4000-8000-000000000000"],
    )
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
