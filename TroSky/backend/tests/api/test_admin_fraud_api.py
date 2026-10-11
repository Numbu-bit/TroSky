"""HTTP checks for fraud detection (section 7 of the admin requests): a
scan raises flags, admins review and act on them, and the actions hold --
a frozen wallet, a blocked device."""

from __future__ import annotations

import secrets
import uuid
from decimal import Decimal

import pytest
from httpx import AsyncClient

from app.api.v1.admin_fraud import DETECTION_LOCK
from app.core.database import get_session_factory
from app.core.permissions import SystemRole
from app.core.redis import RedisLock, get_redis_client
from app.models.payments import Payment, PaymentPurpose, PaymentStatus
from app.providers.payments.base import PaymentChannel
from tests.api.test_admin_dashboard_api import PASSWORD, _committed_user, _login

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]

FLAGS = "/api/v1/admin/fraud/flags"


@pytest.fixture
async def admin(client: AsyncClient, seed_identity_data: None, require_redis: None):
    return await _login(client, await _committed_user(SystemRole.ADMIN))


async def _me(client: AsyncClient, headers: dict[str, str]) -> str:
    return str((await client.get("/api/v1/users/me", headers=headers)).json()["id"])


async def _suspect(client: AsyncClient, failures: int) -> tuple[str, str]:
    """A committed passenger with ``failures`` failed payments just now;
    returns their phone number and id."""
    phone = await _committed_user(SystemRole.PASSENGER)
    user_id = await _me(client, await _login(client, phone))
    async with get_session_factory()() as session:
        for _ in range(failures):
            session.add(
                Payment(
                    user_id=uuid.UUID(user_id),
                    purpose=PaymentPurpose.BOOKING_PAYMENT,
                    channel=PaymentChannel.MTN_MOMO,
                    status=PaymentStatus.FAILED,
                    amount=Decimal("8.00"),
                    internal_reference=f"PAY-{secrets.token_hex(6).upper()}",
                )
            )
        await session.commit()
    return phone, user_id


async def _flag_for(client: AsyncClient, admin: dict[str, str], user_id: str) -> dict:
    scan = await client.post("/api/v1/admin/fraud/scan", headers=admin)
    assert scan.status_code == 200, scan.text
    listed = await client.get(
        FLAGS, headers=admin, params={"rule": "payment_failures", "subject_user_id": user_id}
    )
    [flag] = listed.json()["items"]
    return dict(flag)


class TestReview:
    async def test_from_scan_to_confirmed_fraud(
        self, client: AsyncClient, admin: dict[str, str]
    ) -> None:
        _, suspect = await _suspect(client, 10)  # twice the threshold: high risk
        flag = await _flag_for(client, admin, suspect)
        url = f"{FLAGS}/{flag['id']}"
        me = await _me(client, admin)

        detail = await client.get(url, headers=admin)
        alerts = await client.get("/api/v1/admin/alerts", headers=admin, params={"limit": 500})
        taken = await client.patch(
            url, headers=admin, json={"assigned_to": me, "status": "investigating"}
        )
        frozen = await client.post(
            f"{url}/actions",
            headers=admin,
            json={"action": "freeze_wallet", "reason": "Card testing, it looks like"},
        )
        wallet = await client.get(f"/api/v1/admin/wallets/{suspect}", headers=admin)
        no_reason = await client.patch(url, headers=admin, json={"status": "confirmed"})
        confirmed = await client.patch(
            url, headers=admin, json={"status": "confirmed", "reason": "Ten cards in an hour"}
        )
        stats = await client.get("/api/v1/admin/fraud/stats", headers=admin)
        audit = await client.get(
            "/api/v1/admin/audit-logs",
            headers=admin,
            params={"entity_type": "fraud_flags", "entity_id": flag["id"]},
        )

        assert (flag["risk_score"], flag["severity"], flag["status"]) == (70, "medium", "open")
        assert flag["rule_title"] == "Repeated payment failures in a short time"
        body = detail.json()
        assert [u["id"] for u in body["users"]] == [suspect]
        assert len(body["payments"]) == 10
        assert [e["kind"] for e in body["timeline"]] == ["detected"]
        assert flag["id"] in {
            a["entity_id"] for a in alerts.json()["items"] if a["type"] == "fraud_high_risk"
        }
        assert (taken.json()["assignee_name"], taken.json()["status"]) == (
            "Adwoa Admin",
            "investigating",
        )
        assert frozen.status_code == 201, frozen.text
        assert frozen.json()["event"]["details"]["action"] == "freeze_wallet"
        assert wallet.json()["frozen_reason"] == "Card testing, it looks like"
        assert no_reason.status_code == 422
        assert confirmed.json()["status"] == "confirmed"
        figures = stats.json()
        assert figures["confirmed"] >= 1
        assert figures["precision"]["value"] is not None
        assert "update_fraud_flag" in {entry["action"] for entry in audit.json()["items"]}

    async def test_mistakes_are_refused(self, client: AsyncClient, admin: dict[str, str]) -> None:
        missing = f"{FLAGS}/{uuid.uuid4()}"

        assert (await client.get(missing, headers=admin)).status_code == 404
        assert (
            await client.get(FLAGS, headers=admin, params={"rule": "astrology"})
        ).status_code == 422
        assert (
            await client.get(FLAGS, headers=admin, params={"status": "suspicious"})
        ).status_code == 422
        assert (
            await client.post(
                f"{missing}/actions",
                headers=admin,
                json={"action": "freeze_wallet", "reason": "Because"},
            )
        ).status_code == 404

    async def test_one_scan_at_a_time(self, client: AsyncClient, admin: dict[str, str]) -> None:
        lock = RedisLock(get_redis_client(), DETECTION_LOCK, ttl_seconds=30)
        assert await lock.acquire()
        try:
            response = await client.post("/api/v1/admin/fraud/scan", headers=admin)
        finally:
            await lock.release()

        assert response.status_code == 409
        assert response.json()["error"]["code"] == "DETECTION_RUNNING"


class TestRules:
    async def test_list_and_change(self, client: AsyncClient, admin: dict[str, str]) -> None:
        url = "/api/v1/admin/fraud/rules/unusual_topups"
        listed = await client.get("/api/v1/admin/fraud/rules", headers=admin)
        try:
            changed = await client.patch(
                url, headers=admin, json={"threshold": "5000", "reason": "Market day"}
            )
            too_short = await client.patch(url, headers=admin, json={"window_minutes": 1})
        finally:
            await client.patch(url, headers=admin, json={"threshold": "2000"})
        unknown = await client.patch(
            "/api/v1/admin/fraud/rules/astrology", headers=admin, json={"enabled": False}
        )

        assert len(listed.json()) == 10
        assert {r["key"] for r in listed.json()} >= {"ticket_reused", "shared_device"}
        assert changed.status_code == 200, changed.text
        assert Decimal(changed.json()["threshold"]) == Decimal("5000")
        assert changed.json()["changed"] is True
        assert too_short.status_code == 422
        assert unknown.status_code == 404


class TestActionsHold:
    async def test_a_blocked_device_cannot_sign_in(
        self, client: AsyncClient, admin: dict[str, str]
    ) -> None:
        phone, suspect = await _suspect(client, 5)
        flag = await _flag_for(client, admin, suspect)
        device = {"device_id": f"device-{secrets.token_hex(6)}", "platform": "android"}

        async def sign_in(**extra: object):
            return await client.post(
                "/api/v1/auth/login",
                json={"identifier": phone, "password": PASSWORD, **extra},
            )

        before = await sign_in(device=device)
        token = before.json()["access_token"]
        blocked = await client.post(
            f"{FLAGS}/{flag['id']}/actions",
            headers=admin,
            json={
                "action": "block_device",
                "reason": "Shared by a ring of accounts",
                "device_id": device["device_id"],
            },
        )
        session_after = await client.get(
            "/api/v1/users/me", headers={"Authorization": f"Bearer {token}"}
        )
        again = await sign_in(device=device)
        elsewhere = await sign_in(device={"device_id": "another-phone", "platform": "android"})

        assert before.status_code == 200, before.text
        assert blocked.status_code == 201, blocked.text
        assert session_after.status_code == 401  # signed out on that device
        assert again.status_code == 403
        assert again.json()["error"]["code"] == "DEVICE_BLOCKED"
        assert elsewhere.status_code == 200  # the account itself is fine


class TestWhoMay:
    @pytest.mark.parametrize(
        ("method", "path"),
        [
            ("get", FLAGS),
            ("get", "/api/v1/admin/fraud/stats"),
            ("get", "/api/v1/admin/fraud/rules"),
            ("post", "/api/v1/admin/fraud/scan"),
        ],
    )
    async def test_passengers_are_refused(
        self,
        client: AsyncClient,
        seed_identity_data: None,
        require_redis: None,
        method: str,
        path: str,
    ) -> None:
        passenger = await _login(client, await _committed_user(SystemRole.PASSENGER))

        response = await client.request(method, path, headers=passenger)

        assert response.status_code == 403
