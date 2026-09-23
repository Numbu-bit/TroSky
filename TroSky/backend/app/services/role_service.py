"""Granting additional roles to an existing account.

TroSky is a single app in which one person may be a passenger today, a
driver next month, and a fleet owner after that. ``user_roles`` was built
for that from the start ("a user may hold more than one, e.g. a passenger
who is also a driver" — see :mod:`app.models.identity`), but roles used to
be assigned only once, during registration, which left the rest of that
design unreachable from the API.
"""

from __future__ import annotations

import uuid

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.logging import get_logger
from app.core.permissions import SystemRole
from app.repositories.user_repository import UserRepository

logger = get_logger(__name__)

# Roles an account may take on by itself. Administrative roles are granted
# out of band (scripts/seed_dev_data.py) and must never be self-service.
SELF_SERVICE_ROLES: frozenset[SystemRole] = frozenset(
    {SystemRole.PASSENGER, SystemRole.DRIVER, SystemRole.FLEET_OWNER}
)


async def grant_role(
    session: AsyncSession,
    user_id: uuid.UUID,
    role: SystemRole,
    *,
    granted_by: uuid.UUID | None = None,
) -> bool:
    """Give ``user_id`` the ``role``. Returns True if it was newly added.

    Idempotent: ``UserRepository.assign_role`` no-ops when the account
    already holds the role, so re-running onboarding is harmless.
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
    await users.assign_role(user_id, role_row.id, assigned_by=granted_by)
    logger.info("role_granted", user_id=str(user_id), role=role.value)
    return True
