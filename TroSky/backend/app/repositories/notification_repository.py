"""Database access for the in-app notification inbox."""

from __future__ import annotations

import uuid
from datetime import UTC, datetime
from typing import Any

from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.notifications import Notification, NotificationCategory


class NotificationRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def create(
        self,
        *,
        user_id: uuid.UUID,
        category: NotificationCategory,
        title: str,
        body: str,
        data: dict[str, Any],
        channel_results: dict[str, Any],
    ) -> Notification:
        notification = Notification(
            user_id=user_id,
            category=category,
            title=title,
            body=body,
            data=data,
            channel_results=channel_results,
        )
        self._session.add(notification)
        await self._session.flush()
        return notification

    async def get_for_user(
        self, notification_id: uuid.UUID, user_id: uuid.UUID
    ) -> Notification | None:
        result = await self._session.execute(
            select(Notification).where(
                Notification.id == notification_id, Notification.user_id == user_id
            )
        )
        return result.scalar_one_or_none()

    async def list_for_user(
        self, user_id: uuid.UUID, *, unread_only: bool, limit: int, offset: int
    ) -> tuple[list[Notification], int]:
        stmt = select(Notification).where(Notification.user_id == user_id)
        if unread_only:
            stmt = stmt.where(Notification.is_read.is_(False))
        count_result = await self._session.execute(
            select(func.count()).select_from(stmt.subquery())
        )
        total = count_result.scalar_one()
        result = await self._session.execute(
            stmt.order_by(Notification.created_at.desc()).limit(limit).offset(offset)
        )
        return list(result.scalars().all()), total

    async def count_unread(self, user_id: uuid.UUID) -> int:
        result = await self._session.execute(
            select(func.count(Notification.id)).where(
                Notification.user_id == user_id, Notification.is_read.is_(False)
            )
        )
        return int(result.scalar_one())

    async def mark_all_read(self, user_id: uuid.UUID) -> int:
        """Mark every unread notification read; returns how many changed."""
        result = await self._session.execute(
            update(Notification)
            .where(Notification.user_id == user_id, Notification.is_read.is_(False))
            .values(is_read=True, read_at=datetime.now(UTC))
        )
        return int(result.rowcount)  # type: ignore[attr-defined]

    async def mark_read(self, notification: Notification) -> None:
        notification.is_read = True
        notification.read_at = datetime.now(UTC)
        await self._session.flush()
