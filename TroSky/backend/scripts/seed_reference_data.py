"""Reference data every TroSky database needs: the system roles and the
permission catalogue, with the admin role granted every permission.

Runs after ``alembic upgrade head`` everywhere migrations run (the
docker-compose api service, the container entrypoint and the Kubernetes
migration Job), because registration cannot work without the roles. It
creates no users and no credentials, so unlike ``seed_dev_data`` it is safe
in production. Idempotent: it only adds what is missing, so new permissions
defined in code reach existing databases on the next deploy.

Run by hand with ``make seed-reference`` (``python -m scripts.seed_reference_data``).
"""

from __future__ import annotations

import asyncio

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import dispose_engine, transactional_session
from app.core.logging import configure_logging, get_logger
from app.core.permissions import Permission, SystemRole
from app.models.identity import Permission as PermissionModel
from app.models.identity import Role, RolePermission

logger = get_logger(__name__)

_ROLE_DEFINITIONS: list[tuple[SystemRole, str, str]] = [
    (SystemRole.PASSENGER, "Passenger", "Books and rides trips."),
    (SystemRole.DRIVER, "Driver", "Operates assigned vehicles and trips."),
    (SystemRole.FLEET_OWNER, "Fleet Owner", "Owns and manages vehicles, drivers, and fleets."),
    (SystemRole.ADMIN, "Administrator", "Operates and moderates the platform."),
    (
        SystemRole.SUPER_ADMIN,
        "Super Administrator",
        "Unrestricted break-glass administrative access.",
    ),
]


async def ensure_roles(session: AsyncSession) -> dict[str, Role]:
    roles: dict[str, Role] = {}
    for slug, name, description in _ROLE_DEFINITIONS:
        result = await session.execute(select(Role).where(Role.slug == slug.value))
        role = result.scalar_one_or_none()
        if role is None:
            role = Role(slug=slug.value, name=name, description=description, is_system=True)
            session.add(role)
            await session.flush()
            logger.info("seed_role_created", slug=slug.value)
        roles[slug.value] = role
    return roles


async def ensure_permissions(session: AsyncSession) -> dict[str, PermissionModel]:
    permissions: dict[str, PermissionModel] = {}
    for perm in Permission:
        result = await session.execute(
            select(PermissionModel).where(PermissionModel.code == perm.value)
        )
        record = result.scalar_one_or_none()
        if record is None:
            record = PermissionModel(
                code=perm.value, description=perm.name.replace("_", " ").title()
            )
            session.add(record)
            await session.flush()
            logger.info("seed_permission_created", code=perm.value)
        permissions[perm.value] = record
    return permissions


async def ensure_admin_has_all_permissions(
    session: AsyncSession, admin_role: Role, permissions: dict[str, PermissionModel]
) -> None:
    for permission in permissions.values():
        result = await session.execute(
            select(RolePermission).where(
                RolePermission.role_id == admin_role.id,
                RolePermission.permission_id == permission.id,
            )
        )
        if result.scalar_one_or_none() is None:
            session.add(RolePermission(role_id=admin_role.id, permission_id=permission.id))
    await session.flush()


async def seed_reference_data() -> None:
    async with transactional_session() as session:
        roles = await ensure_roles(session)
        permissions = await ensure_permissions(session)
        await ensure_admin_has_all_permissions(session, roles[SystemRole.ADMIN.value], permissions)
    logger.info("reference_data_ready", roles=len(roles), permissions=len(permissions))


async def main() -> None:
    configure_logging(log_level="INFO", json_logs=False)
    try:
        await seed_reference_data()
    finally:
        await dispose_engine()


if __name__ == "__main__":
    asyncio.run(main())
