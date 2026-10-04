"""Authentication and session business logic.

Route handlers call into this service; the service orchestrates
repositories + providers inside explicit transaction boundaries. No SQL and
no HTTP-status-code decisions live in ``app.api.v1.auth`` — only here.
"""

from __future__ import annotations

import uuid
from datetime import UTC, datetime

from redis.asyncio import Redis
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings, get_settings
from app.core.database import keep_writes_on_failure
from app.core.exceptions import (
    AccountLockedError,
    AccountNotVerifiedError,
    AccountSuspendedError,
    ConflictError,
    DeviceBlockedError,
    InvalidCredentialsError,
    NotFoundError,
    OtpNotFoundError,
    PasswordResetTokenInvalidError,
    TokenReuseDetectedError,
    UnauthorizedError,
    ValidationAppError,
)
from app.core.logging import get_logger
from app.core.security import (
    TokenError,
    TokenType,
    create_token,
    decode_token,
    hash_opaque_token,
    hash_password,
    verify_password,
)
from app.models.fraud import BlockedDevice
from app.models.identity import OtpChannel, OtpPurpose, User, UserSession
from app.providers.email.base import EmailProvider
from app.providers.sms.base import SmsProvider
from app.repositories.otp_repository import OtpRepository
from app.repositories.profile_repository import DeviceRepository, NotificationPreferenceRepository
from app.repositories.session_repository import SessionRepository
from app.repositories.user_repository import DuplicateUserError, UserRepository
from app.schemas.auth import DeviceContext, RegisterRequest, TokenPairResponse
from app.services.otp_service import OtpService, normalize_otp_target
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
        self._devices = DeviceRepository(session)
        self._otp = OtpService(session, redis, sms_provider, email_provider, self._settings)

    @property
    def _codes_by_email(self) -> bool:
        """Whether verification codes go by email rather than SMS."""
        return self._settings.OTP_DELIVERY_CHANNEL == "email"

    def _verification_target(self, user: User) -> str:
        """Where a new registration code for ``user`` would be sent."""
        if self._codes_by_email and user.email is not None:
            return user.email
        return user.phone_number

    def _check_registration_email(self, email: str | None) -> None:
        """Refuse a registration whose email address is missing, or is on a
        domain new accounts may not use (``REGISTRATION_EMAIL_DOMAINS``)."""
        allowed = self._settings.registration_email_domains
        domains = " or ".join(f"@{domain}" for domain in sorted(allowed))
        if email is None:
            if allowed:
                raise ValidationAppError(
                    f"An email address ending in {domains} is required to register.",
                    code="EMAIL_REQUIRED",
                    details={"allowed_domains": sorted(allowed)},
                )
            if self._codes_by_email:
                raise ValidationAppError(
                    "An email address is required: verification codes are sent by email.",
                    code="EMAIL_REQUIRED",
                )
            return
        if allowed and email.rpartition("@")[2].lower() not in allowed:
            raise ValidationAppError(
                f"Please register with an email address ending in {domains}.",
                code="EMAIL_DOMAIN_NOT_ALLOWED",
                details={"allowed_domains": sorted(allowed)},
            )

    def _code_channel(self, purpose: OtpPurpose, requested: OtpChannel) -> OtpChannel:
        """The channel a code for ``purpose`` is actually sent by.

        A code verifying the email must go to the email and one verifying
        the phone to the phone, whatever was asked for -- otherwise one
        could vouch for the other.
        """
        if purpose == OtpPurpose.EMAIL_VERIFICATION:
            return OtpChannel.EMAIL
        if purpose == OtpPurpose.PHONE_VERIFICATION:
            return OtpChannel.SMS
        return OtpChannel.EMAIL if self._codes_by_email else requested

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
        self._check_registration_email(request.email)

        # The code goes out as early as it can: every database round trip
        # before it is time the person waits for their email. So the checks
        # are one query, the insert needs no savepoint (nothing else here to
        # keep if it fails), and the role and preferences come after.
        phone_taken, email_taken = await self._users.contacts_taken(
            request.phone_number, request.email
        )
        if phone_taken:
            raise ConflictError(
                "An account with this phone number already exists.", code="PHONE_ALREADY_REGISTERED"
            )
        if email_taken:
            raise ConflictError(
                "An account with this email already exists.", code="EMAIL_ALREADY_REGISTERED"
            )

        try:
            user = await self._users.create(
                phone_number=request.phone_number,
                email=request.email,
                password_hash=hash_password(request.password),
                full_name=request.full_name,
                preferred_language=request.preferred_language,
                savepoint=False,
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
        if self._codes_by_email and user.email is not None:
            # The one code goes to the email address; verifying it verifies
            # that address. If it cannot be sent the registration fails and
            # rolls back, as it would for an undeliverable SMS.
            await self._otp.request_otp(
                target=user.email,
                channel=OtpChannel.EMAIL,
                purpose=OtpPurpose.REGISTRATION,
                user_id=user.id,
            )
            otp_target = user.email
        else:
            await self._otp.request_otp(
                target=user.phone_number,
                channel=OtpChannel.SMS,
                purpose=OtpPurpose.REGISTRATION,
                user_id=user.id,
            )
            otp_target = user.phone_number

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
                    logger.warning(
                        "registration_email_otp_failed", user_id=str(user.id), exc_info=True
                    )

        role = await self._users.get_role_by_slug(request.role.value)
        if role is None:
            # Roles are seeded at deploy time (see scripts/seed_dev_data.py);
            # reaching this means the environment was never seeded.
            raise RuntimeError(f"Role '{request.role.value}' is not seeded in this environment.")
        await self._users.assign_role(user.id, role.id)
        await self._notification_prefs.create_default(user.id)

        logger.info("user_registered", user_id=str(user.id), role=request.role.value)
        return user, otp_target

    async def verify_otp(self, target: str, purpose: OtpPurpose, code: str) -> User | None:
        """Verify an OTP for ``purpose`` and apply the associated side effect.

        ``registration`` marks verified whichever contact the code was
        delivered to -- the phone by SMS, or the email address when codes go
        by email. ``phone_verification`` / ``email_verification`` mark the
        phone / email verified. ``login`` / ``password_reset`` have no side
        effect here — those flows call :meth:`OtpService.verify_otp`
        directly as part of a larger operation (issuing tokens, generating
        a reset token).
        """
        target = normalize_otp_target(target)
        challenge = await self._otp.verify_otp(target=target, purpose=purpose, code=code)

        if purpose == OtpPurpose.REGISTRATION:
            proves_email = challenge.channel == OtpChannel.EMAIL
        elif purpose in (OtpPurpose.PHONE_VERIFICATION, OtpPurpose.EMAIL_VERIFICATION):
            proves_email = purpose == OtpPurpose.EMAIL_VERIFICATION
        else:
            return None

        user = await self._resolve_user(target)
        if user is None:
            raise NotFoundError("No account found for this phone number or email.")
        if proves_email:
            await self._users.mark_email_verified(user)
        else:
            await self._users.mark_phone_verified(user)
        return user

    async def resend_otp(self, target: str, purpose: OtpPurpose, channel: OtpChannel) -> None:
        """Send a new code to ``target`` -- only if it belongs to an account.

        Every purpose this endpoint serves needs an existing account, so a
        code for anyone else could never be used; sending it would only let
        callers make TroSky pay for SMS to arbitrary numbers. The caller
        still gets the same answer, cooldown included, so the endpoint does
        not reveal which numbers are registered.

        The code goes to the account's own phone or email, so it reaches the
        user whichever identifier they typed. When codes go by email, an
        account with no email address is sent nothing.
        """
        user = await self._resolve_user(target)
        if user is None:
            await self._otp.hold_cooldown(target=target, purpose=purpose)
            logger.info("otp_not_sent_no_account", purpose=purpose.value, channel=channel.value)
            return

        channel = self._code_channel(purpose, channel)
        deliver_to = user.email if channel == OtpChannel.EMAIL else user.phone_number
        if deliver_to is None:
            await self._otp.hold_cooldown(target=target, purpose=purpose)
            logger.warning("otp_not_sent_no_email", user_id=str(user.id), purpose=purpose.value)
            return
        await self._otp.request_otp(
            target=target,
            channel=channel,
            purpose=purpose,
            user_id=user.id,
            deliver_to=deliver_to,
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
            keep_writes_on_failure(self._session)
            raise InvalidCredentialsError()
        # Checked only once the password is right, so a stranger cannot learn
        # whether an account has been verified.
        if self._settings.REQUIRE_VERIFIED_ACCOUNT and not user.is_verified:
            raise AccountNotVerifiedError(
                "Verify your account with the code sent to you before logging in.",
                details={"target": self._verification_target(user), "purpose": "registration"},
            )

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

        challenge = await self._otp.verify_otp(target=target, purpose=OtpPurpose.LOGIN, code=code)
        await self._mark_contact_verified(user, challenge.channel)
        await self._users.record_login_success(user)
        return await self._issue_token_pair(user, device, ip_address)

    async def _issue_token_pair(
        self, user: User, device: DeviceContext | None, ip_address: str | None
    ) -> TokenPairResponse:
        if device is not None and device.device_id:
            blocked = await self._session.scalar(
                select(BlockedDevice.id).where(BlockedDevice.device_id == device.device_id)
            )
            if blocked is not None:
                logger.warning("login_from_blocked_device", user_id=str(user.id))
                raise DeviceBlockedError()
        session_record = await self._sessions.create_session(
            user_id=user.id,
            device_id=device.device_id if device else None,
            device_name=device.device_name if device else None,
            ip_address=ip_address,
            user_agent=None,
        )
        if device is not None:
            await self._register_login_device(user.id, device)
        roles = await self._users.get_roles_for_user(user.id)
        return await self._issue_tokens_for_session(user.id, session_record.id, roles)

    async def _register_login_device(self, user_id: uuid.UUID, device: DeviceContext) -> None:
        """Record the push token the app sent with its login, as
        ``POST /users/me/devices`` would.

        Only when the app sent a token: saving the device without one would
        wipe a token registered earlier. Best-effort -- a clash with a
        concurrent login from the same device must not fail the login.
        """
        if not (device.device_id and device.platform and device.push_token):
            return
        try:
            async with self._session.begin_nested():
                await self._devices.upsert(
                    user_id=user_id,
                    device_id=device.device_id,
                    platform=device.platform,
                    push_token=device.push_token,
                )
        except IntegrityError:
            logger.warning("login_device_registration_failed", user_id=str(user_id))

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
            keep_writes_on_failure(self._session)
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
        """Send a 6-digit reset code for the account behind ``identifier``:
        to its email when codes go by email (or an email was typed), else by
        SMS. Complete the reset with :meth:`reset_password_with_code`.

        Like :meth:`resend_otp`, an identifier with no account -- or an
        account with no email when codes go by email -- gets the same answer
        and cooldown as a real request, but nothing is sent.
        """
        user = await self._resolve_user(identifier)
        by_email = self._codes_by_email or "@" in identifier
        deliver_to = None
        if user is not None:
            deliver_to = user.email if by_email else user.phone_number
        if user is None or deliver_to is None:
            await self._otp.hold_cooldown(target=identifier, purpose=OtpPurpose.PASSWORD_RESET)
            if user is not None:
                logger.warning("password_reset_not_sent_no_email", user_id=str(user.id))
            return
        await self._otp.request_otp(
            target=identifier,
            channel=OtpChannel.EMAIL if by_email else OtpChannel.SMS,
            purpose=OtpPurpose.PASSWORD_RESET,
            user_id=user.id,
            deliver_to=deliver_to,
        )
        logger.info("password_reset_requested", user_id=str(user.id))

    async def reset_password_with_code(self, target: str, code: str, new_password: str) -> None:
        """Set a new password with the code ``forgot_password`` sent for
        ``target``. Signs out every session, as a token reset does."""
        self._enforce_password_policy(new_password)
        user = await self._resolve_user(target)
        if user is None:
            # Indistinguishable from a wrong or expired code.
            raise OtpNotFoundError()
        challenge = await self._otp.verify_otp(
            target=target, purpose=OtpPurpose.PASSWORD_RESET, code=code
        )
        await self._mark_contact_verified(user, challenge.channel)
        await self._users.update_password(user, hash_password(new_password))
        await self._sessions.revoke_all_sessions_for_user(user.id, reason="password_reset")
        logger.info("password_reset_completed", user_id=str(user.id), method="code")

    def _enforce_password_policy(self, password: str) -> None:
        try:
            validate_password_policy(password, self._settings)
        except PasswordPolicyError as exc:
            raise ConflictError(
                "Password does not meet the required policy.",
                code="PASSWORD_POLICY_VIOLATION",
                details={"violations": exc.violations},
            ) from None

    async def _mark_contact_verified(self, user: User, channel: OtpChannel) -> None:
        """A code that reached the user proves the contact it was sent to,
        which also completes an account that never finished verifying."""
        if channel == OtpChannel.EMAIL and user.email_verified_at is None:
            await self._users.mark_email_verified(user)
        elif channel == OtpChannel.SMS and user.phone_verified_at is None:
            await self._users.mark_phone_verified(user)

    async def reset_password(self, raw_token: str, new_password: str) -> None:
        """Set a new password with a long reset token -- the older form of
        reset, still honoured for tokens issued before codes replaced it."""
        self._enforce_password_policy(new_password)

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
