"""End-to-end HTTP tests for booking-endpoint validation and authorization.

Standing up a fully bookable trip (admin-approved driver + vehicle +
schedule) end-to-end over HTTP is exercised at the service-integration
level (``tests/integration/test_booking_service.py``) where it doesn't
require also minting an authenticated admin session; these tests focus on
what's specific to the HTTP layer — auth, validation, and not leaking
another passenger's booking.
"""

from __future__ import annotations

import uuid

import pytest
from httpx import AsyncClient

from app.providers.email.sandbox import SandboxEmailProvider
from app.providers.sms.sandbox import SandboxSmsProvider

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]


def _extract_otp(message: str) -> str:
    return message.split("is ")[1].split(".")[0].strip()


@pytest.fixture(autouse=True)
def _clear_outboxes():
    SandboxSmsProvider.clear()
    SandboxEmailProvider.clear()
    yield
    SandboxSmsProvider.clear()
    SandboxEmailProvider.clear()


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


class TestBookingApiValidation:
    async def test_create_booking_requires_authentication(self, client: AsyncClient) -> None:
        response = await client.post(
            "/api/v1/bookings", json={"trip_id": str(uuid.uuid4()), "passengers": []}
        )
        assert response.status_code == 401

    async def test_create_booking_rejects_empty_passengers(
        self, client: AsyncClient, seed_identity_data: None
    ) -> None:
        token = await _register_and_login(client, "0571234568", "A Passenger")
        response = await client.post(
            "/api/v1/bookings",
            json={"trip_id": str(uuid.uuid4()), "passengers": []},
            headers={"Authorization": f"Bearer {token}"},
        )
        assert response.status_code == 422

    async def test_create_booking_rejects_duplicate_seats(
        self, client: AsyncClient, seed_identity_data: None
    ) -> None:
        token = await _register_and_login(client, "0571234570", "A Passenger")
        seat_id = str(uuid.uuid4())
        response = await client.post(
            "/api/v1/bookings",
            json={
                "trip_id": str(uuid.uuid4()),
                "passengers": [
                    {"seat_id": seat_id, "full_name": "A"},
                    {"seat_id": seat_id, "full_name": "B"},
                ],
            },
            headers={"Authorization": f"Bearer {token}"},
        )
        assert response.status_code == 422

    async def test_get_nonexistent_booking_returns_404(
        self, client: AsyncClient, seed_identity_data: None
    ) -> None:
        token = await _register_and_login(client, "0571234569", "A Passenger")
        response = await client.get(
            f"/api/v1/bookings/{uuid.uuid4()}", headers={"Authorization": f"Bearer {token}"}
        )
        assert response.status_code == 404

    async def test_list_my_bookings_starts_empty(
        self, client: AsyncClient, seed_identity_data: None
    ) -> None:
        token = await _register_and_login(client, "0571234571", "A Passenger")
        response = await client.get(
            "/api/v1/bookings", headers={"Authorization": f"Bearer {token}"}
        )
        assert response.status_code == 200
        assert response.json()["items"] == []
