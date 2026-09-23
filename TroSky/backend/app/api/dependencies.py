"""Shared FastAPI dependency helpers used across API routers.

This is also where the *real* ``get_current_principal`` (JWT + session
validation, backed by the database) lives. ``app.core.permissions`` defines
only the authorization *mechanism* (``Principal``, ``require_roles``,
``require_permissions``) against a placeholder principal resolver, deferring
to a real implementation to keep that module free of repository/database
imports. ``app.main.create_app`` wires this module's implementation in via
``app.dependency_overrides`` — see the comment there for why.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Annotated
from uuid import UUID

from fastapi import Depends, Header, Query, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from redis.asyncio import Redis
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.exceptions import AccountSuspendedError, UnauthorizedError
from app.core.permissions import Principal
from app.core.redis import get_redis
from app.core.security import TokenError, TokenType, decode_token
from app.providers.email.base import EmailProvider
from app.providers.email.factory import get_email_provider
from app.providers.sms.base import SmsProvider
from app.providers.sms.factory import get_sms_provider
from app.providers.storage.base import ObjectStorageProvider
from app.providers.storage.factory import get_storage_provider
from app.providers.storage.malware_scan import MalwareScanner, NoOpMalwareScanner
from app.repositories.session_repository import SessionRepository
from app.repositories.user_repository import UserRepository
from app.services.admin_service import AdminService
from app.services.analytics_service import AnalyticsService
from app.services.auth_service import AuthService
from app.services.booking_service import BookingService
from app.services.complaint_service import ComplaintService
from app.services.driver_service import DriverService
from app.services.fleet_service import FleetService
from app.services.notification_service import NotificationService
from app.services.payment_service import PaymentService
from app.services.rating_service import RatingService
from app.services.refund_service import RefundService
from app.services.route_service import RouteService
from app.services.safety_service import SafetyService
from app.services.ticket_service import TicketService
from app.services.tracking_service import TrackingService
from app.services.trip_service import TripService
from app.services.user_service import UserService
from app.services.wallet_service import WalletService
from app.services.withdrawal_service import WithdrawalService

# Standard idiom: `db: DbSession` in a route signature resolves an
# AsyncSession via `get_db` without repeating `Depends(get_db)` everywhere.
DbSession = Annotated[AsyncSession, Depends(get_db)]
RedisClient = Annotated[Redis, Depends(get_redis)]

_bearer_scheme = HTTPBearer(auto_error=False, description="TroSky access token (JWT).")


@dataclass(frozen=True, slots=True)
class PaginationParams:
    """Standard limit/offset pagination, validated and capped."""

    limit: int = 20
    offset: int = 0


def _pagination_params(
    limit: Annotated[int, Query(ge=1, le=100)] = 20,
    offset: Annotated[int, Query(ge=0)] = 0,
) -> PaginationParams:
    return PaginationParams(limit=limit, offset=offset)


Pagination = Annotated[PaginationParams, Depends(_pagination_params)]


def _extract_idempotency_key(
    value: Annotated[UUID | None, Header(alias="Idempotency-Key")] = None,
) -> UUID | None:
    """Extracts the optional ``Idempotency-Key`` header for high-risk
    commands (bookings, payments). ``None`` means the caller did not supply
    one; services that require idempotency for correctness enforce that
    explicitly rather than defaulting silently."""
    return value


OptionalIdempotencyKey = Annotated[UUID | None, Depends(_extract_idempotency_key)]


def get_sms_provider_dep() -> SmsProvider:
    return get_sms_provider()


def get_email_provider_dep() -> EmailProvider:
    return get_email_provider()


SmsProviderDep = Annotated[SmsProvider, Depends(get_sms_provider_dep)]
EmailProviderDep = Annotated[EmailProvider, Depends(get_email_provider_dep)]


def get_storage_provider_dep() -> ObjectStorageProvider:
    return get_storage_provider()


def get_malware_scanner_dep() -> MalwareScanner:
    return NoOpMalwareScanner()


StorageProviderDep = Annotated[ObjectStorageProvider, Depends(get_storage_provider_dep)]
MalwareScannerDep = Annotated[MalwareScanner, Depends(get_malware_scanner_dep)]


async def get_current_principal(
    request: Request,
    db: DbSession,
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(_bearer_scheme)],
) -> Principal:
    """Resolve the authenticated caller from the ``Authorization: Bearer``
    header: validate the JWT, confirm the session it references hasn't been
    revoked, and load the user's *current* roles/permissions from the
    database (never trusting stale claims embedded in the token itself
    beyond identity and session linkage)."""
    if credentials is None:
        raise UnauthorizedError("Authentication is required.")

    try:
        claims = decode_token(credentials.credentials, expected_type=TokenType.ACCESS)
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

    principal = Principal(
        user_id=user.id,
        session_id=claims.session_id,
        roles=frozenset(roles),
        permissions=frozenset(permissions),
        is_active=True,
    )
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


def get_driver_service(
    db: DbSession, storage: StorageProviderDep, scanner: MalwareScannerDep
) -> DriverService:
    return DriverService(db, storage, scanner)


def get_fleet_service(
    db: DbSession, storage: StorageProviderDep, scanner: MalwareScannerDep
) -> FleetService:
    return FleetService(db, storage, scanner)


def get_route_service(db: DbSession, redis: RedisClient) -> RouteService:
    return RouteService(db, redis)


def get_trip_service(db: DbSession) -> TripService:
    return TripService(db)


def get_booking_service(db: DbSession, redis: RedisClient) -> BookingService:
    return BookingService(db, redis)


def get_payment_service(db: DbSession) -> PaymentService:
    return PaymentService(db)


def get_wallet_service(db: DbSession) -> WalletService:
    return WalletService(db)


def get_refund_service(db: DbSession) -> RefundService:
    return RefundService(db)


def get_ticket_service(db: DbSession) -> TicketService:
    return TicketService(db)


def get_tracking_service(db: DbSession, redis: RedisClient) -> TrackingService:
    return TrackingService(db, redis)


def get_notification_service(db: DbSession) -> NotificationService:
    return NotificationService(db)


def get_rating_service(db: DbSession) -> RatingService:
    return RatingService(db)


def get_complaint_service(db: DbSession) -> ComplaintService:
    return ComplaintService(db)


def get_safety_service(db: DbSession) -> SafetyService:
    return SafetyService(db)


def get_withdrawal_service(db: DbSession) -> WithdrawalService:
    return WithdrawalService(db)


def get_admin_service(db: DbSession) -> AdminService:
    return AdminService(db)


def get_analytics_service(db: DbSession) -> AnalyticsService:
    return AnalyticsService(db)


AuthServiceDep = Annotated[AuthService, Depends(get_auth_service)]
UserServiceDep = Annotated[UserService, Depends(get_user_service)]
DriverServiceDep = Annotated[DriverService, Depends(get_driver_service)]
FleetServiceDep = Annotated[FleetService, Depends(get_fleet_service)]
RouteServiceDep = Annotated[RouteService, Depends(get_route_service)]
TripServiceDep = Annotated[TripService, Depends(get_trip_service)]
BookingServiceDep = Annotated[BookingService, Depends(get_booking_service)]
PaymentServiceDep = Annotated[PaymentService, Depends(get_payment_service)]
WalletServiceDep = Annotated[WalletService, Depends(get_wallet_service)]
RefundServiceDep = Annotated[RefundService, Depends(get_refund_service)]
TicketServiceDep = Annotated[TicketService, Depends(get_ticket_service)]
TrackingServiceDep = Annotated[TrackingService, Depends(get_tracking_service)]
NotificationServiceDep = Annotated[NotificationService, Depends(get_notification_service)]
RatingServiceDep = Annotated[RatingService, Depends(get_rating_service)]
ComplaintServiceDep = Annotated[ComplaintService, Depends(get_complaint_service)]
WithdrawalServiceDep = Annotated[WithdrawalService, Depends(get_withdrawal_service)]
AdminServiceDep = Annotated[AdminService, Depends(get_admin_service)]
AnalyticsServiceDep = Annotated[AnalyticsService, Depends(get_analytics_service)]
SafetyServiceDep = Annotated[SafetyService, Depends(get_safety_service)]

__all__ = [
    "AdminServiceDep",
    "AnalyticsServiceDep",
    "AuthServiceDep",
    "BookingServiceDep",
    "ComplaintServiceDep",
    "CurrentPrincipal",
    "DbSession",
    "DriverServiceDep",
    "EmailProviderDep",
    "FleetServiceDep",
    "MalwareScannerDep",
    "NotificationServiceDep",
    "OptionalIdempotencyKey",
    "Pagination",
    "PaginationParams",
    "PaymentServiceDep",
    "RatingServiceDep",
    "RedisClient",
    "RefundServiceDep",
    "RouteServiceDep",
    "SafetyServiceDep",
    "SmsProviderDep",
    "StorageProviderDep",
    "TicketServiceDep",
    "TrackingServiceDep",
    "TripServiceDep",
    "UserServiceDep",
    "WalletServiceDep",
    "WithdrawalServiceDep",
    "get_admin_service",
    "get_analytics_service",
    "get_auth_service",
    "get_booking_service",
    "get_complaint_service",
    "get_current_principal",
    "get_driver_service",
    "get_email_provider_dep",
    "get_fleet_service",
    "get_malware_scanner_dep",
    "get_notification_service",
    "get_payment_service",
    "get_rating_service",
    "get_refund_service",
    "get_route_service",
    "get_safety_service",
    "get_sms_provider_dep",
    "get_storage_provider_dep",
    "get_ticket_service",
    "get_tracking_service",
    "get_trip_service",
    "get_user_service",
    "get_wallet_service",
    "get_withdrawal_service",
]
