"""Tokens for the live-trip links passengers share with family and friends.

``base64url(booking_id | expires_at | mac)``: 16 bytes of booking id, 8 of
expiry (Unix seconds), and the first 16 bytes of an HMAC-SHA256 over both,
keyed from ``SECRET_KEY`` for this purpose only. 54 characters, short
enough for an SMS. The token proves who issued it and when it expires;
whether the trip is still worth showing is checked against the booking
when the link is opened.
"""

from __future__ import annotations

import base64
import hashlib
import hmac
import uuid
from datetime import UTC, datetime

_PURPOSE = b"trosky.trip-share.v1"
_MAC_BYTES = 16


def _key(secret: str) -> bytes:
    # A key of its own, so a share token can never pass for any other
    # HMAC-signed value made with the same secret.
    return hmac.new(secret.encode("utf-8"), _PURPOSE, hashlib.sha256).digest()


def _mac(payload: bytes, secret: str) -> bytes:
    return hmac.new(_key(secret), payload, hashlib.sha256).digest()[:_MAC_BYTES]


def encode_share_token(booking_id: uuid.UUID, expires_at: datetime, secret: str) -> str:
    payload = booking_id.bytes + int(expires_at.timestamp()).to_bytes(8, "big")
    raw = payload + _mac(payload, secret)
    return base64.urlsafe_b64encode(raw).decode("ascii").rstrip("=")


def decode_share_token(token: str, secret: str) -> tuple[uuid.UUID, datetime] | None:
    """``(booking_id, expires_at)`` for a genuine token, expired or not;
    None for anything malformed or forged. Never raises."""
    try:
        raw = base64.urlsafe_b64decode(token + "=" * (-len(token) % 4))
    except ValueError:
        return None
    if len(raw) != 16 + 8 + _MAC_BYTES:
        return None
    payload, mac = raw[:24], raw[24:]
    if not hmac.compare_digest(mac, _mac(payload, secret)):
        return None
    booking_id = uuid.UUID(bytes=payload[:16])
    expires_at = datetime.fromtimestamp(int.from_bytes(payload[16:], "big"), tz=UTC)
    return booking_id, expires_at
