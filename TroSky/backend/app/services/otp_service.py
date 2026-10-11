"""OTP challenge issuance and verification.

The database (``otp_challenges``) is the authority for whether a code is
valid, unexpired, unconsumed, and within its attempt budget. Redis is used
only to enforce the resend cooldown — an acceleration/abuse-prevention
concern, never the source of truth for correctness.
"""

from __future__ import annotations

import uuid
from datetime import UTC, datetime, timedelta

from redis.asyncio import Redis
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.background import run_in_background
from app.core.config import Settings, get_settings
from app.core.database import keep_writes_on_failure
from app.core.exceptions import (
    OtpAttemptsExceededError,
    OtpExpiredError,
    OtpInvalidError,
    OtpNotFoundError,
    RateLimitExceededError,
)
from app.core.logging import get_logger
from app.core.security import generate_numeric_otp, hash_otp_code
from app.models.identity import OtpChallenge, OtpChannel, OtpPurpose
from app.providers.email.base import EmailProvider
from app.providers.sms.base import SmsProvider
from app.repositories.otp_repository import OtpRepository
from app.utilities.phone import InvalidPhoneNumberError, normalize_phone_number

logger = get_logger(__name__)

_OTP_MESSAGE_TEMPLATE = "Your TroSky verification code is {code}. It expires in {minutes} minutes."
# (subject, message) by purpose, so a reset code does not read like a
# sign-up one.
_MESSAGES: dict[OtpPurpose, tuple[str, str]] = {
    OtpPurpose.PASSWORD_RESET: (
        "Reset your TroSky password",
        "Your TroSky password reset code is {code}. It expires in {minutes} minutes. "
        "If you did not ask to reset your password, ignore this message.",
    ),
}
_DEFAULT_MESSAGE = ("Your TroSky verification code", _OTP_MESSAGE_TEMPLATE)


def normalize_otp_target(target: str) -> str:
    """The single spelling of ``target`` that codes and cooldowns are keyed on.

    A phone number becomes E.164 however it was typed ("0241234567",
    "+233 24 123 4567"), and an email address is lower-cased. Without this,
    a code requested for one spelling of a number could not be verified with
    another, and each spelling had its own resend cooldown.
    """
    if "@" in target:
        return target.strip().lower()
    try:
        return normalize_phone_number(target)
    except InvalidPhoneNumberError:
        return target.strip()


class OtpService:
    def __init__(
        self,
        session: AsyncSession,
        redis: Redis,
        sms_provider: SmsProvider,
        email_provider: EmailProvider,
        settings: Settings | None = None,
    ) -> None:
        self._session = session
        self._repo = OtpRepository(session)
        self._redis = redis
        self._sms_provider = sms_provider
        self._email_provider = email_provider
        self._settings = settings or get_settings()

    def _cooldown_key(self, target: str, purpose: OtpPurpose) -> str:
        return f"otp:cooldown:{purpose.value}:{target}"

    async def hold_cooldown(self, *, target: str, purpose: OtpPurpose) -> None:
        """Start the resend cooldown for ``target``, or raise if it is running.

        Used on its own when a request is answered without sending a code, so
        that request is indistinguishable from one that did send.
        """
        acquired = await self._redis.set(
            self._cooldown_key(normalize_otp_target(target), purpose),
            "1",
            nx=True,
            ex=self._settings.OTP_RESEND_COOLDOWN_SECONDS,
        )
        if not acquired:
            raise RateLimitExceededError(
                "Please wait before requesting another code.",
                details={"cooldown_seconds": self._settings.OTP_RESEND_COOLDOWN_SECONDS},
            )

    async def request_otp(
        self,
        *,
        target: str,
        channel: OtpChannel,
        purpose: OtpPurpose,
        user_id: uuid.UUID | None = None,
        deliver_to: str | None = None,
    ) -> OtpChallenge:
        """Issue a code keyed on ``target`` and send it to ``deliver_to``
        (default: ``target`` itself) -- e.g. keyed on the phone number the
        user typed, but emailed to the account's address."""
        target = normalize_otp_target(target)
        await self.hold_cooldown(target=target, purpose=purpose)

        code = generate_numeric_otp(self._settings.OTP_LENGTH)
        code_hash = hash_otp_code(code, self._settings)
        expires_at = datetime.now(UTC) + timedelta(seconds=self._settings.OTP_EXPIRATION_SECONDS)

        # The code is on its way before it is stored: storing it is part of
        # the request, which cannot be answered -- nor the code checked --
        # until it commits, so nothing is lost by sending first, and the
        # person waits one round trip less.
        subject, template = _MESSAGES.get(purpose, _DEFAULT_MESSAGE)
        message = template.format(code=code, minutes=self._settings.OTP_EXPIRATION_SECONDS // 60)
        delivery = self._deliver(
            channel,
            deliver_to or target,
            message,
            subject=subject,
            target=target,
            purpose=purpose,
        )
        if self._settings.OTP_SEND_IN_BACKGROUND:
            run_in_background(delivery, name=f"otp-{purpose.value}-{channel.value}")
        else:
            await delivery

        challenge = await self._repo.create_challenge(
            target=target,
            channel=channel,
            purpose=purpose,
            code_hash=code_hash,
            user_id=user_id,
            expires_at=expires_at,
            max_attempts=self._settings.OTP_MAX_ATTEMPTS,
        )

        logger.info("otp_requested", target=target, purpose=purpose.value, channel=channel.value)
        return challenge

    async def _deliver(
        self,
        channel: OtpChannel,
        address: str,
        message: str,
        *,
        subject: str,
        target: str,
        purpose: OtpPurpose,
    ) -> None:
        try:
            if channel == OtpChannel.SMS:
                await self._sms_provider.send_sms(address, message)
            else:
                await self._email_provider.send_email(address, subject, message)
        except Exception:
            # Nothing was delivered, so asking again must not have to wait
            # out the cooldown.
            await self._redis.delete(self._cooldown_key(target, purpose))
            raise

    async def verify_otp(self, *, target: str, purpose: OtpPurpose, code: str) -> OtpChallenge:
        target = normalize_otp_target(target)
        challenge = await self._repo.get_latest_active_challenge(target, purpose)
        if challenge is None:
            raise OtpNotFoundError()

        if challenge.expires_at <= datetime.now(UTC):
            raise OtpExpiredError()

        if challenge.attempts >= challenge.max_attempts:
            raise OtpAttemptsExceededError()

        if hash_otp_code(code, self._settings) != challenge.code_hash:
            await self._repo.increment_attempts(challenge)
            keep_writes_on_failure(self._session)
            raise OtpInvalidError()

        await self._repo.consume(challenge)
        logger.info("otp_verified", target=target, purpose=purpose.value)
        return challenge
