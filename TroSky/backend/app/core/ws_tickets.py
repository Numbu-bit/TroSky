"""One-time tickets for opening a WebSocket (B5).

A WebSocket handshake can't carry an ``Authorization`` header from a
browser, so the tracking socket used to take the access token itself as
``?token=``, where every proxy, CDN and access log on the way can record
it. Instead the client now asks for a ticket over an ordinary
authenticated request (``POST /auth/ws/ticket``) and opens the socket with
``?ticket=``. A ticket:

* is random (256 bits) and means nothing on its own;
* opens one socket: it is deleted as it is used, in one atomic step, so a
  copy read from a log afterwards opens nothing;
* dies unused after ``WS_TICKET_TTL_SECONDS`` (60 s by default);
* names the session it was issued to, so the socket is held to that
  session's checks (logout, suspension) while it stays open.

Redis keeps only a hash of each ticket, never the ticket itself.
"""

from __future__ import annotations

import hashlib
import secrets
import uuid
from dataclasses import dataclass

from redis.asyncio import Redis

from app.core.permissions import Principal

_KEY_PREFIX = "ws-ticket:"
# token_urlsafe(32) is 43 characters; anything far longer isn't ours.
_MAX_TICKET_LENGTH = 128


@dataclass(frozen=True, slots=True)
class TicketHolder:
    """Who a redeemed ticket was issued to."""

    user_id: uuid.UUID
    session_id: uuid.UUID


def _key(ticket: str) -> str:
    return _KEY_PREFIX + hashlib.sha256(ticket.encode()).hexdigest()


async def issue_ticket(redis: Redis, principal: Principal, *, ttl_seconds: int) -> str:
    """A new single-use ticket for ``principal``'s session."""
    ticket = secrets.token_urlsafe(32)
    await redis.set(_key(ticket), f"{principal.user_id}:{principal.session_id}", ex=ttl_seconds)
    return ticket


async def redeem_ticket(redis: Redis, ticket: str) -> TicketHolder | None:
    """Use up ``ticket``: who it was issued to, or ``None`` when it is
    unknown, expired or already used. The read and the delete run as one
    transaction, so two sockets racing with the same ticket can't both win.
    """
    if not ticket or len(ticket) > _MAX_TICKET_LENGTH:
        return None
    key = _key(ticket)
    async with redis.pipeline(transaction=True) as pipe:
        pipe.get(key)
        pipe.delete(key)
        stored, _deleted = await pipe.execute()
    if not stored:
        return None
    if isinstance(stored, bytes):
        stored = stored.decode()
    user_id, _, session_id = str(stored).partition(":")
    try:
        return TicketHolder(user_id=uuid.UUID(user_id), session_id=uuid.UUID(session_id))
    except ValueError:
        return None
