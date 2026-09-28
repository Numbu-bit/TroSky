"""HTTP tests for GPS-default pickup: nearby stops, name search, and the
pickup parameters on trip search.

``tests/integration/test_gps_pickup.py`` covers the resolution logic; these
cover the wiring a mobile client depends on -- query validation, response
shape, and the error codes it must branch on.

Stops here are committed so the app's own sessions can see them, which
means they outlive the test. Each is placed at a random point in sparsely
served northern Ghana and deleted afterwards, so neither a leftover from an
earlier run nor another test can turn up as "nearby".
"""

from __future__ import annotations

import random
import uuid
from collections.abc import AsyncIterator
from datetime import date, timedelta

import pytest
import pytest_asyncio
from httpx import AsyncClient
from sqlalchemy import delete

from app.core.database import get_session_factory
from app.models.routes import Stop
from app.utilities.geo import latlng_to_wkt

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]

TOMORROW = (date.today() + timedelta(days=1)).isoformat()
# Null Island, in the Gulf of Guinea: no stop will ever be within a walk.
OPEN_SEA = (0.0, 0.0)


@pytest_asyncio.fixture
async def lone_stop(require_postgres: None) -> AsyncIterator[dict]:
    """One committed stop at a random, otherwise empty spot."""
    latitude = round(random.uniform(9.0, 10.5), 6)
    longitude = round(random.uniform(-2.5, -1.0), 6)
    name = f"Tamale Junction {uuid.uuid4().hex[:8]}"
    session_factory = get_session_factory()
    async with session_factory() as session, session.begin():
        stop = Stop(name=name, location=latlng_to_wkt(latitude, longitude))
        session.add(stop)
        await session.flush()
        stop_id = stop.id
    yield {"id": str(stop_id), "name": name, "latitude": latitude, "longitude": longitude}
    async with session_factory() as session, session.begin():
        await session.execute(delete(Stop).where(Stop.id == stop_id))


class TestNearbyStops:
    async def test_returns_the_stop_the_passenger_is_standing_at(
        self, client: AsyncClient, lone_stop: dict
    ) -> None:
        response = await client.get(
            "/api/v1/stops/nearby",
            params={"latitude": lone_stop["latitude"], "longitude": lone_stop["longitude"]},
        )
        assert response.status_code == 200, response.text
        body = response.json()
        assert body[0]["id"] == lone_stop["id"]
        assert body[0]["distance_m"] < 1.0
        assert {"latitude", "longitude", "name", "distance_m"} <= set(body[0])

    async def test_nobody_nearby_is_an_empty_list_not_an_error(self, client: AsyncClient) -> None:
        """The app shows a default pickup from this call; being far from a
        stop is ordinary, and the app falls back to name search."""
        response = await client.get(
            "/api/v1/stops/nearby", params={"latitude": OPEN_SEA[0], "longitude": OPEN_SEA[1]}
        )
        assert response.status_code == 200
        assert response.json() == []

    @pytest.mark.parametrize(("latitude", "longitude"), [(91, 0), (-91, 0), (0, 181), (0, -181)])
    async def test_impossible_coordinates_are_rejected(
        self, client: AsyncClient, latitude: float, longitude: float
    ) -> None:
        response = await client.get(
            "/api/v1/stops/nearby", params={"latitude": latitude, "longitude": longitude}
        )
        assert response.status_code == 422


class TestStopNameSearch:
    async def test_finds_a_stop_by_part_of_its_name(
        self, client: AsyncClient, lone_stop: dict
    ) -> None:
        fragment = lone_stop["name"].split()[-1]  # the unique suffix
        response = await client.get("/api/v1/stops", params={"q": fragment})
        assert response.status_code == 200
        assert [s["id"] for s in response.json()["items"]] == [lone_stop["id"]]

    async def test_a_single_character_query_is_rejected(self, client: AsyncClient) -> None:
        response = await client.get("/api/v1/stops", params={"q": "a"})
        assert response.status_code == 422


class TestTripSearchPickup:
    async def test_half_a_coordinate_is_rejected(self, client: AsyncClient) -> None:
        response = await client.get(
            "/api/v1/trips/search",
            params={"travel_date": TOMORROW, "pickup_latitude": 5.6},
        )
        assert response.status_code == 422
        assert response.json()["error"]["code"] == "VALIDATION_ERROR"

    async def test_far_from_any_stop_says_so_rather_than_finding_nothing(
        self, client: AsyncClient
    ) -> None:
        """An empty list would read as "no trips today"; the passenger needs
        to hear "you are not near a stop" instead."""
        response = await client.get(
            "/api/v1/trips/search",
            params={
                "travel_date": TOMORROW,
                "pickup_latitude": OPEN_SEA[0],
                "pickup_longitude": OPEN_SEA[1],
            },
        )
        assert response.status_code == 422
        error = response.json()["error"]
        assert error["code"] == "NO_PICKUP_NEARBY"
        assert error["details"]["max_walk_meters"] > 0

    async def test_a_manual_stop_wins_even_when_coordinates_are_far_away(
        self, client: AsyncClient, lone_stop: dict
    ) -> None:
        """Coordinates in the open sea would be refused on their own. With a
        stop chosen by hand they are ignored for pickup, so the search runs."""
        response = await client.get(
            "/api/v1/trips/search",
            params={
                "travel_date": TOMORROW,
                "origin_stop_id": lone_stop["id"],
                "pickup_latitude": OPEN_SEA[0],
                "pickup_longitude": OPEN_SEA[1],
            },
        )
        assert response.status_code == 200, response.text
