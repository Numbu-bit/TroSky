"""Tests for RequestSizeLimitMiddleware.

The middleware used to trust the ``Content-Length`` header alone, so a
chunked request -- which carries no such header -- was never measured and
could be as large as the client liked. These tests pin down both checks:
the declared length, and the running count of bytes actually received.
"""

from __future__ import annotations

from collections.abc import AsyncIterator
from typing import Any

import pytest
from fastapi import FastAPI, Request
from httpx import ASGITransport, AsyncClient
from pydantic import BaseModel

from app.core.config import Settings, get_settings
from app.core.exceptions import register_exception_handlers
from app.middleware.request_context import RequestSizeLimitMiddleware

pytestmark = pytest.mark.asyncio

LIMIT = 100


class _Body(BaseModel):
    text: str


def _settings(max_bytes: int = LIMIT) -> Settings:
    return Settings(
        SECRET_KEY="a" * 40,
        PAYMENTS_WEBHOOK_SIGNING_SECRET="b" * 40,
        TICKET_QR_SIGNING_SECRET="c" * 40,
        DATABASE_URL="postgresql+asyncpg://u:p@localhost:5432/db",
        DATABASE_URL_SYNC="postgresql+psycopg://u:p@localhost:5432/db",
        MAX_REQUEST_BODY_BYTES=max_bytes,
    )


def _app() -> FastAPI:
    app = FastAPI()
    register_exception_handlers(app)
    app.add_middleware(RequestSizeLimitMiddleware, settings=_settings())

    @app.post("/json")
    async def parsed(body: _Body) -> dict[str, int]:
        """Body read by FastAPI's own parser."""
        return {"length": len(body.text)}

    @app.post("/raw")
    async def raw(request: Request) -> dict[str, int]:
        """Body read by the handler, as a webhook verifying a signature does."""
        return {"length": len(await request.body())}

    return app


async def _chunks(total: int, size: int = 10) -> AsyncIterator[bytes]:
    sent = 0
    while sent < total:
        piece = min(size, total - sent)
        sent += piece
        yield b"x" * piece


def _json_of(text_length: int) -> bytes:
    return b'{"text": "' + b"x" * text_length + b'"}'


async def _post(path: str, **kwargs: Any) -> Any:
    # Labelled as JSON, as clients send it: FastAPI only parses a JSON body
    # that says it is one.
    kwargs.setdefault("headers", {"content-type": "application/json"})
    async with AsyncClient(transport=ASGITransport(app=_app()), base_url="http://t") as c:
        return await c.post(path, **kwargs)


class TestDeclaredLength:
    async def test_an_oversized_declared_body_is_refused(self) -> None:
        response = await _post("/json", content=_json_of(200))
        assert response.status_code == 413
        error = response.json()["error"]
        assert error["code"] == "PAYLOAD_TOO_LARGE"
        assert error["details"] == {"max_bytes": LIMIT}

    async def test_a_body_within_the_limit_is_served(self) -> None:
        response = await _post("/json", content=_json_of(20))
        assert response.status_code == 200
        assert response.json() == {"length": 20}


class TestStreamedBody:
    """The bypass: no Content-Length header at all."""

    @pytest.mark.parametrize("path", ["/json", "/raw"])
    async def test_an_oversized_chunked_body_is_refused(self, path: str) -> None:
        response = await _post(path, content=_chunks(250))
        assert "content-length" not in response.request.headers  # really the bypass path
        assert response.status_code == 413
        error = response.json()["error"]
        assert error["code"] == "PAYLOAD_TOO_LARGE"
        assert error["details"] == {"max_bytes": LIMIT}

    async def test_a_chunked_body_within_the_limit_is_served(self) -> None:
        response = await _post("/raw", content=_chunks(60))
        assert "content-length" not in response.request.headers
        assert response.status_code == 200
        assert response.json() == {"length": 60}

    async def test_both_rejections_look_the_same_to_a_client(self) -> None:
        declared = (await _post("/raw", content=b"x" * 250)).json()["error"]
        streamed = (await _post("/raw", content=_chunks(250))).json()["error"]
        for field in ("code", "message", "details"):
            assert declared[field] == streamed[field]


class _Channel:
    """An ASGI ``receive`` that serves body chunks and counts reads."""

    def __init__(self, chunks: list[bytes]) -> None:
        self._chunks = chunks
        self.reads = 0

    async def __call__(self) -> dict[str, Any]:
        self.reads += 1
        if not self._chunks:
            return {"type": "http.disconnect"}
        chunk = self._chunks.pop(0)
        return {"type": "http.request", "body": chunk, "more_body": bool(self._chunks)}


async def _call_raw(headers: list[tuple[bytes, bytes]], channel: _Channel) -> list[dict[str, Any]]:
    sent: list[dict[str, Any]] = []

    async def send(message: dict[str, Any]) -> None:
        sent.append(message)

    scope = {
        "type": "http",
        "asgi": {"version": "3.0"},
        "http_version": "1.1",
        "method": "POST",
        "scheme": "http",
        "path": "/raw",
        "raw_path": b"/raw",
        "query_string": b"",
        "root_path": "",
        "headers": headers,
        "client": ("203.0.113.9", 5000),
        "server": ("t", 80),
    }
    await _app()(scope, channel, send)  # type: ignore[arg-type]
    return sent


def _status(sent: list[dict[str, Any]]) -> int:
    return next(m["status"] for m in sent if m["type"] == "http.response.start")


class TestRawAsgi:
    async def test_a_body_larger_than_it_declared_is_still_caught(self) -> None:
        """Content-Length says 10; the client sends 250. The count, not the
        claim, decides."""
        channel = _Channel([b"x" * 50] * 5)
        sent = await _call_raw([(b"content-length", b"10")], channel)
        assert _status(sent) == 413

    async def test_reading_stops_once_the_limit_is_passed(self) -> None:
        """Ten 50-byte chunks against a 100-byte limit: the third chunk
        crosses it, so the rest are never pulled off the wire."""
        channel = _Channel([b"x" * 50] * 10)
        sent = await _call_raw([], channel)
        assert _status(sent) == 413
        assert channel.reads == 3

    async def test_websocket_traffic_is_not_touched(self) -> None:
        seen: list[str] = []

        async def downstream(scope: Any, receive: Any, send: Any) -> None:
            seen.append(scope["type"])

        middleware = RequestSizeLimitMiddleware(downstream, settings=_settings())
        await middleware({"type": "websocket"}, None, None)  # type: ignore[arg-type]
        assert seen == ["websocket"]


class TestThroughTheRealApp:
    """End to end with every production middleware in place, so ordering
    against the BaseHTTPMiddleware layers is exercised as deployed."""

    async def test_an_oversized_chunked_body_is_refused(self, client: AsyncClient) -> None:
        limit = get_settings().MAX_REQUEST_BODY_BYTES
        response = await client.post(
            "/api/v1/auth/login", content=_chunks(limit + 1024, size=64 * 1024)
        )
        assert "content-length" not in response.request.headers
        assert response.status_code == 413
        assert response.json()["error"]["details"] == {"max_bytes": limit}
