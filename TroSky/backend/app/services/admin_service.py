"""Admin user management: search/list accounts, suspend, reactivate.

Suspension is enforced at authentication time
(``AuthService``/``app.api.dependencies.get_current_principal`` both reject
a suspended account) — this service only changes the flag and records why.
"""

from __future__ import annotations

import uuid

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import NotFoundError
from app.core.logging import get_logger
from app.models.identity import User
from app.repositories.session_repository import SessionRepository
from app.repositories.user_repository import UserRepository

logger = get_logger(__name__)


class AdminService:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session
        self._users = UserRepository(session)
        self._sessions = SessionRepository(session)

    async def list_users(
        self, *, search: str | None, limit: int, offset: int
    ) -> tuple[list[User], int]:
        return await self._users.list_users(search=search, limit=limit, offset=offset)

    async def suspend_user(
        self, user_id: uuid.UUID, *, reason: str, actioned_by: uuid.UUID
    ) -> User:
        user = await self._users.get_by_id(user_id)
        if user is None:
            raise NotFoundError("User not found.")
        await self._users.suspend(user, reason=reason)
        # A suspended account must not keep using sessions issued before
        # the suspension — revoke everything outstanding immediately.
        await self._sessions.revoke_all_sessions_for_user(user_id, reason="account_suspended")
        logger.warning("user_suspended", user_id=str(user_id), actioned_by=str(actioned_by))
        return user

    async def reactivate_user(self, user_id: uuid.UUID, *, actioned_by: uuid.UUID) -> User:
        user = await self._users.get_by_id(user_id)
        if user is None:
            raise NotFoundError("User not found.")
        await self._users.reactivate(user)
        logger.info("user_reactivated", user_id=str(user_id), actioned_by=str(actioned_by))
        return user
