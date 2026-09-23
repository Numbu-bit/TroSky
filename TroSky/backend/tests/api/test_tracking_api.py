"""End-to-end HTTP tests for tracking-endpoint auth, including the
WebSocket handshake's own authentication (query-param token, since a
WebSocket handshake can't carry a bearer ``Authorization`` header)."""

from __future__ import annotations

import uuid

import pytest
from fastapi.testclient import TestClient
from httpx import AsyncClient
from starlette.websockets import WebSocketDisconnect

from app.main import create_app

pytestmark = pytest.mark.integration


class TestTrackingApiAuth:
    async def test_get_location_requires_authentication(self, client: AsyncClient) -> None:
        response = await client.get(f"/api/v1/trips/{uuid.uuid4()}/location")
        assert response.status_code == 401

    async def test_get_eta_requires_authentication(self, client: AsyncClient) -> None:
        response = await client.get(f"/api/v1/trips/{uuid.uuid4()}/eta")
        assert response.status_code == 401

    async def test_report_location_requires_authentication(self, client: AsyncClient) -> None:
        response = await client.post(
            f"/api/v1/driver-trips/{uuid.uuid4()}/location",
            json={"latitude": 5.6, "longitude": -0.19},
        )
        assert response.status_code == 401


class TestTrackingWebSocketAuth:
    def test_connect_without_token_is_rejected(self) -> None:
        app = create_app()
        url = f"/api/v1/ws/trips/{uuid.uuid4()}/track"
        with (
            TestClient(app) as sync_client,
            pytest.raises(WebSocketDisconnect),
            sync_client.websocket_connect(url),
        ):
            pass

    def test_connect_with_garbage_token_is_rejected(self) -> None:
        app = create_app()
        url = f"/api/v1/ws/trips/{uuid.uuid4()}/track?token=not-a-real-token"
        with (
            TestClient(app) as sync_client,
            pytest.raises(WebSocketDisconnect),
            sync_client.websocket_connect(url),
        ):
            pass
