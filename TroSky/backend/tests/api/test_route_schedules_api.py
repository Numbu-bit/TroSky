"""HTTP checks for a route's timetable: added through the admin API and
listed back, earliest departure first, for those who plan routes or
trips."""

from __future__ import annotations

import uuid
from decimal import Decimal

import pytest
from httpx import AsyncClient

from app.core.database import get_session_factory
from app.core.permissions import SystemRole
from app.services.route_service import RouteService
from tests.api.test_admin_dashboard_api import _committed_user, _login

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]


async def _committed_route() -> uuid.UUID:
    suffix = uuid.uuid4().hex[:6]
    async with get_session_factory()() as session:
        routes = RouteService(session)
        stops = [
            await routes.create_stop(
                name=f"{name}-{suffix}",
                code=None,
                latitude=5.6 + index / 10,
                longitude=-0.2,
                address=None,
                city="Accra",
                region=None,
            )
            for index, name in enumerate(("Circle", "Madina"))
        ]
        route = await routes.create_route(
            name=f"Circle-Madina-{suffix}",
            origin_stop_id=stops[0].id,
            destination_stop_id=stops[1].id,
            distance_km=Decimal("12"),
            estimated_duration_minutes=45,
            intermediate_stop_ids=[],
            created_by=None,
        )
        await session.commit()
        return route.id


@pytest.fixture
async def admin(client: AsyncClient, seed_identity_data: None, require_redis: None):
    return await _login(client, await _committed_user(SystemRole.ADMIN))


class TestTimetable:
    async def test_entries_come_back_earliest_first(
        self, client: AsyncClient, admin: dict[str, str]
    ) -> None:
        route_id = await _committed_route()
        url = f"/api/v1/admin/routes/{route_id}/schedules"
        for departure in ("17:45:00", "06:30:00"):
            created = await client.post(
                url,
                headers=admin,
                json={
                    "departure_time": departure,
                    "days_of_week": ["monday"],
                    "fare_amount": "8.00",
                },
            )
            assert created.status_code == 201, created.text

        listed = await client.get(url, headers=admin)

        assert listed.status_code == 200, listed.text
        assert [entry["departure_time"] for entry in listed.json()] == ["06:30:00", "17:45:00"]
        assert all(entry["route_id"] == str(route_id) for entry in listed.json())

    async def test_an_unknown_route_has_none(
        self, client: AsyncClient, admin: dict[str, str]
    ) -> None:
        response = await client.get(f"/api/v1/admin/routes/{uuid.uuid4()}/schedules", headers=admin)

        assert response.status_code == 404

    async def test_only_for_route_or_trip_planners(
        self, client: AsyncClient, seed_identity_data: None, require_redis: None
    ) -> None:
        passenger = await _login(client, await _committed_user(SystemRole.PASSENGER))
        route_id = await _committed_route()

        response = await client.get(f"/api/v1/admin/routes/{route_id}/schedules", headers=passenger)

        assert response.status_code == 403
