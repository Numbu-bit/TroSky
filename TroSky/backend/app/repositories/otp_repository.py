"""Database access for OTP challenges and password-reset tokens.

The database (not Redis) is the authority for OTP consumption and attempt
counts — Redis is used only as a resend-cooldown accelerator in
``app.services.otp_service``.
"""

from __future__ import annotations

import uuid
from datetime import UTC, datetime

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.identity import OtpChallenge, OtpChannel, OtpPurpose, PasswordResetToken


class OtpRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def create_challenge(
        self,
        *,
        target: str,
        channel: OtpChannel,
        purpose: OtpPurpose,
        code_hash: str,
        user_id: uuid.UUID | None,
        expires_at: datetime,
        max_attempts: int,
    ) -> OtpChallenge:
        challenge = OtpChallenge(
            target=target,
            channel=channel,
            purpose=purpose,
            code_hash=code_hash,
            user_id=user_id,
            expires_at=expires_at,
            max_attempts=max_attempts,
        )
        self._session.add(challenge)
        await self._session.flush()
        return challenge

    async def get_latest_active_challenge(
        self, target: str, purpose: OtpPurpose
    ) -> OtpChallenge | None:
        stmt = (
            select(OtpChallenge)
            .where(
                OtpChallenge.target == target,
                OtpChallenge.purpose == purpose,
                OtpChallenge.consumed_at.is_(None),
                OtpChallenge.expires_at > datetime.now(UTC),
            )
            .order_by(OtpChallenge.created_at.desc())
        )
        result = await self._session.execute(stmt)
        return result.scalars().first()

    async def increment_attempts(self, challenge: OtpChallenge) -> None:
        challenge.attempts += 1
        await self._session.flush()

    async def consume(self, challenge: OtpChallenge) -> None:
        challenge.consumed_at = datetime.now(UTC)
        await self._session.flush()

    async def create_password_reset_token(
        self, *, user_id: uuid.UUID, token_hash: str, expires_at: datetime
    ) -> PasswordResetToken:
        record = PasswordResetToken(user_id=user_id, token_hash=token_hash, expires_at=expires_at)
        self._session.add(record)
        await self._session.flush()
        return record

    async def get_active_password_reset_token(self, token_hash: str) -> PasswordResetToken | None:
        stmt = select(PasswordResetToken).where(
            PasswordResetToken.token_hash == token_hash,
            PasswordResetToken.consumed_at.is_(None),
            PasswordResetToken.expires_at > datetime.now(UTC),
        )
        result = await self._session.execute(stmt)
        return result.scalar_one_or_none()

    async def consume_password_reset_token(self, token: PasswordResetToken) -> None:
        token.consumed_at = datetime.now(UTC)
        await self._session.flush()
