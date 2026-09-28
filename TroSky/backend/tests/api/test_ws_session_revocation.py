"""Session revocation parity between HTTP and the tracking WebSocket.

The WebSocket used to build its caller from token claims alone, so a
logged-out or suspended account could keep opening live-location streams
until the token expired. It now runs ``resolve_principal`` -- the same
check behind every HTTP request. These tests prove the two transports now
refuse the same caller for the same reason.

Accounts are created through the real API (committed), because
``authorize_trip_watcher`` opens its own database session, exactly as the
live endpoint does.
"""

from __future__ import annotations

import random
import uuid

import pytest
from fastapi import WebSocketException
from httpx import AsyncClient
from sqlalchemy import update
from starlette.testclient import TestClient
from starlette.websockets import WebSocketDisconnect

from app.api.v1.tracking import authorize_trip_watcher
from app.core.database import dispose_engine, get_session_factory
from app.core.redis import close_redis
from app.core.security import TokenType, decode_token
from app.main import create_app
from app.models.identity import User

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]

PASSWORD = "Str0ngPass!"


def _phone() -> str:
    return f"024{random.randint(1_000_000, 9_999_999)}"


async def _signed_in(client: AsyncClient) -> str:
    phone = _phone()
    registered = await client.post(
        "/api/v1/auth/register",
        json={"phone_number": phone, "password": PASSWORD, "full_name": "Ama Mensah"},
    )
    assert registered.status_code == 201, registered.text
    login = await client.post(
        "/api/v1/auth/login", json={"identifier": phone, "password": PASSWORD}
    )
    assert login.status_code == 200, login.text
    return str(login.json()["access_token"])


async def _refusal(token: str | None) -> WebSocketException:
    """The reason a watcher would be turned away from a trip it has no
    access to. "Forbidden" means every *session* check passed first."""
    with pytest.raises(WebSocketException) as refused:
        await authorize_trip_watcher(token, uuid.uuid4())
    return refused.value


class TestSessionChecks:
    async def test_a_live_session_passes_the_session_checks(
        self, client: AsyncClient, seed_identity_data: None, require_redis: None
    ) -> None:
        token = await _signed_in(client)
        refused = await _refusal(token)
        assert refused.reason == "Forbidden"

    async def test_a_logged_out_session_is_refused(
        self, client: AsyncClient, seed_identity_data: None, require_redis: None
    ) -> None:
        token = await _signed_in(client)
        logout = await client.post(
            "/api/v1/auth/logout", headers={"Authorization": f"Bearer {token}"}
        )
        assert logout.status_code == 204
        refused = await _refusal(token)
        assert refused.code == 1008
        assert refused.reason == "This session has been revoked."

    async def test_a_suspended_account_is_refused(
        self, client: AsyncClient, seed_identity_data: None, require_redis: None
    ) -> None:
        token = await _signed_in(client)
        user_id = decode_token(token, expected_type=TokenType.ACCESS).subject_user_id
        async with get_session_factory()() as session, session.begin():
            await session.execute(update(User).where(User.id == user_id).values(is_suspended=True))
        refused = await _refusal(token)
        assert refused.code == 1008
        assert refused.reason != "Forbidden"
        assert "suspend" in (refused.reason or "").lower()

    async def test_no_token_is_refused(self) -> None:
        refused = await _refusal(None)
        assert refused.reason == "Missing token"

    async def test_http_and_websocket_agree_on_a_revoked_session(
        self, client: AsyncClient, seed_identity_data: None, require_redis: None
    ) -> None:
        token = await _signed_in(client)
        await client.post("/api/v1/auth/logout", headers={"Authorization": f"Bearer {token}"})
        http = await client.get("/api/v1/users/me", headers={"Authorization": f"Bearer {token}"})
        assert http.status_code == 401
        assert http.json()["error"]["message"] == (await _refusal(token)).reason


class TestRealHandshake:
    async def test_the_live_endpoint_refuses_a_logged_out_session(
        self, seed_identity_data: None, require_redis: None
    ) -> None:
        """End to end through the actual WebSocket route. TestClient runs the
        app on its own event loop, so the pooled clients cached on this one
        are released first and the app's lifespan builds and disposes fresh
        ones on that loop."""
        await dispose_engine()
        await close_redis()
        phone = _phone()
        with TestClient(create_app()) as http:
            assert (
                http.post(
                    "/api/v1/auth/register",
                    json={"phone_number": phone, "password": PASSWORD, "full_name": "Ama"},
                ).status_code
                == 201
            )
            token = http.post(
                "/api/v1/auth/login", json={"identifier": phone, "password": PASSWORD}
            ).json()["access_token"]
            url = f"/api/v1/ws/trips/{uuid.uuid4()}/track?token={token}"

            with pytest.raises(WebSocketDisconnect) as before, http.websocket_connect(url):
                pass
            assert before.value.reason == "Forbidden"

            http.post("/api/v1/auth/logout", headers={"Authorization": f"Bearer {token}"})
            with pytest.raises(WebSocketDisconnect) as after, http.websocket_connect(url):
                pass
            assert after.value.code == 1008
            assert after.value.reason == "This session has been revoked."
