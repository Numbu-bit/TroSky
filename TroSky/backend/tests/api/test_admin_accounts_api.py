"""HTTP checks for people (section 11 of the admin requests): users and
their devices, the admin team and what staff may do, an admin's own
devices, and approval requests."""

from __future__ import annotations

import secrets
import uuid

import pytest
from httpx import AsyncClient
from sqlalchemy import select

from app.core.database import get_session_factory
from app.core.permissions import SystemRole
from app.models.drivers import DocumentType
from app.models.identity import Permission as PermissionRow
from app.models.identity import User, UserPermission
from app.providers.storage.malware_scan import NoOpMalwareScanner
from app.providers.storage.sandbox import SandboxStorageProvider
from app.services.fleet_service import FleetService
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
async def passenger_phone(client: AsyncClient, seed_identity_data: None, require_redis: None):
    return await _committed_user(SystemRole.PASSENGER)


async def _me(client: AsyncClient, headers: dict[str, str]) -> str:
    return str((await client.get("/api/v1/users/me", headers=headers)).json()["id"])


async def _staff_with(*codes: str) -> str:
    """A committed staff member granted ``codes``; returns their phone."""
    phone = await _committed_user(SystemRole.STAFF)
    async with get_session_factory()() as session:
        user_id = await session.scalar(select(User.id).where(User.phone_number == phone))
        for code in codes:
            permission_id = await session.scalar(
                select(PermissionRow.id).where(PermissionRow.code == code)
            )
            session.add(UserPermission(user_id=user_id, permission_id=permission_id))
        await session.commit()
    return phone


class TestUsers:
    async def test_browse_look_and_sign_a_device_out(
        self, client: AsyncClient, admin: dict[str, str], passenger_phone: str
    ) -> None:
        signed_in = await _login(client, passenger_phone)
        user_id = await _me(client, signed_in)
        local = "0" + passenger_phone.removeprefix("+233")

        listed = await client.get(
            "/api/v1/admin/users",
            headers=admin,
            params={"search": local, "role": "passenger", "status": "active"},
        )
        exported = await client.get(
            "/api/v1/admin/users", headers=admin, params={"search": local, "format": "csv"}
        )
        detail = await client.get(f"/api/v1/admin/users/{user_id}", headers=admin)
        sessions = await client.get(f"/api/v1/admin/users/{user_id}/sessions", headers=admin)
        [session] = sessions.json()
        signed_out = await client.delete(
            f"/api/v1/admin/users/{user_id}/sessions/{session['id']}", headers=admin
        )
        afterwards = await client.get("/api/v1/users/me", headers=signed_in)

        assert [u["id"] for u in listed.json()["items"]] == [user_id]
        assert listed.json()["items"][0]["roles"] == ["passenger"]
        assert exported.text.splitlines()[0].startswith("id,phone_number,email,full_name")
        body = detail.json()
        assert (body["full_name"], body["active_sessions"], body["open_fraud_flags"]) == (
            "Adwoa Admin",
            1,
            0,
        )
        assert signed_out.status_code == 204
        assert afterwards.status_code == 401

    async def test_bad_requests(self, client: AsyncClient, admin: dict[str, str]) -> None:
        assert (
            await client.get("/api/v1/admin/users", headers=admin, params={"role": "wizard"})
        ).status_code == 422
        assert (
            await client.get("/api/v1/admin/users", headers=admin, params={"status": "asleep"})
        ).status_code == 422
        assert (
            await client.get(f"/api/v1/admin/users/{uuid.uuid4()}", headers=admin)
        ).status_code == 404


class TestTheTeam:
    async def test_invite_change_and_remove(
        self, client: AsyncClient, admin: dict[str, str]
    ) -> None:
        phone = f"024{secrets.randbelow(10**7):07d}"
        invited = await client.post(
            "/api/v1/admin/admins",
            headers=admin,
            json={
                "full_name": "Efua Support",
                "phone_number": phone,
                "email": f"efua.{secrets.token_hex(4)}@gmail.com",
                "role": "staff",
                "permissions": ["complaints:manage"],
                "reason": "Joins the support desk",
            },
        )
        member_id = invited.json()["member"]["id"]
        team = await client.get("/api/v1/admin/admins", headers=admin)
        widened = await client.patch(
            f"/api/v1/admin/admins/{member_id}",
            headers=admin,
            json={"permissions": ["complaints:manage", "sos:review"]},
        )
        myself = await client.patch(
            f"/api/v1/admin/admins/{await _me(client, admin)}",
            headers=admin,
            json={"active": False},
        )
        removed = await client.patch(
            f"/api/v1/admin/admins/{member_id}", headers=admin, json={"active": False}
        )
        bad_phone = await client.post(
            "/api/v1/admin/admins",
            headers=admin,
            json={"full_name": "Nobody", "phone_number": "12345", "role": "staff"},
        )

        assert invited.status_code == 201, invited.text
        assert (invited.json()["new_account"], invited.json()["invitation_sent"]) == (True, True)
        assert member_id in {m["id"] for m in team.json()}
        assert widened.json()["member"]["granted_permissions"] == [
            "complaints:manage",
            "sos:review",
        ]
        assert myself.status_code == 403
        assert removed.json() == {"on_team": False, "member": None}
        assert bad_phone.status_code == 422

    async def test_staff_may_do_what_they_were_granted(self, client: AsyncClient) -> None:
        staff = await _login(client, await _staff_with("complaints:manage"))

        allowed = await client.get("/api/v1/admin/complaints", headers=staff)
        refused = await client.get("/api/v1/admin/fraud/flags", headers=staff)
        team = await client.get("/api/v1/admin/admins", headers=staff)

        assert allowed.status_code == 200
        assert refused.status_code == 403
        assert team.status_code == 403

    async def test_my_own_devices(self, client: AsyncClient, admin: dict[str, str]) -> None:
        mine = await client.get("/api/v1/admin/me/sessions", headers=admin)
        [current] = [s for s in mine.json() if s["is_current"]]
        unknown = await client.delete(f"/api/v1/admin/me/sessions/{uuid.uuid4()}", headers=admin)

        assert current["id"]
        assert unknown.status_code == 404


class TestApprovals:
    async def test_ask_for_new_documents_and_look_at_one(
        self, client: AsyncClient, admin: dict[str, str]
    ) -> None:
        scenario = await _committed_trip_with_paid_and_unpaid_seats()
        async with get_session_factory()() as session:
            document = await FleetService(
                session, SandboxStorageProvider(), NoOpMalwareScanner()
            ).upload_vehicle_document(
                scenario.owner_user_id,
                scenario.vehicle_id,
                document_type=DocumentType.VEHICLE_INSURANCE,
                filename="insurance.pdf",
                content_type="application/pdf",
                data=b"%PDF-1.4 fake",
            )
            await session.commit()

        asked = await client.post(
            f"/api/v1/admin/vehicles/{scenario.vehicle_id}/request-info",
            headers=admin,
            json={
                "document_types": ["vehicle_insurance"],
                "note": "The certificate has expired.",
            },
        )
        link = await client.get(f"/api/v1/admin/documents/{document.id}", headers=admin)
        missing = await client.post(
            f"/api/v1/admin/drivers/{uuid.uuid4()}/request-info",
            headers=admin,
            json={"document_types": ["driver_license"], "note": "Blurred photo."},
        )

        assert asked.status_code == 201, asked.text
        assert asked.json()["documents_returned"] == [str(document.id)]
        assert asked.json()["notified_user_id"] == str(scenario.owner_user_id)
        assert link.json()["status"] == "rejected"  # returned by the request just made
        assert document.storage_key in link.json()["url"]
        assert missing.status_code == 404


class TestWhoMay:
    @pytest.mark.parametrize(
        "path",
        [
            "/api/v1/admin/users",
            "/api/v1/admin/admins",
            "/api/v1/admin/me/sessions",
            f"/api/v1/admin/documents/{uuid.uuid4()}",
        ],
    )
    async def test_passengers_are_refused(
        self, client: AsyncClient, passenger_phone: str, path: str
    ) -> None:
        passenger = await _login(client, passenger_phone)

        assert (await client.get(path, headers=passenger)).status_code == 403
