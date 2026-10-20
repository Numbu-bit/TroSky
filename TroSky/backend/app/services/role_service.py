"""Granting roles to an existing account, and which roles may share one.

An account is one of two kinds:

* a **passenger account**, which books and rides;
* a **work account**: a driver, a fleet owner, or an owner who drives their
  own vehicle (both roles on one account).

They never mix. Someone who drives and also rides has two accounts, each
with its own phone number and email: the passenger app and the driver app
never share a login. An account becomes a driver or a fleet owner by
creating that profile (``POST /drivers/me``, ``POST /fleet-owners/me``),
which a passenger account is refused. Team roles (admin, staff, ...) are
outside the rule: a team member's account may also be a passenger or a
work account.
"""

from __future__ import annotations

import uuid
from collections.abc import Collection

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ConflictError
from app.core.logging import get_logger
from app.core.permissions import SystemRole
from app.repositories.user_repository import UserRepository

logger = get_logger(__name__)

# Roles an account may take on by itself. Administrative roles are granted
# out of band (scripts/seed_dev_data.py) and must never be self-service.
SELF_SERVICE_ROLES: frozenset[SystemRole] = frozenset(
    {SystemRole.PASSENGER, SystemRole.DRIVER, SystemRole.FLEET_OWNER}
)
# The roles of a work account; it may hold one or both.
WORK_ROLES: frozenset[SystemRole] = frozenset({SystemRole.DRIVER, SystemRole.FLEET_OWNER})


def account_kind_conflict(held: Collection[str], role: SystemRole) -> ConflictError | None:
    """Why an account holding ``held`` cannot take on ``role``; None if it
    can."""
    work = {r.value for r in WORK_ROLES}
    if role in WORK_ROLES and SystemRole.PASSENGER.value in held:
        return ConflictError(
            "This is a passenger account. Drivers and fleet owners have an account of "
            "their own: sign up again as a driver or fleet owner, with a different phone "
            "number and email.",
            code="PASSENGER_ACCOUNT",
        )
    if role == SystemRole.PASSENGER and work & set(held):
        return ConflictError(
            "This account is for driving or running a fleet. To ride, sign up for a "
            "passenger account with a different phone number and email.",
            code="WORK_ACCOUNT",
        )
    return None


async def assert_can_take_role(session: AsyncSession, user_id: uuid.UUID, role: SystemRole) -> None:
    """Refuse, before anything is created, a role this kind of account
    cannot hold."""
    conflict = account_kind_conflict(
        await UserRepository(session).get_roles_for_user(user_id), role
    )
    if conflict is not None:
        raise conflict


async def grant_role(
    session: AsyncSession,
    user_id: uuid.UUID,
    role: SystemRole,
    *,
    granted_by: uuid.UUID | None = None,
) -> bool:
    """Give ``user_id`` the ``role``. Returns True if it was newly added.

    Idempotent: ``UserRepository.assign_role`` no-ops when the account
    already holds the role, so re-running onboarding is harmless. A role the
    account's kind cannot hold is refused (``account_kind_conflict``).
    """
    users = UserRepository(session)
    role_row = await users.get_role_by_slug(role.value)
    if role_row is None:
        # Roles are seeded at deploy time (scripts/seed_dev_data.py);
        # reaching this means the environment was never seeded.
        raise RuntimeError(f"Role '{role.value}' is not seeded in this environment.")
    held = set(await users.get_roles_for_user(user_id))
    if role.value in held:
        return False
    conflict = account_kind_conflict(held, role)
    if conflict is not None:
        raise conflict
    await users.assign_role(user_id, role_row.id, assigned_by=granted_by)
    logger.info("role_granted", user_id=str(user_id), role=role.value)
    return True
