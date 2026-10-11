"""Top-level ``/api/v1`` router aggregation.

Each domain module (``app.api.v1.auth``, ``app.api.v1.bookings``, ...) owns
its own ``APIRouter`` and is included here as it is implemented in later
phases.
"""

from __future__ import annotations

from fastapi import APIRouter, Depends

from app.api.v1 import (
    admin,
    admin_accounts,
    admin_analytics,
    admin_complaints,
    admin_directory,
    admin_dispatch,
    admin_fraud,
    admin_ops,
    admin_platform,
    admin_reports,
    admin_stream,
    auth,
    bookings,
    complaints,
    driver_trips,
    drivers,
    fleets,
    notifications,
    payments,
    routes,
    safety,
    shared_trips,
    tickets,
    tracking,
    users,
)
from app.core.audit import audit_admin_requests

api_router = APIRouter()
# Every admin request that writes is audited (app.core.audit).
_AUDITED = [Depends(audit_admin_requests)]

api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(users.router, prefix="/users", tags=["users"])
api_router.include_router(drivers.onboarding_router, prefix="/drivers", tags=["drivers"])
api_router.include_router(drivers.router, prefix="/drivers", tags=["drivers"])
# Before the fleet routers: see tracking.vehicles_router.
api_router.include_router(tracking.vehicles_router, tags=["tracking"])
# fleets.router declares its own full paths (/fleet-owners, /fleets, /vehicles)
# rather than sharing one resource prefix, so it is mounted with none here.
api_router.include_router(fleets.onboarding_router, tags=["fleets"])
api_router.include_router(fleets.router, tags=["fleets"])
# routes.router declares its own full paths (/routes, /stops, /trips) for
# the same reason.
api_router.include_router(routes.router, tags=["routes"])
api_router.include_router(driver_trips.router, prefix="/driver-trips", tags=["driver-trips"])
api_router.include_router(bookings.router, prefix="/bookings", tags=["bookings"])
# payments.router declares its own full paths (/payments, /wallet) for the
# same reason as fleets/routes above.
api_router.include_router(payments.router, tags=["payments"])
api_router.include_router(tickets.router, prefix="/tickets", tags=["tickets"])
# tracking.router declares its own full paths (/trips/*, /ws/trips/*) for
# the same reason as fleets/routes/payments above.
api_router.include_router(tracking.router, tags=["tracking"])
api_router.include_router(notifications.router, prefix="/notifications", tags=["notifications"])
api_router.include_router(complaints.router, prefix="/complaints", tags=["complaints"])
# safety.router declares its own full paths (/trips/*, /incidents/*, /sos/*)
# for the same reason as fleets/routes/payments/tracking above.
api_router.include_router(safety.router, tags=["safety"])
api_router.include_router(admin.router, prefix="/admin", tags=["admin"], dependencies=_AUDITED)
# After admin.router, whose /drivers/pending and /vehicles/pending -- and
# admin_analytics' /drivers/performance -- must match before the directory's
# /drivers/{driver_id} and /vehicles/{vehicle_id}.
api_router.include_router(
    admin_analytics.router, prefix="/admin", tags=["admin"], dependencies=_AUDITED
)
api_router.include_router(
    admin_platform.router, prefix="/admin", tags=["admin"], dependencies=_AUDITED
)
api_router.include_router(
    admin_directory.router, prefix="/admin", tags=["admin"], dependencies=_AUDITED
)
api_router.include_router(
    admin_complaints.router, prefix="/admin", tags=["admin"], dependencies=_AUDITED
)
api_router.include_router(admin_ops.router, prefix="/admin", tags=["admin"], dependencies=_AUDITED)
api_router.include_router(
    admin_stream.router, prefix="/admin", tags=["admin"], dependencies=_AUDITED
)
api_router.include_router(
    admin_fraud.router, prefix="/admin", tags=["admin"], dependencies=_AUDITED
)
api_router.include_router(
    admin_reports.router, prefix="/admin", tags=["admin"], dependencies=_AUDITED
)
api_router.include_router(
    admin_accounts.router, prefix="/admin", tags=["admin"], dependencies=_AUDITED
)
api_router.include_router(
    admin_dispatch.router, prefix="/admin", tags=["admin"], dependencies=_AUDITED
)

# ... additional domain routers are attached here as each phase lands.

api_router.include_router(shared_trips.router, prefix="/shared-trips", tags=["shared trips"])
