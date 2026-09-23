"""Unit tests for core cryptographic primitives (no external services)."""

from __future__ import annotations

import uuid
from datetime import timedelta

import pytest

from app.core.security import (
    TokenError,
    TokenType,
    create_token,
    decode_token,
    generate_numeric_otp,
    generate_opaque_token,
    hash_opaque_token,
    hash_password,
    verify_password,
)


class TestPasswordHashing:
    def test_hash_is_not_the_plaintext(self) -> None:
        hashed = hash_password("correct horse battery staple")
        assert hashed != "correct horse battery staple"
        assert hashed.startswith("$argon2id$")

    def test_verify_succeeds_for_correct_password(self) -> None:
        hashed = hash_password("correct horse battery staple")
        assert verify_password("correct horse battery staple", hashed) is True

    def test_verify_fails_for_incorrect_password(self) -> None:
        hashed = hash_password("correct horse battery staple")
        assert verify_password("wrong password", hashed) is False

    def test_verify_fails_gracefully_on_malformed_hash(self) -> None:
        assert verify_password("anything", "not-a-real-hash") is False

    def test_two_hashes_of_same_password_differ(self) -> None:
        # Argon2id salts each hash independently.
        assert hash_password("same-password") != hash_password("same-password")


class TestOtpAndTokens:
    def test_otp_has_requested_length_and_is_numeric(self) -> None:
        otp = generate_numeric_otp(6)
        assert len(otp) == 6
        assert otp.isdigit()

    def test_otp_generation_is_not_constant(self) -> None:
        otps = {generate_numeric_otp(6) for _ in range(20)}
        assert len(otps) > 1

    def test_opaque_token_hash_is_deterministic_and_one_way(self) -> None:
        token = generate_opaque_token()
        assert hash_opaque_token(token) == hash_opaque_token(token)
        assert hash_opaque_token(token) != token


class TestJwt:
    def test_create_and_decode_access_token_round_trips(self) -> None:
        user_id, session_id = uuid.uuid4(), uuid.uuid4()
        token, claims = create_token(
            user_id=user_id,
            session_id=session_id,
            token_type=TokenType.ACCESS,
            roles=["passenger"],
        )
        decoded = decode_token(token, expected_type=TokenType.ACCESS)
        assert decoded.subject_user_id == user_id
        assert decoded.session_id == session_id
        assert decoded.token_id == claims.token_id
        assert decoded.roles == ["passenger"]

    def test_decode_rejects_wrong_token_type(self) -> None:
        user_id, session_id = uuid.uuid4(), uuid.uuid4()
        token, _ = create_token(
            user_id=user_id, session_id=session_id, token_type=TokenType.REFRESH, roles=[]
        )
        with pytest.raises(TokenError):
            decode_token(token, expected_type=TokenType.ACCESS)

    def test_decode_rejects_expired_token(self) -> None:
        user_id, session_id = uuid.uuid4(), uuid.uuid4()
        token, _ = create_token(
            user_id=user_id,
            session_id=session_id,
            token_type=TokenType.ACCESS,
            roles=[],
            expires_delta=timedelta(seconds=-1),
        )
        with pytest.raises(TokenError):
            decode_token(token, expected_type=TokenType.ACCESS)

    def test_decode_rejects_tampered_signature(self) -> None:
        user_id, session_id = uuid.uuid4(), uuid.uuid4()
        token, _ = create_token(
            user_id=user_id, session_id=session_id, token_type=TokenType.ACCESS, roles=[]
        )
        tampered = token[:-4] + ("AAAA" if token[-4:] != "AAAA" else "BBBB")
        with pytest.raises(TokenError):
            decode_token(tampered, expected_type=TokenType.ACCESS)

    def test_decode_rejects_malformed_token(self) -> None:
        with pytest.raises(TokenError):
            decode_token("not-a-jwt-at-all", expected_type=TokenType.ACCESS)
