"""Authentication and session business logic.

Route handlers call into this service; the service orchestrates
repositories + providers inside explicit transaction boundaries. No SQL and
no HTTP-status-code decisions live in ``app.api.v1.auth`` — only here.
"""

from __future__ import annotations

import uuid
from datetime import UTC, datetime, timedelta

from redis.asyncio import Redis
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings, get_settings
from app.core.exceptions import (
    AccountLockedError,
    AccountSuspendedError,
    ConflictError,
    InvalidCredentialsError,
    NotFoundError,
    PasswordResetTokenInvalidError,
    TokenReuseDetectedError,
    UnauthorizedError,
)
from app.core.logging import get_logger
from app.core.security import (
    TokenError,
    TokenType,
    create_token,
    decode_token,
    generate_opaque_token,
    hash_opaque_token,
    hash_password,
    verify_password,
)
from app.models.identity import OtpChannel, OtpPurpose, User, UserSession
from app.providers.email.base import EmailProvider
from app.providers.sms.base import SmsProvider
from app.repositories.otp_repository import OtpRepository
from app.repositories.profile_repository import NotificationPreferenceRepository
from app.repositories.session_repository import SessionRepository
from app.repositories.user_repository import DuplicateUserError, UserRepository
from app.schemas.auth import DeviceContext, RegisterRequest, TokenPairResponse
from app.services.otp_service import OtpService
from app.utilities.password_policy import PasswordPolicyError, validate_password_policy
from app.utilities.phone import InvalidPhoneNumberError, normalize_phone_number

logger = get_logger(__name__)


class AuthService:
    def __init__(
        self,
        session: AsyncSession,
        redis: Redis,
        sms_provider: SmsProvider,
        email_provider: EmailProvider,
        settings: Settings | None = None,
    ) -> None:
        self._session = session
        self._settings = settings or get_settings()
        self._sms_provider = sms_provider
        self._email_provider = email_provider
        self._users = UserRepository(session)
        self._sessions = SessionRepository(session)
        self._otp_repo = OtpRepository(session)
        self._notification_prefs = NotificationPreferenceRepository(session)
        self._otp = OtpService(session, redis, sms_provider, email_provider, self._settings)

    # ------------------------------------------------------------------
    # Registration
    # ------------------------------------------------------------------
    async def register(self, request: RegisterRequest) -> tuple[User, str]:
        try:
            validate_password_policy(request.password, self._settings)
        except PasswordPolicyError as exc:
            raise ConflictError(
                "Password does not meet the required policy.",
                code="PASSWORD_POLICY_VIOLATION",
                details={"violations": exc.violations},
            ) from None

        if await self._users.get_by_phone(request.phone_number) is not None:
            raise ConflictError(
                "An account with this phone number already exists.", code="PHONE_ALREADY_REGISTERED"
            )
        if request.email is not None and await self._users.get_by_email(request.email) is not None:
            raise ConflictError(
                "An account with this email already exists.", code="EMAIL_ALREADY_REGISTERED"
            )

        role = await self._users.get_role_by_slug(request.role.value)
        if role is None:
            # Roles are seeded at deploy time (see scripts/seed_dev_data.py);
            # reaching this means the environment was never seeded.
            raise RuntimeError(f"Role '{request.role.value}' is not seeded in this environment.")

        try:
            user = await self._users.create(
                phone_number=request.phone_number,
                email=request.email,
                password_hash=hash_password(request.password),
                full_name=request.full_name,
                preferred_language=request.preferred_language,
            )
        except DuplicateUserError as exc:
            # The checks above already rejected the ordinary duplicate; a
            # concurrent registration won the race between them and this
            # insert. Report the same 409 either way rather than a 500.
            if exc.field == "email":
                raise ConflictError(
                    "An account with this email already exists.", code="EMAIL_ALREADY_REGISTERED"
                ) from None
            raise ConflictError(
                "An account with this phone number already exists.",
                code="PHONE_ALREADY_REGISTERED",
            ) from None
        await self._users.assign_role(user.id, role.id)
        await self._notification_prefs.create_default(user.id)

        await self._otp.request_otp(
            target=user.phone_number,
            channel=OtpChannel.SMS,
            purpose=OtpPurpose.REGISTRATION,
            user_id=user.id,
        )

        if user.email is not None:
            # Best-effort: the phone number is the account's verified
            # identity (see RegisterResponse), so a mail-transport failure
            # must not roll back an otherwise completed registration. The
            # savepoint keeps a failed challenge insert from poisoning the
            # request's outer transaction. The caller can always re-request
            # this code via POST /auth/resend-otp.
            try:
                async with self._session.begin_nested():
                    await self._otp.request_otp(
                        target=user.email,
                        channel=OtpChannel.EMAIL,
                        purpose=OtpPurpose.EMAIL_VERIFICATION,
                        user_id=user.id,
                    )
            except Exception:
                logger.warning("registration_email_otp_failed", user_id=str(user.id), exc_info=True)

        logger.info("user_registered", user_id=str(user.id), role=request.role.value)
        return user, user.phone_number

    async def verify_otp(self, target: str, purpose: OtpPurpose, code: str) -> User | None:
        """Verify an OTP for ``purpose`` and apply the associated side effect.

        ``registration`` / ``phone_verification`` mark the account's phone
        number verified; ``email_verification`` marks the email verified.
        ``login`` / ``password_reset`` have no side effect here — those
        flows call :meth:`OtpService.verify_otp` directly as part of a
        larger operation (issuing tokens, generating a reset token).
        """
        await self._otp.verify_otp(target=target, purpose=purpose, code=code)

        if purpose in (OtpPurpose.REGISTRATION, OtpPurpose.PHONE_VERIFICATION):
            user = await self._users.get_by_phone(target)
            if user is None:
                raise NotFoundError("No account found for this phone number.")
            await self._users.mark_phone_verified(user)
            return user

        if purpose == OtpPurpose.EMAIL_VERIFICATION:
            user = await self._users.get_by_email(target)
            if user is None:
                raise NotFoundError("No account found for this email address.")
            await self._users.mark_email_verified(user)
            return user

        return None

    async def resend_otp(self, target: str, purpose: OtpPurpose, channel: OtpChannel) -> None:
        user = await self._resolve_user(target)
        await self._otp.request_otp(
            target=target, channel=channel, purpose=purpose, user_id=user.id if user else None
        )

    # ------------------------------------------------------------------
    # Login
    # ------------------------------------------------------------------
    async def _resolve_user(self, identifier: str) -> User | None:
        try:
            phone = normalize_phone_number(identifier)
        except InvalidPhoneNumberError:
            phone = None
        if phone is not None:
            user = await self._users.get_by_phone(phone)
            if user is not None:
                return user
        return await self._users.get_by_email(identifier.strip().lower())

    def _assert_login_allowed(self, user: User) -> None:
        if user.is_suspended:
            raise AccountSuspendedError(details={"reason": user.suspended_reason})
        if user.locked_until is not None and user.locked_until > datetime.now(UTC):
            raise AccountLockedError(details={"locked_until": user.locked_until.isoformat()})

    async def login_password(
        self, identifier: str, password: str, device: DeviceContext | None, ip_address: str | None
    ) -> TokenPairResponse:
        user = await self._resolve_user(identifier)
        if user is None:
            raise InvalidCredentialsError()

        self._assert_login_allowed(user)

        if not verify_password(password, user.password_hash):
            await self._users.record_login_failure(
                user,
                max_attempts=self._settings.LOGIN_MAX_FAILED_ATTEMPTS,
                lockout_seconds=self._settings.LOGIN_LOCKOUT_SECONDS,
            )
            raise InvalidCredentialsError()

        await self._users.record_login_success(user)
        return await self._issue_token_pair(user, device, ip_address)

    async def request_login_otp(self, target: str, channel: OtpChannel) -> None:
        user = await self._resolve_user(target)
        if user is None:
            raise NotFoundError("No account found for this identifier.")
        self._assert_login_allowed(user)
        await self._otp.request_otp(
            target=target, channel=channel, purpose=OtpPurpose.LOGIN, user_id=user.id
        )

    async def login_otp(
        self, target: str, code: str, device: DeviceContext | None, ip_address: str | None
    ) -> TokenPairResponse:
        user = await self._resolve_user(target)
        if user is None:
            raise NotFoundError("No account found for this identifier.")
        self._assert_login_allowed(user)

        await self._otp.verify_otp(target=target, purpose=OtpPurpose.LOGIN, code=code)
        await self._users.record_login_success(user)
        return await self._issue_token_pair(user, device, ip_address)

    async def _issue_token_pair(
        self, user: User, device: DeviceContext | None, ip_address: str | None
    ) -> TokenPairResponse:
        session_record = await self._sessions.create_session(
            user_id=user.id,
            device_id=device.device_id if device else None,
            device_name=device.device_name if device else None,
            ip_address=ip_address,
            user_agent=None,
        )
        roles = await self._users.get_roles_for_user(user.id)
        return await self._issue_tokens_for_session(user.id, session_record.id, roles)

    async def _issue_tokens_for_session(
        self, user_id: uuid.UUID, session_id: uuid.UUID, roles: list[str]
    ) -> TokenPairResponse:
        access_token, _access_claims = create_token(
            user_id=user_id, session_id=session_id, token_type=TokenType.ACCESS, roles=roles
        )
        refresh_token, refresh_claims = create_token(
            user_id=user_id, session_id=session_id, token_type=TokenType.REFRESH, roles=roles
        )
        await self._sessions.create_refresh_token(
            session_id=session_id,
            user_id=user_id,
            token_hash=hash_opaque_token(refresh_token),
            expires_at=refresh_claims.expires_at,
        )
        return TokenPairResponse(
            access_token=access_token,
            refresh_token=refresh_token,
            expires_in=self._settings.ACCESS_TOKEN_TTL_SECONDS,
            session_id=session_id,
        )

    # ------------------------------------------------------------------
    # Token refresh (rotation + reuse detection)
    # ------------------------------------------------------------------
    async def refresh_tokens(self, raw_refresh_token: str) -> TokenPairResponse:
        try:
            decode_token(raw_refresh_token, expected_type=TokenType.REFRESH)
        except TokenError as exc:
            raise UnauthorizedError("Invalid or expired refresh token.") from exc

        token_hash = hash_opaque_token(raw_refresh_token)
        stored = await self._sessions.get_refresh_token_by_hash(token_hash)
        if stored is None:
            raise UnauthorizedError("Invalid or expired refresh token.")

        if stored.revoked_at is not None:
            # Reuse of an already-rotated (or explicitly revoked) refresh
            # token indicates the token was stolen and used by someone else
            # after the legitimate client rotated past it. Nuke the session.
            await self._sessions.revoke_all_sessions_for_user(
                stored.user_id, reason="refresh_token_reuse_detected"
            )
            logger.warning(
                "refresh_token_reuse_detected",
                user_id=str(stored.user_id),
                session_id=str(stored.session_id),
            )
            raise TokenReuseDetectedError()

        if stored.expires_at <= datetime.now(UTC):
            raise UnauthorizedError("Invalid or expired refresh token.")

        session_record = await self._sessions.get_active_session(stored.session_id)
        if session_record is None:
            raise UnauthorizedError("This session has been revoked.")

        user = await self._users.get_by_id(stored.user_id)
        if user is None or user.deleted_at is not None:
            raise UnauthorizedError("Account no longer exists.")
        self._assert_login_allowed(user)

        roles = await self._users.get_roles_for_user(user.id)
        new_pair = await self._issue_tokens_for_session(user.id, session_record.id, roles)

        new_token_record = await self._sessions.get_refresh_token_by_hash(
            hash_opaque_token(new_pair.refresh_token)
        )
        await self._sessions.revoke_refresh_token(
            stored, replaced_by_id=new_token_record.id if new_token_record else None
        )
        await self._sessions.touch_last_seen(session_record.id)
        return new_pair

    # ------------------------------------------------------------------
    # Logout / sessions
    # ------------------------------------------------------------------
    async def logout(self, session_id: uuid.UUID) -> None:
        await self._sessions.revoke_session(session_id, reason="user_logout")

    async def logout_all(self, user_id: uuid.UUID) -> None:
        await self._sessions.revoke_all_sessions_for_user(user_id, reason="user_logout_all")

    async def list_sessions(self, user_id: uuid.UUID) -> list[UserSession]:
        return await self._sessions.list_active_sessions_for_user(user_id)

    async def revoke_session_for_user(self, user_id: uuid.UUID, session_id: uuid.UUID) -> None:
        session_record = await self._sessions.get_active_session(session_id)
        if session_record is None or session_record.user_id != user_id:
            raise NotFoundError("Session not found.")
        await self._sessions.revoke_session(session_id, reason="user_revoked")

    # ------------------------------------------------------------------
    # Password reset
    # ------------------------------------------------------------------
    async def forgot_password(self, identifier: str) -> None:
        user = await self._resolve_user(identifier)
        if user is None:
            # Do not reveal whether an account exists.
            return

        raw_token = generate_opaque_token()
        await self._otp_repo.create_password_reset_token(
            user_id=user.id,
            token_hash=hash_opaque_token(raw_token),
            expires_at=datetime.now(UTC)
            + timedelta(seconds=self._settings.PASSWORD_RESET_TOKEN_TTL_SECONDS),
        )
        message = f"Your TroSky password reset code is {raw_token}. It expires in 30 minutes."
        if "@" in identifier:
            await self._email_provider.send_email(
                user.email or identifier, "Reset your TroSky password", message
            )
        else:
            await self._sms_provider.send_sms(user.phone_number, message)
        logger.info("password_reset_requested", user_id=str(user.id))

    async def reset_password(self, raw_token: str, new_password: str) -> None:
        try:
            validate_password_policy(new_password, self._settings)
        except PasswordPolicyError as exc:
            raise ConflictError(
                "Password does not meet the required policy.",
                code="PASSWORD_POLICY_VIOLATION",
                details={"violations": exc.violations},
            ) from None

        token_hash = hash_opaque_token(raw_token)
        token_record = await self._otp_repo.get_active_password_reset_token(token_hash)
        if token_record is None:
            raise PasswordResetTokenInvalidError()

        user = await self._users.get_by_id(token_record.user_id)
        if user is None:
            raise PasswordResetTokenInvalidError()

        await self._users.update_password(user, hash_password(new_password))
        await self._otp_repo.consume_password_reset_token(token_record)
        await self._sessions.revoke_all_sessions_for_user(user.id, reason="password_reset")
        logger.info("password_reset_completed", user_id=str(user.id))
