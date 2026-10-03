"""The reference data step that runs after every migration."""

from __future__ import annotations

import pytest
from scripts.seed_reference_data import seed_reference_data
from sqlalchemy import func, select

from app.core.database import get_session_factory
from app.core.permissions import Permission, SystemRole
from app.models.identity import Permission as PermissionModel
from app.models.identity import Role, RolePermission

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]


async def test_every_role_and_permission_exists_and_a_rerun_adds_nothing(
    require_postgres: None,
) -> None:
    await seed_reference_data()
    await seed_reference_data()

    async with get_session_factory()() as session:
        slugs = list(await session.scalars(select(Role.slug)))
        codes = list(await session.scalars(select(PermissionModel.code)))
        admin_grants = await session.scalar(
            select(func.count())
            .select_from(RolePermission)
            .join(Role, Role.id == RolePermission.role_id)
            .where(Role.slug == SystemRole.ADMIN.value)
        )

    assert sorted(slugs) == sorted(role.value for role in SystemRole)
    assert sorted(codes) == sorted(permission.value for permission in Permission)
    assert admin_grants == len(Permission)
