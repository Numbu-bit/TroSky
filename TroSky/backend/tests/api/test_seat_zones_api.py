"""Through the API: which seats a ride is offered, and which a booking may take.

The scenario's route is Madina, Legon and Circle. A ride to the next stop covers
half of it by counting stops, or less by distance, so these tests give each stop
a measured distance rather than rely on the route's defaults.
"""

from __future__ import annotations

import secrets
import uuid
from datetime import UTC, datetime, timedelta
from decimal import Decimal

import pytest
from httpx import AsyncClient
from sqlalchemy import select

from app.core.config import get_settings
from app.core.database import get_session_factory
from app.core.security import hash_password
from app.models.identity import User, UserProfile
from app.models.routes import RouteStop
from app.models.vehicles import VehicleSeat
from tests.integration.scenarios import TripScenario, build_trip_scenario

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]

PASSWORD = "Str0ngPass"
MADINA, LEGON, CIRCLE = 0, 1, 2


def _local_number() -> str:
    return "057" + "".join(secrets.choice("0123456789") for _ in range(7))


@pytest.fixture(autouse=True)
def _pay_straight_away(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(get_settings(), "BOOKING_ACCEPTANCE_REQUIRED", False)
    monkeypatch.setattr(get_settings(), "REQUIRE_VERIFIED_ACCOUNT", False)


@pytest.fixture
async def trip(seed_identity_data: None, require_redis: None) -> TripScenario:
    """Four seats in two rows, on a 20 km route with Legon 4 km along it."""

    async with get_session_factory()() as session:

        async def make_user(**_: object) -> User:
            local = _local_number()
            user = User(phone_number="+233" + local[1:], password_hash=hash_password(PASSWORD))
            user.profile = UserProfile(full_name="Kojo Asante", preferred_language="en")
            session.add(user)
            await session.flush()
            return user

        scenario = await build_trip_scenario(
            session, make_user, departure=datetime.now(UTC) + timedelta(hours=2), seats=4
        )
        for stop_id, km in zip(scenario.stop_ids, ("0", "4", "20"), strict=True):
            route_stop = (
                await session.execute(
                    select(RouteStop).where(
                        RouteStop.route_id == scenario.route_id, RouteStop.stop_id == stop_id
                    )
                )
            ).scalar_one()
            route_stop.distance_from_origin_km = Decimal(km)
        seats = (
            (
                await session.execute(
                    select(VehicleSeat).where(VehicleSeat.id.in_(scenario.seat_ids))
                )
            )
            .scalars()
            .all()
        )
        by_id = {seat.id: seat for seat in seats}
        for index, seat_id in enumerate(scenario.seat_ids):
            by_id[seat_id].row_number = index // 2 + 1
        await session.commit()
    return scenario


async def _passenger(client: AsyncClient) -> dict[str, str]:
    phone = _local_number()
    registered = await client.post(
        "/api/v1/auth/register",
        json={"phone_number": phone, "password": PASSWORD, "full_name": "Akua Mensah"},
    )
    assert registered.status_code == 201, registered.text
    login = await client.post(
        "/api/v1/auth/login", json={"identifier": phone, "password": PASSWORD}
    )
    assert login.status_code == 200, login.text
    return {"Authorization": f"Bearer {login.json()['access_token']}"}


async def _seats(client: AsyncClient, trip: TripScenario, **params: str) -> dict:
    response = await client.get(f"/api/v1/trips/{trip.trip_id}/seats", params=params)
    assert response.status_code == 200, response.text
    return response.json()


async def _book(
    client: AsyncClient,
    trip: TripScenario,
    seat_indexes: list[int],
    *,
    origin: int,
    destination: int,
):
    return await client.post(
        "/api/v1/bookings",
        headers=await _passenger(client),
        json={
            "trip_id": str(trip.trip_id),
            "passengers": [
                {"seat_id": str(trip.seat_ids[index]), "full_name": f"Rider {index}"}
                for index in seat_indexes
            ],
            "origin_stop_id": str(trip.stop_ids[origin]),
            "destination_stop_id": str(trip.stop_ids[destination]),
        },
    )


class TestSeatsOffered:
    async def test_a_short_ride_is_offered_the_front_seats(
        self, client: AsyncClient, trip: TripScenario
    ) -> None:
        body = await _seats(
            client,
            trip,
            origin_stop_id=str(trip.stop_ids[MADINA]),
            destination_stop_id=str(trip.stop_ids[LEGON]),
        )
        assert body["passenger_zone"] == "front"
        by_id = {seat["id"]: seat for seat in body["seats"]}
        rows = [by_id[str(seat_id)] for seat_id in trip.seat_ids]
        assert [seat["zone"] for seat in rows] == ["front", "front", "back", "back"]
        assert [seat["is_selectable"] for seat in rows] == [True, True, False, False]
        assert all(seat["is_available"] for seat in rows)

    async def test_a_long_ride_is_offered_the_back_seats(
        self, client: AsyncClient, trip: TripScenario
    ) -> None:
        body = await _seats(
            client,
            trip,
            origin_stop_id=str(trip.stop_ids[MADINA]),
            destination_stop_id=str(trip.stop_ids[CIRCLE]),
        )
        assert body["passenger_zone"] == "back"
        by_id = {seat["id"]: seat for seat in body["seats"]}
        rows = [by_id[str(seat_id)] for seat_id in trip.seat_ids]
        assert [seat["is_selectable"] for seat in rows] == [False, False, True, True]

    async def test_with_no_stops_every_free_seat_is_offered(
        self, client: AsyncClient, trip: TripScenario
    ) -> None:
        """What the app gets until it sends the ride, so it keeps working."""
        body = await _seats(client, trip)
        assert body["passenger_zone"] is None
        assert all(seat["is_selectable"] for seat in body["seats"])

    async def test_a_stop_not_on_the_route_is_refused(
        self, client: AsyncClient, trip: TripScenario
    ) -> None:
        response = await client.get(
            f"/api/v1/trips/{trip.trip_id}/seats",
            params={"destination_stop_id": str(uuid.uuid4())},
        )
        assert response.status_code == 422
        assert response.json()["error"]["code"] == "STOP_NOT_ON_ROUTE"

    async def test_a_pickup_after_the_destination_is_refused(
        self, client: AsyncClient, trip: TripScenario
    ) -> None:
        response = await client.get(
            f"/api/v1/trips/{trip.trip_id}/seats",
            params={
                "origin_stop_id": str(trip.stop_ids[CIRCLE]),
                "destination_stop_id": str(trip.stop_ids[LEGON]),
            },
        )
        assert response.status_code == 422


class TestBookingWithZonesEnforced:
    @pytest.fixture(autouse=True)
    def _enforced(self, monkeypatch: pytest.MonkeyPatch) -> None:
        monkeypatch.setattr(get_settings(), "SEAT_ZONES_ENFORCED", True)

    async def test_a_short_ride_may_take_a_front_seat(
        self, client: AsyncClient, trip: TripScenario
    ) -> None:
        response = await _book(client, trip, [0], origin=MADINA, destination=LEGON)
        assert response.status_code == 201, response.text

    async def test_a_short_ride_may_not_take_a_back_seat(
        self, client: AsyncClient, trip: TripScenario
    ) -> None:
        response = await _book(client, trip, [3], origin=MADINA, destination=LEGON)
        assert response.status_code == 409
        error = response.json()["error"]
        assert error["code"] == "SEAT_NOT_IN_ZONE"
        assert error["details"]["passenger_zone"] == "front"
        assert error["details"]["seat_ids"] == [str(trip.seat_ids[3])]

    async def test_a_long_ride_may_not_take_a_front_seat(
        self, client: AsyncClient, trip: TripScenario
    ) -> None:
        response = await _book(client, trip, [0], origin=MADINA, destination=CIRCLE)
        assert response.status_code == 409

    async def test_any_free_seat_will_do_once_the_zone_is_full(
        self, client: AsyncClient, trip: TripScenario
    ) -> None:
        full = await _book(client, trip, [2, 3], origin=MADINA, destination=CIRCLE)
        assert full.status_code == 201, full.text
        response = await _book(client, trip, [0], origin=MADINA, destination=CIRCLE)
        assert response.status_code == 201, response.text

    async def test_a_group_fills_its_zone_and_then_spills_over(
        self, client: AsyncClient, trip: TripScenario
    ) -> None:
        response = await _book(client, trip, [0, 1, 2], origin=MADINA, destination=LEGON)
        assert response.status_code == 201, response.text


class TestBookingWithZonesOff:
    async def test_any_free_seat_can_be_booked(
        self, client: AsyncClient, trip: TripScenario
    ) -> None:
        """The default, until the app offers only the seats that suit the ride."""
        assert get_settings().SEAT_ZONES_ENFORCED is False
        response = await _book(client, trip, [3], origin=MADINA, destination=LEGON)
        assert response.status_code == 201, response.text
