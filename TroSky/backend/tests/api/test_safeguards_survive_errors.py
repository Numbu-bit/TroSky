"""Safeguards that write to the database and then fail the request.

``get_db`` rolls a request's transaction back when the request raises, so a
safeguard whose whole point is to record a failure (a wrong password, a
wrong code, a stolen refresh token) is undone by that same rollback unless
it asks for its writes to be kept. These tests go through HTTP, the only
place that rollback happens.
"""

from __future__ import annotations

import pytest
from httpx import AsyncClient

from app.providers.sms.sandbox import SandboxSmsProvider
from tests.api.test_auth_api import _extract_otp, _fresh_local_number

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]

PASSWORD = "Str0ngPass"


async def _register(client: AsyncClient) -> tuple[str, str]:
    """Returns the local number used to log in and the E.164 OTP target."""
    phone = _fresh_local_number()
    response = await client.post(
        "/api/v1/auth/register",
        json={"phone_number": phone, "password": PASSWORD, "full_name": "Efua Sarpong"},
    )
    assert response.status_code == 201, response.text
    return phone, response.json()["otp_sent_to"]


async def _login(client: AsyncClient, phone: str, password: str = PASSWORD):
    return await client.post("/api/v1/auth/login", json={"identifier": phone, "password": password})


class TestLoginLockout:
    async def test_the_right_password_is_refused_once_the_account_is_locked(
        self, client: AsyncClient, seed_identity_data: None, require_redis: None
    ) -> None:
        phone, _ = await _register(client)
        for _ in range(5):  # LOGIN_MAX_FAILED_ATTEMPTS
            wrong = await _login(client, phone, "WrongPass1")
            assert wrong.status_code == 401, wrong.text

        right = await _login(client, phone)

        assert right.status_code == 423, right.text
        assert right.json()["error"]["code"] == "ACCOUNT_LOCKED"


class TestOtpAttemptLimit:
    async def test_the_right_code_is_refused_after_too_many_wrong_ones(
        self, client: AsyncClient, seed_identity_data: None, require_redis: None
    ) -> None:
        _, target = await _register(client)
        message = SandboxSmsProvider.get_last_message(target)
        assert message is not None
        code = _extract_otp(message)
        wrong_code = "000000" if code != "000000" else "111111"

        for _ in range(5):  # OTP_MAX_ATTEMPTS
            wrong = await client.post(
                "/api/v1/auth/verify-otp",
                json={"target": target, "purpose": "registration", "code": wrong_code},
            )
            assert wrong.json()["error"]["code"] == "OTP_INVALID", wrong.text

        right = await client.post(
            "/api/v1/auth/verify-otp",
            json={"target": target, "purpose": "registration", "code": code},
        )

        assert right.json()["error"]["code"] == "OTP_ATTEMPTS_EXCEEDED", right.text


class TestRefreshTokenReuse:
    async def test_reusing_a_rotated_token_signs_out_every_session(
        self, client: AsyncClient, seed_identity_data: None, require_redis: None
    ) -> None:
        phone, _ = await _register(client)
        stolen = (await _login(client, phone)).json()
        other_device = (await _login(client, phone)).json()
        rotated = await client.post(
            "/api/v1/auth/refresh", json={"refresh_token": stolen["refresh_token"]}
        )
        assert rotated.status_code == 200, rotated.text

        reuse = await client.post(
            "/api/v1/auth/refresh", json={"refresh_token": stolen["refresh_token"]}
        )
        assert reuse.json()["error"]["code"] == "REFRESH_TOKEN_REUSE_DETECTED", reuse.text

        for access_token in (other_device["access_token"], rotated.json()["access_token"]):
            me = await client.get(
                "/api/v1/users/me", headers={"Authorization": f"Bearer {access_token}"}
            )
            assert me.status_code == 401, me.text
