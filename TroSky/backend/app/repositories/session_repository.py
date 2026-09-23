"""Database access for login sessions and their refresh-token rotation chain."""

from __future__ import annotations

import uuid
from datetime import UTC, datetime

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.identity import RefreshToken, UserSession


class SessionRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def create_session(
        self,
        *,
        user_id: uuid.UUID,
        device_id: str | None,
        device_name: str | None,
        ip_address: str | None,
        user_agent: str | None,
    ) -> UserSession:
        record = UserSession(
            user_id=user_id,
            device_id=device_id,
            device_name=device_name,
            ip_address=ip_address,
            user_agent=user_agent,
        )
        self._session.add(record)
        await self._session.flush()
        return record

    async def get_active_session(self, session_id: uuid.UUID) -> UserSession | None:
        result = await self._session.execute(
            select(UserSession).where(
                UserSession.id == session_id, UserSession.revoked_at.is_(None)
            )
        )
        return result.scalar_one_or_none()

    async def touch_last_seen(self, session_id: uuid.UUID) -> None:
        await self._session.execute(
            update(UserSession)
            .where(UserSession.id == session_id)
            .values(last_seen_at=datetime.now(UTC))
        )

    async def revoke_session(self, session_id: uuid.UUID, *, reason: str) -> None:
        await self._session.execute(
            update(UserSession)
            .where(UserSession.id == session_id, UserSession.revoked_at.is_(None))
            .values(revoked_at=datetime.now(UTC), revoked_reason=reason)
        )
        await self._session.execute(
            update(RefreshToken)
            .where(RefreshToken.session_id == session_id, RefreshToken.revoked_at.is_(None))
            .values(revoked_at=datetime.now(UTC))
        )

    async def revoke_all_sessions_for_user(self, user_id: uuid.UUID, *, reason: str) -> None:
        await self._session.execute(
            update(UserSession)
            .where(UserSession.user_id == user_id, UserSession.revoked_at.is_(None))
            .values(revoked_at=datetime.now(UTC), revoked_reason=reason)
        )
        await self._session.execute(
            update(RefreshToken)
            .where(RefreshToken.user_id == user_id, RefreshToken.revoked_at.is_(None))
            .values(revoked_at=datetime.now(UTC))
        )

    async def list_active_sessions_for_user(self, user_id: uuid.UUID) -> list[UserSession]:
        result = await self._session.execute(
            select(UserSession)
            .where(UserSession.user_id == user_id, UserSession.revoked_at.is_(None))
            .order_by(UserSession.last_seen_at.desc())
        )
        return list(result.scalars().all())

    async def create_refresh_token(
        self,
        *,
        session_id: uuid.UUID,
        user_id: uuid.UUID,
        token_hash: str,
        expires_at: datetime,
    ) -> RefreshToken:
        record = RefreshToken(
            session_id=session_id, user_id=user_id, token_hash=token_hash, expires_at=expires_at
        )
        self._session.add(record)
        await self._session.flush()
        return record

    async def get_refresh_token_by_hash(self, token_hash: str) -> RefreshToken | None:
        result = await self._session.execute(
            select(RefreshToken).where(RefreshToken.token_hash == token_hash)
        )
        return result.scalar_one_or_none()

    async def revoke_refresh_token(
        self, token: RefreshToken, *, replaced_by_id: uuid.UUID | None = None
    ) -> None:
        token.revoked_at = datetime.now(UTC)
        token.replaced_by_id = replaced_by_id
        await self._session.flush()
