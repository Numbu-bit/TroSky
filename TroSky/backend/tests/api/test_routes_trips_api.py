"""End-to-end HTTP tests for public route/trip search and driver-facing
trip lifecycle endpoints."""

from __future__ import annotations

import uuid

import pytest
from httpx import AsyncClient

from app.core.database import get_session_factory
from app.models.routes import Route, Stop
from app.providers.email.sandbox import SandboxEmailProvider
from app.providers.sms.sandbox import SandboxSmsProvider
from app.utilities.geo import latlng_to_wkt

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
    assert login_response.status_code == 200
    return str(login_response.json()["access_token"])


async def _seed_route_and_committed_trip() -> tuple[uuid.UUID, uuid.UUID]:
    """Creates a stop/route/trip via a real, committed session (visible to
    the app's own request-scoped sessions through the `client` fixture)."""
    session_factory = get_session_factory()
    async with session_factory() as session:
        origin = Stop(name=f"Origin-{uuid.uuid4().hex[:6]}", location=latlng_to_wkt(5.6, -0.2))
        destination = Stop(
            name=f"Destination-{uuid.uuid4().hex[:6]}", location=latlng_to_wkt(6.7, -1.6)
        )
        session.add_all([origin, destination])
        await session.flush()

        route = Route(
            name=f"Route-{uuid.uuid4().hex[:8]}",
            origin_stop_id=origin.id,
            destination_stop_id=destination.id,
            estimated_duration_minutes=180,
        )
        session.add(route)
        await session.flush()
        route_id = route.id
        await session.commit()
    return route_id, origin.id


class TestPublicSearchApi:
    async def test_list_routes_and_get_route_detail(
        self, client: AsyncClient, seed_identity_data: None
    ) -> None:
        route_id, _ = await _seed_route_and_committed_trip()

        list_response = await client.get("/api/v1/routes")
        assert list_response.status_code == 200
        assert list_response.json()["total"] >= 1

        detail_response = await client.get(f"/api/v1/routes/{route_id}")
        assert detail_response.status_code == 200
        assert len(detail_response.json()["stops"]) == 2

    async def test_search_trips_requires_travel_date(
        self, client: AsyncClient, seed_identity_data: None
    ) -> None:
        response = await client.get("/api/v1/trips/search")
        assert response.status_code == 422


class TestDriverTripLifecycleApi:
    async def test_non_driver_cannot_start_a_trip(
        self, client: AsyncClient, seed_identity_data: None
    ) -> None:
        token = await _register_and_login(client, "0561234567", "A Passenger", "passenger")
        response = await client.post(
            f"/api/v1/driver-trips/{uuid.uuid4()}/start",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert response.status_code == 403

    async def test_driver_start_requires_active_assignment(
        self, client: AsyncClient, seed_identity_data: None
    ) -> None:
        token = await _register_and_login(client, "0561234568", "A Driver", "driver")
        response = await client.post(
            f"/api/v1/driver-trips/{uuid.uuid4()}/start",
            headers={"Authorization": f"Bearer {token}"},
        )
        # No driver profile has been created yet for this account.
        assert response.status_code == 403
