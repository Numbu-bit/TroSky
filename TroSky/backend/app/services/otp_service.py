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

from app.core.config import Settings, get_settings
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

logger = get_logger(__name__)

_OTP_MESSAGE_TEMPLATE = "Your TroSky verification code is {code}. It expires in {minutes} minutes."


class OtpService:
    def __init__(
        self,
        session: AsyncSession,
        redis: Redis,
        sms_provider: SmsProvider,
        email_provider: EmailProvider,
        settings: Settings | None = None,
    ) -> None:
        self._repo = OtpRepository(session)
        self._redis = redis
        self._sms_provider = sms_provider
        self._email_provider = email_provider
        self._settings = settings or get_settings()

    def _cooldown_key(self, target: str, purpose: OtpPurpose) -> str:
        return f"otp:cooldown:{purpose.value}:{target}"

    async def request_otp(
        self,
        *,
        target: str,
        channel: OtpChannel,
        purpose: OtpPurpose,
        user_id: uuid.UUID | None = None,
    ) -> OtpChallenge:
        cooldown_key = self._cooldown_key(target, purpose)
        acquired = await self._redis.set(
            cooldown_key, "1", nx=True, ex=self._settings.OTP_RESEND_COOLDOWN_SECONDS
        )
        if not acquired:
            raise RateLimitExceededError(
                "Please wait before requesting another code.",
                details={"cooldown_seconds": self._settings.OTP_RESEND_COOLDOWN_SECONDS},
            )

        code = generate_numeric_otp(self._settings.OTP_LENGTH)
        code_hash = hash_otp_code(code, self._settings)
        expires_at = datetime.now(UTC) + timedelta(seconds=self._settings.OTP_EXPIRATION_SECONDS)

        challenge = await self._repo.create_challenge(
            target=target,
            channel=channel,
            purpose=purpose,
            code_hash=code_hash,
            user_id=user_id,
            expires_at=expires_at,
            max_attempts=self._settings.OTP_MAX_ATTEMPTS,
        )

        message = _OTP_MESSAGE_TEMPLATE.format(
            code=code, minutes=self._settings.OTP_EXPIRATION_SECONDS // 60
        )
        if channel == OtpChannel.SMS:
            await self._sms_provider.send_sms(target, message)
        else:
            await self._email_provider.send_email(target, "Your TroSky verification code", message)

        logger.info("otp_requested", target=target, purpose=purpose.value, channel=channel.value)
        return challenge

    async def verify_otp(self, *, target: str, purpose: OtpPurpose, code: str) -> OtpChallenge:
        challenge = await self._repo.get_latest_active_challenge(target, purpose)
        if challenge is None:
            raise OtpNotFoundError()

        if challenge.expires_at <= datetime.now(UTC):
            raise OtpExpiredError()

        if challenge.attempts >= challenge.max_attempts:
            raise OtpAttemptsExceededError()

        if hash_otp_code(code, self._settings) != challenge.code_hash:
            await self._repo.increment_attempts(challenge)
            raise OtpInvalidError()

        await self._repo.consume(challenge)
        logger.info("otp_verified", target=target, purpose=purpose.value)
        return challenge
