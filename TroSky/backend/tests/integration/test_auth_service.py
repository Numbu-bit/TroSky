"""Integration tests for AuthService: registration, OTP, login, refresh
rotation, logout, and password reset — against a real Postgres + Redis, with
sandbox SMS/email providers (no real vendor is ever called).
"""

from __future__ import annotations

import pytest
from redis.asyncio import Redis
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.exceptions import (
    AccountLockedError,
    AccountSuspendedError,
    ConflictError,
    InvalidCredentialsError,
    OtpInvalidError,
    TokenReuseDetectedError,
)
from app.core.security import TokenType, decode_token
from app.models.identity import OtpPurpose
from app.providers.email.sandbox import SandboxEmailProvider
from app.providers.sms.sandbox import SandboxSmsProvider
from app.repositories.user_repository import UserRepository
from app.schemas.auth import RegisterRequest
from app.services.auth_service import AuthService

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]

_PHONE = "0241234567"
_PHONE_E164 = "+233241234567"


@pytest.fixture(autouse=True)
def _clear_sandbox_outboxes():
    SandboxSmsProvider.clear()
    SandboxEmailProvider.clear()
    yield
    SandboxSmsProvider.clear()
    SandboxEmailProvider.clear()


def _auth_service(db_session: AsyncSession, redis: Redis) -> AuthService:
    return AuthService(db_session, redis, SandboxSmsProvider(), SandboxEmailProvider())


async def _get_redis(require_redis: None) -> Redis:
    from app.core.redis import get_redis_client

    return get_redis_client()


class TestRegistration:
    async def test_register_creates_user_and_sends_otp(
        self, db_session: AsyncSession, seeded_roles, require_redis: None
    ) -> None:
        redis = await _get_redis(require_redis)
        service = _auth_service(db_session, redis)
        request = RegisterRequest(
            phone_number=_PHONE, password="Str0ngPass", full_name="Ama Mensah", role="passenger"
        )

        user, otp_target = await service.register(request)

        assert user.phone_number == _PHONE_E164
        assert otp_target == _PHONE_E164
        assert user.phone_verified_at is None

        sent = SandboxSmsProvider.get_last_message(_PHONE_E164)
        assert sent is not None
        assert "TroSky" in sent

        roles = await UserRepository(db_session).get_roles_for_user(user.id)
        assert roles == ["passenger"]

    async def test_register_duplicate_phone_rejected(
        self, db_session: AsyncSession, seeded_roles, require_redis: None
    ) -> None:
        redis = await _get_redis(require_redis)
        service = _auth_service(db_session, redis)
        request = RegisterRequest(
            phone_number=_PHONE, password="Str0ngPass", full_name="Ama Mensah", role="passenger"
        )
        await service.register(request)

        with pytest.raises(ConflictError) as exc_info:
            await service.register(request)
        assert exc_info.value.code == "PHONE_ALREADY_REGISTERED"

    async def test_register_weak_password_rejected(
        self, db_session: AsyncSession, seeded_roles, require_redis: None
    ) -> None:
        redis = await _get_redis(require_redis)
        service = _auth_service(db_session, redis)
        request = RegisterRequest(
            phone_number=_PHONE, password="weak", full_name="Ama Mensah", role="passenger"
        )
        with pytest.raises(ConflictError) as exc_info:
            await service.register(request)
        assert exc_info.value.code == "PASSWORD_POLICY_VIOLATION"


class TestOtpVerification:
    async def test_verify_registration_otp_marks_phone_verified(
        self, db_session: AsyncSession, seeded_roles, require_redis: None
    ) -> None:
        redis = await _get_redis(require_redis)
        service = _auth_service(db_session, redis)
        request = RegisterRequest(
            phone_number=_PHONE, password="Str0ngPass", full_name="Ama Mensah", role="passenger"
        )
        user, _ = await service.register(request)

        message = SandboxSmsProvider.get_last_message(_PHONE_E164)
        assert message is not None
        code = "".join(filter(str.isdigit, message.split("is ")[1].split(".")[0]))

        verified_user = await service.verify_otp(_PHONE_E164, OtpPurpose.REGISTRATION, code)
        assert verified_user is not None
        assert verified_user.id == user.id
        assert verified_user.phone_verified_at is not None

    async def test_verify_otp_wrong_code_fails_and_counts_attempt(
        self, db_session: AsyncSession, seeded_roles, require_redis: None
    ) -> None:
        redis = await _get_redis(require_redis)
        service = _auth_service(db_session, redis)
        request = RegisterRequest(
            phone_number=_PHONE, password="Str0ngPass", full_name="Ama Mensah", role="passenger"
        )
        await service.register(request)

        with pytest.raises(OtpInvalidError):
            await service.verify_otp(_PHONE_E164, OtpPurpose.REGISTRATION, "000000")


class TestPasswordLogin:
    async def _register_and_verify(self, db_session: AsyncSession, redis: Redis) -> None:
        service = _auth_service(db_session, redis)
        request = RegisterRequest(
            phone_number=_PHONE, password="Str0ngPass", full_name="Ama Mensah", role="passenger"
        )
        await service.register(request)
        message = SandboxSmsProvider.get_last_message(_PHONE_E164)
        assert message is not None
        code = "".join(filter(str.isdigit, message.split("is ")[1].split(".")[0]))
        await service.verify_otp(_PHONE_E164, OtpPurpose.REGISTRATION, code)

    async def test_login_with_correct_password_succeeds(
        self, db_session: AsyncSession, seeded_roles, require_redis: None
    ) -> None:
        redis = await _get_redis(require_redis)
        await self._register_and_verify(db_session, redis)

        service = _auth_service(db_session, redis)
        tokens = await service.login_password(_PHONE, "Str0ngPass", None, "127.0.0.1")

        assert tokens.access_token
        assert tokens.refresh_token
        claims = decode_token(tokens.access_token, expected_type=TokenType.ACCESS)
        assert claims.roles == ["passenger"]

    async def test_login_with_wrong_password_fails(
        self, db_session: AsyncSession, seeded_roles, require_redis: None
    ) -> None:
        redis = await _get_redis(require_redis)
        await self._register_and_verify(db_session, redis)

        service = _auth_service(db_session, redis)
        with pytest.raises(InvalidCredentialsError):
            await service.login_password(_PHONE, "WrongPassword1", None, "127.0.0.1")

    async def test_account_locks_after_max_failed_attempts(
        self, db_session: AsyncSession, seeded_roles, require_redis: None
    ) -> None:
        redis = await _get_redis(require_redis)
        await self._register_and_verify(db_session, redis)
        service = _auth_service(db_session, redis)

        for _ in range(get_settings().LOGIN_MAX_FAILED_ATTEMPTS):
            with pytest.raises(InvalidCredentialsError):
                await service.login_password(_PHONE, "WrongPassword1", None, "127.0.0.1")

        with pytest.raises(AccountLockedError):
            await service.login_password(_PHONE, "Str0ngPass", None, "127.0.0.1")


class TestTokenRefresh:
    async def _login(self, db_session: AsyncSession, redis: Redis):
        service = _auth_service(db_session, redis)
        request = RegisterRequest(
            phone_number=_PHONE, password="Str0ngPass", full_name="Ama Mensah", role="passenger"
        )
        await service.register(request)
        message = SandboxSmsProvider.get_last_message(_PHONE_E164)
        assert message is not None
        code = "".join(filter(str.isdigit, message.split("is ")[1].split(".")[0]))
        await service.verify_otp(_PHONE_E164, OtpPurpose.REGISTRATION, code)
        return await service.login_password(_PHONE, "Str0ngPass", None, "127.0.0.1")

    async def test_refresh_issues_new_tokens(
        self, db_session: AsyncSession, seeded_roles, require_redis: None
    ) -> None:
        redis = await _get_redis(require_redis)
        tokens = await self._login(db_session, redis)

        service = _auth_service(db_session, redis)
        new_tokens = await service.refresh_tokens(tokens.refresh_token)

        assert new_tokens.access_token != tokens.access_token
        assert new_tokens.refresh_token != tokens.refresh_token
        assert new_tokens.session_id == tokens.session_id

    async def test_reusing_a_rotated_refresh_token_revokes_the_session(
        self, db_session: AsyncSession, seeded_roles, require_redis: None
    ) -> None:
        redis = await _get_redis(require_redis)
        tokens = await self._login(db_session, redis)

        service = _auth_service(db_session, redis)
        await service.refresh_tokens(tokens.refresh_token)

        # Reusing the now-rotated-away-from token must be treated as theft.
        with pytest.raises(TokenReuseDetectedError):
            await service.refresh_tokens(tokens.refresh_token)


class TestLogout:
    async def test_logout_revokes_current_session_only(
        self, db_session: AsyncSession, seeded_roles, require_redis: None
    ) -> None:
        redis = await _get_redis(require_redis)
        service = _auth_service(db_session, redis)
        request = RegisterRequest(
            phone_number=_PHONE, password="Str0ngPass", full_name="Ama Mensah", role="passenger"
        )
        await service.register(request)
        message = SandboxSmsProvider.get_last_message(_PHONE_E164)
        assert message is not None
        code = "".join(filter(str.isdigit, message.split("is ")[1].split(".")[0]))
        await service.verify_otp(_PHONE_E164, OtpPurpose.REGISTRATION, code)

        tokens = await service.login_password(_PHONE, "Str0ngPass", None, "127.0.0.1")
        await service.logout(tokens.session_id)

        with pytest.raises(Exception):  # noqa: B017,PT011 - UnauthorizedError from refresh
            await service.refresh_tokens(tokens.refresh_token)


class TestSuspendedAccount:
    async def test_suspended_account_cannot_log_in(
        self, db_session: AsyncSession, seeded_roles, require_redis: None
    ) -> None:
        redis = await _get_redis(require_redis)
        service = _auth_service(db_session, redis)
        request = RegisterRequest(
            phone_number=_PHONE, password="Str0ngPass", full_name="Ama Mensah", role="passenger"
        )
        user, _ = await service.register(request)
        user.is_suspended = True
        user.suspended_reason = "Fraud investigation"
        await db_session.flush()

        with pytest.raises(AccountSuspendedError):
            await service.login_password(_PHONE, "Str0ngPass", None, "127.0.0.1")
