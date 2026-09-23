"""End-to-end HTTP tests for payment/wallet-endpoint validation, auth, and
the public webhook route.

Standing up a fully paid booking end-to-end over HTTP is exercised at the
service-integration level (``tests/integration/test_payment_service.py``,
``test_wallet_service.py``, ``test_refund_service.py``) for the same reason
``test_bookings_api.py`` scopes itself down — these tests focus on what's
specific to the HTTP layer: auth, validation, and the webhook route's
deliberate lack of it.
"""

from __future__ import annotations

import uuid

import pytest
from httpx import AsyncClient

from app.providers.payments.sandbox import SandboxPaymentProvider
from app.providers.sms.sandbox import SandboxSmsProvider

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]


@pytest.fixture(autouse=True)
def _clear_sandboxes():
    SandboxSmsProvider.clear()
    SandboxPaymentProvider.clear()
    yield
    SandboxSmsProvider.clear()
    SandboxPaymentProvider.clear()


def _extract_otp(message: str) -> str:
    return message.split("is ")[1].split(".")[0].strip()


async def _register_and_login(client: AsyncClient, phone: str, name: str) -> str:
    register_response = await client.post(
        "/api/v1/auth/register",
        json={
            "phone_number": phone,
            "password": "Str0ngPass",
            "full_name": name,
            "role": "passenger",
        },
    )
    assert register_response.status_code == 201, register_response.text
    otp_target = register_response.json()["otp_sent_to"]
    message = SandboxSmsProvider.get_last_message(otp_target)
    assert message is not None
    await client.post(
        "/api/v1/auth/verify-otp",
        json={"target": otp_target, "purpose": "registration", "code": _extract_otp(message)},
    )
    login_response = await client.post(
        "/api/v1/auth/login", json={"identifier": phone, "password": "Str0ngPass"}
    )
    assert login_response.status_code == 200
    return str(login_response.json()["access_token"])


class TestPaymentApiAuth:
    async def test_list_payments_requires_authentication(self, client: AsyncClient) -> None:
        response = await client.get("/api/v1/payments")
        assert response.status_code == 401

    async def test_get_wallet_requires_authentication(self, client: AsyncClient) -> None:
        response = await client.get("/api/v1/wallet")
        assert response.status_code == 401

    async def test_topup_requires_authentication(self, client: AsyncClient) -> None:
        response = await client.post(
            "/api/v1/wallet/topups", json={"amount": "10.00", "channel": "mtn_momo"}
        )
        assert response.status_code == 401

    async def test_pay_for_booking_requires_authentication(self, client: AsyncClient) -> None:
        response = await client.post(
            f"/api/v1/bookings/{uuid.uuid4()}/pay", json={"channel": "wallet"}
        )
        assert response.status_code == 401


class TestPaymentApiValidation:
    async def test_wallet_starts_empty(self, client: AsyncClient, seed_identity_data: None) -> None:
        token = await _register_and_login(client, "0571234580", "A Passenger")
        response = await client.get("/api/v1/wallet", headers={"Authorization": f"Bearer {token}"})
        assert response.status_code == 200
        assert response.json()["balance"] == "0.00"

    async def test_topup_rejects_zero_amount(
        self, client: AsyncClient, seed_identity_data: None
    ) -> None:
        token = await _register_and_login(client, "0571234581", "A Passenger")
        response = await client.post(
            "/api/v1/wallet/topups",
            json={"amount": "0.00", "channel": "mtn_momo"},
            headers={"Authorization": f"Bearer {token}"},
        )
        assert response.status_code == 422

    async def test_topup_rejects_wallet_as_its_own_channel(
        self, client: AsyncClient, seed_identity_data: None
    ) -> None:
        token = await _register_and_login(client, "0571234582", "A Passenger")
        response = await client.post(
            "/api/v1/wallet/topups",
            json={"amount": "10.00", "channel": "wallet"},
            headers={"Authorization": f"Bearer {token}"},
        )
        assert response.status_code == 409

    async def test_topup_via_sandbox_mtn_momo_reaches_processing(
        self, client: AsyncClient, seed_identity_data: None
    ) -> None:
        token = await _register_and_login(client, "0571234583", "A Passenger")
        response = await client.post(
            "/api/v1/wallet/topups",
            json={
                "amount": "15.00",
                "channel": "mtn_momo",
                "payer_phone_number": "0244000001",
            },
            headers={"Authorization": f"Bearer {token}"},
        )
        assert response.status_code == 201, response.text
        assert response.json()["status"] == "processing"

    async def test_pay_for_nonexistent_booking_returns_404(
        self, client: AsyncClient, seed_identity_data: None
    ) -> None:
        token = await _register_and_login(client, "0571234584", "A Passenger")
        response = await client.post(
            f"/api/v1/bookings/{uuid.uuid4()}/pay",
            json={"channel": "wallet"},
            headers={"Authorization": f"Bearer {token}"},
        )
        assert response.status_code == 404

    async def test_get_nonexistent_payment_returns_404(
        self, client: AsyncClient, seed_identity_data: None
    ) -> None:
        token = await _register_and_login(client, "0571234585", "A Passenger")
        response = await client.get(
            f"/api/v1/payments/{uuid.uuid4()}", headers={"Authorization": f"Bearer {token}"}
        )
        assert response.status_code == 404


class TestPaymentWebhook:
    async def test_invalid_channel_is_rejected(self, client: AsyncClient) -> None:
        response = await client.post(
            "/api/v1/payments/webhooks/not-a-real-channel", json={"status": "successful"}
        )
        assert response.status_code == 422

    async def test_webhook_is_publicly_accessible_without_authentication(
        self, client: AsyncClient, require_postgres: None
    ) -> None:
        # An unmatched reference is still accepted (200) and simply recorded
        # for audit — a webhook endpoint must never require a client-style
        # Authorization header, and an unknown reference is not the caller's
        # fault to diagnose via an error response. Unlike the auth-guarded
        # tests above, this route executes a real DB write (recording the
        # webhook event) with no auth check to short-circuit it first, so
        # it needs Postgres reachable to do anything at all — hence the
        # explicit `require_postgres` dependency, so it skips cleanly
        # rather than failing with a raw connection error when it isn't.
        response = await client.post(
            "/api/v1/payments/webhooks/mtn_momo",
            json={"reference": "unknown-reference", "status": "successful"},
        )
        assert response.status_code == 200
