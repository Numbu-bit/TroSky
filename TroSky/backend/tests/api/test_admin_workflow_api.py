"""HTTP checks for the admin dashboard's step 4: the complaint workflow,
SOS details and escalations, the alerts feed, search and trip replay -- and
who may use them. (The live stream itself is in test_admin_stream_api.)"""

from __future__ import annotations

import uuid
from datetime import UTC, datetime, timedelta

import pytest
from httpx import AsyncClient
from sqlalchemy import select

from app.core.database import get_session_factory
from app.core.permissions import SystemRole
from app.models.bookings import Booking
from app.models.payments import Payment
from app.models.tracking import TripLocation
from app.utilities.geo import latlng_to_wkt
from tests.api.test_admin_dashboard_api import (
    _committed_trip_with_paid_and_unpaid_seats,
    _committed_user,
    _login,
)

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]


@pytest.fixture
async def admin(client: AsyncClient, seed_identity_data: None, require_redis: None):
    return await _login(client, await _committed_user(SystemRole.ADMIN))


@pytest.fixture
async def passenger(client: AsyncClient, seed_identity_data: None, require_redis: None):
    return await _login(client, await _committed_user(SystemRole.PASSENGER))


async def _me(client: AsyncClient, headers: dict[str, str]) -> dict[str, str]:
    return (await client.get("/api/v1/users/me", headers=headers)).json()


async def _file(client: AsyncClient, passenger: dict[str, str], **fields: str) -> str:
    response = await client.post(
        "/api/v1/complaints",
        headers=passenger,
        json={
            "category": "driver_conduct",
            "subject": "Rude driver",
            "description": "He shouted at an old woman getting on at Legon.",
            **fields,
        },
    )
    assert response.status_code == 201, response.text
    return str(response.json()["id"])


class TestComplaintWorkflow:
    async def test_from_filing_to_a_decision(
        self, client: AsyncClient, admin: dict[str, str], passenger: dict[str, str]
    ) -> None:
        complaint_id = await _file(client, passenger)
        me = (await _me(client, admin))["id"]
        url = f"/api/v1/admin/complaints/{complaint_id}"

        queue = await client.get(
            "/api/v1/admin/complaints",
            headers=admin,
            params={"complaint_status": "open", "unassigned": "true", "sort": "-created_at"},
        )
        taken = await client.patch(
            url,
            headers=admin,
            json={"assigned_to": me, "status": "in_review", "priority": "high", "reason": "Mine"},
        )
        await client.post(
            f"{url}/notes",
            headers=admin,
            json={"kind": "internal", "body": "Two earlier complaints about him."},
        )
        await client.post(
            f"{url}/notes",
            headers=admin,
            json={"kind": "message", "body": "We have spoken to the driver."},
        )
        detail = await client.get(url, headers=admin)
        passenger_sees = await client.get(
            f"/api/v1/complaints/{complaint_id}/messages", headers=passenger
        )
        resolved = await client.post(f"{url}/resolve", headers=admin, json={"notes": "Warned."})
        too_late = await client.patch(url, headers=admin, json={"priority": "low"})
        audit = await client.get(
            "/api/v1/admin/audit-logs",
            headers=admin,
            params={"entity_type": "complaints", "entity_id": complaint_id},
        )

        assert complaint_id in [c["id"] for c in queue.json()["items"]]
        assert taken.status_code == 200, taken.text
        body = taken.json()
        assert (body["assigned_to"], body["assignee_name"]) == (me, "Adwoa Admin")
        assert (body["status"], body["priority"], body["is_overdue"]) == (
            "in_review",
            "high",
            False,
        )
        assert body["first_response_at"] is not None
        notes = detail.json()["notes"]
        assert [(n["kind"], n["author_name"]) for n in notes] == [
            ("internal", "Adwoa Admin"),
            ("message", "Adwoa Admin"),
        ]
        assert [m["body"] for m in passenger_sees.json()] == ["We have spoken to the driver."]
        assert resolved.json()["status"] == "resolved"
        assert too_late.status_code == 409
        recorded = {entry["action"] for entry in audit.json()["items"]}
        assert {"update_complaint", "resolve_complaint"} <= recorded

    async def test_the_figures(self, client: AsyncClient, admin: dict[str, str]) -> None:
        today = datetime.now(UTC).date()

        response = await client.get(
            "/api/v1/admin/complaints/stats",
            headers=admin,
            params={"from": str(today - timedelta(days=6)), "to": str(today)},
        )

        assert response.status_code == 200, response.text
        body = response.json()
        assert body["period"]["days"] == 7
        assert {p["priority"]: p["resolution_hours"] for p in body["by_priority"]} == {
            "low": 72,
            "medium": 48,
            "high": 24,
            "urgent": 4,
        }
        assert body["open"] == sum(p["open"] for p in body["by_priority"])
        assert len(body["filed"]["series"]) == 7
        assert {c["category"] for c in body["by_category"]} >= {"driver_conduct", "safety"}

    async def test_mistakes_are_refused(
        self, client: AsyncClient, admin: dict[str, str], passenger: dict[str, str]
    ) -> None:
        complaint_id = await _file(client, passenger)
        passenger_id = (await _me(client, passenger))["id"]
        missing = f"/api/v1/admin/complaints/{uuid.uuid4()}"

        to_a_passenger = await client.patch(
            f"/api/v1/admin/complaints/{complaint_id}",
            headers=admin,
            json={"assigned_to": passenger_id},
        )
        unknown_priority = await client.get(
            "/api/v1/admin/complaints", headers=admin, params={"priority": "extreme"}
        )
        unknown_sort = await client.get(
            "/api/v1/admin/complaints", headers=admin, params={"sort": "subject"}
        )
        empty_note = await client.post(
            f"/api/v1/admin/complaints/{complaint_id}/notes",
            headers=admin,
            json={"kind": "message", "body": ""},
        )

        assert to_a_passenger.status_code == 422
        assert unknown_priority.status_code == 422
        assert unknown_sort.status_code == 422
        assert empty_note.status_code == 422
        assert (await client.get(missing, headers=admin)).status_code == 404
        assert (
            await client.post(
                f"{missing}/notes", headers=admin, json={"kind": "internal", "body": "x"}
            )
        ).status_code == 404

    async def test_someone_else_cannot_read_the_messages(
        self, client: AsyncClient, passenger: dict[str, str]
    ) -> None:
        complaint_id = await _file(client, passenger)
        stranger = await _login(client, await _committed_user(SystemRole.PASSENGER))

        response = await client.get(f"/api/v1/complaints/{complaint_id}/messages", headers=stranger)

        assert response.status_code == 404


class TestSos:
    async def test_from_the_alert_to_calling_the_police(
        self, client: AsyncClient, admin: dict[str, str], passenger: dict[str, str]
    ) -> None:
        raised = await client.post(
            "/api/v1/sos", headers=passenger, json={"latitude": 5.65, "longitude": -0.18}
        )
        alert_id = raised.json()["id"]
        url = f"/api/v1/admin/sos-alerts/{alert_id}"

        feed_before = await client.get("/api/v1/admin/alerts", headers=admin, params={"limit": 500})
        detail = await client.get(url, headers=admin)
        escalated = await client.post(
            f"{url}/escalations",
            headers=admin,
            json={"contact_type": "police", "contact_name": "Legon Police", "phone_number": "191"},
        )
        after = await client.get(url, headers=admin)
        feed_after = await client.get("/api/v1/admin/alerts", headers=admin, params={"limit": 500})

        def active(feed: dict[str, list[dict[str, str]]]) -> set[str]:
            return {item["entity_id"] for item in feed["items"] if item["type"] == "sos_active"}

        assert raised.status_code == 201, raised.text
        assert alert_id in active(feed_before.json())
        body = detail.json()
        assert (body["latitude"], body["longitude"]) == (5.65, -0.18)
        assert body["trip"] is None
        assert body["triggered_by_phone"] == (await _me(client, passenger))["phone_number"]
        assert escalated.status_code == 201, escalated.text
        picked_up = after.json()
        assert picked_up["status"] == "acknowledged"
        assert [(e["contact_type"], e["logged_by_name"]) for e in picked_up["escalations"]] == [
            ("police", "Adwoa Admin")
        ]
        assert alert_id not in active(feed_after.json())

    async def test_an_unknown_alert(self, client: AsyncClient, admin: dict[str, str]) -> None:
        url = f"/api/v1/admin/sos-alerts/{uuid.uuid4()}"

        assert (await client.get(url, headers=admin)).status_code == 404
        assert (
            await client.post(f"{url}/escalations", headers=admin, json={"contact_type": "police"})
        ).status_code == 404


class TestSearchAndReplay:
    async def test_search(self, client: AsyncClient, admin: dict[str, str]) -> None:
        scenario = await _committed_trip_with_paid_and_unpaid_seats()
        async with get_session_factory()() as session:
            # The scenario's one paid booking, and its payment.
            payment = await session.scalar(
                select(Payment)
                .join(Booking, Booking.id == Payment.booking_id)
                .where(Booking.trip_id == scenario.trip_id)
            )
            assert payment is not None
            booking = await session.get(Booking, payment.booking_id)
            assert booking is not None

        by_reference = await client.get(
            "/api/v1/admin/search", headers=admin, params={"q": booking.booking_reference}
        )
        by_plate = await client.get(
            "/api/v1/admin/search",
            headers=admin,
            params={"q": scenario.registration_number.lower()},
        )

        assert by_reference.status_code == 200, by_reference.text
        assert set(by_reference.json()["searched"]) == {
            "users",
            "drivers",
            "vehicles",
            "trips",
            "bookings",
            "payments",
        }
        assert str(booking.id) in {hit["id"] for hit in by_reference.json()["bookings"]}
        assert [hit["id"] for hit in by_plate.json()["vehicles"]] == [str(scenario.vehicle_id)]
        by_payment = await client.get(
            "/api/v1/admin/search", headers=admin, params={"q": payment.internal_reference}
        )
        assert str(payment.id) in {hit["id"] for hit in by_payment.json()["payments"]}
        too_short = await client.get("/api/v1/admin/search", headers=admin, params={"q": "a"})
        assert too_short.status_code == 422

    async def test_trip_replay(self, client: AsyncClient, admin: dict[str, str]) -> None:
        scenario = await _committed_trip_with_paid_and_unpaid_seats()
        start = datetime.now(UTC) - timedelta(minutes=5)
        async with get_session_factory()() as session:
            for minute, latitude in enumerate((5.60, 5.61)):
                session.add(
                    TripLocation(
                        trip_id=scenario.trip_id,
                        location=latlng_to_wkt(latitude, -1.0),
                        recorded_at=start + timedelta(minutes=minute),
                    )
                )
            await session.commit()
        url = f"/api/v1/admin/trips/{scenario.trip_id}/track"

        track = await client.get(url, headers=admin)
        exported = await client.get(url, headers=admin, params={"format": "csv"})
        missing = await client.get(f"/api/v1/admin/trips/{uuid.uuid4()}/track", headers=admin)

        assert track.status_code == 200, track.text
        body = track.json()
        assert (body["point_count"], body["truncated"]) == (2, False)
        assert [round(p["latitude"], 2) for p in body["points"]] == [5.60, 5.61]
        assert exported.headers["content-type"].startswith("text/csv")
        assert exported.text.splitlines()[0].startswith("latitude,longitude")
        assert missing.status_code == 404


class TestWhoMayUseThem:
    @pytest.mark.parametrize(
        "path",
        [
            "/api/v1/admin/alerts",
            "/api/v1/admin/search?q=ama",
            "/api/v1/admin/complaints",
            "/api/v1/admin/complaints/stats",
            f"/api/v1/admin/sos-alerts/{uuid.uuid4()}",
            f"/api/v1/admin/trips/{uuid.uuid4()}/track",
            "/api/v1/admin/stream",
        ],
    )
    async def test_passengers_are_refused(
        self, client: AsyncClient, passenger: dict[str, str], path: str
    ) -> None:
        assert (await client.get(path, headers=passenger)).status_code == 403

    async def test_the_stream_needs_a_token(self, client: AsyncClient) -> None:
        assert (await client.get("/api/v1/admin/stream")).status_code == 401

    async def test_the_stream_knows_its_topics(
        self, client: AsyncClient, admin: dict[str, str]
    ) -> None:
        response = await client.get(
            "/api/v1/admin/stream", headers=admin, params={"topics": "gossip"}
        )

        assert response.status_code == 422


# What "TroSky Admin: Missing Backend Endpoints" asked for, by section, as
# all of them.
_ASKED_FOR = {
    # 1. Features behind existing but unused permissions
    ("get", "/api/v1/admin/audit-logs"),
    ("get", "/api/v1/admin/audit-logs/{entry_id}"),
    ("get", "/api/v1/admin/settings"),
    ("patch", "/api/v1/admin/settings"),
    ("get", "/api/v1/admin/feature-flags"),
    ("patch", "/api/v1/admin/feature-flags/{key}"),
    ("get", "/api/v1/admin/wallets/{user_id}"),
    ("post", "/api/v1/admin/wallets/{user_id}/adjustments"),
    # 2. Active buses, fleet and drivers
    ("get", "/api/v1/admin/vehicles"),
    ("get", "/api/v1/admin/vehicles/{vehicle_id}"),
    ("get", "/api/v1/admin/drivers"),
    ("get", "/api/v1/admin/drivers/{driver_id}"),
    ("get", "/api/v1/admin/fleets"),
    ("get", "/api/v1/admin/fleets/{fleet_id}"),
    # 3. Driver performance
    ("get", "/api/v1/admin/drivers/performance"),
    ("get", "/api/v1/admin/drivers/{driver_id}/performance"),
    # 4. Complaints monitoring and workflow
    ("get", "/api/v1/admin/complaints/stats"),
    ("patch", "/api/v1/admin/complaints/{complaint_id}"),
    ("post", "/api/v1/admin/complaints/{complaint_id}/notes"),
    # 5. Revenue
    ("get", "/api/v1/admin/payments"),
    ("get", "/api/v1/admin/analytics/revenue"),
    # 6. User growth
    ("get", "/api/v1/admin/analytics/users"),
    ("get", "/api/v1/admin/analytics/funnel"),
    # 7. Fraud detection
    ("get", "/api/v1/admin/fraud/flags"),
    ("get", "/api/v1/admin/fraud/flags/{flag_id}"),
    ("patch", "/api/v1/admin/fraud/flags/{flag_id}"),
    ("post", "/api/v1/admin/fraud/flags/{flag_id}/actions"),
    ("get", "/api/v1/admin/fraud/stats"),
    ("get", "/api/v1/admin/fraud/rules"),
    ("patch", "/api/v1/admin/fraud/rules/{rule}"),
    # 8. Demand heat maps
    ("get", "/api/v1/admin/analytics/demand"),
    # 9. Reports
    ("get", "/api/v1/admin/reports/{report}"),
    # 10. Alerts, search, live updates and history
    ("get", "/api/v1/admin/alerts"),
    ("get", "/api/v1/admin/stream"),
    ("get", "/api/v1/admin/search"),
    ("get", "/api/v1/admin/trips/{trip_id}/track"),
    ("post", "/api/v1/admin/sos-alerts/{alert_id}/escalations"),
    # 11. Approvals, accounts and admin team
    ("post", "/api/v1/admin/drivers/{driver_id}/request-info"),
    ("post", "/api/v1/admin/vehicles/{vehicle_id}/request-info"),
    ("get", "/api/v1/admin/documents/{document_id}"),
    ("get", "/api/v1/admin/users"),
    ("get", "/api/v1/admin/users/{user_id}"),
    ("get", "/api/v1/admin/users/{user_id}/sessions"),
    ("delete", "/api/v1/admin/users/{user_id}/sessions/{session_id}"),
    ("get", "/api/v1/admin/admins"),
    ("post", "/api/v1/admin/admins"),
    ("patch", "/api/v1/admin/admins/{admin_id}"),
    ("get", "/api/v1/admin/me/sessions"),
    ("delete", "/api/v1/admin/me/sessions/{session_id}"),
}


async def test_every_endpoint_asked_for_is_documented(app_instance) -> None:
    paths = app_instance.openapi()["paths"]

    missing = {(method, path) for method, path in _ASKED_FOR if method not in paths.get(path, {})}

    assert len(_ASKED_FOR) == 49  # the document's count
    assert missing == set()
    assert (
        "text/event-stream" in paths["/api/v1/admin/stream"]["get"]["responses"]["200"]["content"]
    )
