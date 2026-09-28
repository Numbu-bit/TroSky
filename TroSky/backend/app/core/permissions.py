"""Policy-based authorization primitives.

Role/permission checks are enforced **server-side** on every protected route
via FastAPI dependencies — the mobile/web clients' own role-based UI is
never trusted as an authorization boundary.

The concrete ``users`` / ``roles`` / ``permissions`` persistence model is
introduced in Phase 2 (``app.models.identity``); this module defines the
*mechanism* — a ``Principal`` describing the authenticated caller and
dependency factories that enforce role/permission/ownership rules — so every
later phase wires into the same, single authorization pathway rather than
inventing ad-hoc checks per router.
"""

from __future__ import annotations

import uuid
from collections.abc import Callable, Coroutine
from dataclasses import dataclass, field
from enum import StrEnum
from typing import Any

from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.core.exceptions import ForbiddenError, UnauthorizedError


class SystemRole(StrEnum):
    """Baseline platform roles. Additional fine-grained permissions are
    layered on top via the ``role_permissions`` table introduced in Phase 2."""

    PASSENGER = "passenger"
    DRIVER = "driver"
    FLEET_OWNER = "fleet_owner"
    ADMIN = "admin"
    SUPER_ADMIN = "super_admin"


class Permission(StrEnum):
    """Fine-grained permission slugs enforced for sensitive administrative
    and cross-tenant actions. Assigned to roles via ``role_permissions``."""

    USERS_MANAGE = "users:manage"
    USERS_SUSPEND = "users:suspend"
    DRIVERS_APPROVE = "drivers:approve"
    VEHICLES_APPROVE = "vehicles:approve"
    FLEETS_MANAGE_OWN = "fleets:manage_own"
    ROUTES_MANAGE = "routes:manage"
    TRIPS_MANAGE = "trips:manage"
    TRIPS_MONITOR_LIVE = "trips:monitor_live"
    BOOKINGS_VIEW_ANY = "bookings:view_any"
    PAYMENTS_REVIEW = "payments:review"
    REFUNDS_APPROVE = "refunds:approve"
    WITHDRAWALS_REVIEW = "withdrawals:review"
    WALLET_ADJUST = "wallet:adjust"
    COMPLAINTS_MANAGE = "complaints:manage"
    INCIDENTS_MANAGE = "incidents:manage"
    SOS_REVIEW = "sos:review"
    REPORTS_VIEW = "reports:view"
    SYSTEM_SETTINGS_MANAGE = "system_settings:manage"
    FEATURE_FLAGS_MANAGE = "feature_flags:manage"
    AUDIT_LOGS_VIEW = "audit_logs:view"


@dataclass(frozen=True, slots=True)
class Principal:
    """The authenticated caller, resolved once per request by the auth
    dependency (Phase 2) and reused by every downstream permission check."""

    user_id: uuid.UUID
    session_id: uuid.UUID
    roles: frozenset[str]
    permissions: frozenset[str] = field(default_factory=frozenset)
    is_active: bool = True

    def has_role(self, *roles: SystemRole | str) -> bool:
        wanted = {r.value if isinstance(r, SystemRole) else r for r in roles}
        return bool(wanted & self.roles)

    def has_permission(self, *permissions: Permission | str) -> bool:
        if self.has_role(SystemRole.SUPER_ADMIN):
            return True
        wanted = {p.value if isinstance(p, Permission) else p for p in permissions}
        return bool(wanted & self.permissions)


PrincipalDependency = Callable[..., Coroutine[Any, Any, Principal]]


def require_roles(*roles: SystemRole) -> PrincipalDependency:
    """Dependency factory: caller must hold at least one of ``roles``.

    Usage::

        @router.post(..., dependencies=[Depends(require_roles(SystemRole.ADMIN))])
    """

    async def _dependency(principal: Principal = Depends(get_current_principal)) -> Principal:
        if not principal.is_active:
            raise ForbiddenError("Account is not active.")
        if not principal.has_role(*roles):
            allowed = ", ".join(r.value for r in roles)
            raise ForbiddenError(f"This action requires one of the following roles: {allowed}")
        return principal

    return _dependency


def require_permissions(*permissions: Permission) -> PrincipalDependency:
    """Dependency factory: caller must hold at least one of ``permissions``."""

    async def _dependency(principal: Principal = Depends(get_current_principal)) -> Principal:
        if not principal.is_active:
            raise ForbiddenError("Account is not active.")
        if not principal.has_permission(*permissions):
            raise ForbiddenError("This action requires a permission your account does not have.")
        return principal

    return _dependency


def require_self_or_roles(
    resource_owner_id: uuid.UUID, *roles: SystemRole
) -> Callable[[Principal], Coroutine[Any, Any, Principal]]:
    """Enforce that the principal either owns ``resource_owner_id`` or holds
    one of ``roles`` — the core guard against horizontal privilege escalation
    (e.g. a passenger reading another passenger's booking)."""

    async def _dependency(principal: Principal = Depends(get_current_principal)) -> Principal:
        if principal.user_id == resource_owner_id:
            return principal
        if principal.has_role(*roles):
            return principal
        raise ForbiddenError("You do not have access to this resource.")

    return _dependency


# The one bearer-token scheme every protected route declares -- here and
# in the real ``app.api.auth_dependencies.get_current_principal``.
bearer_scheme = HTTPBearer(auto_error=False, description="TroSky access token (JWT).")


async def get_current_principal(
    _credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
) -> Principal:
    """Placeholder resolved for real by ``app.api.dependencies.get_current_principal``
    once Phase 2 introduces session/JWT-backed authentication. Kept here so
    permission dependency factories have a stable import target from Phase 1
    onward; it always raises until overridden by the Phase 2 dependency.

    It still declares the bearer token: OpenAPI is built from this signature,
    not from the override, so without it routes guarded only by
    ``require_roles``/``require_permissions`` were documented as public and
    Swagger never sent them the token.
    """
    raise UnauthorizedError("Authentication is not yet configured for this route.")
