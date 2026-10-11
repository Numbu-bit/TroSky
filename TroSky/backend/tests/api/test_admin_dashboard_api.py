"""HTTP checks for the admin dashboard requests: the directory, overview
periods, CSV export, and cancelling a trip with its bookings."""

from __future__ import annotations

import secrets
import uuid
from datetime import UTC, datetime, timedelta
from decimal import Decimal

import pytest
from httpx import AsyncClient
from sqlalchemy import select

from app.core.database import get_session_factory
from app.core.permissions import SystemRole
from app.core.security import hash_password
from app.models.analytics import SearchEvent
from app.models.identity import Role, User, UserProfile, UserRole
from app.models.payments import WalletReferenceType
from app.providers.payments.base import PaymentChannel
from app.services.payment_service import PaymentService
from app.services.wallet_service import WalletService
from tests.integration.scenarios import TripScenario, book, build_trip_scenario

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]

PASSWORD = "Str0ngPass"


def _phone() -> str:
    return f"+23324{secrets.randbelow(10**7):07d}"


async def _committed_user(role: SystemRole) -> str:
    """A committed account holding ``role``; returns its phone number."""
    async with get_session_factory()() as session:
        user = User(phone_number=_phone(), password_hash=hash_password(PASSWORD))
        user.profile = UserProfile(full_name="Adwoa Admin", preferred_language="en")
        session.add(user)
        await session.flush()
        role_id = await session.scalar(select(Role.id).where(Role.slug == role.value))
        session.add(UserRole(user_id=user.id, role_id=role_id))
        await session.commit()
        return user.phone_number


async def _login(client: AsyncClient, phone: str) -> dict[str, str]:
    response = await client.post(
        "/api/v1/auth/login", json={"identifier": phone, "password": PASSWORD}
    )
    assert response.status_code == 200, response.text
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


@pytest.fixture
async def admin(client: AsyncClient, seed_identity_data: None, require_redis: None):
    return await _login(client, await _committed_user(SystemRole.ADMIN))


@pytest.fixture
async def passenger(client: AsyncClient, seed_identity_data: None, require_redis: None):
    return await _login(client, await _committed_user(SystemRole.PASSENGER))


async def _committed_trip_with_paid_and_unpaid_seats() -> TripScenario:
    async with get_session_factory()() as session:

        async def make_user(**_: object) -> User:
            user = User(phone_number=_phone(), password_hash="not-a-real-hash")
            user.profile = UserProfile(full_name="Test User", preferred_language="en")
            session.add(user)
            await session.flush()
            return user

        scenario = await build_trip_scenario(
            session, make_user, departure=datetime.now(UTC) + timedelta(hours=4)
        )
        payer = await make_user()
        paid = await book(session, payer.id, scenario, seat=0, confirm=False)
        await WalletService(session).credit(
            payer.id,
            amount=Decimal("20.00"),
            reference_type=WalletReferenceType.WALLET_TOPUP,
            reference_id=None,
            description="Test top-up",
        )
        await PaymentService(session).pay_for_booking(
            payer.id, paid.id, channel=PaymentChannel.WALLET, payer_phone=None, idempotency_key=None
        )
        await book(session, (await make_user()).id, scenario, seat=1, confirm=False)
        await session.commit()
        return scenario


class TestPermissionsAndRouting:
    @pytest.mark.parametrize(
        "path", ["/api/v1/admin/vehicles", "/api/v1/admin/drivers", "/api/v1/admin/fleets"]
    )
    async def test_passengers_are_refused(
        self, client: AsyncClient, passenger: dict[str, str], path: str
    ) -> None:
        assert (await client.get(path, headers=passenger)).status_code == 403

    async def test_pending_lists_still_reach_their_own_routes(
        self, client: AsyncClient, admin: dict[str, str]
    ) -> None:
        for path in ("/api/v1/admin/drivers/pending", "/api/v1/admin/vehicles/pending"):
            response = await client.get(path, headers=admin)
            assert response.status_code == 200, (path, response.text)

    async def test_unknown_ids_sorts_and_statuses(
        self, client: AsyncClient, admin: dict[str, str]
    ) -> None:
        missing = await client.get(f"/api/v1/admin/vehicles/{uuid.uuid4()}", headers=admin)
        bad_sort = await client.get(
            "/api/v1/admin/drivers", headers=admin, params={"sort": "-salary"}
        )
        bad_status = await client.get(
            "/api/v1/admin/vehicles", headers=admin, params={"live_status": "flying"}
        )

        assert missing.status_code == 404
        assert bad_sort.status_code == 422
        assert bad_status.status_code == 422


class TestCsvExport:
    @pytest.mark.parametrize(
        "path",
        [
            "/api/v1/admin/vehicles",
            "/api/v1/admin/drivers",
            "/api/v1/admin/fleets",
            "/api/v1/admin/trips",
            "/api/v1/admin/bookings",
            "/api/v1/admin/complaints",
            "/api/v1/admin/incidents",
            "/api/v1/admin/withdrawals",
        ],
    )
    async def test_every_list_exports(
        self, client: AsyncClient, admin: dict[str, str], path: str
    ) -> None:
        response = await client.get(path, headers=admin, params={"format": "csv"})

        assert response.status_code == 200, response.text
        assert response.headers["content-type"].startswith("text/csv")
        assert "attachment" in response.headers["content-disposition"]


class TestOverview:
    async def test_period_and_city(self, client: AsyncClient, admin: dict[str, str]) -> None:
        default = await client.get("/api/v1/admin/reports/overview", headers=admin)
        accra = await client.get(
            "/api/v1/admin/reports/overview",
            headers=admin,
            params={"from": "2026-09-01", "to": "2026-09-07", "city": "Accra"},
        )
        backwards = await client.get(
            "/api/v1/admin/reports/overview",
            headers=admin,
            params={"from": "2026-09-07", "to": "2026-09-01"},
        )

        assert default.status_code == 200, default.text
        body = default.json()
        assert body["period"]["days"] == 30
        assert len(body["figures"]["paid_bookings"]["series"]) == 30
        assert "total_users" in body  # the all-time figures are still there
        assert accra.json()["period"]["previous_to_date"] == "2026-08-31"
        assert accra.json()["figures"]["new_users"] is None
        assert accra.json()["figures"]["booking_payments"]["value"] == "0.00"
        assert backwards.status_code == 422


class TestCancellingATrip:
    async def test_the_response_counts_cancelled_bookings_and_refunds(
        self, client: AsyncClient, admin: dict[str, str]
    ) -> None:
        scenario = await _committed_trip_with_paid_and_unpaid_seats()

        response = await client.post(
            f"/api/v1/admin/trips/{scenario.trip_id}/cancel",
            headers=admin,
            json={"reason": "Road closed"},
        )
        refunds = await client.get(
            "/api/v1/admin/refund-requests", headers=admin, params={"limit": 100}
        )

        assert response.status_code == 200, response.text
        body = response.json()
        assert body["status"] == "cancelled"
        assert (body["bookings_cancelled"], body["refunds_queued"]) == (2, 1)
        assert body["refund_amount"] == "8.50"
        assert refunds.status_code == 200


class TestReports:
    @pytest.mark.parametrize(
        "path",
        [
            "/api/v1/admin/payments",
            "/api/v1/admin/analytics/revenue",
            "/api/v1/admin/analytics/users",
            "/api/v1/admin/analytics/funnel",
            "/api/v1/admin/drivers/performance",
        ],
    )
    async def test_admin_only(
        self, client: AsyncClient, passenger: dict[str, str], path: str
    ) -> None:
        assert (await client.get(path, headers=passenger)).status_code == 403

    async def test_every_report_answers(self, client: AsyncClient, admin: dict[str, str]) -> None:
        revenue = await client.get("/api/v1/admin/analytics/revenue", headers=admin)
        users = await client.get("/api/v1/admin/analytics/users", headers=admin)
        funnel = await client.get(
            "/api/v1/admin/analytics/funnel", headers=admin, params={"city": "Accra"}
        )
        performance = await client.get(
            "/api/v1/admin/drivers/performance", headers=admin, params={"sort": "-score"}
        )

        assert revenue.status_code == 200, revenue.text
        assert set(revenue.json()) >= {"gross", "refunds", "net", "by_method", "by_hour"}
        assert users.status_code == 200, users.text
        assert len(users.json()["daily_active"]) == 30
        assert [s["stage"] for s in funnel.json()["stages"]] == [
            "searches",
            "reserved",
            "paid",
            "boarded",
        ]
        # /drivers/performance is not mistaken for /drivers/{driver_id}.
        assert performance.status_code == 200, performance.text

    async def test_payments_and_performance_export(
        self, client: AsyncClient, admin: dict[str, str]
    ) -> None:
        for path in ("/api/v1/admin/payments", "/api/v1/admin/drivers/performance"):
            response = await client.get(path, headers=admin, params={"format": "csv"})
            assert response.headers["content-type"].startswith("text/csv"), path

    async def test_unknown_driver_performance_is_404(
        self, client: AsyncClient, admin: dict[str, str]
    ) -> None:
        response = await client.get(
            f"/api/v1/admin/drivers/{uuid.uuid4()}/performance", headers=admin
        )

        assert response.status_code == 404


class TestSearchLogging:
    async def test_a_search_far_from_any_stop_is_kept_though_it_fails(
        self, client: AsyncClient, seed_identity_data: None, require_redis: None
    ) -> None:
        # Somewhere in the South Atlantic, different every run, so a row left
        # by an earlier run cannot stand in for this one.
        latitude = -30 + secrets.randbelow(100_000) / 10_000
        longitude = -20 + secrets.randbelow(100_000) / 10_000
        response = await client.get(
            "/api/v1/trips/search",
            params={
                "pickup_latitude": latitude,
                "pickup_longitude": longitude,
                "travel_date": "2026-10-03",
            },
        )

        assert response.status_code == 422
        cell = Decimal("0.005")
        async with get_session_factory()() as session:
            event = await session.scalar(
                select(SearchEvent).where(
                    SearchEvent.cell_latitude
                    == ((Decimal(str(latitude)) / cell).to_integral_value() * cell),
                    SearchEvent.cell_longitude
                    == ((Decimal(str(longitude)) / cell).to_integral_value() * cell),
                )
            )
        assert event is not None
        assert event.outcome == "no_pickup_nearby"
        assert event.results_count == 0
