"""HTTP checks for the demand heat maps (section 8 of the admin requests):
searches made through the app land on the map; parameters are checked."""

from __future__ import annotations

import secrets
from datetime import UTC, datetime, timedelta

import pytest
from httpx import AsyncClient
from sqlalchemy import update

from app.core.database import get_session_factory
from app.core.permissions import SystemRole
from app.models.routes import Stop
from tests.api.test_admin_dashboard_api import (
    _committed_trip_with_paid_and_unpaid_seats,
    _committed_user,
    _login,
)

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]

URL = "/api/v1/admin/analytics/demand"
DAYS = ("mon", "tue", "wed", "thu", "fri", "sat", "sun")


@pytest.fixture
async def admin(client: AsyncClient, seed_identity_data: None, require_redis: None):
    return await _login(client, await _committed_user(SystemRole.ADMIN))


class TestDemand:
    async def test_searches_in_the_app_land_on_the_map(
        self, client: AsyncClient, admin: dict[str, str]
    ) -> None:
        scenario = await _committed_trip_with_paid_and_unpaid_seats()
        city = f"Heatville {secrets.token_hex(3)}"
        async with get_session_factory()() as session:
            await session.execute(
                update(Stop).where(Stop.id.in_(scenario.stop_ids)).values(city=city)
            )
            await session.commit()
        tomorrow = (datetime.now(UTC) + timedelta(days=1)).date()
        started = datetime.now(UTC)
        for _ in range(3):
            searched = await client.get(
                "/api/v1/trips/search",
                params={
                    "origin_stop_id": str(scenario.stop_ids[1]),
                    "destination_stop_id": str(scenario.stop_ids[2]),
                    "travel_date": str(tomorrow),
                },
            )
            assert searched.status_code == 200, searched.text

        response = await client.get(URL, headers=admin, params={"city": city})
        today = DAYS[started.weekday()]
        on_today = await client.get(URL, headers=admin, params={"city": city, "days": today})
        other_day = DAYS[(started.weekday() + 1) % 7]
        on_another_day = await client.get(
            URL, headers=admin, params={"city": city, "days": other_day}
        )

        assert response.status_code == 200, response.text
        body = response.json()
        assert (body["type"], body["total"], body["withheld"]) == ("searches", 3, 0)
        assert [(c["latitude"], c["longitude"], c["weight"]) for c in body["cells"]] == [
            ("5.700", "-1.000", 3)
        ]
        assert [o["stop_id"] for o in body["top_origins"]] == [str(scenario.stop_ids[1])]
        assert [p["weight"] for p in body["top_pairs"]] == [3]
        assert body["cell_degrees"] == "0.005"
        assert tuple(d["day"] for d in body["by_day_and_hour"]) == DAYS
        assert all(len(d["hours"]) == 24 for d in body["by_day_and_hour"])
        [row] = [d for d in body["by_day_and_hour"] if d["day"] == today]
        assert sum(row["hours"]) == 3
        assert row["hours"].index(3) in {started.hour, (started.hour + 1) % 24}
        assert on_today.json()["total"] == 3
        assert on_another_day.json()["total"] == 0

    async def test_filters_are_echoed(self, client: AsyncClient, admin: dict[str, str]) -> None:
        response = await client.get(
            URL,
            headers=admin,
            params={"type": "unmet", "days": "fri,Mon", "hour_from": 22, "hour_to": 5},
        )

        assert response.status_code == 200, response.text
        body = response.json()
        assert (body["type"], body["days"], body["hour_from"], body["hour_to"]) == (
            "unmet",
            ["mon", "fri"],
            22,
            5,
        )

    @pytest.mark.parametrize(
        "params",
        [{"days": "funday"}, {"hour_from": 24}, {"hour_to": -1}, {"type": "walks"}],
    )
    async def test_bad_parameters(
        self, client: AsyncClient, admin: dict[str, str], params: dict[str, object]
    ) -> None:
        assert (await client.get(URL, headers=admin, params=params)).status_code == 422

    async def test_for_reports_viewers(
        self, client: AsyncClient, seed_identity_data: None, require_redis: None
    ) -> None:
        passenger = await _login(client, await _committed_user(SystemRole.PASSENGER))

        assert (await client.get(URL, headers=passenger)).status_code == 403
