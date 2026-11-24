"""HTTP checks for the app's Step 20 backend gaps: deep links and topics on
notifications, topic switches, favourite places, and changing the password
and the email address -- routed, validated and working end to end."""

from __future__ import annotations

import re
import secrets
import uuid

import pytest
from httpx import AsyncClient

from app.core.database import get_session_factory
from app.models.notifications import NotificationTopic
from app.providers.email.sandbox import SandboxEmailProvider
from app.services.notification_service import NotificationService

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]

PASSWORD = "Str0ngPass"


def _local_number() -> str:
    return f"024{secrets.randbelow(10**7):07d}"


async def _login(client: AsyncClient, identifier: str, password: str = PASSWORD) -> dict[str, str]:
    response = await client.post(
        "/api/v1/auth/login", json={"identifier": identifier, "password": password}
    )
    assert response.status_code == 200, response.text
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


async def _passenger(client: AsyncClient) -> tuple[str, dict[str, str]]:
    phone = _local_number()
    registered = await client.post(
        "/api/v1/auth/register",
        json={"phone_number": phone, "password": PASSWORD, "full_name": "Akua Mensah"},
    )
    assert registered.status_code == 201, registered.text
    return phone, await _login(client, phone)


async def _user_id(client: AsyncClient, headers: dict[str, str]) -> uuid.UUID:
    return uuid.UUID((await client.get("/api/v1/users/me", headers=headers)).json()["id"])


class TestNotificationLinks:
    async def test_each_notification_has_its_topic_and_deep_link(
        self, client: AsyncClient, seed_identity_data: None
    ) -> None:
        _, headers = await _passenger(client)
        user_id = await _user_id(client, headers)
        booking_id = str(uuid.uuid4())
        async with get_session_factory()() as session:
            service = NotificationService(session)
            await service.notify(
                user_id,
                topic=NotificationTopic.BOOKING_UPDATES,
                title="Booking confirmed",
                body="See you on board",
                data={"booking_id": booking_id},
            )
            await service.notify(
                user_id, topic=NotificationTopic.ACCOUNT, title="Welcome", body="Hello"
            )
            await session.commit()

        response = await client.get("/api/v1/notifications", headers=headers)

        assert response.status_code == 200, response.text
        by_title = {item["title"]: item for item in response.json()["items"]}
        assert by_title["Booking confirmed"]["deep_link"] == f"/bookings/{booking_id}"
        assert by_title["Booking confirmed"]["topic"] == "booking_updates"
        assert by_title["Welcome"]["deep_link"] is None
        assert by_title["Welcome"]["topic"] == "account"


class TestPreferences:
    async def test_topic_switches(self, client: AsyncClient, seed_identity_data: None) -> None:
        _, headers = await _passenger(client)
        url = "/api/v1/users/me/notification-preferences"

        before = await client.get(url, headers=headers)
        changed = await client.patch(
            url, headers=headers, json={"promotions_enabled": True, "payment_enabled": False}
        )
        refused = await client.patch(url, headers=headers, json={"safety_enabled": False})

        assert before.status_code == 200, before.text
        assert before.json() == {
            "push_enabled": True,
            "sms_enabled": True,
            "email_enabled": True,
            "booking_updates_enabled": True,
            "payment_enabled": True,
            "promotions_enabled": False,
            "safety_enabled": True,
            "account_enabled": True,
            "promotional_opt_in": False,
        }
        assert changed.status_code == 200, changed.text
        assert changed.json()["promotions_enabled"] is True
        assert changed.json()["promotional_opt_in"] is True
        assert changed.json()["payment_enabled"] is False
        assert refused.status_code == 422


class TestFavouritePlaces:
    async def test_save_list_change_and_remove(
        self, client: AsyncClient, seed_identity_data: None
    ) -> None:
        _, headers = await _passenger(client)
        url = "/api/v1/users/me/favourite-places"

        work = await client.post(
            url, headers=headers, json={"kind": "work", "latitude": 5.55, "longitude": -0.21}
        )
        home = await client.post(
            url, headers=headers, json={"kind": "home", "latitude": 5.6, "longitude": -0.2}
        )
        second_home = await client.post(
            url, headers=headers, json={"kind": "home", "latitude": 5.7, "longitude": -0.2}
        )
        unnamed = await client.post(
            url, headers=headers, json={"kind": "custom", "latitude": 5.7, "longitude": -0.2}
        )
        unknown_stop = await client.post(
            url,
            headers=headers,
            json={"kind": "custom", "label": "X", "stop_id": str(uuid.uuid4())},
        )
        renamed = await client.patch(
            f"{url}/{home.json()['id']}", headers=headers, json={"label": "Our house"}
        )
        listed = await client.get(url, headers=headers)
        removed = await client.delete(f"{url}/{work.json()['id']}", headers=headers)
        after = await client.get(url, headers=headers)

        assert work.status_code == 201, work.text
        assert home.json()["label"] == "Home"
        assert second_home.status_code == 409
        assert second_home.json()["error"]["code"] == "FAVOURITE_PLACE_EXISTS"
        assert unnamed.status_code == 422
        assert unknown_stop.status_code == 404
        assert renamed.json()["label"] == "Our house"
        assert [p["kind"] for p in listed.json()] == ["home", "work"]
        assert removed.status_code == 204
        assert [p["label"] for p in after.json()] == ["Our house"]


class TestChangePassword:
    async def test_wrong_current_password_then_a_real_change(
        self, client: AsyncClient, seed_identity_data: None
    ) -> None:
        phone, headers = await _passenger(client)
        url = "/api/v1/users/me/change-password"

        wrong = await client.post(
            url,
            headers=headers,
            json={"current_password": "Wr0ngPass", "new_password": "N3wPassword"},
        )
        same = await client.post(
            url, headers=headers, json={"current_password": PASSWORD, "new_password": PASSWORD}
        )
        changed = await client.post(
            url,
            headers=headers,
            json={"current_password": PASSWORD, "new_password": "N3wPassword"},
        )
        still_signed_in = await client.get("/api/v1/users/me", headers=headers)
        old_password = await client.post(
            "/api/v1/auth/login", json={"identifier": phone, "password": PASSWORD}
        )

        assert wrong.status_code == 401
        assert wrong.json()["error"]["code"] == "INVALID_CREDENTIALS"
        assert same.status_code == 409
        assert same.json()["error"]["code"] == "PASSWORD_UNCHANGED"
        assert changed.status_code == 200, changed.text
        assert still_signed_in.status_code == 200
        assert old_password.status_code == 401
        await _login(client, phone, "N3wPassword")


class TestChangeEmail:
    async def test_code_to_the_new_address_then_confirm(
        self, client: AsyncClient, seed_identity_data: None
    ) -> None:
        SandboxEmailProvider.clear()
        _, headers = await _passenger(client)
        new_email = f"akua.{uuid.uuid4().hex[:8]}@gmail.com"

        started = await client.post(
            "/api/v1/users/me/change-email",
            headers=headers,
            json={"new_email": new_email, "current_password": PASSWORD},
        )
        before = await client.get("/api/v1/users/me", headers=headers)
        sent = SandboxEmailProvider.get_last_email(new_email)
        assert sent is not None
        found = re.search(r"\b(\d{4,10})\b", sent.body_text)
        assert found is not None, sent.body_text
        code = found.group(1)
        wrong = await client.post(
            "/api/v1/users/me/change-email/confirm",
            headers=headers,
            json={"new_email": new_email, "code": "000000" if code != "000000" else "111111"},
        )
        confirmed = await client.post(
            "/api/v1/users/me/change-email/confirm",
            headers=headers,
            json={"new_email": new_email, "code": code},
        )

        assert started.status_code == 200, started.text
        assert started.json()["otp_sent_to"] == new_email
        assert before.json()["email"] is None
        assert wrong.status_code == 400, wrong.text
        assert wrong.json()["error"]["code"] == "OTP_INVALID"
        assert confirmed.status_code == 200, confirmed.text
        assert confirmed.json()["email"] == new_email
        assert confirmed.json()["email_verified"] is True
        SandboxEmailProvider.clear()
