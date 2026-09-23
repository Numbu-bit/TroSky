"""Core cryptographic primitives: password hashing and JWT issuance/verification.

Concrete authentication flows (registration, login, session/refresh-token
persistence) live in ``app.services`` (Phase 2); this module only provides
the low-level, well-tested primitives they build on.
"""

from __future__ import annotations

import hashlib
import hmac
import secrets
import uuid
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from enum import StrEnum
from typing import Any

import jwt
from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerifyMismatchError

from app.core.config import Settings, get_settings

_password_hasher = PasswordHasher(
    time_cost=3,
    memory_cost=65536,  # 64 MiB
    parallelism=4,
    hash_len=32,
    salt_len=16,
)


# ---------------------------------------------------------------------------
# Password hashing (Argon2id)
# ---------------------------------------------------------------------------
def hash_password(plain_password: str) -> str:
    """Hash a plaintext password with Argon2id. Never log or return the input."""
    return _password_hasher.hash(plain_password)


def verify_password(plain_password: str, password_hash: str) -> bool:
    """Verify a plaintext password against a stored Argon2id hash."""
    try:
        return _password_hasher.verify(password_hash, plain_password)
    except (VerifyMismatchError, InvalidHashError):
        return False


def password_needs_rehash(password_hash: str) -> bool:
    """True if the stored hash was made with weaker-than-current parameters."""
    return _password_hasher.check_needs_rehash(password_hash)


# ---------------------------------------------------------------------------
# Secure random generation (OTPs, opaque tokens)
# ---------------------------------------------------------------------------
def generate_numeric_otp(length: int = 6) -> str:
    """Generate a cryptographically secure numeric OTP of the given length."""
    return "".join(str(secrets.randbelow(10)) for _ in range(length))


def generate_opaque_token(num_bytes: int = 32) -> str:
    """Generate a URL-safe, cryptographically secure opaque token."""
    return secrets.token_urlsafe(num_bytes)


def hash_opaque_token(token: str) -> str:
    """Hash an opaque token (e.g. refresh token) for at-rest storage.

    Refresh tokens are bearer secrets; only their hash is persisted so a
    database read (or leak) cannot be replayed as a valid token.
    """
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def hash_otp_code(code: str, settings: Settings | None = None) -> str:
    """Hash an OTP code with an HMAC keyed by the application secret.

    A plain hash of a short numeric OTP is brute-forceable offline from a
    database dump alone (only ~10^length possibilities); keying the hash
    with the application secret means an attacker also needs that secret,
    on top of the per-challenge attempt limit enforced in the OTP service.
    """
    settings = settings or get_settings()
    key = settings.SECRET_KEY.get_secret_value().encode("utf-8")
    return hmac.new(key, code.encode("utf-8"), hashlib.sha256).hexdigest()


# ---------------------------------------------------------------------------
# JWT access / refresh tokens
# ---------------------------------------------------------------------------
class TokenType(StrEnum):
    ACCESS = "access"
    REFRESH = "refresh"


@dataclass(frozen=True, slots=True)
class TokenClaims:
    """Decoded, validated claims of a TroSky-issued JWT."""

    subject_user_id: uuid.UUID
    session_id: uuid.UUID
    token_id: uuid.UUID
    token_type: TokenType
    roles: list[str]
    issued_at: datetime
    expires_at: datetime


class TokenError(Exception):
    """Raised for any token creation/validation failure."""


def _signing_key_and_algorithm(settings: Settings) -> tuple[str, str]:
    algorithm = settings.JWT_SIGNING_ALGORITHM
    if algorithm.startswith(("RS", "ES")):
        if not settings.JWT_PRIVATE_KEY:
            raise TokenError(f"{algorithm} configured but JWT_PRIVATE_KEY is not set")
        return settings.JWT_PRIVATE_KEY.get_secret_value(), algorithm
    return settings.jwt_effective_secret.get_secret_value(), algorithm


def _verification_key_and_algorithm(settings: Settings) -> tuple[str, str]:
    algorithm = settings.JWT_SIGNING_ALGORITHM
    if algorithm.startswith(("RS", "ES")):
        if not settings.JWT_PUBLIC_KEY:
            raise TokenError(f"{algorithm} configured but JWT_PUBLIC_KEY is not set")
        return settings.JWT_PUBLIC_KEY, algorithm
    return settings.jwt_effective_secret.get_secret_value(), algorithm


def create_token(
    *,
    user_id: uuid.UUID,
    session_id: uuid.UUID,
    token_type: TokenType,
    roles: list[str],
    settings: Settings | None = None,
    token_id: uuid.UUID | None = None,
    expires_delta: timedelta | None = None,
) -> tuple[str, TokenClaims]:
    """Create a signed JWT and return it alongside its decoded claims."""
    settings = settings or get_settings()
    key, algorithm = _signing_key_and_algorithm(settings)

    now = datetime.now(UTC)
    if expires_delta is None:
        ttl = (
            settings.ACCESS_TOKEN_TTL_SECONDS
            if token_type is TokenType.ACCESS
            else settings.REFRESH_TOKEN_TTL_SECONDS
        )
        expires_delta = timedelta(seconds=ttl)
    expires_at = now + expires_delta
    token_id = token_id or uuid.uuid4()

    payload: dict[str, Any] = {
        "sub": str(user_id),
        "sid": str(session_id),
        "jti": str(token_id),
        "type": token_type.value,
        "roles": roles,
        "iss": settings.JWT_ISSUER,
        "aud": settings.JWT_AUDIENCE,
        "iat": int(now.timestamp()),
        "exp": int(expires_at.timestamp()),
        "nbf": int(now.timestamp()),
    }
    token = jwt.encode(payload, key, algorithm=algorithm)
    claims = TokenClaims(
        subject_user_id=user_id,
        session_id=session_id,
        token_id=token_id,
        token_type=token_type,
        roles=roles,
        issued_at=now,
        expires_at=expires_at,
    )
    return token, claims


def decode_token(
    token: str,
    *,
    expected_type: TokenType | None = None,
    settings: Settings | None = None,
) -> TokenClaims:
    """Decode and fully validate a JWT (signature, issuer, audience, expiry)."""
    settings = settings or get_settings()
    key, algorithm = _verification_key_and_algorithm(settings)

    try:
        payload = jwt.decode(
            token,
            key,
            algorithms=[algorithm],
            issuer=settings.JWT_ISSUER,
            audience=settings.JWT_AUDIENCE,
            options={"require": ["exp", "iat", "sub", "sid", "jti", "type"]},
        )
    except jwt.ExpiredSignatureError as exc:
        raise TokenError("Token has expired") from exc
    except jwt.InvalidTokenError as exc:
        raise TokenError("Token is invalid") from exc

    token_type = TokenType(payload["type"])
    if expected_type is not None and token_type is not expected_type:
        raise TokenError(f"Expected a {expected_type.value} token, got {token_type.value}")

    try:
        return TokenClaims(
            subject_user_id=uuid.UUID(payload["sub"]),
            session_id=uuid.UUID(payload["sid"]),
            token_id=uuid.UUID(payload["jti"]),
            token_type=token_type,
            roles=list(payload.get("roles", [])),
            issued_at=datetime.fromtimestamp(payload["iat"], tz=UTC),
            expires_at=datetime.fromtimestamp(payload["exp"], tz=UTC),
        )
    except (KeyError, ValueError) as exc:
        raise TokenError("Token payload is malformed") from exc
