"""Database access for users, profiles, and role/permission assignment.

Contains database operations only — no business rules (that's
``app.services.auth_service`` / ``app.services.user_service``) and no HTTP
concerns.
"""

from __future__ import annotations

import uuid
from collections.abc import Collection
from datetime import UTC, datetime, timedelta

from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.identity import Permission, Role, RolePermission, User, UserProfile, UserRole


class DuplicateUserError(Exception):
    """Raised when a unique contact detail is already taken. The service
    layer's pre-insert check catches the ordinary case; this covers the
    race where a concurrent request inserted the same phone/email between
    that check and this flush. Caught by ``app.services.auth_service`` and
    translated to the client-facing ``ConflictError``."""

    def __init__(self, field: str) -> None:
        super().__init__(f"A user with this {field} already exists.")
        self.field = field


class UserRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def contacts_by_ids(
        self, user_ids: Collection[uuid.UUID]
    ) -> dict[uuid.UUID, tuple[str | None, str]]:
        """``user_id -> (full name, phone number)`` in one query."""
        if not user_ids:
            return {}
        rows = await self._session.execute(
            select(User.id, UserProfile.full_name, User.phone_number)
            .outerjoin(UserProfile, UserProfile.user_id == User.id)
            .where(User.id.in_(list(user_ids)))
        )
        return {row.id: (row.full_name, row.phone_number) for row in rows}

    async def get_by_id(self, user_id: uuid.UUID, *, include_deleted: bool = False) -> User | None:
        stmt = select(User).options(selectinload(User.profile)).where(User.id == user_id)
        if not include_deleted:
            stmt = stmt.where(User.deleted_at.is_(None))
        result = await self._session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_phone(self, phone_number: str) -> User | None:
        stmt = (
            select(User)
            .options(selectinload(User.profile))
            .where(User.phone_number == phone_number, User.deleted_at.is_(None))
        )
        result = await self._session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_email(self, email: str) -> User | None:
        stmt = (
            select(User)
            .options(selectinload(User.profile))
            .where(User.email == email, User.deleted_at.is_(None))
        )
        result = await self._session.execute(stmt)
        return result.scalar_one_or_none()

    async def create(
        self,
        *,
        phone_number: str,
        email: str | None,
        password_hash: str,
        full_name: str,
        preferred_language: str = "en",
    ) -> User:
        user = User(phone_number=phone_number, email=email, password_hash=password_hash)
        user.profile = UserProfile(full_name=full_name, preferred_language=preferred_language)
        try:
            async with self._session.begin_nested():
                self._session.add(user)
                await self._session.flush()
        except IntegrityError as exc:
            constraint = str(exc.orig)
            if "uq_users_email" in constraint:
                raise DuplicateUserError("email") from exc
            if "uq_users_phone_number" in constraint:
                raise DuplicateUserError("phone number") from exc
            raise
        return user

    async def get_role_by_slug(self, slug: str) -> Role | None:
        result = await self._session.execute(select(Role).where(Role.slug == slug))
        return result.scalar_one_or_none()

    async def assign_role(
        self, user_id: uuid.UUID, role_id: uuid.UUID, *, assigned_by: uuid.UUID | None = None
    ) -> None:
        existing = await self._session.execute(
            select(UserRole).where(UserRole.user_id == user_id, UserRole.role_id == role_id)
        )
        if existing.scalar_one_or_none() is not None:
            return
        self._session.add(UserRole(user_id=user_id, role_id=role_id, assigned_by=assigned_by))
        await self._session.flush()

    async def get_roles_for_user(self, user_id: uuid.UUID) -> list[str]:
        stmt = (
            select(Role.slug)
            .join(UserRole, UserRole.role_id == Role.id)
            .where(UserRole.user_id == user_id)
        )
        result = await self._session.execute(stmt)
        return list(result.scalars().all())

    async def get_permissions_for_roles(self, role_slugs: list[str]) -> set[str]:
        if not role_slugs:
            return set()
        stmt = (
            select(Permission.code)
            .join(RolePermission, RolePermission.permission_id == Permission.id)
            .join(Role, Role.id == RolePermission.role_id)
            .where(Role.slug.in_(role_slugs))
        )
        result = await self._session.execute(stmt)
        return set(result.scalars().all())

    async def record_login_success(self, user: User) -> None:
        user.failed_login_attempts = 0
        user.locked_until = None
        user.last_login_at = datetime.now(UTC)
        await self._session.flush()

    async def record_login_failure(
        self, user: User, *, max_attempts: int, lockout_seconds: int
    ) -> None:
        user.failed_login_attempts += 1
        if user.failed_login_attempts >= max_attempts:
            user.locked_until = datetime.now(UTC) + timedelta(seconds=lockout_seconds)
        await self._session.flush()

    async def mark_phone_verified(self, user: User) -> None:
        user.phone_verified_at = datetime.now(UTC)
        await self._session.flush()

    async def mark_email_verified(self, user: User) -> None:
        user.email_verified_at = datetime.now(UTC)
        await self._session.flush()

    async def update_password(self, user: User, password_hash: str) -> None:
        user.password_hash = password_hash
        await self._session.flush()

    async def update_profile(self, profile: UserProfile, **fields: object) -> None:
        for key, value in fields.items():
            if value is not None:
                setattr(profile, key, value)
        await self._session.flush()

    async def soft_delete(self, user: User) -> None:
        user.deleted_at = datetime.now(UTC)
        user.is_active = False
        await self._session.flush()

    # ------------------------------------------------------------------
    # Admin user management
    # ------------------------------------------------------------------
    async def list_users(
        self, *, search: str | None, limit: int, offset: int
    ) -> tuple[list[User], int]:
        stmt = select(User).options(selectinload(User.profile)).where(User.deleted_at.is_(None))
        if search:
            like = f"%{search}%"
            condition = User.phone_number.ilike(like) | User.email.ilike(like)
            digits = search.replace(" ", "").replace("-", "")
            if digits.startswith("0") and digits[1:].isdigit():
                # Numbers are stored as +233..., so "024 555 0101" -- the way
                # people write them -- must match without its leading 0.
                condition = condition | User.phone_number.ilike(f"%+233{digits[1:]}%")
            stmt = stmt.where(condition)
        count_result = await self._session.execute(
            select(func.count()).select_from(stmt.subquery())
        )
        total = count_result.scalar_one()
        result = await self._session.execute(
            stmt.order_by(User.created_at.desc()).limit(limit).offset(offset)
        )
        return list(result.scalars().all()), total

    async def suspend(self, user: User, *, reason: str) -> None:
        user.is_suspended = True
        user.suspended_reason = reason
        user.suspended_at = datetime.now(UTC)
        await self._session.flush()

    async def reactivate(self, user: User) -> None:
        user.is_suspended = False
        user.suspended_reason = None
        user.suspended_at = None
        await self._session.flush()

    async def count_by_role(self, role_slug: str) -> int:
        result = await self._session.execute(
            select(UserRole.user_id)
            .join(Role, Role.id == UserRole.role_id)
            .where(Role.slug == role_slug)
        )
        return len(result.scalars().all())
