"""End-to-end HTTP tests for driver and fleet-owner self-service endpoints."""

from __future__ import annotations

from datetime import date, timedelta

import pytest
from httpx import AsyncClient

from app.providers.email.sandbox import SandboxEmailProvider
from app.providers.sms.sandbox import SandboxSmsProvider
from app.providers.storage.sandbox import SandboxStorageProvider

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]


def _extract_otp(message: str) -> str:
    return message.split("is ")[1].split(".")[0].strip()


@pytest.fixture(autouse=True)
def _clear_outboxes():
    SandboxSmsProvider.clear()
    SandboxEmailProvider.clear()
    SandboxStorageProvider.clear()
    yield
    SandboxSmsProvider.clear()
    SandboxEmailProvider.clear()
    SandboxStorageProvider.clear()


async def _register_and_login(client: AsyncClient, phone: str, name: str, role: str) -> str:
    register_response = await client.post(
        "/api/v1/auth/register",
        json={"phone_number": phone, "password": "Str0ngPass", "full_name": name, "role": role},
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
    assert login_response.status_code == 200, login_response.text
    return str(login_response.json()["access_token"])


class TestDriverApi:
    async def test_driver_profile_and_document_upload_flow(
        self, client: AsyncClient, seed_identity_data: None
    ) -> None:
        token = await _register_and_login(client, "0291234567", "Kojo Driver", "driver")
        headers = {"Authorization": f"Bearer {token}"}

        create_response = await client.post(
            "/api/v1/drivers/me",
            json={
                "license_number": "GHA-API-001",
                "license_expiry": str(date.today() + timedelta(days=365)),
                "license_class": "C",
            },
            headers=headers,
        )
        assert create_response.status_code == 201, create_response.text
        assert create_response.json()["status"] == "pending"

        get_response = await client.get("/api/v1/drivers/me", headers=headers)
        assert get_response.status_code == 200
        assert get_response.json()["license_number"] == "GHA-API-001"

        upload_response = await client.post(
            "/api/v1/drivers/me/documents",
            data={"document_type": "driver_license"},
            files={"file": ("license.jpg", b"fake-bytes", "image/jpeg")},
            headers=headers,
        )
        assert upload_response.status_code == 201, upload_response.text
        document_id = upload_response.json()["id"]

        download_response = await client.get(
            f"/api/v1/drivers/me/documents/{document_id}/download-url", headers=headers
        )
        assert download_response.status_code == 200
        assert "download_url" in download_response.json()

    async def test_passenger_cannot_access_driver_endpoints(
        self, client: AsyncClient, seed_identity_data: None
    ) -> None:
        token = await _register_and_login(client, "0291234568", "A Passenger", "passenger")
        response = await client.get(
            "/api/v1/drivers/me", headers={"Authorization": f"Bearer {token}"}
        )
        assert response.status_code == 403


class TestFleetApi:
    async def test_fleet_owner_full_vehicle_and_seat_layout_flow(
        self, client: AsyncClient, seed_identity_data: None
    ) -> None:
        token = await _register_and_login(client, "0291234569", "Fleet Owner", "fleet_owner")
        headers = {"Authorization": f"Bearer {token}"}

        owner_response = await client.post(
            "/api/v1/fleet-owners/me",
            json={"business_name": "Kumasi Transit"},
            headers=headers,
        )
        assert owner_response.status_code == 201, owner_response.text

        fleet_response = await client.post(
            "/api/v1/fleets", json={"name": "Main Fleet"}, headers=headers
        )
        assert fleet_response.status_code == 201, fleet_response.text
        fleet_id = fleet_response.json()["id"]

        vehicle_response = await client.post(
            f"/api/v1/fleets/{fleet_id}/vehicles",
            json={
                "registration_number": "GR-API-24",
                "vehicle_type": "bus",
                "capacity": 4,
            },
            headers=headers,
        )
        assert vehicle_response.status_code == 201, vehicle_response.text
        vehicle_id = vehicle_response.json()["id"]

        layout_response = await client.put(
            f"/api/v1/vehicles/{vehicle_id}/seat-layout",
            json={
                "rows": 2,
                "columns": 2,
                "seats": [
                    {"seat_number": "1A", "row_number": 1, "column_number": 1},
                    {"seat_number": "1B", "row_number": 1, "column_number": 2},
                    {"seat_number": "2A", "row_number": 2, "column_number": 1},
                    {"seat_number": "2B", "row_number": 2, "column_number": 2},
                ],
            },
            headers=headers,
        )
        assert layout_response.status_code == 200, layout_response.text
        assert layout_response.json()["total_seats"] == 4

    async def test_fleet_owner_cannot_access_another_owners_fleet(
        self, client: AsyncClient, seed_identity_data: None
    ) -> None:
        token_a = await _register_and_login(client, "0291234570", "Owner A", "fleet_owner")
        token_b = await _register_and_login(client, "0291234571", "Owner B", "fleet_owner")

        await client.post(
            "/api/v1/fleet-owners/me",
            json={"business_name": "Owner A Co"},
            headers={"Authorization": f"Bearer {token_a}"},
        )
        await client.post(
            "/api/v1/fleet-owners/me",
            json={"business_name": "Owner B Co"},
            headers={"Authorization": f"Bearer {token_b}"},
        )
        fleet_response = await client.post(
            "/api/v1/fleets",
            json={"name": "A's Fleet"},
            headers={"Authorization": f"Bearer {token_a}"},
        )
        fleet_id = fleet_response.json()["id"]

        forbidden_response = await client.get(
            f"/api/v1/fleets/{fleet_id}", headers={"Authorization": f"Bearer {token_b}"}
        )
        assert forbidden_response.status_code == 404
