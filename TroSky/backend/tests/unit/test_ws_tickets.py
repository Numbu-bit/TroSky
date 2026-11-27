"""One-time WebSocket tickets (B5): issued for a session, used up by the
first socket, dead after their time, and never stored in the clear."""

from __future__ import annotations

import asyncio
import uuid

import pytest
from fakeredis import FakeAsyncRedis

from app.core.permissions import Principal
from app.core.ws_tickets import TicketHolder, issue_ticket, redeem_ticket

pytestmark = pytest.mark.asyncio


def _principal() -> Principal:
    return Principal(user_id=uuid.uuid4(), session_id=uuid.uuid4(), roles=frozenset({"passenger"}))


@pytest.fixture
async def redis():
    client = FakeAsyncRedis(decode_responses=True)
    yield client
    await client.aclose()


async def test_a_ticket_names_the_session_it_was_issued_to(redis) -> None:
    principal = _principal()
    ticket = await issue_ticket(redis, principal, ttl_seconds=60)

    holder = await redeem_ticket(redis, ticket)

    assert holder == TicketHolder(user_id=principal.user_id, session_id=principal.session_id)


async def test_a_ticket_opens_one_socket_only(redis) -> None:
    ticket = await issue_ticket(redis, _principal(), ttl_seconds=60)

    assert await redeem_ticket(redis, ticket) is not None
    assert await redeem_ticket(redis, ticket) is None


async def test_two_sockets_racing_with_one_ticket_cannot_both_win(redis) -> None:
    ticket = await issue_ticket(redis, _principal(), ttl_seconds=60)

    results = await asyncio.gather(*(redeem_ticket(redis, ticket) for _ in range(5)))

    assert sum(result is not None for result in results) == 1


async def test_unknown_empty_and_oversized_tickets_open_nothing(redis) -> None:
    await issue_ticket(redis, _principal(), ttl_seconds=60)

    assert await redeem_ticket(redis, "not-a-ticket") is None
    assert await redeem_ticket(redis, "") is None
    assert await redeem_ticket(redis, "x" * 500) is None


async def test_a_ticket_expires_unused(redis) -> None:
    ticket = await issue_ticket(redis, _principal(), ttl_seconds=60)

    (key,) = await redis.keys("ws-ticket:*")
    assert 0 < await redis.ttl(key) <= 60
    await redis.delete(key)  # what expiry does
    assert await redeem_ticket(redis, ticket) is None


async def test_redis_holds_a_hash_not_the_ticket(redis) -> None:
    ticket = await issue_ticket(redis, _principal(), ttl_seconds=60)

    (key,) = await redis.keys("ws-ticket:*")
    assert ticket not in key
    assert ticket not in await redis.get(key)


async def test_every_ticket_is_different(redis) -> None:
    principal = _principal()
    tickets = {await issue_ticket(redis, principal, ttl_seconds=60) for _ in range(20)}

    assert len(tickets) == 20
    assert all(len(ticket) >= 40 for ticket in tickets)
