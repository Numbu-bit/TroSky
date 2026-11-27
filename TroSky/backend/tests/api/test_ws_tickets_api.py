"""Opening the tracking WebSocket with a one-time ticket instead of the
access token in its URL (B5), through the real route.

TestClient runs the app on its own event loop, so the pooled clients
cached on the test's loop are released first and the app's lifespan builds
fresh ones (see ``test_ws_session_revocation.TestRealHandshake``).
"""

from __future__ import annotations

import secrets
import uuid
from datetime import UTC, datetime, timedelta

import pytest
from starlette.testclient import TestClient
from starlette.websockets import WebSocketDisconnect

from app.core.config import get_settings
from app.core.database import dispose_engine, get_session_factory
from app.core.redis import close_redis
from app.core.security import hash_password
from app.main import create_app
from app.models.identity import User, UserProfile
from tests.integration.scenarios import build_trip_scenario

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]

PASSWORD = "Str0ngPass!"


def _phone() -> str:
    return f"024{secrets.randbelow(10**7):07d}"


def _sign_in(http: TestClient, phone: str | None = None) -> dict[str, str]:
    if phone is None:
        phone = _phone()
        registered = http.post(
            "/api/v1/auth/register",
            json={"phone_number": phone, "password": PASSWORD, "full_name": "Ama Mensah"},
        )
        assert registered.status_code == 201, registered.text
    login = http.post("/api/v1/auth/login", json={"identifier": phone, "password": PASSWORD})
    assert login.status_code == 200, login.text
    return {"Authorization": f"Bearer {login.json()['access_token']}"}


def _ticket(http: TestClient, headers: dict[str, str]) -> str:
    issued = http.post("/api/v1/auth/ws/ticket", headers=headers)
    assert issued.status_code == 201, issued.text
    return str(issued.json()["ticket"])


def _refusal(http: TestClient, url: str) -> WebSocketDisconnect:
    with pytest.raises(WebSocketDisconnect) as refused, http.websocket_connect(url):
        pass
    return refused.value


@pytest.fixture
async def _fresh_loop_clients(seed_identity_data: None, require_redis: None) -> None:
    await dispose_engine()
    await close_redis()


@pytest.mark.usefixtures("_fresh_loop_clients")
async def test_a_ticket_needs_a_signed_in_caller() -> None:
    with TestClient(create_app()) as http:
        assert http.post("/api/v1/auth/ws/ticket").status_code == 401

        issued = http.post("/api/v1/auth/ws/ticket", headers=_sign_in(http))

    assert issued.status_code == 201, issued.text
    body = issued.json()
    assert len(body["ticket"]) >= 40
    assert body["expires_in"] == get_settings().WS_TICKET_TTL_SECONDS
    expires_at = datetime.fromisoformat(body["expires_at"])
    assert datetime.now(UTC) < expires_at <= datetime.now(UTC) + timedelta(seconds=61)


@pytest.mark.usefixtures("_fresh_loop_clients")
async def test_a_ticket_opens_one_socket_only() -> None:
    with TestClient(create_app()) as http:
        url = f"/api/v1/ws/trips/{uuid.uuid4()}/track?ticket={_ticket(http, _sign_in(http))}"

        first = _refusal(http, url)
        replay = _refusal(http, url)

    # "Forbidden": the caller was recognised, then refused a trip that isn't theirs.
    assert first.reason == "Forbidden"
    assert replay.code == 1008
    assert replay.reason == "Invalid or expired ticket"


@pytest.mark.usefixtures("_fresh_loop_clients")
async def test_an_unknown_ticket_is_refused() -> None:
    with TestClient(create_app()) as http:
        refused = _refusal(http, f"/api/v1/ws/trips/{uuid.uuid4()}/track?ticket=made-up")

    assert refused.code == 1008
    assert refused.reason == "Invalid or expired ticket"


@pytest.mark.usefixtures("_fresh_loop_clients")
async def test_a_ticket_from_a_signed_out_session_is_refused() -> None:
    with TestClient(create_app()) as http:
        headers = _sign_in(http)
        ticket = _ticket(http, headers)
        assert http.post("/api/v1/auth/logout", headers=headers).status_code == 204

        refused = _refusal(http, f"/api/v1/ws/trips/{uuid.uuid4()}/track?ticket={ticket}")

    assert refused.code == 1008
    assert refused.reason == "This session has been revoked."


async def test_the_trips_driver_is_let_in_with_a_ticket(
    seed_identity_data: None, require_redis: None
) -> None:
    phones: dict[uuid.UUID, str] = {}
    async with get_session_factory()() as session:

        async def make_user(**_: object) -> User:
            local = _phone()
            user = User(phone_number="+233" + local[1:], password_hash=hash_password(PASSWORD))
            user.profile = UserProfile(full_name="Yaw Darko", preferred_language="en")
            session.add(user)
            await session.flush()
            phones[user.id] = local
            return user

        scenario = await build_trip_scenario(
            session, make_user, departure=datetime.now(UTC) + timedelta(hours=1)
        )
        await session.commit()
    await dispose_engine()
    await close_redis()

    with TestClient(create_app()) as http:
        driver = _sign_in(http, phones[scenario.driver_user_id])
        url = f"/api/v1/ws/trips/{scenario.trip_id}/track?ticket={_ticket(http, driver)}"

        with http.websocket_connect(url) as socket:
            socket.close()


@pytest.mark.usefixtures("_fresh_loop_clients")
class TestTheOldQueryToken:
    async def test_still_works_while_allowed(self) -> None:
        with TestClient(create_app()) as http:
            token = _sign_in(http)["Authorization"].removeprefix("Bearer ")

            refused = _refusal(http, f"/api/v1/ws/trips/{uuid.uuid4()}/track?token={token}")

        assert refused.reason == "Forbidden"  # recognised, then refused a stranger's trip

    async def test_is_refused_once_switched_off(self, monkeypatch: pytest.MonkeyPatch) -> None:
        monkeypatch.setattr(get_settings(), "WS_QUERY_TOKEN_ALLOWED", False)
        with TestClient(create_app()) as http:
            token = _sign_in(http)["Authorization"].removeprefix("Bearer ")

            refused = _refusal(http, f"/api/v1/ws/trips/{uuid.uuid4()}/track?token={token}")

        assert refused.code == 1008
        assert refused.reason == "Use ?ticket= from POST /auth/ws/ticket"
