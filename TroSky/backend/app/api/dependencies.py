"""Compatibility facade over the per-context dependency modules.

Dependencies used to be defined here, all in one module that every change
to any bounded context had to touch. They now live beside the context
they serve:

========================================  ====================================
``app.api.common_dependencies``           database, Redis, pagination,
                                          idempotency keys, providers
``app.api.auth_dependencies``             the current principal, auth, users
``app.api.trip_dependencies``             routes, trips, bookings, tickets,
                                          ratings
``app.api.tracking_dependencies``         live tracking, safety
``app.api.payment_dependencies``          payments, wallet, refunds,
                                          withdrawals
``app.api.fleet_dependencies``            drivers, fleets
``app.api.admin_dependencies``            administration, analytics
``app.api.support_dependencies``          notifications, complaints
========================================  ====================================

Everything is re-exported here so existing ``from app.api.dependencies
import ...`` statements keep working unchanged. The names are the *same
objects*, not copies, so FastAPI ``dependency_overrides`` keyed on a
function imported from here still take effect. New code should import from
the context module directly.
"""

from __future__ import annotations

from app.api.admin_dependencies import (
    AdminServiceDep,
    AnalyticsServiceDep,
    get_admin_service,
    get_analytics_service,
)
from app.api.auth_dependencies import (
    AuthServiceDep,
    CurrentPrincipal,
    UserServiceDep,
    get_auth_service,
    get_current_principal,
    get_user_service,
    resolve_principal,
)
from app.api.common_dependencies import (
    DbSession,
    EmailProviderDep,
    MalwareScannerDep,
    OptionalIdempotencyKey,
    Pagination,
    PaginationParams,
    RedisClient,
    SmsProviderDep,
    StorageProviderDep,
    get_email_provider_dep,
    get_malware_scanner_dep,
    get_sms_provider_dep,
    get_storage_provider_dep,
)
from app.api.common_dependencies import (
    _extract_idempotency_key as _extract_idempotency_key,  # used by unit tests
)
from app.api.common_dependencies import (
    _pagination_params as _pagination_params,  # used by unit tests
)
from app.api.fleet_dependencies import (
    DriverServiceDep,
    FleetServiceDep,
    get_driver_service,
    get_fleet_service,
)
from app.api.payment_dependencies import (
    PaymentServiceDep,
    RefundServiceDep,
    WalletServiceDep,
    WithdrawalServiceDep,
    get_payment_service,
    get_refund_service,
    get_wallet_service,
    get_withdrawal_service,
)
from app.api.support_dependencies import (
    ComplaintServiceDep,
    NotificationServiceDep,
    get_complaint_service,
    get_notification_service,
)
from app.api.tracking_dependencies import (
    SafetyServiceDep,
    TrackingServiceDep,
    get_safety_service,
    get_tracking_service,
)
from app.api.trip_dependencies import (
    BookingServiceDep,
    RatingServiceDep,
    RouteServiceDep,
    TicketServiceDep,
    TripServiceDep,
    get_booking_service,
    get_rating_service,
    get_route_service,
    get_ticket_service,
    get_trip_service,
)

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
    "resolve_principal",
]
