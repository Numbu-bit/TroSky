"""Unit tests for the QR-ticket token codec (pure logic, no database)."""

from __future__ import annotations

import uuid
from datetime import UTC, datetime, timedelta

from app.utilities.ticket_qr import decode_qr_token, encode_qr_token

_SECRET = "test-signing-secret"


class TestTicketQrCodec:
    def test_roundtrip(self) -> None:
        ticket_id = uuid.uuid4()
        expires_at = datetime.now(UTC).replace(microsecond=0) + timedelta(hours=2)
        token = encode_qr_token(ticket_id, expires_at, _SECRET)
        decoded = decode_qr_token(token, _SECRET)
        assert decoded is not None
        decoded_id, decoded_expiry = decoded
        assert decoded_id == ticket_id
        assert decoded_expiry == expires_at

    def test_tampered_token_is_rejected(self) -> None:
        ticket_id = uuid.uuid4()
        expires_at = datetime.now(UTC).replace(microsecond=0) + timedelta(hours=2)
        token = encode_qr_token(ticket_id, expires_at, _SECRET)
        tampered = token[:-4] + ("A" if token[-4] != "A" else "B") + token[-3:]
        assert decode_qr_token(tampered, _SECRET) is None

    def test_wrong_secret_is_rejected(self) -> None:
        ticket_id = uuid.uuid4()
        expires_at = datetime.now(UTC).replace(microsecond=0) + timedelta(hours=2)
        token = encode_qr_token(ticket_id, expires_at, _SECRET)
        assert decode_qr_token(token, "a-different-secret") is None

    def test_garbage_input_is_rejected(self) -> None:
        assert decode_qr_token("not-a-valid-token", _SECRET) is None
        assert decode_qr_token("", _SECRET) is None

    def test_different_expiry_changes_the_signature(self) -> None:
        ticket_id = uuid.uuid4()
        expires_at = datetime.now(UTC).replace(microsecond=0)
        token_a = encode_qr_token(ticket_id, expires_at, _SECRET)
        token_b = encode_qr_token(ticket_id, expires_at + timedelta(seconds=1), _SECRET)
        assert token_a != token_b
