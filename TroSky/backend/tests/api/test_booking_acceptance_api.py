"""HTTP checks for drivers accepting trips and bookings, the operations
team's control over it, passengers getting off, and onward trips: routed,
guarded, and working end to end through the app's own sessions.

Two committed trips on one route (Madina -> Legon -> Circle), half an hour
apart, each with its own driver and 4-seat minibus.
"""

from __future__ import annotations

import secrets
import uuid
from datetime import UTC, datetime, timedelta

import pytest
from httpx import AsyncClient
from sqlalchemy import select

from app.core.config import get_settings
from app.core.database import get_session_factory
from app.core.permissions import SystemRole
from app.core.security import hash_password
from app.models.identity import User, UserProfile
from app.models.notifications import Notification
from app.services.booking_service import BookingService
from app.services.trip_service import TripService
from tests.api.test_admin_dashboard_api import _committed_user
from tests.integration.scenarios import TripScenario, another_trip, build_trip_scenario

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]

PASSWORD = "Str0ngPass"
MADINA, LEGON, CIRCLE = 0, 1, 2


def _local_number() -> str:
    return f"024{secrets.randbelow(10**7):07d}"


class World:
    def __init__(self, first: TripScenario, second: TripScenario, phones: dict[uuid.UUID, str]):
        self.first = first
        self.second = second
        self.phones = phones

    def stop(self, index: int) -> str:
        return str(self.first.stop_ids[index])


@pytest.fixture(autouse=True)
def _acceptance_on(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(get_settings(), "BOOKING_ACCEPTANCE_REQUIRED", True)


async def _world(departs: datetime) -> World:
    phones: dict[uuid.UUID, str] = {}
    async with get_session_factory()() as session:

        async def make_user(**_: object) -> User:
            local = _local_number()
            user = User(phone_number="+233" + local[1:], password_hash=hash_password(PASSWORD))
            user.profile = UserProfile(full_name="Kojo Asante", preferred_language="en")
            session.add(user)
            await session.flush()
            phones[user.id] = local
            return user

        first = await build_trip_scenario(session, make_user, departure=departs)
        second = await another_trip(
            session, make_user, first, departure=departs + timedelta(minutes=30)
        )
        await session.commit()
    return World(first, second, phones)


@pytest.fixture
async def world(seed_identity_data: None, require_redis: None) -> World:
    return await _world(datetime.now(UTC) + timedelta(hours=2))


@pytest.fixture
async def admin(client: AsyncClient, seed_identity_data: None, require_redis: None):
    return await _login(client, await _committed_user(SystemRole.ADMIN))


async def _login(client: AsyncClient, phone: str) -> dict[str, str]:
    response = await client.post(
        "/api/v1/auth/login", json={"identifier": phone, "password": PASSWORD}
    )
    assert response.status_code == 200, response.text
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


async def _driver(client: AsyncClient, world: World, trip: TripScenario) -> dict[str, str]:
    return await _login(client, world.phones[trip.driver_user_id])


async def _passenger(client: AsyncClient) -> dict[str, str]:
    phone = _local_number()
    registered = await client.post(
        "/api/v1/auth/register",
        json={"phone_number": phone, "password": PASSWORD, "full_name": "Akua Mensah"},
    )
    assert registered.status_code == 201, registered.text
    return await _login(client, phone)


async def _book(
    client: AsyncClient,
    headers: dict[str, str],
    world: World,
    *,
    seat: int = 0,
    origin: int = LEGON,
    destination: int = CIRCLE,
) -> dict:
    response = await client.post(
        "/api/v1/bookings",
        headers=headers,
        json={
            "trip_id": str(world.first.trip_id),
            "passengers": [{"seat_id": str(world.first.seat_ids[seat]), "full_name": "Akua"}],
            "origin_stop_id": world.stop(origin),
            "destination_stop_id": world.stop(destination),
        },
    )
    assert response.status_code == 201, response.text
    return response.json()


class TestTheDriverAnswersABooking:
    async def test_from_request_to_acceptance_to_payment(
        self, client: AsyncClient, world: World
    ) -> None:
        passenger = await _passenger(client)
        driver = await _driver(client, world, world.first)
        booking = await _book(client, passenger, world)
        url = f"/api/v1/driver-trips/{world.first.trip_id}/bookings/{booking['id']}"

        too_soon = await client.post(
            f"/api/v1/bookings/{booking['id']}/pay", headers=passenger, json={"channel": "wallet"}
        )
        waiting = await client.get("/api/v1/driver-trips/booking-requests", headers=driver)
        accepted = await client.post(f"{url}/accept", headers=driver)
        mine = await client.get(f"/api/v1/bookings/{booking['id']}", headers=passenger)

        assert booking["status"] == "awaiting_acceptance"
        assert too_soon.status_code == 409, too_soon.text
        assert too_soon.json()["error"]["code"] == "BOOKING_NOT_PAYABLE"
        assert waiting.status_code == 200, waiting.text
        [request] = waiting.json()["items"]
        assert request["booking_id"] == booking["id"]
        assert request["seat_numbers"] == ["A1"]
        assert 0 < request["seconds_left"] <= 120
        assert accepted.status_code == 200, accepted.text
        assert accepted.json()["status"] == "pending"
        assert mine.json()["status"] == "pending"

    async def test_a_declined_booking_moves_to_the_other_vehicle(
        self, client: AsyncClient, world: World
    ) -> None:
        passenger = await _passenger(client)
        driver = await _driver(client, world, world.first)
        other_driver = await _driver(client, world, world.second)
        booking = await _book(client, passenger, world)

        declined = await client.post(
            f"/api/v1/driver-trips/{world.first.trip_id}/bookings/{booking['id']}/decline",
            headers=driver,
            json={"reason": "Minibus is full"},
        )
        mine = await client.get(f"/api/v1/bookings/{booking['id']}", headers=passenger)
        theirs = await client.get("/api/v1/driver-trips/booking-requests", headers=other_driver)

        assert declined.status_code == 200, declined.text
        assert mine.json()["trip_id"] == str(world.second.trip_id)
        assert mine.json()["status"] == "awaiting_acceptance"
        assert [r["attempt"] for r in theirs.json()["items"]] == [2]

    async def test_drivers_answer_only_for_their_own_trips(
        self, client: AsyncClient, world: World
    ) -> None:
        passenger = await _passenger(client)
        other_driver = await _driver(client, world, world.second)
        booking = await _book(client, passenger, world)

        on_their_trip = await client.post(
            f"/api/v1/driver-trips/{world.first.trip_id}/bookings/{booking['id']}/accept",
            headers=other_driver,
        )
        on_the_wrong_trip = await client.post(
            f"/api/v1/driver-trips/{world.second.trip_id}/bookings/{booking['id']}/accept",
            headers=other_driver,
        )
        as_passenger = await client.get("/api/v1/driver-trips/booking-requests", headers=passenger)
        no_reason = await client.post(
            f"/api/v1/driver-trips/{world.first.trip_id}/bookings/{booking['id']}/decline",
            headers=other_driver,
            json={},
        )

        assert on_their_trip.status_code == 403
        assert on_the_wrong_trip.status_code == 404
        assert as_passenger.status_code == 403
        assert no_reason.status_code == 422


class TestTheDriverAnswersATrip:
    async def test_accept_then_a_second_driver_declines_theirs(
        self, client: AsyncClient, world: World, admin: dict[str, str]
    ) -> None:
        driver = await _driver(client, world, world.first)
        other_driver = await _driver(client, world, world.second)

        accepted = await client.post(
            f"/api/v1/driver-trips/{world.first.trip_id}/accept", headers=driver
        )
        declined = await client.post(
            f"/api/v1/driver-trips/{world.second.trip_id}/decline",
            headers=other_driver,
            json={"reason": "Tyre puncture"},
        )
        my_trips = await client.get("/api/v1/drivers/me/trips", headers=driver)
        trips = await client.get(
            "/api/v1/admin/trips",
            headers=admin,
            params={"route_id": str(world.first.route_id)},
        )

        assert accepted.status_code == 200, accepted.text
        assert accepted.json()["response"] == "accepted"
        assert declined.json()["response"] == "declined"
        assert declined.json()["is_active"] is False
        assert [t["driver_response"] for t in my_trips.json()["items"]] == ["accepted"]
        by_trip = {t["trip_id"]: t for t in trips.json()["items"]}
        assert by_trip[str(world.second.trip_id)]["driver_id"] is None
        assert by_trip[str(world.second.trip_id)]["driver_response"] is None


class TestTheOperationsTeam:
    async def test_sees_and_answers_bookings_and_trips_for_drivers(
        self, client: AsyncClient, world: World, admin: dict[str, str]
    ) -> None:
        passenger = await _passenger(client)
        first, second = (
            await _book(client, passenger, world),
            await _book(client, passenger, world, seat=1),
        )

        queue = await client.get(
            "/api/v1/admin/booking-requests",
            headers=admin,
            params={"trip_id": str(world.first.trip_id)},
        )
        accepted = await client.post(f"/api/v1/admin/bookings/{first['id']}/accept", headers=admin)
        ended = await client.post(
            f"/api/v1/admin/bookings/{second['id']}/decline",
            headers=admin,
            json={"reason": "Duplicate booking", "move_to_another_trip": False},
        )
        trip_accepted = await client.post(
            f"/api/v1/admin/trips/{world.first.trip_id}/accept-for-driver", headers=admin
        )
        trip_declined = await client.post(
            f"/api/v1/admin/trips/{world.second.trip_id}/decline-for-driver",
            headers=admin,
            json={"reason": "Driver called in sick"},
        )
        log = await client.get(
            "/api/v1/admin/driver-actions",
            headers=admin,
            params={"acted_as": "admin", "trip_id": str(world.first.trip_id)},
        )
        csv = await client.get(
            "/api/v1/admin/driver-actions", headers=admin, params={"format": "csv"}
        )

        assert queue.status_code == 200, queue.text
        assert queue.json()["total"] == 2
        assert accepted.json()["status"] == "pending"
        assert ended.json()["status"] == "cancelled"
        assert trip_accepted.json()["response"] == "accepted"
        assert trip_declined.json()["response"] == "declined"
        assert log.status_code == 200, log.text
        assert [item["kind"] for item in log.json()["items"]] == [
            "trip_accepted",
            "booking_declined",
            "booking_accepted",
        ]
        assert all(item["actor_name"] == "Adwoa Admin" for item in log.json()["items"])
        assert csv.status_code == 200
        assert csv.headers["content-type"].startswith("text/csv")

    async def test_moves_a_booking_to_a_trip_of_their_choice(
        self, client: AsyncClient, world: World, admin: dict[str, str]
    ) -> None:
        passenger = await _passenger(client)
        booking = await _book(client, passenger, world)

        moved = await client.post(
            f"/api/v1/admin/bookings/{booking['id']}/move",
            headers=admin,
            json={"trip_id": str(world.second.trip_id)},
        )

        assert moved.status_code == 200, moved.text
        assert moved.json()["trip_id"] == str(world.second.trip_id)

    async def test_is_the_only_one_who_may(self, client: AsyncClient, world: World) -> None:
        passenger = await _passenger(client)
        driver = await _driver(client, world, world.first)
        booking = await _book(client, passenger, world)

        for headers in (passenger, driver):
            for method, path in (
                ("get", "/api/v1/admin/booking-requests"),
                ("get", "/api/v1/admin/driver-actions"),
                ("post", f"/api/v1/admin/bookings/{booking['id']}/accept"),
                ("post", f"/api/v1/admin/trips/{world.first.trip_id}/accept-for-driver"),
            ):
                response = await getattr(client, method)(path, headers=headers)
                assert response.status_code == 403, (path, response.text)


class TestGettingOffAndGoingOn:
    async def test_the_driver_marks_a_passenger_off_and_they_are_offered_a_way_on(
        self, client: AsyncClient, seed_identity_data: None, require_redis: None
    ) -> None:
        world = await _world(datetime.now(UTC) - timedelta(minutes=5))
        passenger = await _passenger(client)
        driver = await _driver(client, world, world.first)
        # Booked and paid from Madina to Legon; then the trip leaves.
        booking = await _book(client, passenger, world, origin=MADINA, destination=LEGON)
        accepted = await client.post(
            f"/api/v1/driver-trips/{world.first.trip_id}/bookings/{booking['id']}/accept",
            headers=driver,
        )
        assert accepted.status_code == 200, accepted.text
        async with get_session_factory()() as session:
            await BookingService(session).confirm_booking(uuid.UUID(booking["id"]))
            await TripService(session).start_trip(world.first.trip_id, world.first.driver_user_id)
            await session.commit()

        manifest = await client.get(
            f"/api/v1/driver-trips/{world.first.trip_id}/passengers", headers=driver
        )
        [rider] = manifest.json()
        off = await client.post(
            f"/api/v1/driver-trips/{world.first.trip_id}/passengers/"
            f"{rider['booking_passenger_id']}/alight",
            headers=driver,
            json={"stop_id": world.stop(LEGON)},
        )
        after = await client.get(
            f"/api/v1/driver-trips/{world.first.trip_id}/passengers", headers=driver
        )
        onward = await client.get(
            f"/api/v1/bookings/{booking['id']}/onward-trips", headers=passenger
        )

        assert rider["alighted_at"] is None
        assert off.status_code == 200, off.text
        assert off.json()["booking_status"] == "completed"
        assert off.json()["alighted_how"] == "driver"
        assert after.json()[0]["alighted_at"] is not None
        assert onward.status_code == 200, onward.text
        # The other vehicle on the route still passes Legon, and has seats.
        assert [trip["trip_id"] for trip in onward.json()] == [str(world.second.trip_id)]
        assert onward.json()[0]["pickup_stop_id"] == world.stop(LEGON)
        async with get_session_factory()() as session:
            data = await session.scalars(
                select(Notification.data).where(Notification.title.startswith("You're at"))
            )
            assert {"booking_id": booking["id"], "stop_id": world.stop(LEGON)}.items() <= next(
                d for d in data if d.get("booking_id") == booking["id"]
            ).items()
