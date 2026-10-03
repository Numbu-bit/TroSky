"""End-to-end HTTP tests for the authentication API surface."""

from __future__ import annotations

import secrets

import pytest
from httpx import AsyncClient

from app.providers.email.sandbox import SandboxEmailProvider
from app.providers.sms.sandbox import SandboxSmsProvider

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]


def _extract_otp(message: str) -> str:
    return message.split("is ")[1].split(".")[0].strip()


@pytest.fixture(autouse=True)
def _clear_sandbox_outboxes():
    # .env.test pins SMS_PROVIDER/EMAIL_PROVIDER to "sandbox" so these
    # outboxes are what the app itself writes to during these tests.
    SandboxSmsProvider.clear()
    SandboxEmailProvider.clear()
    yield
    SandboxSmsProvider.clear()
    SandboxEmailProvider.clear()


class TestRegistrationAndLoginFlow:
    async def test_full_registration_login_refresh_logout_flow(
        self, client: AsyncClient, seed_identity_data: None
    ) -> None:
        phone = "0271234567"
        register_response = await client.post(
            "/api/v1/auth/register",
            json={
                "phone_number": phone,
                "password": "Str0ngPass",
                "full_name": "Kwame Asante",
                "role": "passenger",
            },
        )
        assert register_response.status_code == 201, register_response.text
        body = register_response.json()
        otp_target = body["otp_sent_to"]

        message = SandboxSmsProvider.get_last_message(otp_target)
        assert message is not None
        code = _extract_otp(message)

        verify_response = await client.post(
            "/api/v1/auth/verify-otp",
            json={"target": otp_target, "purpose": "registration", "code": code},
        )
        assert verify_response.status_code == 200, verify_response.text

        login_response = await client.post(
            "/api/v1/auth/login",
            json={"identifier": phone, "password": "Str0ngPass"},
        )
        assert login_response.status_code == 200, login_response.text
        tokens = login_response.json()
        assert "access_token" in tokens
        assert "refresh_token" in tokens

        me_response = await client.get(
            "/api/v1/users/me",
            headers={"Authorization": f"Bearer {tokens['access_token']}"},
        )
        assert me_response.status_code == 200, me_response.text
        me_body = me_response.json()
        assert me_body["phone_number"] == otp_target
        assert me_body["roles"] == ["passenger"]

        refresh_response = await client.post(
            "/api/v1/auth/refresh", json={"refresh_token": tokens["refresh_token"]}
        )
        assert refresh_response.status_code == 200, refresh_response.text
        new_tokens = refresh_response.json()
        assert new_tokens["access_token"] != tokens["access_token"]

        # The rotated-away-from refresh token must now be rejected, and its
        # reuse reads as theft: every session is signed out, the rotated one
        # included.
        reuse_response = await client.post(
            "/api/v1/auth/refresh", json={"refresh_token": tokens["refresh_token"]}
        )
        assert reuse_response.status_code == 401
        revoked = await client.get(
            "/api/v1/users/me",
            headers={"Authorization": f"Bearer {new_tokens['access_token']}"},
        )
        assert revoked.status_code == 401

        fresh = await client.post(
            "/api/v1/auth/login",
            json={"identifier": phone, "password": "Str0ngPass"},
        )
        logout_response = await client.post(
            "/api/v1/auth/logout",
            headers={"Authorization": f"Bearer {fresh.json()['access_token']}"},
        )
        assert logout_response.status_code == 204

    async def test_register_rejects_unknown_fields(
        self, client: AsyncClient, seed_identity_data: None
    ) -> None:
        response = await client.post(
            "/api/v1/auth/register",
            json={
                "phone_number": "0271234568",
                "password": "Str0ngPass",
                "full_name": "Ama Owusu",
                "role": "passenger",
                "is_admin": True,  # mass-assignment attempt
            },
        )
        assert response.status_code == 422

    async def test_protected_endpoint_requires_authentication(self, client: AsyncClient) -> None:
        response = await client.get("/api/v1/users/me")
        assert response.status_code == 401
        body = response.json()
        assert body["error"]["code"] == "UNAUTHORIZED"

    async def test_login_with_wrong_password_returns_401_with_standard_error_body(
        self, client: AsyncClient, seed_identity_data: None
    ) -> None:
        phone = "0271234569"
        await client.post(
            "/api/v1/auth/register",
            json={
                "phone_number": phone,
                "password": "Str0ngPass",
                "full_name": "Kojo Boateng",
                "role": "passenger",
            },
        )
        response = await client.post(
            "/api/v1/auth/login", json={"identifier": phone, "password": "WrongPassword1"}
        )
        assert response.status_code == 401
        body = response.json()
        assert body["error"]["code"] == "INVALID_CREDENTIALS"
        assert "request_id" in body["error"]


def _fresh_local_number() -> str:
    """A valid MTN number no earlier run has registered (these requests
    commit, and phone numbers are unique)."""
    return f"024{secrets.randbelow(10**7):07d}"


class TestPasswordlessLogin:
    async def test_login_code_works_however_the_number_is_written(
        self, client: AsyncClient, seed_identity_data: None, require_redis: None
    ) -> None:
        local = _fresh_local_number()
        international = "+233" + local[1:]
        registered = await client.post(
            "/api/v1/auth/register",
            json={
                "phone_number": local,
                "password": "Str0ngPass",
                "full_name": "Akua Boateng",
                "role": "passenger",
            },
        )
        assert registered.status_code == 201, registered.text
        SandboxSmsProvider.clear()  # drop the registration code

        requested = await client.post(
            "/api/v1/auth/resend-otp", json={"target": local, "purpose": "login"}
        )
        assert requested.status_code == 200, requested.text
        message = SandboxSmsProvider.get_last_message(international)
        assert message is not None

        login = await client.post(
            "/api/v1/auth/otp-login",
            json={"target": international, "code": _extract_otp(message)},
        )
        assert login.status_code == 200, login.text
        assert login.json()["access_token"]

    async def test_unregistered_number_gets_the_same_answer_but_no_sms(
        self, client: AsyncClient, seed_identity_data: None, require_redis: None
    ) -> None:
        local = _fresh_local_number()
        response = await client.post(
            "/api/v1/auth/resend-otp", json={"target": local, "purpose": "login"}
        )
        assert response.status_code == 200
        assert response.json() == {"message": "A new verification code has been sent."}
        assert SandboxSmsProvider.get_sent_messages("+233" + local[1:]) == []
        assert SandboxSmsProvider.get_sent_messages(local) == []


class TestRejectedPasswordsStayPrivate:
    async def test_a_too_short_password_is_not_echoed(
        self, client: AsyncClient, seed_identity_data: None, require_redis: None
    ) -> None:
        response = await client.post(
            "/api/v1/auth/register",
            json={
                "phone_number": _fresh_local_number(),
                "password": "Short12",
                "full_name": "Kwame Mensah",
                "role": "passenger",
            },
        )
        assert response.status_code == 422
        assert "Short12" not in response.text
        [error] = response.json()["error"]["details"]["errors"]
        assert error["loc"] == ["body", "password"]
        assert error["input"] == "***REDACTED***"
