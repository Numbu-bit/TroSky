"""Notification domain model: the in-app inbox record and per-channel
dispatch outcome for every notification sent.

One row per logical notification event — always written regardless of
channel preferences (it's the in-app inbox) — with ``channel_results``
recording what happened on each attempted out-of-app channel (push/SMS/
email), e.g. ``{"push": "sent", "sms": "skipped_opted_out", "email":
"failed"}``. ``category`` decides whether preference opt-outs apply at
all: ``TRANSACTIONAL`` and ``SAFETY`` notifications always bypass
``NotificationPreference`` opt-outs (see
``app.services.notification_service``) — only ``PROMOTIONAL`` respects
``promotional_opt_in``.
"""

from __future__ import annotations

import uuid
from datetime import datetime
from enum import StrEnum
from typing import Any

from sqlalchemy import Enum as PgEnum
from sqlalchemy import ForeignKey, Index
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.types import TIMESTAMP, Boolean, String

from app.models.base import UUIDAuditBase, enum_values


class NotificationCategory(StrEnum):
    TRANSACTIONAL = "transactional"
    SAFETY = "safety"
    PROMOTIONAL = "promotional"


class Notification(UUIDAuditBase):
    __tablename__ = "notifications"

    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    category: Mapped[NotificationCategory] = mapped_column(
        PgEnum(
            NotificationCategory,
            name="notification_category",
            native_enum=True,
            values_callable=enum_values,
        ),
        nullable=False,
    )
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    body: Mapped[str] = mapped_column(String(1000), nullable=False)
    data: Mapped[dict[str, Any]] = mapped_column(JSONB, nullable=False, default=dict)
    channel_results: Mapped[dict[str, Any]] = mapped_column(JSONB, nullable=False, default=dict)
    is_read: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    read_at: Mapped[datetime | None] = mapped_column(TIMESTAMP(timezone=True), nullable=True)

    __table_args__ = (
        Index("ix_notifications_user_id_created_at", "user_id", "created_at"),
        Index("ix_notifications_user_id_is_read", "user_id", "is_read"),
    )
