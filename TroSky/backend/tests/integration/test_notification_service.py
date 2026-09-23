"""Integration tests for NotificationService: the in-app inbox is always
written, transactional/safety notifications bypass preference opt-outs
while promotional ones respect them, push dispatch reaches a registered
device, and mark-read is ownership-scoped — against a real Postgres."""

from __future__ import annotations

import uuid

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import NotFoundError
from app.core.redis import get_redis_client
from app.models.identity import DevicePlatform
from app.models.notifications import NotificationCategory
from app.providers.email.sandbox import SandboxEmailProvider
from app.providers.push.sandbox import SandboxPushProvider
from app.providers.sms.sandbox import SandboxSmsProvider
from app.repositories.profile_repository import DeviceRepository, NotificationPreferenceRepository
from app.schemas.auth import RegisterRequest
from app.services.auth_service import AuthService
from app.services.notification_service import NotificationService

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]


@pytest.fixture(autouse=True)
def _clear_sandboxes():
    SandboxSmsProvider.clear()
    SandboxEmailProvider.clear()
    SandboxPushProvider.clear()
    yield
    SandboxSmsProvider.clear()
    SandboxEmailProvider.clear()
    SandboxPushProvider.clear()


async def _make_user(session: AsyncSession, phone: str) -> uuid.UUID:
    auth = AuthService(session, get_redis_client(), SandboxSmsProvider(), SandboxEmailProvider())
    user, _otp_target = await auth.register(
        RegisterRequest(
            phone_number=phone, password="Str0ngPass", full_name="Test User", role="passenger"
        )
    )
    return user.id


class TestNotify:
    async def test_notify_always_writes_in_app_record(
        self, db_session: AsyncSession, seeded_roles, require_redis: None
    ) -> None:
        user_id = await _make_user(db_session, "0571111101")
        service = NotificationService(db_session)
        notification = await service.notify(
            user_id,
            category=NotificationCategory.TRANSACTIONAL,
            title="Hi",
            body="Body text",
        )
        assert notification.title == "Hi"
        notifications, total = await service.list_notifications(
            user_id, unread_only=False, limit=10, offset=0
        )
        assert total == 1
        assert notifications[0].id == notification.id

    async def test_transactional_bypasses_sms_opt_out(
        self, db_session: AsyncSession, seeded_roles, require_redis: None
    ) -> None:
        user_id = await _make_user(db_session, "0571111102")
        preferences = NotificationPreferenceRepository(db_session)
        pref = await preferences.create_default(user_id)
        await preferences.update(pref, sms_enabled=False)

        service = NotificationService(db_session)
        notification = await service.notify(
            user_id, category=NotificationCategory.TRANSACTIONAL, title="Paid", body="Thanks"
        )
        assert notification.channel_results["sms"] == "sent"

    async def test_promotional_respects_sms_opt_out(
        self, db_session: AsyncSession, seeded_roles, require_redis: None
    ) -> None:
        user_id = await _make_user(db_session, "0571111103")
        preferences = NotificationPreferenceRepository(db_session)
        pref = await preferences.create_default(user_id)
        await preferences.update(pref, sms_enabled=False)

        service = NotificationService(db_session)
        notification = await service.notify(
            user_id, category=NotificationCategory.PROMOTIONAL, title="Sale!", body="50% off"
        )
        assert notification.channel_results["sms"] == "skipped_opted_out"

    async def test_push_reaches_registered_device(
        self, db_session: AsyncSession, seeded_roles, require_redis: None
    ) -> None:
        user_id = await _make_user(db_session, "0571111104")
        await DeviceRepository(db_session).upsert(
            user_id=user_id,
            device_id="device-abc",
            platform=DevicePlatform.ANDROID,
            push_token="push-token-xyz",
        )
        service = NotificationService(db_session)
        notification = await service.notify(
            user_id, category=NotificationCategory.TRANSACTIONAL, title="Hi", body="Body"
        )
        assert notification.channel_results["push"] == "sent"
        assert len(SandboxPushProvider.get_sent("push-token-xyz")) == 1

    async def test_push_without_device_is_skipped(
        self, db_session: AsyncSession, seeded_roles, require_redis: None
    ) -> None:
        user_id = await _make_user(db_session, "0571111105")
        service = NotificationService(db_session)
        notification = await service.notify(
            user_id, category=NotificationCategory.TRANSACTIONAL, title="Hi", body="Body"
        )
        assert notification.channel_results["push"] == "skipped_no_device"


class TestMarkRead:
    async def test_owner_can_mark_read(
        self, db_session: AsyncSession, seeded_roles, require_redis: None
    ) -> None:
        user_id = await _make_user(db_session, "0571111106")
        service = NotificationService(db_session)
        notification = await service.notify(
            user_id, category=NotificationCategory.TRANSACTIONAL, title="Hi", body="Body"
        )
        assert notification.is_read is False
        updated = await service.mark_read(notification.id, user_id)
        assert updated.is_read is True

    async def test_non_owner_cannot_mark_read(
        self, db_session: AsyncSession, seeded_roles, require_redis: None
    ) -> None:
        user_id = await _make_user(db_session, "0571111107")
        service = NotificationService(db_session)
        notification = await service.notify(
            user_id, category=NotificationCategory.TRANSACTIONAL, title="Hi", body="Body"
        )
        with pytest.raises(NotFoundError):
            await service.mark_read(notification.id, uuid.uuid4())
