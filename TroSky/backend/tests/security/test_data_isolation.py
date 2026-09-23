"""Security regression tests: horizontal privilege escalation must be
impossible between two passenger accounts."""

from __future__ import annotations

import pytest
from httpx import AsyncClient

from app.providers.email.sandbox import SandboxEmailProvider
from app.providers.sms.sandbox import SandboxSmsProvider

pytestmark = [pytest.mark.integration, pytest.mark.security, pytest.mark.asyncio]


def _extract_otp(message: str) -> str:
    return message.split("is ")[1].split(".")[0].strip()


@pytest.fixture(autouse=True)
def _clear_sandbox_outboxes():
    SandboxSmsProvider.clear()
    SandboxEmailProvider.clear()
    yield
    SandboxSmsProvider.clear()
    SandboxEmailProvider.clear()


async def _register_and_login(client: AsyncClient, phone: str, name: str) -> str:
    register_response = await client.post(
        "/api/v1/auth/register",
        json={
            "phone_number": phone,
            "password": "Str0ngPass",
            "full_name": name,
            "role": "passenger",
        },
    )
    assert register_response.status_code == 201, register_response.text
    otp_target = register_response.json()["otp_sent_to"]
    message = SandboxSmsProvider.get_last_message(otp_target)
    assert message is not None
    await client.post(
        "/api/v1/auth/verify-otp",
        json={"target": otp_target, "purpose": "registration", "code": _extract_otp(message)},
    )
    login_response = await client.post(
        "/api/v1/auth/login", json={"identifier": phone, "password": "Str0ngPass"}
    )
    assert login_response.status_code == 200
    return str(login_response.json()["access_token"])


class TestPassengerDataIsolation:
    async def test_passenger_cannot_read_or_modify_another_passengers_emergency_contact(
        self, client: AsyncClient, seed_identity_data: None
    ) -> None:
        token_a = await _register_and_login(client, "0281234567", "Passenger A")
        token_b = await _register_and_login(client, "0281234568", "Passenger B")

        create_response = await client.post(
            "/api/v1/users/me/emergency-contacts",
            json={"name": "Mother", "phone_number": "0201234567"},
            headers={"Authorization": f"Bearer {token_a}"},
        )
        assert create_response.status_code == 201, create_response.text
        contact_id = create_response.json()["id"]

        # B must not be able to update A's contact.
        update_response = await client.patch(
            f"/api/v1/users/me/emergency-contacts/{contact_id}",
            json={"name": "Hijacked"},
            headers={"Authorization": f"Bearer {token_b}"},
        )
        assert update_response.status_code == 404

        # B must not be able to delete A's contact.
        delete_response = await client.delete(
            f"/api/v1/users/me/emergency-contacts/{contact_id}",
            headers={"Authorization": f"Bearer {token_b}"},
        )
        assert delete_response.status_code == 404

        # A's contact must remain untouched and visible only to A.
        list_response_a = await client.get(
            "/api/v1/users/me/emergency-contacts",
            headers={"Authorization": f"Bearer {token_a}"},
        )
        assert [c["name"] for c in list_response_a.json()] == ["Mother"]

        list_response_b = await client.get(
            "/api/v1/users/me/emergency-contacts",
            headers={"Authorization": f"Bearer {token_b}"},
        )
        assert list_response_b.json() == []

    async def test_access_token_stops_working_immediately_after_logout_all(
        self, client: AsyncClient, seed_identity_data: None
    ) -> None:
        token = await _register_and_login(client, "0281234569", "Passenger C")

        logout_all_response = await client.post(
            "/api/v1/auth/logout-all", headers={"Authorization": f"Bearer {token}"}
        )
        assert logout_all_response.status_code == 204

        # Every request re-validates that the session behind the access
        # token's `sid` claim is still active (see
        # app.api.dependencies.get_current_principal) — so revocation takes
        # effect immediately, not just on the next refresh.
        me_response = await client.get(
            "/api/v1/users/me", headers={"Authorization": f"Bearer {token}"}
        )
        assert me_response.status_code == 401
        assert me_response.json()["error"]["code"] == "UNAUTHORIZED"
