"""QR-ticket token codec: encode/decode the compact, HMAC-signed string a
ticket's QR code encodes.

The token is fully self-verifying and carries no database lookup
requirement to *check its integrity* (only to check the ticket's current
*status*, which is a separate, deliberate concern — see
``TicketService.validate_qr``): ``base64url(ticket_id | expires_at |
signature)`` where ``signature = HMAC-SHA256(TICKET_QR_SIGNING_SECRET,
"ticket_id|expires_at")``. A forged or tampered token fails the signature
check before any database round trip happens.
"""

from __future__ import annotations

import base64
import hashlib
import hmac
import uuid
from datetime import UTC, datetime

_SEPARATOR = "|"


def _sign(ticket_id: uuid.UUID, expires_at: datetime, secret: str) -> str:
    payload = f"{ticket_id}{_SEPARATOR}{int(expires_at.timestamp())}"
    return hmac.new(secret.encode("utf-8"), payload.encode("utf-8"), hashlib.sha256).hexdigest()


def encode_qr_token(ticket_id: uuid.UUID, expires_at: datetime, secret: str) -> str:
    signature = _sign(ticket_id, expires_at, secret)
    raw = f"{ticket_id}{_SEPARATOR}{int(expires_at.timestamp())}{_SEPARATOR}{signature}"
    return base64.urlsafe_b64encode(raw.encode("utf-8")).decode("ascii").rstrip("=")


def decode_qr_token(token: str, secret: str) -> tuple[uuid.UUID, datetime] | None:
    """Returns ``(ticket_id, expires_at)`` if the token is well-formed and
    its signature is valid, else ``None``. Never raises — a malformed or
    forged token is an expected input, not an exceptional one."""
    try:
        padded = token + "=" * (-len(token) % 4)
        raw = base64.urlsafe_b64decode(padded.encode("ascii")).decode("utf-8")
        ticket_id_str, expires_at_str, signature = raw.split(_SEPARATOR)
        ticket_id = uuid.UUID(ticket_id_str)
        expires_at = datetime.fromtimestamp(int(expires_at_str), tz=UTC)
    except (ValueError, UnicodeDecodeError):
        return None

    expected_signature = _sign(ticket_id, expires_at, secret)
    if not hmac.compare_digest(signature, expected_signature):
        return None
    return ticket_id, expires_at
