"""Integration tests for NotificationService: the in-app inbox is always
written; a notification goes out on a channel only when its channel and
its topic are both on, except safety and account ones, which always do;
promotions are off by default; a push carries the deep link; and
mark-read is ownership-scoped — against a real Postgres."""

from __future__ import annotations

import uuid

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import NotFoundError
from app.core.redis import get_redis_client
from app.models.identity import DevicePlatform
from app.models.notifications import NotificationCategory, NotificationTopic
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
            topic=NotificationTopic.BOOKING_UPDATES,
            title="Hi",
            body="Body text",
        )
        assert notification.title == "Hi"
        assert notification.topic == NotificationTopic.BOOKING_UPDATES
        assert notification.category == NotificationCategory.TRANSACTIONAL
        notifications, total = await service.list_notifications(
            user_id, unread_only=False, limit=10, offset=0
        )
        assert total == 1
        assert notifications[0].id == notification.id

    async def test_booking_update_respects_sms_opt_out(
        self, db_session: AsyncSession, seeded_roles, require_redis: None
    ) -> None:
        user_id = await _make_user(db_session, "0571111102")
        preferences = NotificationPreferenceRepository(db_session)
        pref = await preferences.get_for_user(user_id)  # created at registration
        assert pref is not None
        await preferences.update(pref, sms_enabled=False)

        service = NotificationService(db_session)
        notification = await service.notify(
            user_id, topic=NotificationTopic.BOOKING_UPDATES, title="Paid", body="Thanks"
        )
        assert notification.channel_results["sms"] == "skipped_opted_out"
        assert notification.channel_results["email"] != "skipped_opted_out"

    async def test_topic_switch_silences_every_channel_but_keeps_the_inbox(
        self, db_session: AsyncSession, seeded_roles, require_redis: None
    ) -> None:
        user_id = await _make_user(db_session, "0571111108")
        preferences = NotificationPreferenceRepository(db_session)
        pref = await preferences.get_for_user(user_id)
        assert pref is not None
        await preferences.update(pref, booking_updates_enabled=False)

        service = NotificationService(db_session)
        notification = await service.notify(
            user_id, topic=NotificationTopic.BOOKING_UPDATES, title="Moved", body="New bus"
        )
        assert set(notification.channel_results.values()) == {"skipped_opted_out"}
        _, total = await service.list_notifications(user_id, unread_only=False, limit=5, offset=0)
        assert total == 1

    async def test_account_and_safety_ignore_every_switch(
        self, db_session: AsyncSession, seeded_roles, require_redis: None
    ) -> None:
        user_id = await _make_user(db_session, "0571111109")
        preferences = NotificationPreferenceRepository(db_session)
        pref = await preferences.get_for_user(user_id)
        assert pref is not None
        await preferences.update(
            pref,
            push_enabled=False,
            sms_enabled=False,
            email_enabled=False,
            booking_updates_enabled=False,
            payment_enabled=False,
        )

        service = NotificationService(db_session)
        for topic in (NotificationTopic.ACCOUNT, NotificationTopic.SAFETY):
            notification = await service.notify(user_id, topic=topic, title="Hi", body="Body")
            assert notification.channel_results["sms"] == "sent"
            assert "skipped_opted_out" not in notification.channel_results.values()

    async def test_promotions_are_off_until_turned_on(
        self, db_session: AsyncSession, seeded_roles, require_redis: None
    ) -> None:
        user_id = await _make_user(db_session, "0571111103")
        service = NotificationService(db_session)
        notification = await service.notify(
            user_id, topic=NotificationTopic.PROMOTIONS, title="Sale!", body="50% off"
        )
        assert notification.category == NotificationCategory.PROMOTIONAL
        assert notification.channel_results["sms"] == "skipped_opted_out"

        preferences = NotificationPreferenceRepository(db_session)
        pref = await preferences.get_for_user(user_id)
        assert pref is not None
        await preferences.update(pref, promotional_opt_in=True, sms_enabled=False)
        notification = await service.notify(
            user_id, topic=NotificationTopic.PROMOTIONS, title="Sale!", body="50% off"
        )
        assert notification.channel_results["sms"] == "skipped_opted_out"
        assert notification.channel_results["email"] != "skipped_opted_out"

    async def test_push_reaches_registered_device_with_its_deep_link(
        self, db_session: AsyncSession, seeded_roles, require_redis: None
    ) -> None:
        user_id = await _make_user(db_session, "0571111104")
        await DeviceRepository(db_session).upsert(
            user_id=user_id,
            device_id="device-abc",
            platform=DevicePlatform.ANDROID,
            push_token="push-token-xyz",
        )
        booking_id = str(uuid.uuid4())
        service = NotificationService(db_session)
        notification = await service.notify(
            user_id,
            topic=NotificationTopic.BOOKING_UPDATES,
            title="Hi",
            body="Body",
            data={"booking_id": booking_id},
        )
        assert notification.channel_results["push"] == "sent"
        [sent] = SandboxPushProvider.get_sent("push-token-xyz")
        assert sent["data"]["deep_link"] == f"/bookings/{booking_id}"
        # The link rides on the push only; the stored data is unchanged.
        assert notification.data == {"booking_id": booking_id}

    async def test_push_without_device_is_skipped(
        self, db_session: AsyncSession, seeded_roles, require_redis: None
    ) -> None:
        user_id = await _make_user(db_session, "0571111105")
        service = NotificationService(db_session)
        notification = await service.notify(
            user_id, topic=NotificationTopic.BOOKING_UPDATES, title="Hi", body="Body"
        )
        assert notification.channel_results["push"] == "skipped_no_device"


class TestMarkRead:
    async def test_owner_can_mark_read(
        self, db_session: AsyncSession, seeded_roles, require_redis: None
    ) -> None:
        user_id = await _make_user(db_session, "0571111106")
        service = NotificationService(db_session)
        notification = await service.notify(
            user_id, topic=NotificationTopic.BOOKING_UPDATES, title="Hi", body="Body"
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
            user_id, topic=NotificationTopic.BOOKING_UPDATES, title="Hi", body="Body"
        )
        with pytest.raises(NotFoundError):
            await service.mark_read(notification.id, uuid.uuid4())
