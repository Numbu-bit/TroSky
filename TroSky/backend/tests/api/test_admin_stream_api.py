"""The admin live stream over real HTTP.

An in-process test client waits for a response to finish, and this one
never does, so the app is served by uvicorn on a free local port for the
length of each test. The admin connects as a browser's EventSource would:
the token in the query string.
"""

from __future__ import annotations

import asyncio
import json
from collections.abc import AsyncIterator
from typing import Any

import httpx
import pytest
import uvicorn
from httpx import AsyncClient

from app.api.v1 import admin_stream
from app.core.permissions import SystemRole
from app.core.redis import get_redis_pool
from app.main import create_app
from tests.api.test_admin_dashboard_api import _committed_user, _login

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]


@pytest.fixture
async def live_server(seed_identity_data: None, require_redis: None) -> AsyncIterator[str]:
    server = uvicorn.Server(
        uvicorn.Config(
            create_app(),
            host="127.0.0.1",
            port=0,
            log_level="warning",
            lifespan="off",
            ws="none",  # plain HTTP is all this needs
        )
    )
    serving = asyncio.create_task(server.serve())
    while not server.started:
        if serving.done():
            serving.result()  # failed to start: say why
        await asyncio.sleep(0.02)
    port = server.servers[0].sockets[0].getsockname()[1]
    try:
        yield f"http://127.0.0.1:{port}"
    finally:
        server.should_exit = True
        await asyncio.wait_for(serving, 15)


async def _event_mentioning(lines: AsyncIterator[str], marker: str) -> dict[str, Any]:
    """The next event whose data mentions ``marker``, parsed."""
    fields: dict[str, Any] = {}
    while True:
        line = await asyncio.wait_for(anext(lines), 15)
        if line:
            name, _, value = line.partition(": ")
            fields[name] = value
            continue
        if marker in fields.get("data", ""):
            return {**fields, "data": json.loads(fields["data"])}
        fields = {}


async def _token(client: AsyncClient, role: SystemRole) -> str:
    headers = await _login(client, await _committed_user(role))
    return headers["Authorization"].removeprefix("Bearer ")


class TestTheLiveStream:
    async def test_an_admin_sees_a_complaint_as_it_is_filed(
        self, client: AsyncClient, live_server: str
    ) -> None:
        token = await _token(client, SystemRole.ADMIN)
        passenger = await _login(client, await _committed_user(SystemRole.PASSENGER))

        async with (
            httpx.AsyncClient(base_url=live_server, timeout=15) as http,
            http.stream(
                "GET", "/api/v1/admin/stream", params={"token": token, "topics": "complaints"}
            ) as response,
        ):
            lines = response.aiter_lines()
            first = await asyncio.wait_for(anext(lines), 15)
            filed = await client.post(
                "/api/v1/complaints",
                headers=passenger,
                json={
                    "category": "safety",
                    "subject": "Speeding on the motorway",
                    "description": "Well over the limit all the way to Tema.",
                },
            )
            complaint_id = filed.json()["id"]
            event = await _event_mentioning(lines, complaint_id)

        assert response.status_code == 200
        assert response.headers["content-type"].startswith("text/event-stream")
        assert first == "retry: 5000"
        assert event["event"] == "complaint.created"
        assert event["id"]
        assert event["data"]["data"]["priority"] == "high"  # a safety complaint

        # The server let go of the stream when the client left.
        for _ in range(100):
            if admin_stream._open_streams == 0:
                break
            await asyncio.sleep(0.05)
        assert admin_stream._open_streams == 0

    async def test_leaving_gives_back_the_redis_connection(
        self, client: AsyncClient, live_server: str
    ) -> None:
        """Bus positions hold a Redis connection while the stream is open. A
        browser that leaves cancels the stream, and the connection must
        still go back to the pool: it once did not, and after some fifty
        reloads of the dashboard every stream failed with "Too many
        connections"."""
        token = await _token(client, SystemRole.ADMIN)
        pool = get_redis_pool()
        in_use = len(pool._in_use_connections)

        for _ in range(3):
            async with (
                httpx.AsyncClient(base_url=live_server, timeout=15) as http,
                http.stream(
                    "GET", "/api/v1/admin/stream", params={"token": token, "topics": "positions"}
                ) as response,
            ):
                first = await asyncio.wait_for(anext(response.aiter_lines()), 15)
                assert first == "retry: 5000"
        for _ in range(100):
            if admin_stream._open_streams == 0 and len(pool._in_use_connections) <= in_use:
                break
            await asyncio.sleep(0.05)

        assert admin_stream._open_streams == 0
        assert len(pool._in_use_connections) == in_use

    async def test_a_passenger_token_is_refused(
        self, client: AsyncClient, live_server: str
    ) -> None:
        token = await _token(client, SystemRole.PASSENGER)

        async with httpx.AsyncClient(base_url=live_server, timeout=15) as http:
            response = await http.get("/api/v1/admin/stream", params={"token": token})

        assert response.status_code == 403
