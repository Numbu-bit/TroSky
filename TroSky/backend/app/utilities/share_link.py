"""Tokens for the live-trip links passengers share with family and friends.

``base64url(booking_id | issued_at | expires_at | mac)``: 16 bytes of
booking id, 8 of issue time (Unix milliseconds), 8 of expiry (Unix
seconds), and the first 16 bytes of an HMAC-SHA256 over them, keyed from
``SECRET_KEY`` for this purpose only. 64 characters, short enough for an
SMS. The token proves who issued it and when; whether the trip is still
worth showing, and whether the passenger has since stopped sharing it, is
checked against the booking when the link is opened.

The first links (version 1) had no issue time: 54 characters, booking id,
expiry and a MAC with a key of their own. They still open, as links made
before any "stop sharing".
"""

from __future__ import annotations

import base64
import hashlib
import hmac
import uuid
from dataclasses import dataclass
from datetime import UTC, datetime

_PURPOSE_V1 = b"trosky.trip-share.v1"
_PURPOSE = b"trosky.trip-share.v2"
_MAC_BYTES = 16
_V1_BYTES = 16 + 8 + _MAC_BYTES
_V2_BYTES = 16 + 8 + 8 + _MAC_BYTES


@dataclass(frozen=True, slots=True)
class ShareToken:
    booking_id: uuid.UUID
    # None for a version 1 link, made before links had an issue time.
    issued_at: datetime | None
    expires_at: datetime


def _key(secret: str, purpose: bytes) -> bytes:
    # A key of its own, so a share token can never pass for any other
    # HMAC-signed value made with the same secret.
    return hmac.new(secret.encode("utf-8"), purpose, hashlib.sha256).digest()


def _mac(payload: bytes, secret: str, purpose: bytes = _PURPOSE) -> bytes:
    return hmac.new(_key(secret, purpose), payload, hashlib.sha256).digest()[:_MAC_BYTES]


def _seconds(moment: datetime) -> bytes:
    return int(moment.timestamp()).to_bytes(8, "big")


def encode_share_token(
    booking_id: uuid.UUID, expires_at: datetime, secret: str, *, issued_at: datetime | None = None
) -> str:
    issued = issued_at or datetime.now(UTC)
    payload = (
        booking_id.bytes + int(issued.timestamp() * 1000).to_bytes(8, "big") + _seconds(expires_at)
    )
    raw = payload + _mac(payload, secret)
    return base64.urlsafe_b64encode(raw).decode("ascii").rstrip("=")


def decode_share_token(token: str, secret: str) -> ShareToken | None:
    """The booking and times for a genuine token, expired or not; None for
    anything malformed or forged. Never raises."""
    try:
        raw = base64.urlsafe_b64decode(token + "=" * (-len(token) % 4))
    except ValueError:
        return None
    if len(raw) == _V2_BYTES:
        payload, mac, purpose = raw[:32], raw[32:], _PURPOSE
    elif len(raw) == _V1_BYTES:
        payload, mac, purpose = raw[:24], raw[24:], _PURPOSE_V1
    else:
        return None
    if not hmac.compare_digest(mac, _mac(payload, secret, purpose)):
        return None
    booking_id = uuid.UUID(bytes=payload[:16])
    issued_at = None
    if len(payload) == 32:
        issued_at = datetime.fromtimestamp(int.from_bytes(payload[16:24], "big") / 1000, tz=UTC)
    expires_at = datetime.fromtimestamp(int.from_bytes(payload[-8:], "big"), tz=UTC)
    return ShareToken(booking_id=booking_id, issued_at=issued_at, expires_at=expires_at)
