"""Notification dispatch: the in-app inbox plus best-effort fan-out to
push/SMS/email based on the recipient's preferences.

``category`` decides whether preference opt-outs even apply:
``TRANSACTIONAL`` (booking/payment/ticket/trip updates) and ``SAFETY``
(SOS/incident acknowledgements) always bypass
``NotificationPreference`` opt-outs — a passenger cannot accidentally
silence their own payment receipt or an SOS acknowledgement. Only
``PROMOTIONAL`` notifications respect ``promotional_opt_in``. This mirrors
the policy `NotificationPreference`'s own docstring stated back in Phase 2.

A failure on any one channel never blocks the others or the in-app
record — the ``Notification`` row is always written first, and each
channel's outcome (``sent`` / `skipped_opted_out` / `failed`) is recorded
independently in ``channel_results``.
"""

from __future__ import annotations

import uuid
from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings, get_settings
from app.core.exceptions import NotFoundError, ProviderError
from app.core.logging import get_logger
from app.core.telemetry import NOTIFICATION_DELIVERY_TOTAL
from app.models.notifications import Notification, NotificationCategory
from app.providers.email.factory import get_email_provider
from app.providers.push.factory import get_push_provider
from app.providers.sms.factory import get_sms_provider
from app.repositories.notification_repository import NotificationRepository
from app.repositories.profile_repository import DeviceRepository, NotificationPreferenceRepository
from app.repositories.user_repository import UserRepository

logger = get_logger(__name__)


class NotificationService:
    def __init__(self, session: AsyncSession, settings: Settings | None = None) -> None:
        self._session = session
        self._settings = settings or get_settings()
        self._notifications = NotificationRepository(session)
        self._preferences = NotificationPreferenceRepository(session)
        self._devices = DeviceRepository(session)
        self._users = UserRepository(session)

    async def notify(
        self,
        user_id: uuid.UUID,
        *,
        category: NotificationCategory,
        title: str,
        body: str,
        data: dict[str, Any] | None = None,
    ) -> Notification:
        data = data or {}
        preference = await self._preferences.get_for_user(user_id)
        bypasses_opt_out = category in (
            NotificationCategory.TRANSACTIONAL,
            NotificationCategory.SAFETY,
        )

        channel_results: dict[str, str] = {}
        channel_results["push"] = await self._dispatch_push(
            user_id,
            title=title,
            body=body,
            data=data,
            preference_allows=self._allows(preference, "push_enabled", bypasses_opt_out),
        )
        channel_results["sms"] = await self._dispatch_sms(
            user_id,
            body=body,
            preference_allows=self._allows(preference, "sms_enabled", bypasses_opt_out),
        )
        channel_results["email"] = await self._dispatch_email(
            user_id,
            title=title,
            body=body,
            preference_allows=self._allows(preference, "email_enabled", bypasses_opt_out),
        )
        for channel, result in channel_results.items():
            NOTIFICATION_DELIVERY_TOTAL.labels(channel=channel, result=result).inc()

        return await self._notifications.create(
            user_id=user_id,
            category=category,
            title=title,
            body=body,
            data=data,
            channel_results=channel_results,
        )

    @staticmethod
    def _allows(preference: object, field: str, bypasses_opt_out: bool) -> bool:
        if bypasses_opt_out:
            return True
        if preference is None:
            return True  # no preference row yet — defaults are opt-in
        return bool(getattr(preference, field))

    async def _dispatch_push(
        self,
        user_id: uuid.UUID,
        *,
        title: str,
        body: str,
        data: dict[str, Any],
        preference_allows: bool,
    ) -> str:
        if not preference_allows:
            return "skipped_opted_out"
        devices = await self._devices.list_active_for_user(user_id)
        if not devices:
            return "skipped_no_device"
        provider = get_push_provider(self._settings)
        any_sent = False
        for device in devices:
            if device.push_token is None:
                continue
            try:
                result = await provider.send(
                    token=device.push_token, title=title, body=body, data=data
                )
            except ProviderError:
                logger.warning("push_dispatch_provider_error", user_id=str(user_id))
                continue
            any_sent = any_sent or result.success
        return "sent" if any_sent else "failed"

    async def _dispatch_sms(self, user_id: uuid.UUID, *, body: str, preference_allows: bool) -> str:
        if not preference_allows:
            return "skipped_opted_out"
        user = await self._users.get_by_id(user_id)
        if user is None:
            return "failed"
        provider = get_sms_provider(self._settings)
        try:
            result = await provider.send_sms(user.phone_number, body)
        except ProviderError:
            logger.warning("sms_dispatch_provider_error", user_id=str(user_id))
            return "failed"
        return "sent" if result.success else "failed"

    async def _dispatch_email(
        self, user_id: uuid.UUID, *, title: str, body: str, preference_allows: bool
    ) -> str:
        if not preference_allows:
            return "skipped_opted_out"
        user = await self._users.get_by_id(user_id)
        if user is None or not user.email:
            return "skipped_no_email"
        provider = get_email_provider(self._settings)
        try:
            result = await provider.send_email(to=user.email, subject=title, body_text=body)
        except ProviderError:
            logger.warning("email_dispatch_provider_error", user_id=str(user_id))
            return "failed"
        return "sent" if result.success else "failed"

    # ------------------------------------------------------------------
    # Inbox reads
    # ------------------------------------------------------------------
    async def list_notifications(
        self, user_id: uuid.UUID, *, unread_only: bool, limit: int, offset: int
    ) -> tuple[list[Notification], int]:
        return await self._notifications.list_for_user(
            user_id, unread_only=unread_only, limit=limit, offset=offset
        )

    async def mark_read(self, notification_id: uuid.UUID, user_id: uuid.UUID) -> Notification:
        notification = await self._notifications.get_for_user(notification_id, user_id)
        if notification is None:
            raise NotFoundError("Notification not found.")
        if not notification.is_read:
            await self._notifications.mark_read(notification)
        return notification
