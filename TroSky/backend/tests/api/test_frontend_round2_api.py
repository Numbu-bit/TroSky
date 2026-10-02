"""HTTP checks for the second round of frontend requests (G19-G33): routed,
validating input, and working end to end through the app's own sessions.

The scenario trip is committed for real so those sessions can see it:
Madina -> Legon -> Circle, 20 km, GHS 8.00, a 4-seat minibus.
"""

from __future__ import annotations

import secrets
import uuid
from datetime import UTC, datetime, timedelta

import pytest
from httpx import AsyncClient

from app.core.database import get_session_factory
from app.core.security import hash_password
from app.models.identity import User, UserProfile
from app.models.notifications import NotificationCategory
from app.providers.storage.sandbox import SandboxStorageProvider
from app.services.booking_service import BookingService
from app.services.notification_service import NotificationService
from tests.integration.scenarios import TripScenario, build_trip_scenario, fleet_service

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]

PASSWORD = "Str0ngPass"
PNG = b"\x89PNG\r\n\x1a\n" + b"\x00" * 64
MADINA, LEGON, CIRCLE = 0, 1, 2


@pytest.fixture(autouse=True)
def _clear_storage():
    SandboxStorageProvider.clear()
    yield
    SandboxStorageProvider.clear()


def _local_number() -> str:
    return f"024{secrets.randbelow(10**7):07d}"


class World:
    """A committed trip, plus the phone numbers its people log in with."""

    def __init__(self, scenario: TripScenario, phones: dict[uuid.UUID, str], departs: datetime):
        self.scenario = scenario
        self.phones = phones
        self.departs = departs

    @property
    def driver_phone(self) -> str:
        return self.phones[self.scenario.driver_user_id]

    def stop(self, index: int) -> str:
        return str(self.scenario.stop_ids[index])


@pytest.fixture
async def world(seed_identity_data: None, require_redis: None) -> World:
    departs = datetime.now(UTC) + timedelta(hours=2)
    phones: dict[uuid.UUID, str] = {}
    async with get_session_factory()() as session:

        async def make_user(**_: object) -> User:
            local = _local_number()
            user = User(phone_number="+233" + local[1:], password_hash=hash_password(PASSWORD))
            user.profile = UserProfile(full_name="Yaw Darko", preferred_language="en")
            session.add(user)
            await session.flush()
            phones[user.id] = local
            return user

        scenario = await build_trip_scenario(session, make_user, departure=departs)
        await session.commit()
    return World(scenario, phones, departs)


async def _login(client: AsyncClient, phone: str) -> dict[str, str]:
    response = await client.post(
        "/api/v1/auth/login", json={"identifier": phone, "password": PASSWORD}
    )
    assert response.status_code == 200, response.text
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


async def _passenger(client: AsyncClient) -> dict[str, str]:
    phone = _local_number()
    registered = await client.post(
        "/api/v1/auth/register",
        json={"phone_number": phone, "password": PASSWORD, "full_name": "Akua Mensah"},
    )
    assert registered.status_code == 201, registered.text
    return await _login(client, phone)


async def _book(client: AsyncClient, headers: dict[str, str], world: World, seat: int = 0) -> dict:
    response = await client.post(
        "/api/v1/bookings",
        headers=headers,
        json={
            "trip_id": str(world.scenario.trip_id),
            "passengers": [
                {"seat_id": str(world.scenario.seat_ids[seat]), "full_name": "Akua Mensah"}
            ],
            "origin_stop_id": world.stop(LEGON),
            "destination_stop_id": world.stop(CIRCLE),
        },
    )
    assert response.status_code == 201, response.text
    return response.json()


async def _confirm(booking_id: str) -> None:
    async with get_session_factory()() as session:
        await BookingService(session).confirm_booking(uuid.UUID(booking_id))
        await session.commit()


class TestTripSearchAndDetails:  # G20, G21, G22
    async def test_search_results_carry_the_fare_and_live_fields(
        self, client: AsyncClient, world: World
    ) -> None:
        response = await client.get(
            "/api/v1/trips/search",
            params={
                "origin_stop_id": world.stop(LEGON),
                "destination_stop_id": world.stop(CIRCLE),
                "travel_date": world.departs.date().isoformat(),
                "sort": "cheapest",
                "vehicle_type": "minibus",
            },
        )

        assert response.status_code == 200, response.text
        [result] = response.json()["items"]
        assert result["fare"] == {
            "current": "4.00",
            "solo": "4.00",
            "minimum": "1.14",
            "platform_fee": "0.50",
            "total": "4.50",
            "currency": "GHS",
            "riders_count": 0,
            "seats": 1,
        }
        assert result["ride_minutes"] == 20
        assert result["has_passed_pickup"] is False
        assert result["vehicle_eta_to_pickup_minutes"] is None

    @pytest.mark.parametrize(
        "bad", [{"sort": "price"}, {"seats": "0"}, {"vehicle_type": "spaceship"}]
    )
    async def test_search_rejects_unknown_options(self, client: AsyncClient, bad: dict) -> None:
        response = await client.get(
            "/api/v1/trips/search", params={"travel_date": "2026-10-02", **bad}
        )

        assert response.status_code == 422

    async def test_fare_quote(self, client: AsyncClient, world: World) -> None:
        url = f"/api/v1/trips/{world.scenario.trip_id}/fare-quote"

        quote = await client.get(
            url,
            params={
                "origin_stop_id": world.stop(LEGON),
                "destination_stop_id": world.stop(CIRCLE),
                "seats": 2,
            },
        )
        backwards = await client.get(
            url,
            params={"origin_stop_id": world.stop(CIRCLE), "destination_stop_id": world.stop(LEGON)},
        )
        whole_route = await client.get(url)
        missing = await client.get(f"/api/v1/trips/{uuid.uuid4()}/fare-quote")

        assert quote.status_code == 200, quote.text
        assert quote.json()["total"] == "9.00"  # 2 x 4.00 + 2 x 0.50
        assert quote.json()["origin_stop_id"] == world.stop(LEGON)
        assert backwards.status_code == 422
        assert backwards.json()["error"]["code"] == "STOP_NOT_ON_ROUTE"
        assert whole_route.json()["solo"] == "8.00"
        assert missing.status_code == 404

    async def test_trip_details(self, client: AsyncClient, world: World) -> None:
        response = await client.get(f"/api/v1/trips/{world.scenario.trip_id}")

        assert response.status_code == 200, response.text
        trip = response.json()
        assert trip["route_name"] == world.scenario.route_name
        assert trip["origin_stop_name"] == world.scenario.stop_names[MADINA]
        assert trip["destination_stop_name"] == world.scenario.stop_names[CIRCLE]
        assert trip["vehicle"]["registration_number"] == world.scenario.registration_number
        assert trip["vehicle"]["type"] == "minibus"
        assert trip["driver"]["id"] == str(world.scenario.driver_id)
        assert trip["driver"]["full_name"] == "Yaw Darko"
        assert trip["driver"]["rating_count"] == 0
        assert (trip["seats_total"], trip["riders_count"], trip["available_seats"]) == (4, 0, 4)


class TestSos:  # G19
    async def test_sos_from_home(self, client: AsyncClient, seed_identity_data: None) -> None:
        headers = await _passenger(client)

        raised = await client.post(
            "/api/v1/sos", headers=headers, json={"latitude": 5.6037, "longitude": -0.187}
        )

        assert raised.status_code == 201, raised.text
        assert raised.json()["trip_id"] is None
        fetched = await client.get(f"/api/v1/sos/{raised.json()['id']}", headers=headers)
        assert fetched.status_code == 200


class TestNotifications:  # G27
    async def test_unread_count_and_read_all(
        self, client: AsyncClient, seed_identity_data: None
    ) -> None:
        headers = await _passenger(client)
        user_id = uuid.UUID((await client.get("/api/v1/users/me", headers=headers)).json()["id"])
        async with get_session_factory()() as session:
            for title in ("Booked", "Paid"):
                await NotificationService(session).notify(
                    user_id, category=NotificationCategory.TRANSACTIONAL, title=title, body=title
                )
            await session.commit()

        before = await client.get("/api/v1/notifications/unread-count", headers=headers)
        cleared = await client.post("/api/v1/notifications/read-all", headers=headers)
        after = await client.get("/api/v1/notifications/unread-count", headers=headers)

        assert before.json() == {"unread_count": 2}
        assert cleared.json() == {"marked_read": 2}
        assert after.json() == {"unread_count": 0}


class TestPaymentMethods:  # G28
    async def test_save_rename_switch_default_delete(
        self, client: AsyncClient, seed_identity_data: None
    ) -> None:
        headers = await _passenger(client)
        url = "/api/v1/users/me/payment-methods"

        mtn = await client.post(
            url, headers=headers, json={"channel": "mtn_momo", "phone_number": "0241234567"}
        )
        telecel = await client.post(
            url,
            headers=headers,
            json={"channel": "telecel_cash", "phone_number": "0201234567", "is_default": True},
        )
        renamed = await client.patch(
            f"{url}/{mtn.json()['id']}", headers=headers, json={"label": "Work phone"}
        )
        listed = await client.get(url, headers=headers)
        deleted = await client.delete(f"{url}/{telecel.json()['id']}", headers=headers)
        after = await client.get(url, headers=headers)

        assert mtn.status_code == 201, mtn.text
        assert mtn.json()["masked_number"] == "+23324•••4567"
        assert "phone_number" not in mtn.json()
        assert renamed.json()["label"] == "Work phone"
        assert [m["is_default"] for m in listed.json()] == [True, False]
        assert listed.json()[0]["channel"] == "telecel_cash"
        assert deleted.status_code == 204
        assert [(m["id"], m["is_default"]) for m in after.json()] == [(mtn.json()["id"], True)]

    async def test_cards_cannot_be_saved(
        self, client: AsyncClient, seed_identity_data: None
    ) -> None:
        headers = await _passenger(client)

        response = await client.post(
            "/api/v1/users/me/payment-methods",
            headers=headers,
            json={"channel": "card", "phone_number": "0241234567"},
        )

        assert response.status_code == 422

    async def test_pay_with_a_saved_method(self, client: AsyncClient, world: World) -> None:
        headers = await _passenger(client)
        booking = await _book(client, headers, world)
        method = await client.post(
            "/api/v1/users/me/payment-methods",
            headers=headers,
            json={"channel": "mtn_momo", "phone_number": "0241234567"},
        )
        pay = f"/api/v1/bookings/{booking['id']}/pay"

        both = await client.post(
            pay,
            headers=headers,
            json={"payment_method_id": method.json()["id"], "channel": "mtn_momo"},
        )
        neither = await client.post(pay, headers=headers, json={})
        strangers = await client.post(
            pay, headers=headers, json={"payment_method_id": str(uuid.uuid4())}
        )
        paid = await client.post(
            pay, headers=headers, json={"payment_method_id": method.json()["id"]}
        )

        assert both.status_code == 422
        assert neither.status_code == 422
        assert strangers.status_code == 404
        assert paid.status_code == 201, paid.text
        assert paid.json()["channel"] == "mtn_momo"


class TestBookingSummary:  # G25
    async def test_month_parameter(self, client: AsyncClient, seed_identity_data: None) -> None:
        headers = await _passenger(client)

        default = await client.get("/api/v1/bookings/summary", headers=headers)
        february = await client.get(
            "/api/v1/bookings/summary", headers=headers, params={"month": "2026-02"}
        )
        nonsense = await client.get(
            "/api/v1/bookings/summary", headers=headers, params={"month": "2026-13"}
        )

        assert default.status_code == 200, default.text
        assert default.json()["month"] == f"{datetime.now(UTC):%Y-%m}"
        assert february.json() == {
            "month": "2026-02",
            "currency": "GHS",
            "trips_count": 0,
            "total_spent": "0.00",
            "average_fare": "0.00",
            "total_saved": "0.00",
        }
        assert nonsense.status_code == 422


class TestShareLinks:  # G24
    async def test_share_open_and_view_the_page(self, client: AsyncClient, world: World) -> None:
        headers = await _passenger(client)
        booking = await _book(client, headers, world)
        await _confirm(booking["id"])

        shared = await client.post(f"/api/v1/bookings/{booking['id']}/share", headers=headers)
        assert shared.status_code == 201, shared.text
        token = shared.json()["token"]
        data = await client.get(f"/api/v1/shared-trips/{token}")
        page = await client.get(f"/share/{token}")
        bogus = await client.get(f"/api/v1/shared-trips/{'A' * 54}")

        assert shared.json()["url"] == f"http://testserver/share/{token}"
        assert data.status_code == 200, data.text
        assert data.json()["passenger_first_name"] == "Akua"
        assert data.json()["driver_first_name"] == "Yaw"
        assert data.json()["boarding_stop_name"] == world.scenario.stop_names[LEGON]
        assert "phone" not in data.text
        assert page.status_code == 200
        assert page.headers["content-type"].startswith("text/html")
        assert token in page.text
        assert "/api/v1/shared-trips/" in page.text
        assert bogus.status_code == 404

    async def test_an_unpaid_booking_cannot_be_shared(
        self, client: AsyncClient, world: World
    ) -> None:
        headers = await _passenger(client)
        booking = await _book(client, headers, world)

        response = await client.post(f"/api/v1/bookings/{booking['id']}/share", headers=headers)

        assert response.status_code == 409
        assert response.json()["error"]["code"] == "BOOKING_NOT_SHAREABLE"


class TestDriverApp:  # G29, G30, G31, G32
    async def test_profile_rating_assignments_and_payments(
        self, client: AsyncClient, world: World
    ) -> None:
        async with get_session_factory()() as session:
            await fleet_service(session).assign_driver(
                world.scenario.owner_user_id, world.scenario.vehicle_id, world.scenario.driver_id
            )
            await session.commit()
        driver = await _login(client, world.driver_phone)
        passenger = await _passenger(client)
        booking = await _book(client, passenger, world)
        await _confirm(booking["id"])

        me = await client.get("/api/v1/drivers/me", headers=driver)
        rating = await client.get("/api/v1/drivers/me/rating-summary", headers=driver)
        assignments = await client.get("/api/v1/drivers/me/assignments", headers=driver)
        payments = await client.get(
            f"/api/v1/driver-trips/{world.scenario.trip_id}/payments", headers=driver
        )
        not_a_driver = await client.get(
            f"/api/v1/driver-trips/{world.scenario.trip_id}/payments", headers=passenger
        )

        assert me.json()["full_name"] == "Yaw Darko"
        assert me.json()["phone_number"] == "+233" + world.driver_phone[1:]
        assert rating.json()["rating_count"] == 0
        assert rating.json()["driver_id"] == str(world.scenario.driver_id)
        [assignment] = assignments.json()
        assert assignment["vehicle"]["registration_number"] == world.scenario.registration_number
        assert assignment["vehicle"]["status"] == "approved"
        assert payments.status_code == 200, payments.text
        # Confirmed without a payment record: nothing collected yet.
        assert payments.json()["total_collected"] == "0.00"
        assert payments.json()["fare_per_seat"] == "8.00"
        assert not_a_driver.status_code == 403

    async def test_incident_without_severity_then_a_photo(
        self, client: AsyncClient, world: World
    ) -> None:
        driver = await _login(client, world.driver_phone)

        reported = await client.post(
            f"/api/v1/trips/{world.scenario.trip_id}/incidents",
            headers=driver,
            json={"incident_type": "road_hazard", "description": "Flooding near Legon"},
        )
        incident_id = reported.json()["id"]
        photo = await client.post(
            f"/api/v1/incidents/{incident_id}/photo",
            headers=driver,
            files={"file": ("scene.png", PNG, "image/png")},
        )
        not_an_image = await client.post(
            f"/api/v1/incidents/{incident_id}/photo",
            headers=driver,
            files={"file": ("notes.txt", b"hello", "text/plain")},
        )

        assert reported.status_code == 201, reported.text
        assert reported.json()["severity"] == "medium"
        assert reported.json()["photo_url"] is None
        assert photo.status_code == 200, photo.text
        assert photo.json()["photo_url"]
        assert not_an_image.status_code == 422


async def test_every_new_endpoint_is_in_the_openapi_document(app_instance) -> None:
    paths = app_instance.openapi()["paths"]
    expected = {
        ("get", "/api/v1/trips/{trip_id}/fare-quote"),
        ("post", "/api/v1/sos"),
        ("post", "/api/v1/bookings/{booking_id}/share"),
        ("get", "/api/v1/shared-trips/{token}"),
        ("get", "/api/v1/bookings/summary"),
        ("get", "/api/v1/notifications/unread-count"),
        ("post", "/api/v1/notifications/read-all"),
        ("get", "/api/v1/users/me/payment-methods"),
        ("post", "/api/v1/users/me/payment-methods"),
        ("patch", "/api/v1/users/me/payment-methods/{method_id}"),
        ("delete", "/api/v1/users/me/payment-methods/{method_id}"),
        ("get", "/api/v1/drivers/me/rating-summary"),
        ("get", "/api/v1/driver-trips/{trip_id}/payments"),
        ("post", "/api/v1/incidents/{incident_id}/photo"),
    }
    missing = {(method, path) for method, path in expected if method not in paths.get(path, {})}
    assert missing == set()
    search = {p["name"] for p in paths["/api/v1/trips/search"]["get"]["parameters"]}
    assert {"sort", "vehicle_type", "seats"} <= search
    assert "/share/{token}" not in paths  # a page, not part of the API
