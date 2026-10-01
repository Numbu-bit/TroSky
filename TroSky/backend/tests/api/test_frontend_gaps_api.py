"""HTTP checks for the endpoints the frontend asked for (G1-G16): wired up,
reached where their paths overlap with older routes, validating input, and
working end to end where a flow spans several calls."""

from __future__ import annotations

import secrets
import uuid
from datetime import date, timedelta

import pytest
from httpx import AsyncClient

from app.core.database import get_session_factory
from app.models.routes import Stop
from app.providers.sms.sandbox import SandboxSmsProvider
from app.providers.storage.sandbox import SandboxStorageProvider
from app.utilities.geo import latlng_to_wkt

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]

PNG = b"\x89PNG\r\n\x1a\n" + b"\x00" * 64


@pytest.fixture(autouse=True)
def _clear_sandboxes():
    SandboxSmsProvider.clear()
    SandboxStorageProvider.clear()
    yield
    SandboxSmsProvider.clear()
    SandboxStorageProvider.clear()


def _local_number() -> str:
    return f"024{secrets.randbelow(10**7):07d}"


async def _signed_in(client: AsyncClient, role: str = "passenger") -> tuple[dict[str, str], str]:
    """Register and log in; returns (auth headers, local phone number)."""
    phone = _local_number()
    registered = await client.post(
        "/api/v1/auth/register",
        json={
            "phone_number": phone,
            "password": "Str0ngPass",
            "full_name": "Akua Mensah",
            "role": role,
        },
    )
    assert registered.status_code == 201, registered.text
    login = await client.post(
        "/api/v1/auth/login", json={"identifier": phone, "password": "Str0ngPass"}
    )
    assert login.status_code == 200, login.text
    return {"Authorization": f"Bearer {login.json()['access_token']}"}, phone


async def _committed_stops(count: int) -> list[uuid.UUID]:
    """Stops committed for real, so the app's own sessions can see them."""
    async with get_session_factory()() as session:
        stops = [
            Stop(name=f"Stop-{uuid.uuid4().hex[:6]}", location=latlng_to_wkt(5.6 + i / 10, -0.2))
            for i in range(count)
        ]
        session.add_all(stops)
        await session.commit()
        return [stop.id for stop in stops]


class TestPasswordResetCode:  # G1
    async def test_reset_with_the_texted_code(
        self, client: AsyncClient, seed_identity_data: None, require_redis: None
    ) -> None:
        _, phone = await _signed_in(client)
        forgot = await client.post("/api/v1/auth/password/forgot", json={"identifier": phone})
        assert forgot.status_code == 200
        message = SandboxSmsProvider.get_last_message("+233" + phone[1:])
        assert message is not None
        code = message.split("is ")[1].split(".")[0].strip()

        reset = await client.post(
            "/api/v1/auth/password/reset",
            json={"target": phone, "code": code, "new_password": "N3wPassword"},
        )
        assert reset.status_code == 200, reset.text
        login = await client.post(
            "/api/v1/auth/login", json={"identifier": phone, "password": "N3wPassword"}
        )
        assert login.status_code == 200

    @pytest.mark.parametrize(
        "body",
        [
            {
                "token": "x" * 40,
                "target": "0244564567",
                "code": "123456",
                "new_password": "N3wPassword",
            },
            {"target": "0244564567", "new_password": "N3wPassword"},
            {"new_password": "N3wPassword"},
        ],
    )
    async def test_exactly_one_way_to_prove_it(
        self, client: AsyncClient, seed_identity_data: None, require_redis: None, body: dict
    ) -> None:
        response = await client.post("/api/v1/auth/password/reset", json=body)
        assert response.status_code == 422


class TestOverlappingPaths:
    async def test_nearby_vehicles_is_not_taken_for_a_vehicle_id(  # G16
        self, client: AsyncClient, seed_identity_data: None, require_redis: None
    ) -> None:
        headers, _ = await _signed_in(client)
        response = await client.get(
            "/api/v1/vehicles/nearby", params={"latitude": 5.6, "longitude": -0.2}, headers=headers
        )
        assert response.status_code == 200, response.text
        assert response.json() == []

    async def test_driver_lookup_is_not_taken_for_a_fleet_id(  # G10
        self, client: AsyncClient, seed_identity_data: None, require_redis: None
    ) -> None:
        headers, _ = await _signed_in(client, role="fleet_owner")
        created = await client.post(
            "/api/v1/fleet-owners/me", json={"business_name": "Akua Transport"}, headers=headers
        )
        assert created.status_code == 201, created.text

        response = await client.get(
            "/api/v1/fleets/driver-lookup", params={"phone": _local_number()}, headers=headers
        )
        assert response.status_code == 404, response.text
        assert response.json()["error"]["code"] == "NOT_FOUND"


class TestDriverEndpoints:  # G2, G7
    async def test_trips_and_earnings_respond_and_validate(
        self, client: AsyncClient, seed_identity_data: None, require_redis: None
    ) -> None:
        headers, _ = await _signed_in(client, role="driver")
        profile = await client.post(
            "/api/v1/drivers/me",
            json={
                "license_number": f"GHA-{uuid.uuid4().hex[:8]}",
                "license_expiry": str(date.today() + timedelta(days=365)),
            },
            headers=headers,
        )
        assert profile.status_code == 201, profile.text

        trips = await client.get("/api/v1/drivers/me/trips", headers=headers)
        assert trips.status_code == 200
        assert trips.json() == {"items": [], "total": 0, "limit": 20, "offset": 0}

        bad_status = await client.get(
            "/api/v1/drivers/me/trips", params={"status": "scheduled,flying"}, headers=headers
        )
        assert bad_status.status_code == 422
        assert "scheduled" in bad_status.json()["error"]["details"]["allowed"]

        earnings = await client.get("/api/v1/drivers/me/earnings", headers=headers)
        assert earnings.status_code == 200
        body = earnings.json()
        assert body["period"] == "week"
        assert (body["total"], body["trips_count"], body["currency"]) == ("0.00", 0, "GHS")
        assert len(body["buckets"]) == 1

        backwards = await client.get(
            "/api/v1/drivers/me/earnings",
            params={"from": "2031-03-05", "to": "2031-03-01"},
            headers=headers,
        )
        assert backwards.status_code == 422


class TestPassengerEndpoints:  # G4, G5, G12
    async def test_booking_filters_are_validated(
        self, client: AsyncClient, seed_identity_data: None, require_redis: None
    ) -> None:
        headers, _ = await _signed_in(client)
        bad = await client.get("/api/v1/bookings", params={"status": "lost"}, headers=headers)
        assert bad.status_code == 422
        good = await client.get(
            "/api/v1/bookings", params={"status": "confirmed", "upcoming": "true"}, headers=headers
        )
        assert good.status_code == 200
        assert good.json()["items"] == []

    async def test_avatar_upload(
        self, client: AsyncClient, seed_identity_data: None, require_redis: None
    ) -> None:
        headers, _ = await _signed_in(client)
        uploaded = await client.post(
            "/api/v1/users/me/avatar",
            files={"file": ("me.png", PNG, "image/png")},
            headers=headers,
        )
        assert uploaded.status_code == 200, uploaded.text
        assert uploaded.json()["profile"]["avatar_url"]

        me = await client.get("/api/v1/users/me", headers=headers)
        assert me.json()["profile"]["avatar_url"]

        wrong = await client.post(
            "/api/v1/users/me/avatar",
            files={"file": ("cv.pdf", b"%PDF-1.4", "application/pdf")},
            headers=headers,
        )
        assert wrong.status_code == 422

    async def test_favourite_routes_round_trip(
        self, client: AsyncClient, seed_identity_data: None, require_redis: None
    ) -> None:
        headers, _ = await _signed_in(client)
        origin, destination = await _committed_stops(2)
        body = {
            "origin_stop_id": str(origin),
            "destination_stop_id": str(destination),
            "label": "Work",
        }

        created = await client.post("/api/v1/users/me/favourite-routes", json=body, headers=headers)
        assert created.status_code == 201, created.text
        favourite = created.json()
        assert favourite["label"] == "Work"
        assert favourite["origin_stop_name"].startswith("Stop-")

        again = await client.post("/api/v1/users/me/favourite-routes", json=body, headers=headers)
        assert again.status_code == 409
        assert again.json()["error"]["code"] == "FAVOURITE_ROUTE_EXISTS"

        listed = await client.get("/api/v1/users/me/favourite-routes", headers=headers)
        assert [f["id"] for f in listed.json()] == [favourite["id"]]

        deleted = await client.delete(
            f"/api/v1/users/me/favourite-routes/{favourite['id']}", headers=headers
        )
        assert deleted.status_code == 204
        assert (await client.get("/api/v1/users/me/favourite-routes", headers=headers)).json() == []
