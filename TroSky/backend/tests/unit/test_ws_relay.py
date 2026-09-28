"""Unit tests for the tracking WebSocket's relay loop.

``relay_while_authorized`` is what keeps an *open* socket honest: HTTP gets
re-authorized on every request, a socket never would be. These tests drive
the loop with in-memory fakes, so the timing behaviour is checked without a
database, Redis or a real connection.
"""

from __future__ import annotations

import asyncio
from typing import Any

import pytest
from fastapi import WebSocketException, status

from app.api.v1.tracking import relay_while_authorized

pytestmark = pytest.mark.asyncio


class FakePubSub:
    def __init__(self, messages: list[dict[str, Any]] | None = None) -> None:
        self._messages = list(messages or [])

    # Mirrors redis-py's PubSub.get_message, which takes ``timeout``.
    async def get_message(
        self,
        ignore_subscribe_messages: bool = False,
        timeout: float = 0.0,  # noqa: ASYNC109
    ) -> dict[str, Any] | None:
        if self._messages:
            return self._messages.pop(0)
        await asyncio.sleep(timeout)
        return None


class FakeWebSocket:
    def __init__(self, *, expect_sends: int = 0) -> None:
        self.sent: list[str] = []
        self.closed: tuple[int, str | None] | None = None
        self._inbox: asyncio.Queue[dict[str, Any]] = asyncio.Queue()
        self._expect_sends = expect_sends
        self.delivered = asyncio.Event()

    async def receive(self) -> dict[str, Any]:
        return await self._inbox.get()

    def client_says(self, message: dict[str, Any]) -> None:
        self._inbox.put_nowait(message)

    async def send_text(self, data: str) -> None:
        self.sent.append(data)
        if len(self.sent) >= self._expect_sends:
            self.delivered.set()

    async def close(self, code: int = 1000, reason: str | None = None) -> None:
        self.closed = (code, reason)


def _update(data: str) -> dict[str, Any]:
    return {"type": "message", "data": data}


async def _always_allowed() -> None:
    return None


async def _run(coro: Any, *, within: float = 2.0) -> None:
    await asyncio.wait_for(coro, timeout=within)


class TestRelay:
    async def test_published_updates_reach_the_client(self) -> None:
        ws = FakeWebSocket(expect_sends=2)
        relay = asyncio.ensure_future(
            relay_while_authorized(
                ws,  # type: ignore[arg-type]
                FakePubSub([_update("a"), _update("b")]),  # type: ignore[arg-type]
                reauthorize=_always_allowed,
                recheck_seconds=60,
                poll_seconds=0.005,
            )
        )
        await asyncio.wait_for(ws.delivered.wait(), timeout=1.0)
        ws.client_says({"type": "websocket.disconnect", "code": 1000})
        await _run(relay)
        assert ws.sent == ["a", "b"]

    async def test_a_refused_recheck_closes_the_socket_with_its_reason(self) -> None:
        """The core of the fix: an already-open socket loses access when the
        session is revoked, instead of streaming until the client leaves."""

        async def revoked() -> None:
            raise WebSocketException(
                code=status.WS_1008_POLICY_VIOLATION, reason="This session has been revoked."
            )

        ws = FakeWebSocket()
        await _run(
            relay_while_authorized(
                ws,  # type: ignore[arg-type]
                FakePubSub(),  # type: ignore[arg-type]
                reauthorize=revoked,
                recheck_seconds=0.01,
                poll_seconds=0.005,
            )
        )
        assert ws.closed == (status.WS_1008_POLICY_VIOLATION, "This session has been revoked.")

    async def test_access_is_rechecked_repeatedly_while_it_holds(self) -> None:
        checks = 0

        async def counting() -> None:
            nonlocal checks
            checks += 1

        ws = FakeWebSocket()
        relay = asyncio.ensure_future(
            relay_while_authorized(
                ws,  # type: ignore[arg-type]
                FakePubSub(),  # type: ignore[arg-type]
                reauthorize=counting,
                recheck_seconds=0.02,
                poll_seconds=0.005,
            )
        )
        await asyncio.sleep(0.2)
        ws.client_says({"type": "websocket.disconnect", "code": 1000})
        await _run(relay)
        assert checks >= 3
        assert ws.closed is None

    async def test_a_client_that_leaves_ends_the_loop_without_further_checks(self) -> None:
        """A dropped client must not keep costing a database check every
        interval on behalf of a connection that no longer exists."""
        checks = 0

        async def counting() -> None:
            nonlocal checks
            checks += 1

        ws = FakeWebSocket()
        ws.client_says({"type": "websocket.disconnect", "code": 1001})
        await _run(
            relay_while_authorized(
                ws,  # type: ignore[arg-type]
                FakePubSub(),  # type: ignore[arg-type]
                reauthorize=counting,
                recheck_seconds=0.01,
                poll_seconds=0.005,
            ),
            within=1.0,
        )
        assert checks == 0
        assert ws.closed is None

    async def test_client_chatter_does_not_end_the_stream(self) -> None:
        ws = FakeWebSocket(expect_sends=1)
        ws.client_says({"type": "websocket.receive", "text": "ping"})
        relay = asyncio.ensure_future(
            relay_while_authorized(
                ws,  # type: ignore[arg-type]
                FakePubSub([_update("after-ping")]),  # type: ignore[arg-type]
                reauthorize=_always_allowed,
                recheck_seconds=60,
                poll_seconds=0.005,
            )
        )
        await asyncio.wait_for(ws.delivered.wait(), timeout=1.0)
        assert not relay.done()
        ws.client_says({"type": "websocket.disconnect", "code": 1000})
        await _run(relay)
        assert ws.sent == ["after-ping"]
