"""Identity dependencies: who the caller is, and the auth/user services.

This is where the *real* ``get_current_principal`` (JWT + session
validation, backed by the database) lives. ``app.core.permissions`` defines
only the authorization *mechanism* (``Principal``, ``require_roles``,
``require_permissions``) against a placeholder principal resolver, deferring
to a real implementation to keep that module free of repository/database
imports. ``app.main.create_app`` wires this implementation in via
``app.dependency_overrides`` -- see the comment there for why.
"""

from __future__ import annotations

from typing import Annotated

from fastapi import Depends, Request
from fastapi.security import HTTPAuthorizationCredentials
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.common_dependencies import DbSession, EmailProviderDep, RedisClient, SmsProviderDep
from app.core.exceptions import AccountSuspendedError, UnauthorizedError
from app.core.permissions import Principal, bearer_scheme
from app.core.security import TokenError, TokenType, decode_token
from app.repositories.session_repository import SessionRepository
from app.repositories.user_repository import UserRepository
from app.services.auth_service import AuthService
from app.services.user_service import UserService

_bearer_scheme = bearer_scheme  # the same scheme the permission guards declare


async def resolve_principal(db: AsyncSession, token: str) -> Principal:
    """Everything that makes an access token *currently* valid: signature
    and expiry, a session that has not been revoked, and an account that is
    still active and not suspended. Roles and permissions are loaded fresh
    from the database, never trusted from the token's own claims.

    This is the single implementation behind both transports: HTTP requests
    (``get_current_principal``) and the tracking WebSocket, which cannot use
    FastAPI dependencies. Keeping one copy is what guarantees that a logout
    or a suspension cuts off both in the same way.

    Raises ``UnauthorizedError`` or ``AccountSuspendedError``.
    """
    try:
        claims = decode_token(token, expected_type=TokenType.ACCESS)
    except TokenError as exc:
        raise UnauthorizedError("Invalid or expired access token.") from exc

    sessions = SessionRepository(db)
    session_record = await sessions.get_active_session(claims.session_id)
    if session_record is None:
        raise UnauthorizedError("This session has been revoked.")

    users = UserRepository(db)
    user = await users.get_by_id(claims.subject_user_id)
    if user is None:
        raise UnauthorizedError("Account no longer exists.")
    if user.is_suspended:
        raise AccountSuspendedError(details={"reason": user.suspended_reason})
    if not user.is_active:
        raise UnauthorizedError("Account is not active.")

    roles = await users.get_roles_for_user(user.id)
    permissions = await users.get_permissions_for_roles(roles)
    permissions |= await users.get_granted_permissions(user.id)

    return Principal(
        user_id=user.id,
        session_id=claims.session_id,
        roles=frozenset(roles),
        permissions=frozenset(permissions),
        is_active=True,
    )


async def get_current_principal(
    request: Request,
    db: DbSession,
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(_bearer_scheme)],
) -> Principal:
    """Resolve the authenticated caller from the ``Authorization: Bearer``
    header -- see ``resolve_principal`` for what is checked."""
    if credentials is None:
        raise UnauthorizedError("Authentication is required.")
    principal = await resolve_principal(db, credentials.credentials)
    request.state.principal = principal
    return principal


CurrentPrincipal = Annotated[Principal, Depends(get_current_principal)]


def get_auth_service(
    db: DbSession, redis: RedisClient, sms: SmsProviderDep, email: EmailProviderDep
) -> AuthService:
    """Bundles the four low-level dependencies ``AuthService`` needs into a
    single injectable, so route signatures don't repeat them."""
    return AuthService(db, redis, sms, email)


def get_user_service(db: DbSession) -> UserService:
    return UserService(db)


AuthServiceDep = Annotated[AuthService, Depends(get_auth_service)]
UserServiceDep = Annotated[UserService, Depends(get_user_service)]
