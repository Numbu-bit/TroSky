"""HTTP checks for ``/admin/reports/{report}`` (section 9 of the admin
requests): every report answers, as JSON or CSV, for report viewers only."""

from __future__ import annotations

import uuid
from datetime import UTC, datetime, timedelta

import pytest
from httpx import AsyncClient

from app.core.permissions import SystemRole
from tests.api.test_admin_dashboard_api import (
    _committed_trip_with_paid_and_unpaid_seats,
    _committed_user,
    _login,
)

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]

REPORTS = (
    "daily_rides",
    "revenue",
    "peak_hours",
    "route_popularity",
    "passenger_growth",
    "cancellation_rates",
)


@pytest.fixture
async def admin(client: AsyncClient, seed_identity_data: None, require_redis: None):
    return await _login(client, await _committed_user(SystemRole.ADMIN))


class TestReports:
    @pytest.mark.parametrize("report", REPORTS)
    async def test_every_report_answers(
        self, client: AsyncClient, admin: dict[str, str], report: str
    ) -> None:
        response = await client.get(f"/api/v1/admin/reports/{report}", headers=admin)

        assert response.status_code == 200, response.text
        body = response.json()
        keys = [column["key"] for column in body["columns"]]
        assert body["report"] == report
        assert all(set(row) == set(keys) for row in body["rows"])
        assert set(body["totals"]) <= set(keys)

    async def test_for_one_route_by_week_and_as_csv(
        self, client: AsyncClient, admin: dict[str, str]
    ) -> None:
        scenario = await _committed_trip_with_paid_and_unpaid_seats()
        today = datetime.now(UTC).date()
        params = {
            "route": str(scenario.route_id),
            "granularity": "week",
            "from": str(today - timedelta(days=20)),
            "to": str(today),
        }

        weekly = await client.get(
            "/api/v1/admin/reports/cancellation_rates", headers=admin, params=params
        )
        exported = await client.get(
            "/api/v1/admin/reports/route_popularity",
            headers=admin,
            params={**params, "format": "csv"},
        )

        body = weekly.json()
        assert (body["granularity"], body["route_id"]) == ("week", str(scenario.route_id))
        assert all(datetime.fromisoformat(row["period"]).weekday() == 0 for row in body["rows"])
        assert body["totals"]["bookings_made"] == 2  # one paid, one held
        assert exported.headers["content-type"].startswith("text/csv")
        lines = exported.text.splitlines()
        assert lines[0].startswith("route_id,route_name,origin,destination")
        assert scenario.route_name in lines[1]

    async def test_peak_hours_has_every_hour(
        self, client: AsyncClient, admin: dict[str, str]
    ) -> None:
        response = await client.get("/api/v1/admin/reports/peak_hours", headers=admin)

        body = response.json()
        assert [row["hour"] for row in body["rows"]][:3] == ["00:00", "01:00", "02:00"]
        assert len(body["rows"]) == 24
        assert body["granularity"] is None

    @pytest.mark.parametrize(
        "path",
        [
            "/api/v1/admin/reports/horoscopes",
            "/api/v1/admin/reports/revenue?granularity=fortnight",
            f"/api/v1/admin/reports/revenue?route={uuid.uuid4()}&fleet=not-a-uuid",
        ],
    )
    async def test_bad_requests(
        self, client: AsyncClient, admin: dict[str, str], path: str
    ) -> None:
        assert (await client.get(path, headers=admin)).status_code == 422

    async def test_the_overview_is_still_the_overview(
        self, client: AsyncClient, admin: dict[str, str]
    ) -> None:
        response = await client.get("/api/v1/admin/reports/overview", headers=admin)

        assert response.status_code == 200
        assert "figures" in response.json()

    async def test_for_report_viewers(
        self, client: AsyncClient, seed_identity_data: None, require_redis: None
    ) -> None:
        passenger = await _login(client, await _committed_user(SystemRole.PASSENGER))

        response = await client.get("/api/v1/admin/reports/revenue", headers=passenger)

        assert response.status_code == 403
