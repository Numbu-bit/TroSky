"""Integration tests for AuthService: registration, OTP, login, refresh
rotation, logout, and password reset — against a real Postgres + Redis, with
sandbox SMS/email providers (no real vendor is ever called).
"""

from __future__ import annotations

import asyncio

import pytest
from redis.asyncio import Redis
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.background import drain_background_jobs
from app.core.config import get_settings
from app.core.exceptions import (
    AccountLockedError,
    AccountNotVerifiedError,
    AccountSuspendedError,
    ConflictError,
    InvalidCredentialsError,
    OtpInvalidError,
    ProviderError,
    RateLimitExceededError,
    TokenReuseDetectedError,
    ValidationAppError,
)
from app.core.security import TokenType, decode_token
from app.models.identity import DevicePlatform, OtpChannel, OtpPurpose
from app.providers.email.sandbox import SandboxEmailProvider
from app.providers.sms.sandbox import SandboxSmsProvider
from app.repositories.otp_repository import OtpRepository
from app.repositories.profile_repository import DeviceRepository
from app.repositories.user_repository import UserRepository
from app.schemas.auth import DeviceContext, RegisterRequest
from app.services.auth_service import AuthService

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]

_PHONE = "0241234567"
_PHONE_E164 = "+233241234567"
_EMAIL = "ama.mensah@example.com"
_UNREGISTERED = "0209876543"
_UNREGISTERED_E164 = "+233209876543"


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
        # Long enough to pass the schema's length check, so it's the
        # service's policy (no uppercase, no digit) that rejects it.
        request = RegisterRequest(
            phone_number=_PHONE, password="weakpassword", full_name="Ama Mensah", role="passenger"
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


def _code_from(message: str | None) -> str:
    assert message is not None
    return "".join(filter(str.isdigit, message.split("is ")[1].split(".")[0]))


def _ama() -> RegisterRequest:
    return RegisterRequest(
        phone_number=_PHONE, password="Str0ngPass", full_name="Ama Mensah", role="passenger"
    )


class TestOtpTargetSpelling:
    """A number means the same account however it is written."""

    async def test_login_code_requested_as_local_number_works_as_international(
        self, db_session: AsyncSession, seeded_roles, require_redis: None
    ) -> None:
        service = _auth_service(db_session, await _get_redis(require_redis))
        user, _ = await service.register(_ama())
        SandboxSmsProvider.clear()  # drop the registration code

        await service.resend_otp(_PHONE, OtpPurpose.LOGIN, OtpChannel.SMS)
        code = _code_from(SandboxSmsProvider.get_last_message(_PHONE_E164))

        tokens = await service.login_otp(_PHONE_E164, code, None, "127.0.0.1")
        claims = decode_token(tokens.access_token, expected_type=TokenType.ACCESS)
        assert claims.subject_user_id == user.id

    async def test_registration_code_verifies_with_the_local_number(
        self, db_session: AsyncSession, seeded_roles, require_redis: None
    ) -> None:
        service = _auth_service(db_session, await _get_redis(require_redis))
        await service.register(_ama())
        code = _code_from(SandboxSmsProvider.get_last_message(_PHONE_E164))

        verified_user = await service.verify_otp(_PHONE, OtpPurpose.REGISTRATION, code)
        assert verified_user is not None
        assert verified_user.phone_verified_at is not None

    async def test_resend_cooldown_cannot_be_dodged_by_respelling_the_number(
        self, db_session: AsyncSession, seeded_roles, require_redis: None
    ) -> None:
        service = _auth_service(db_session, await _get_redis(require_redis))
        await service.register(_ama())

        await service.resend_otp(_PHONE, OtpPurpose.LOGIN, OtpChannel.SMS)
        with pytest.raises(RateLimitExceededError):
            await service.resend_otp(_PHONE_E164, OtpPurpose.LOGIN, OtpChannel.SMS)


class TestResendToUnregisteredTarget:
    async def test_no_code_is_created_or_sent(
        self, db_session: AsyncSession, seeded_roles, require_redis: None
    ) -> None:
        service = _auth_service(db_session, await _get_redis(require_redis))

        await service.resend_otp(_UNREGISTERED, OtpPurpose.REGISTRATION, OtpChannel.SMS)

        assert SandboxSmsProvider.get_sent_messages(_UNREGISTERED_E164) == []
        assert SandboxSmsProvider.get_sent_messages(_UNREGISTERED) == []
        challenge = await OtpRepository(db_session).get_latest_active_challenge(
            _UNREGISTERED_E164, OtpPurpose.REGISTRATION
        )
        assert challenge is None

    async def test_the_cooldown_still_applies_so_it_looks_like_a_real_request(
        self, db_session: AsyncSession, seeded_roles, require_redis: None
    ) -> None:
        service = _auth_service(db_session, await _get_redis(require_redis))

        await service.resend_otp(_UNREGISTERED, OtpPurpose.LOGIN, OtpChannel.SMS)
        with pytest.raises(RateLimitExceededError):
            await service.resend_otp(_UNREGISTERED, OtpPurpose.LOGIN, OtpChannel.SMS)


class TestLoginDevice:
    async def test_push_token_sent_at_login_is_registered(
        self, db_session: AsyncSession, seeded_roles, require_redis: None
    ) -> None:
        service = _auth_service(db_session, await _get_redis(require_redis))
        user, _ = await service.register(_ama())

        await service.login_password(
            _PHONE,
            "Str0ngPass",
            DeviceContext(
                device_id="phone-1", platform=DevicePlatform.ANDROID, push_token="push-abc"
            ),
            "127.0.0.1",
        )

        [device] = await DeviceRepository(db_session).list_active_for_user(user.id)
        assert device.device_id == "phone-1"
        assert device.push_token == "push-abc"

    async def test_login_without_a_push_token_keeps_the_one_registered_earlier(
        self, db_session: AsyncSession, seeded_roles, require_redis: None
    ) -> None:
        service = _auth_service(db_session, await _get_redis(require_redis))
        user, _ = await service.register(_ama())
        devices = DeviceRepository(db_session)
        await devices.upsert(
            user_id=user.id,
            device_id="phone-1",
            platform=DevicePlatform.ANDROID,
            push_token="push-abc",
        )

        await service.login_password(
            _PHONE,
            "Str0ngPass",
            DeviceContext(device_id="phone-1", platform=DevicePlatform.ANDROID),
            "127.0.0.1",
        )

        [device] = await devices.list_active_for_user(user.id)
        assert device.push_token == "push-abc"


def _email_mode(db_session: AsyncSession, redis: Redis, email_provider=None) -> AuthService:
    """An AuthService configured with OTP_DELIVERY_CHANNEL=email."""
    settings = get_settings().model_copy(update={"OTP_DELIVERY_CHANNEL": "email"})
    return AuthService(
        db_session,
        redis,
        SandboxSmsProvider(),
        email_provider or SandboxEmailProvider(),
        settings,
    )


def _ama_with_email() -> RegisterRequest:
    return RegisterRequest(
        phone_number=_PHONE,
        email=_EMAIL,
        password="Str0ngPass",
        full_name="Ama Mensah",
        role="passenger",
    )


def _emailed_code(to: str) -> str:
    sent = SandboxEmailProvider.get_last_email(to)
    assert sent is not None, f"no email sent to {to}"
    return _code_from(sent.body_text)


class _UnreachableMailServer:
    async def send_email(
        self, to: str, subject: str, body_text: str, body_html: str | None = None
    ) -> None:
        raise ProviderError("Failed to send email via SMTP.")


class TestCodesByEmail:
    """OTP_DELIVERY_CHANNEL=email: no code ever goes by SMS."""

    async def test_registration_requires_an_email_address(
        self, db_session: AsyncSession, seeded_roles, require_redis: None
    ) -> None:
        service = _email_mode(db_session, await _get_redis(require_redis))
        with pytest.raises(ValidationAppError) as exc_info:
            await service.register(_ama())
        assert exc_info.value.code == "EMAIL_REQUIRED"

    async def test_registration_code_is_emailed_and_verifies_the_email(
        self, db_session: AsyncSession, seeded_roles, require_redis: None
    ) -> None:
        service = _email_mode(db_session, await _get_redis(require_redis))
        _, otp_target = await service.register(_ama_with_email())

        assert otp_target == _EMAIL
        assert SandboxSmsProvider.get_sent_messages(_PHONE_E164) == []
        assert len(SandboxEmailProvider.get_sent_emails(_EMAIL)) == 1  # one code, not two

        verified = await service.verify_otp(_EMAIL, OtpPurpose.REGISTRATION, _emailed_code(_EMAIL))
        assert verified is not None
        assert verified.email_verified_at is not None

    async def test_login_code_asked_for_by_phone_number_is_emailed(
        self, db_session: AsyncSession, seeded_roles, require_redis: None
    ) -> None:
        service = _email_mode(db_session, await _get_redis(require_redis))
        user, _ = await service.register(_ama_with_email())
        SandboxEmailProvider.clear()  # drop the registration code

        # The app's default channel is sms; email mode overrides it.
        await service.resend_otp(_PHONE, OtpPurpose.LOGIN, OtpChannel.SMS)

        assert SandboxSmsProvider.get_sent_messages(_PHONE_E164) == []
        tokens = await service.login_otp(_PHONE, _emailed_code(_EMAIL), None, "127.0.0.1")
        claims = decode_token(tokens.access_token, expected_type=TokenType.ACCESS)
        assert claims.subject_user_id == user.id

    async def test_password_reset_asked_for_by_phone_number_is_emailed(
        self, db_session: AsyncSession, seeded_roles, require_redis: None
    ) -> None:
        service = _email_mode(db_session, await _get_redis(require_redis))
        await service.register(_ama_with_email())
        SandboxEmailProvider.clear()

        await service.forgot_password(_PHONE)

        sent = SandboxEmailProvider.get_last_email(_EMAIL)
        assert sent is not None
        assert sent.subject == "Reset your TroSky password"
        assert SandboxSmsProvider.get_sent_messages(_PHONE_E164) == []

    async def test_an_account_without_email_is_sent_nothing(
        self, db_session: AsyncSession, seeded_roles, require_redis: None
    ) -> None:
        redis = await _get_redis(require_redis)
        await _auth_service(db_session, redis).register(_ama())  # registered before the switch
        SandboxSmsProvider.clear()

        await _email_mode(db_session, redis).resend_otp(_PHONE, OtpPurpose.LOGIN, OtpChannel.SMS)

        assert SandboxSmsProvider.get_sent_messages(_PHONE_E164) == []
        challenge = await OtpRepository(db_session).get_latest_active_challenge(
            _PHONE_E164, OtpPurpose.LOGIN
        )
        assert challenge is None

    async def test_a_failed_email_does_not_leave_the_user_waiting_out_the_cooldown(
        self, db_session: AsyncSession, seeded_roles, require_redis: None
    ) -> None:
        redis = await _get_redis(require_redis)
        await _auth_service(db_session, redis).register(_ama_with_email())
        broken = _email_mode(db_session, redis, email_provider=_UnreachableMailServer())

        with pytest.raises(ProviderError):
            await broken.resend_otp(_PHONE, OtpPurpose.LOGIN, OtpChannel.EMAIL)
        # Asking again straight away reaches the mail server again, rather
        # than being told to wait for a code that never arrived.
        with pytest.raises(ProviderError):
            await broken.resend_otp(_PHONE, OtpPurpose.LOGIN, OtpChannel.EMAIL)


class TestCodeChannelFollowsWhatItVerifies:
    async def test_an_email_verification_code_goes_to_the_email_even_if_sms_is_asked_for(
        self, db_session: AsyncSession, seeded_roles, require_redis: None
    ) -> None:
        redis = await _get_redis(require_redis)
        service = _auth_service(db_session, redis)  # SMS mode
        await service.register(_ama_with_email())
        # Use up the code registration emailed. Codes issued in one
        # transaction share a timestamp, so with two outstanding, which one
        # counts as "latest" would be arbitrary.
        await service.verify_otp(_EMAIL, OtpPurpose.EMAIL_VERIFICATION, _emailed_code(_EMAIL))
        await redis.flushdb()  # registration started this purpose's cooldown
        SandboxSmsProvider.clear()
        SandboxEmailProvider.clear()

        await service.resend_otp(_EMAIL, OtpPurpose.EMAIL_VERIFICATION, OtpChannel.SMS)

        # A code texted to the phone must not be able to verify the email:
        # nothing is texted, and the live code is the emailed one.
        assert SandboxSmsProvider.get_sent_messages(_PHONE_E164) == []
        verified = await service.verify_otp(
            _EMAIL, OtpPurpose.EMAIL_VERIFICATION, _emailed_code(_EMAIL)
        )
        assert verified is not None


def _gmail_only(db_session: AsyncSession, redis: Redis) -> AuthService:
    """An AuthService that only lets new accounts register with Gmail."""
    settings = get_settings().model_copy(
        update={"REGISTRATION_EMAIL_DOMAINS": "gmail.com,googlemail.com"}
    )
    return AuthService(db_session, redis, SandboxSmsProvider(), SandboxEmailProvider(), settings)


def _ama_with(email: str | None) -> RegisterRequest:
    return RegisterRequest(
        phone_number=_PHONE,
        email=email,
        password="Str0ngPass",
        full_name="Ama Mensah",
        role="passenger",
    )


class TestGmailRequiredAtRegistration:
    async def test_registering_without_an_email_is_refused(
        self, db_session: AsyncSession, seeded_roles, require_redis: None
    ) -> None:
        service = _gmail_only(db_session, await _get_redis(require_redis))
        with pytest.raises(ValidationAppError) as exc_info:
            await service.register(_ama_with(None))
        assert exc_info.value.code == "EMAIL_REQUIRED"
        assert exc_info.value.details == {"allowed_domains": ["gmail.com", "googlemail.com"]}

    @pytest.mark.parametrize(
        "email",
        [
            "ama@yahoo.com",
            "ama@outlook.com",
            "ama@notgmail.com",  # ends in "gmail.com", but isn't Gmail
            "ama@gmail.com.example.com",  # starts with it, isn't either
        ],
    )
    async def test_a_non_gmail_address_is_refused_and_nothing_is_created(
        self, db_session: AsyncSession, seeded_roles, require_redis: None, email: str
    ) -> None:
        service = _gmail_only(db_session, await _get_redis(require_redis))
        with pytest.raises(ValidationAppError) as exc_info:
            await service.register(_ama_with(email))
        assert exc_info.value.code == "EMAIL_DOMAIN_NOT_ALLOWED"
        assert await UserRepository(db_session).get_by_phone(_PHONE_E164) is None
        assert SandboxSmsProvider.get_sent_messages(_PHONE_E164) == []

    @pytest.mark.parametrize(
        "email", ["ama.mensah@gmail.com", "Ama.Mensah@GMAIL.COM", "ama.mensah@googlemail.com"]
    )
    async def test_a_gmail_address_is_accepted(
        self, db_session: AsyncSession, seeded_roles, require_redis: None, email: str
    ) -> None:
        service = _gmail_only(db_session, await _get_redis(require_redis))
        user, _ = await service.register(_ama_with(email))
        assert user.email is not None
        assert user.email.lower() == email.lower()


def _configured(
    db_session: AsyncSession, redis: Redis, email_provider=None, **settings: object
) -> AuthService:
    """An AuthService with ``settings`` overriding the test configuration."""
    return AuthService(
        db_session,
        redis,
        SandboxSmsProvider(),
        email_provider or SandboxEmailProvider(),
        get_settings().model_copy(update=settings),
    )


class _SlowMailServer:
    """Holds every email until ``release()``, like a mail server that takes
    its time answering."""

    def __init__(self) -> None:
        self._gate = asyncio.Event()
        self.sent: list[tuple[str, str]] = []

    async def send_email(
        self, to: str, subject: str, body_text: str, body_html: str | None = None
    ) -> None:
        await self._gate.wait()
        self.sent.append((to, body_text))

    def release(self) -> None:
        self._gate.set()


class TestCodesSentInBackground:
    async def test_registration_answers_before_the_email_is_sent(
        self, db_session: AsyncSession, seeded_roles, require_redis: None
    ) -> None:
        mail = _SlowMailServer()
        service = _configured(
            db_session,
            await _get_redis(require_redis),
            mail,
            OTP_DELIVERY_CHANNEL="email",
            OTP_SEND_IN_BACKGROUND=True,
        )
        await service.register(_ama_with_email())
        assert mail.sent == []  # registration did not wait for the mail server

        mail.release()
        await drain_background_jobs(timeout_seconds=5)
        [(to, body)] = mail.sent
        assert to == _EMAIL
        verified = await service.verify_otp(_EMAIL, OtpPurpose.REGISTRATION, _code_from(body))
        assert verified is not None
        assert verified.email_verified_at is not None

    async def test_a_failed_background_email_does_not_hold_the_cooldown(
        self, db_session: AsyncSession, seeded_roles, require_redis: None
    ) -> None:
        service = _configured(
            db_session,
            await _get_redis(require_redis),
            _UnreachableMailServer(),
            OTP_DELIVERY_CHANNEL="email",
            OTP_SEND_IN_BACKGROUND=True,
        )
        await service.register(_ama_with_email())  # succeeds; the send fails later
        await drain_background_jobs(timeout_seconds=5)

        # The failed send gave the cooldown back, so asking again works at once.
        await service.resend_otp(_EMAIL, OtpPurpose.REGISTRATION, OtpChannel.EMAIL)
        await drain_background_jobs(timeout_seconds=5)

    async def test_a_password_reset_email_is_sent_in_the_background(
        self, db_session: AsyncSession, seeded_roles, require_redis: None
    ) -> None:
        redis = await _get_redis(require_redis)
        await _auth_service(db_session, redis).register(_ama_with_email())
        mail = _SlowMailServer()
        service = _configured(
            db_session, redis, mail, OTP_DELIVERY_CHANNEL="email", OTP_SEND_IN_BACKGROUND=True
        )

        await service.forgot_password(_PHONE)
        assert mail.sent == []

        mail.release()
        await drain_background_jobs(timeout_seconds=5)
        [(to, body)] = mail.sent
        assert to == _EMAIL
        assert "password reset code" in body


class TestVerificationRequired:
    async def test_an_unverified_account_cannot_log_in_with_its_password(
        self, db_session: AsyncSession, seeded_roles, require_redis: None
    ) -> None:
        service = _configured(
            db_session,
            await _get_redis(require_redis),
            OTP_DELIVERY_CHANNEL="email",
            REQUIRE_VERIFIED_ACCOUNT=True,
        )
        await service.register(_ama_with_email())

        with pytest.raises(AccountNotVerifiedError) as exc_info:
            await service.login_password(_PHONE, "Str0ngPass", None, "127.0.0.1")
        # Tells the app where to send a new code from.
        assert exc_info.value.details == {"target": _EMAIL, "purpose": "registration"}

    async def test_a_wrong_password_does_not_reveal_whether_it_is_verified(
        self, db_session: AsyncSession, seeded_roles, require_redis: None
    ) -> None:
        service = _configured(
            db_session, await _get_redis(require_redis), REQUIRE_VERIFIED_ACCOUNT=True
        )
        await service.register(_ama())
        with pytest.raises(InvalidCredentialsError):
            await service.login_password(_PHONE, "WrongPass1", None, "127.0.0.1")

    async def test_after_verifying_the_account_can_log_in(
        self, db_session: AsyncSession, seeded_roles, require_redis: None
    ) -> None:
        service = _configured(
            db_session,
            await _get_redis(require_redis),
            OTP_DELIVERY_CHANNEL="email",
            REQUIRE_VERIFIED_ACCOUNT=True,
        )
        await service.register(_ama_with_email())
        await service.verify_otp(_EMAIL, OtpPurpose.REGISTRATION, _emailed_code(_EMAIL))

        tokens = await service.login_password(_PHONE, "Str0ngPass", None, "127.0.0.1")
        assert tokens.access_token

    async def test_logging_in_with_an_emailed_code_verifies_the_account(
        self, db_session: AsyncSession, seeded_roles, require_redis: None
    ) -> None:
        service = _configured(
            db_session,
            await _get_redis(require_redis),
            OTP_DELIVERY_CHANNEL="email",
            REQUIRE_VERIFIED_ACCOUNT=True,
        )
        user, _ = await service.register(_ama_with_email())
        SandboxEmailProvider.clear()  # the registration code goes unused

        await service.resend_otp(_PHONE, OtpPurpose.LOGIN, OtpChannel.SMS)
        await service.login_otp(_PHONE, _emailed_code(_EMAIL), None, "127.0.0.1")

        refreshed = await UserRepository(db_session).get_by_id(user.id)
        assert refreshed is not None
        assert refreshed.email_verified_at is not None
        # ...so the password works from now on too.
        await service.login_password(_PHONE, "Str0ngPass", None, "127.0.0.1")

    async def test_in_sms_mode_the_hint_points_at_the_phone(
        self, db_session: AsyncSession, seeded_roles, require_redis: None
    ) -> None:
        service = _configured(
            db_session, await _get_redis(require_redis), REQUIRE_VERIFIED_ACCOUNT=True
        )
        await service.register(_ama())
        with pytest.raises(AccountNotVerifiedError) as exc_info:
            await service.login_password(_PHONE, "Str0ngPass", None, "127.0.0.1")
        assert exc_info.value.details["target"] == _PHONE_E164
