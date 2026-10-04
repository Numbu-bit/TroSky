"""HTTP checks for platform administration (section 1 of the admin
requests): the audit trail, settings, feature flags and wallet adjustments.

Settings and flags are shared, committed state: every test that changes
them puts them back.
"""

from __future__ import annotations

import uuid
from datetime import date, timedelta
from decimal import Decimal

import pytest
from httpx import AsyncClient
from sqlalchemy import func, select

from app.core.config import get_settings
from app.core.database import get_session_factory
from app.core.permissions import SystemRole
from app.models.admin import AuditLog
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


async def _me(client: AsyncClient, headers: dict[str, str]) -> str:
    return (await client.get("/api/v1/users/me", headers=headers)).json()["id"]


async def _audit_rows_by(actor_id: str) -> int:
    async with get_session_factory()() as session:
        return int(
            await session.scalar(
                select(func.count(AuditLog.id)).where(AuditLog.actor_user_id == uuid.UUID(actor_id))
            )
            or 0
        )


class TestAuditTrail:
    async def test_an_admin_action_is_recorded_with_before_and_after(
        self, client: AsyncClient, admin: dict[str, str], passenger: dict[str, str]
    ) -> None:
        target = await _me(client, passenger)

        suspended = await client.post(
            f"/api/v1/admin/users/{target}/suspend",
            headers=admin,
            json={"reason": "Abusive messages to drivers"},
        )
        log = await client.get(
            "/api/v1/admin/audit-logs",
            headers=admin,
            params={"entity_type": "users", "entity_id": target},
        )

        assert suspended.status_code == 200, suspended.text
        [entry] = log.json()["items"]
        assert entry["action"] == "suspend_user"
        assert entry["method"] == "POST"
        assert entry["path"] == "/api/v1/admin/users/{user_id}/suspend"
        assert entry["before"]["is_suspended"] is False
        assert entry["after"]["is_suspended"] is True
        assert entry["reason"] == "Abusive messages to drivers"
        assert entry["actor_user_id"] == await _me(client, admin)
        assert entry["actor_name"] == "Adwoa Admin"
        assert "password_hash" not in entry["before"]
        one = await client.get(f"/api/v1/admin/audit-logs/{entry['id']}", headers=admin)
        assert one.json() == entry
        day = date.fromisoformat(entry["created_at"][:10])
        that_day = await client.get(
            "/api/v1/admin/audit-logs",
            headers=admin,
            params={"entity_id": target, "from": str(day), "to": str(day)},
        )
        until_the_day_before = await client.get(
            "/api/v1/admin/audit-logs",
            headers=admin,
            params={"entity_id": target, "to": str(day - timedelta(days=1))},
        )
        assert [e["id"] for e in that_day.json()["items"]] == [entry["id"]]
        assert until_the_day_before.json()["items"] == []

    async def test_reads_failures_and_passengers_leave_no_trace(
        self, client: AsyncClient, admin: dict[str, str], passenger: dict[str, str]
    ) -> None:
        admin_id, passenger_id = await _me(client, admin), await _me(client, passenger)
        before = await _audit_rows_by(admin_id)

        await client.get("/api/v1/admin/vehicles", headers=admin)
        missing = await client.post(
            f"/api/v1/admin/users/{uuid.uuid4()}/suspend", headers=admin, json={"reason": "x"}
        )
        await client.patch("/api/v1/users/me", headers=passenger, json={"preferred_language": "tw"})

        assert missing.status_code == 404
        assert await _audit_rows_by(admin_id) == before
        assert await _audit_rows_by(passenger_id) == 0

    async def test_an_action_that_changes_nothing_is_still_on_record(
        self, client: AsyncClient, admin: dict[str, str]
    ) -> None:
        admin_id = await _me(client, admin)

        nothing = await client.patch(
            "/api/v1/admin/settings", headers=admin, json={"reason": "Just checking"}
        )
        log = await client.get(
            "/api/v1/admin/audit-logs",
            headers=admin,
            params={"actor_id": admin_id, "action": "update_system_settings"},
        )

        assert nothing.status_code == 200
        [entry] = log.json()["items"]
        assert (entry["entity_type"], entry["before"], entry["after"]) == ("request", None, None)
        assert entry["reason"] == "Just checking"

    async def test_audit_log_is_for_auditors_only(
        self, client: AsyncClient, passenger: dict[str, str]
    ) -> None:
        response = await client.get("/api/v1/admin/audit-logs", headers=passenger)

        assert response.status_code == 403


class TestSettings:
    async def test_change_validate_and_reset(
        self, client: AsyncClient, admin: dict[str, str]
    ) -> None:
        try:
            changed = await client.patch(
                "/api/v1/admin/settings",
                headers=admin,
                json={"platform_fee_flat_per_seat": "1.25", "reservation_hold_seconds": 600},
            )
            invalid = await client.patch(
                "/api/v1/admin/settings",
                headers=admin,
                json={"reservation_hold_seconds": 5, "approval_target_hours": 24},
            )
            missing_priority = await client.patch(
                "/api/v1/admin/settings",
                headers=admin,
                json={"complaint_sla_hours": {"low": 72}},
            )
            unknown = await client.patch(
                "/api/v1/admin/settings", headers=admin, json={"surge_pricing": True}
            )
            after = {
                s["key"]: s
                for s in (await client.get("/api/v1/admin/settings", headers=admin)).json()
            }

            assert changed.status_code == 200, changed.text
            assert invalid.status_code == 422
            assert missing_priority.status_code == 422
            assert unknown.status_code == 422
            assert after["platform_fee_flat_per_seat"]["value"] == "1.25"
            assert after["platform_fee_flat_per_seat"]["overridden"] is True
            assert after["reservation_hold_seconds"]["value"] == 600
            # Nothing from the invalid request was saved, valid part included.
            assert after["approval_target_hours"]["overridden"] is False
        finally:
            reset = await client.patch(
                "/api/v1/admin/settings",
                headers=admin,
                json={
                    "platform_fee_flat_per_seat": None,
                    "reservation_hold_seconds": None,
                    "approval_target_hours": None,
                    "complaint_sla_hours": None,
                },
            )
        assert all(not s["overridden"] for s in reset.json())

    async def test_a_new_fee_applies_to_the_next_quote(
        self, client: AsyncClient, admin: dict[str, str]
    ) -> None:
        scenario = await _committed_trip_with_paid_and_unpaid_seats()
        url = f"/api/v1/trips/{scenario.trip_id}/fare-quote"
        stops = {
            "origin_stop_id": str(scenario.stop_ids[1]),
            "destination_stop_id": str(scenario.stop_ids[2]),
        }
        try:
            before = await client.get(url, params=stops)
            await client.patch(
                "/api/v1/admin/settings", headers=admin, json={"platform_fee_flat_per_seat": "1.25"}
            )
            after = await client.get(url, params=stops)
        finally:
            await client.patch(
                "/api/v1/admin/settings", headers=admin, json={"platform_fee_flat_per_seat": None}
            )

        assert before.status_code == 200, before.text
        assert Decimal(before.json()["platform_fee"]) == get_settings().PLATFORM_FEE_FLAT_PER_SEAT
        assert Decimal(after.json()["platform_fee"]) == Decimal("1.25")

    async def test_settings_are_for_settings_managers_only(
        self, client: AsyncClient, passenger: dict[str, str]
    ) -> None:
        assert (await client.get("/api/v1/admin/settings", headers=passenger)).status_code == 403


class TestFeatureFlags:
    async def test_list_switch_and_restore(
        self, client: AsyncClient, admin: dict[str, str]
    ) -> None:
        try:
            listed = await client.get("/api/v1/admin/feature-flags", headers=admin)
            off = await client.patch(
                "/api/v1/admin/feature-flags/trip_share_links",
                headers=admin,
                json={"enabled": False, "rollout_percent": 25},
            )
            global_rollout = await client.patch(
                "/api/v1/admin/feature-flags/fare_sharing",
                headers=admin,
                json={"rollout_percent": 50},
            )
            unknown = await client.patch(
                "/api/v1/admin/feature-flags/teleport", headers=admin, json={"enabled": True}
            )

            assert {f["key"] for f in listed.json()} >= {
                "fare_sharing",
                "book_moving_trips",
                "trip_share_links",
            }
            assert (off.json()["enabled"], off.json()["rollout_percent"]) == (False, 25)
            assert global_rollout.status_code == 422
            assert unknown.status_code == 404
        finally:
            await client.patch(
                "/api/v1/admin/feature-flags/trip_share_links",
                headers=admin,
                json={"enabled": True, "rollout_percent": 100},
            )


class TestWallets:
    async def test_credit_debit_and_idempotency(
        self, client: AsyncClient, admin: dict[str, str], passenger: dict[str, str]
    ) -> None:
        user = await _me(client, passenger)
        url = f"/api/v1/admin/wallets/{user}/adjustments"
        key = {"Idempotency-Key": str(uuid.uuid4()), **admin}

        credit = await client.post(
            url, headers=key, json={"direction": "credit", "amount": "5.00", "reason": "Goodwill"}
        )
        retried = await client.post(
            url, headers=key, json={"direction": "credit", "amount": "5.00", "reason": "Goodwill"}
        )
        debit = await client.post(
            url,
            headers=admin,
            json={"direction": "debit", "amount": "2.00", "reason": "Fare correction"},
        )
        too_much = await client.post(
            url,
            headers=admin,
            json={"direction": "debit", "amount": "100.00", "reason": "Fare correction"},
        )
        wallet = await client.get(f"/api/v1/admin/wallets/{user}", headers=admin)

        assert credit.status_code == 201, credit.text
        assert retried.json()["transaction"]["id"] == credit.json()["transaction"]["id"]
        assert debit.json()["balance"] == "3.00"
        assert too_much.status_code == 402
        assert Decimal(wallet.json()["balance"]) == Decimal("3.00")
        assert wallet.json()["transactions_total"] == 2
        assert "Goodwill" in wallet.json()["transactions"][-1]["description"]
        # The new row is on record by its id.
        log = await client.get(
            "/api/v1/admin/audit-logs",
            headers=admin,
            params={
                "entity_type": "wallet_transactions",
                "entity_id": credit.json()["transaction"]["id"],
            },
        )
        [entry] = log.json()["items"]
        assert (entry["before"], entry["after"]["amount_minor_units"]) == (None, 500)
        assert entry["reason"] == "Goodwill"

    async def test_unknown_user_and_permissions(
        self, client: AsyncClient, admin: dict[str, str], passenger: dict[str, str]
    ) -> None:
        missing = await client.get(f"/api/v1/admin/wallets/{uuid.uuid4()}", headers=admin)
        refused = await client.post(
            f"/api/v1/admin/wallets/{uuid.uuid4()}/adjustments",
            headers=passenger,
            json={"direction": "credit", "amount": "5.00", "reason": "Free money"},
        )

        assert missing.status_code == 404
        assert refused.status_code == 403
