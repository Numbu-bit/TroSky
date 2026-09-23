"""Unit tests for the role/permission policy mechanism (no external services)."""

from __future__ import annotations

import uuid

import pytest

from app.core.exceptions import ForbiddenError, UnauthorizedError
from app.core.permissions import (
    Permission,
    Principal,
    SystemRole,
    get_current_principal,
    require_permissions,
    require_roles,
    require_self_or_roles,
)


def _principal(
    *, roles: set[str] | None = None, permissions: set[str] | None = None, is_active: bool = True
) -> Principal:
    return Principal(
        user_id=uuid.uuid4(),
        session_id=uuid.uuid4(),
        roles=frozenset(roles or set()),
        permissions=frozenset(permissions or set()),
        is_active=is_active,
    )


class TestPrincipalRoleChecks:
    def test_has_role_true_when_matching(self) -> None:
        p = _principal(roles={SystemRole.DRIVER.value})
        assert p.has_role(SystemRole.DRIVER) is True

    def test_has_role_false_when_not_matching(self) -> None:
        p = _principal(roles={SystemRole.PASSENGER.value})
        assert p.has_role(SystemRole.ADMIN) is False

    def test_has_role_accepts_multiple_candidates(self) -> None:
        p = _principal(roles={SystemRole.FLEET_OWNER.value})
        assert p.has_role(SystemRole.ADMIN, SystemRole.FLEET_OWNER) is True


class TestPrincipalPermissionChecks:
    def test_super_admin_has_every_permission(self) -> None:
        p = _principal(roles={SystemRole.SUPER_ADMIN.value})
        assert p.has_permission(Permission.WALLET_ADJUST) is True

    def test_regular_admin_requires_explicit_permission(self) -> None:
        p = _principal(roles={SystemRole.ADMIN.value}, permissions={Permission.USERS_MANAGE.value})
        assert p.has_permission(Permission.USERS_MANAGE) is True
        assert p.has_permission(Permission.WALLET_ADJUST) is False


class TestGetCurrentPrincipalPlaceholder:
    pytestmark = pytest.mark.asyncio

    async def test_raises_until_phase_2_wires_real_auth(self) -> None:
        with pytest.raises(UnauthorizedError):
            await get_current_principal()


class TestRequireRoles:
    pytestmark = pytest.mark.asyncio

    async def test_allows_matching_role(self) -> None:
        p = _principal(roles={SystemRole.ADMIN.value})
        dependency = require_roles(SystemRole.ADMIN)
        result = await dependency(principal=p)
        assert result is p

    async def test_rejects_missing_role(self) -> None:
        p = _principal(roles={SystemRole.PASSENGER.value})
        dependency = require_roles(SystemRole.ADMIN)
        with pytest.raises(ForbiddenError):
            await dependency(principal=p)

    async def test_rejects_inactive_account_even_with_role(self) -> None:
        p = _principal(roles={SystemRole.ADMIN.value}, is_active=False)
        dependency = require_roles(SystemRole.ADMIN)
        with pytest.raises(ForbiddenError):
            await dependency(principal=p)


class TestRequirePermissions:
    pytestmark = pytest.mark.asyncio

    async def test_allows_matching_permission(self) -> None:
        p = _principal(
            roles={SystemRole.ADMIN.value}, permissions={Permission.DRIVERS_APPROVE.value}
        )
        dependency = require_permissions(Permission.DRIVERS_APPROVE)
        result = await dependency(principal=p)
        assert result is p

    async def test_rejects_missing_permission(self) -> None:
        p = _principal(roles={SystemRole.ADMIN.value}, permissions=set())
        dependency = require_permissions(Permission.DRIVERS_APPROVE)
        with pytest.raises(ForbiddenError):
            await dependency(principal=p)


class TestRequireSelfOrRoles:
    pytestmark = pytest.mark.asyncio

    async def test_owner_can_access_own_resource(self) -> None:
        p = _principal(roles={SystemRole.PASSENGER.value})
        dependency = require_self_or_roles(p.user_id, SystemRole.ADMIN)
        result = await dependency(principal=p)
        assert result is p

    async def test_non_owner_without_role_is_forbidden(self) -> None:
        p = _principal(roles={SystemRole.PASSENGER.value})
        other_user_id = uuid.uuid4()
        dependency = require_self_or_roles(other_user_id, SystemRole.ADMIN)
        with pytest.raises(ForbiddenError):
            await dependency(principal=p)

    async def test_admin_can_access_others_resource(self) -> None:
        p = _principal(roles={SystemRole.ADMIN.value})
        other_user_id = uuid.uuid4()
        dependency = require_self_or_roles(other_user_id, SystemRole.ADMIN)
        result = await dependency(principal=p)
        assert result is p
