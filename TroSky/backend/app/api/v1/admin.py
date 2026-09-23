"""Administrator endpoints.

Grows substantially in Phase 10 (dashboard, user/payment/report
management); this phase adds driver/vehicle approval review, route/stop/
schedule/trip management, and read-only booking review.
"""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends

from app.api.dependencies import (
    AdminServiceDep,
    AnalyticsServiceDep,
    BookingServiceDep,
    ComplaintServiceDep,
    CurrentPrincipal,
    DriverServiceDep,
    FleetServiceDep,
    Pagination,
    PaymentServiceDep,
    RatingServiceDep,
    RefundServiceDep,
    RouteServiceDep,
    SafetyServiceDep,
    TripServiceDep,
    WithdrawalServiceDep,
)
from app.core.permissions import Permission, require_permissions
from app.models.bookings import BookingStatus, CancellationStatus
from app.models.feedback import ComplaintStatus
from app.models.payments import RefundStatus, WithdrawalStatus
from app.models.routes import Stop
from app.models.safety import IncidentStatus, SosAlertStatus
from app.schemas.admin import AdminUserSummaryResponse, SuspendUserRequest
from app.schemas.analytics import PlatformOverviewResponse
from app.schemas.booking import (
    BookingPassengerResponse,
    BookingResponse,
    CancellationRequestResponse,
)
from app.schemas.common import MessageResponse, PaginatedResponse
from app.schemas.driver import ApprovalReviewRequest, DriverResponse
from app.schemas.feedback import (
    ComplaintDecisionRequest,
    ComplaintResponse,
    DriverRatingSummaryResponse,
)
from app.schemas.fleet import VehicleResponse
from app.schemas.payment import (
    CancellationReviewRequest,
    RefundDecisionRequest,
    RefundRequestResponse,
)
from app.schemas.route import (
    RouteCreateRequest,
    RouteResponse,
    RouteScheduleCreateRequest,
    RouteScheduleResponse,
    ScheduleTripRequest,
    StopCreateRequest,
    StopResponse,
)
from app.schemas.safety import (
    IncidentDecisionRequest,
    IncidentResponse,
    SosAlertResponse,
    SosDecisionRequest,
)
from app.schemas.trip import (
    AssignTripDriverRequest,
    AssignTripVehicleRequest,
    CancelTripRequest,
    TripCreateRequest,
    TripResponse,
)
from app.schemas.withdrawal import (
    CompleteWithdrawalRequest,
    FailWithdrawalRequest,
    WithdrawalDecisionRequest,
    WithdrawalResponse,
)
from app.utilities.geo import wkb_to_latlng

router = APIRouter()


def _stop_response(stop: Stop) -> StopResponse:
    latlng = wkb_to_latlng(stop.location)
    latitude, longitude = latlng if latlng is not None else (0.0, 0.0)
    return StopResponse(
        id=stop.id,
        name=stop.name,
        code=stop.code,
        address=stop.address,
        city=stop.city,
        region=stop.region,
        latitude=latitude,
        longitude=longitude,
    )


@router.get(
    "/drivers/pending",
    response_model=PaginatedResponse[DriverResponse],
    dependencies=[Depends(require_permissions(Permission.DRIVERS_APPROVE))],
)
async def list_pending_drivers(
    pagination: Pagination, drivers: DriverServiceDep
) -> PaginatedResponse[DriverResponse]:
    records, total = await drivers.list_pending(limit=pagination.limit, offset=pagination.offset)
    return PaginatedResponse(
        items=[DriverResponse.model_validate(d) for d in records],
        total=total,
        limit=pagination.limit,
        offset=pagination.offset,
    )


@router.post(
    "/drivers/{driver_id}/approve",
    response_model=DriverResponse,
    dependencies=[Depends(require_permissions(Permission.DRIVERS_APPROVE))],
)
async def approve_driver(
    driver_id: uuid.UUID,
    body: ApprovalReviewRequest,
    principal: CurrentPrincipal,
    drivers: DriverServiceDep,
) -> DriverResponse:
    driver = await drivers.approve(driver_id, reviewer_id=principal.user_id, notes=body.notes)
    return DriverResponse.model_validate(driver)


@router.post(
    "/drivers/{driver_id}/reject",
    response_model=DriverResponse,
    dependencies=[Depends(require_permissions(Permission.DRIVERS_APPROVE))],
)
async def reject_driver(
    driver_id: uuid.UUID,
    body: ApprovalReviewRequest,
    principal: CurrentPrincipal,
    drivers: DriverServiceDep,
) -> DriverResponse:
    rejection_reason = body.rejection_reason or "Not specified"
    driver = await drivers.reject(
        driver_id,
        reviewer_id=principal.user_id,
        rejection_reason=rejection_reason,
        notes=body.notes,
    )
    return DriverResponse.model_validate(driver)


@router.get(
    "/vehicles/pending",
    response_model=PaginatedResponse[VehicleResponse],
    dependencies=[Depends(require_permissions(Permission.VEHICLES_APPROVE))],
)
async def list_pending_vehicles(
    pagination: Pagination, fleets: FleetServiceDep
) -> PaginatedResponse[VehicleResponse]:
    records, total = await fleets.list_pending_vehicles(
        limit=pagination.limit, offset=pagination.offset
    )
    return PaginatedResponse(
        items=[VehicleResponse.model_validate(v) for v in records],
        total=total,
        limit=pagination.limit,
        offset=pagination.offset,
    )


@router.post(
    "/vehicles/{vehicle_id}/approve",
    response_model=VehicleResponse,
    dependencies=[Depends(require_permissions(Permission.VEHICLES_APPROVE))],
)
async def approve_vehicle(
    vehicle_id: uuid.UUID,
    body: ApprovalReviewRequest,
    principal: CurrentPrincipal,
    fleets: FleetServiceDep,
) -> VehicleResponse:
    vehicle = await fleets.approve_vehicle(
        vehicle_id, reviewer_id=principal.user_id, notes=body.notes
    )
    return VehicleResponse.model_validate(vehicle)


@router.post(
    "/vehicles/{vehicle_id}/reject",
    response_model=VehicleResponse,
    dependencies=[Depends(require_permissions(Permission.VEHICLES_APPROVE))],
)
async def reject_vehicle(
    vehicle_id: uuid.UUID,
    body: ApprovalReviewRequest,
    principal: CurrentPrincipal,
    fleets: FleetServiceDep,
) -> VehicleResponse:
    rejection_reason = body.rejection_reason or "Not specified"
    vehicle = await fleets.reject_vehicle(
        vehicle_id,
        reviewer_id=principal.user_id,
        rejection_reason=rejection_reason,
        notes=body.notes,
    )
    return VehicleResponse.model_validate(vehicle)


# ---------------------------------------------------------------------------
# Routes, stops, schedules
# ---------------------------------------------------------------------------
@router.post(
    "/stops",
    response_model=StopResponse,
    status_code=201,
    dependencies=[Depends(require_permissions(Permission.ROUTES_MANAGE))],
)
async def create_stop(body: StopCreateRequest, service: RouteServiceDep) -> StopResponse:
    stop = await service.create_stop(
        name=body.name,
        code=body.code,
        latitude=body.latitude,
        longitude=body.longitude,
        address=body.address,
        city=body.city,
        region=body.region,
    )
    return _stop_response(stop)


@router.post(
    "/routes",
    response_model=RouteResponse,
    status_code=201,
    dependencies=[Depends(require_permissions(Permission.ROUTES_MANAGE))],
)
async def create_route(
    body: RouteCreateRequest, principal: CurrentPrincipal, service: RouteServiceDep
) -> RouteResponse:
    route = await service.create_route(
        name=body.name,
        origin_stop_id=body.origin_stop_id,
        destination_stop_id=body.destination_stop_id,
        distance_km=body.distance_km,
        estimated_duration_minutes=body.estimated_duration_minutes,
        intermediate_stop_ids=body.intermediate_stop_ids,
        created_by=principal.user_id,
    )
    return RouteResponse.model_validate(route)


@router.post(
    "/routes/{route_id}/schedules",
    response_model=RouteScheduleResponse,
    status_code=201,
    dependencies=[Depends(require_permissions(Permission.ROUTES_MANAGE))],
)
async def create_route_schedule(
    route_id: uuid.UUID, body: RouteScheduleCreateRequest, service: RouteServiceDep
) -> RouteScheduleResponse:
    schedule = await service.create_schedule(
        route_id=route_id,
        departure_time=body.departure_time,
        days_of_week=body.days_of_week,
        fare_amount=body.fare_amount,
    )
    return RouteScheduleResponse.model_validate(schedule)


# ---------------------------------------------------------------------------
# Trips
# ---------------------------------------------------------------------------
@router.post(
    "/trips",
    response_model=TripResponse,
    status_code=201,
    dependencies=[Depends(require_permissions(Permission.TRIPS_MANAGE))],
)
async def create_trip(
    body: TripCreateRequest, principal: CurrentPrincipal, service: TripServiceDep
) -> TripResponse:
    trip = await service.create_trip(
        route_id=body.route_id,
        route_schedule_id=None,
        scheduled_departure_at=body.scheduled_departure_at,
        scheduled_arrival_at=body.scheduled_arrival_at,
        fare_amount=body.fare_amount,
        created_by=principal.user_id,
    )
    return TripResponse.model_validate(trip)


@router.post(
    "/trips/from-schedule",
    response_model=TripResponse,
    status_code=201,
    dependencies=[Depends(require_permissions(Permission.TRIPS_MANAGE))],
)
async def create_trip_from_schedule(
    body: ScheduleTripRequest, principal: CurrentPrincipal, service: RouteServiceDep
) -> TripResponse:
    trip = await service.create_trip_from_schedule(
        schedule_id=body.schedule_id, travel_date=body.travel_date, created_by=principal.user_id
    )
    return TripResponse.model_validate(trip)


@router.post(
    "/trips/{trip_id}/assign-driver",
    response_model=MessageResponse,
    dependencies=[Depends(require_permissions(Permission.TRIPS_MANAGE))],
)
async def assign_trip_driver(
    trip_id: uuid.UUID,
    body: AssignTripDriverRequest,
    principal: CurrentPrincipal,
    service: TripServiceDep,
) -> MessageResponse:
    await service.assign_driver(trip_id, body.driver_id, assigned_by=principal.user_id)
    return MessageResponse(message="Driver assigned.")


@router.post(
    "/trips/{trip_id}/assign-vehicle",
    response_model=MessageResponse,
    dependencies=[Depends(require_permissions(Permission.TRIPS_MANAGE))],
)
async def assign_trip_vehicle(
    trip_id: uuid.UUID,
    body: AssignTripVehicleRequest,
    principal: CurrentPrincipal,
    service: TripServiceDep,
) -> MessageResponse:
    await service.assign_vehicle(trip_id, body.vehicle_id, assigned_by=principal.user_id)
    return MessageResponse(message="Vehicle assigned.")


@router.post(
    "/trips/{trip_id}/cancel",
    response_model=TripResponse,
    dependencies=[Depends(require_permissions(Permission.TRIPS_MANAGE))],
)
async def cancel_trip(
    trip_id: uuid.UUID,
    body: CancelTripRequest,
    principal: CurrentPrincipal,
    service: TripServiceDep,
) -> TripResponse:
    trip = await service.cancel_trip(trip_id, cancelled_by=principal.user_id, reason=body.reason)
    return TripResponse.model_validate(trip)


# ---------------------------------------------------------------------------
# Bookings (read-only review)
# ---------------------------------------------------------------------------
@router.get(
    "/bookings",
    response_model=PaginatedResponse[BookingResponse],
    dependencies=[Depends(require_permissions(Permission.BOOKINGS_VIEW_ANY))],
)
async def list_all_bookings(
    pagination: Pagination,
    service: BookingServiceDep,
    booking_status: BookingStatus | None = None,
) -> PaginatedResponse[BookingResponse]:
    records, total = await service.list_all_bookings(
        status=booking_status, limit=pagination.limit, offset=pagination.offset
    )
    items = []
    for booking in records:
        passengers = await service.get_booking_passengers(booking.id)
        items.append(
            BookingResponse(
                id=booking.id,
                booking_reference=booking.booking_reference,
                trip_id=booking.trip_id,
                status=booking.status,
                passenger_count=booking.passenger_count,
                origin_stop_id=booking.origin_stop_id,
                destination_stop_id=booking.destination_stop_id,
                fare_amount=booking.fare_amount,
                platform_fee=booking.platform_fee,
                total_amount=booking.total_amount,
                expires_at=booking.expires_at,
                created_at=booking.created_at,
                passengers=[BookingPassengerResponse.model_validate(p) for p in passengers],
            )
        )
    return PaginatedResponse(
        items=items, total=total, limit=pagination.limit, offset=pagination.offset
    )


# ---------------------------------------------------------------------------
# Cancellation review (post-boarding cancellations only — pre-boarding ones
# are auto-decided by BookingService.cancel_booking itself)
# ---------------------------------------------------------------------------
@router.get(
    "/cancellation-requests",
    response_model=PaginatedResponse[CancellationRequestResponse],
    dependencies=[Depends(require_permissions(Permission.REFUNDS_APPROVE))],
)
async def list_cancellation_requests(
    pagination: Pagination,
    bookings: BookingServiceDep,
    request_status: CancellationStatus | None = None,
) -> PaginatedResponse[CancellationRequestResponse]:
    records, total = await bookings.list_cancellation_requests(
        status=request_status, limit=pagination.limit, offset=pagination.offset
    )
    return PaginatedResponse(
        items=[CancellationRequestResponse.model_validate(r) for r in records],
        total=total,
        limit=pagination.limit,
        offset=pagination.offset,
    )


@router.post(
    "/cancellation-requests/{request_id}/review",
    response_model=BookingResponse,
    dependencies=[Depends(require_permissions(Permission.REFUNDS_APPROVE))],
)
async def review_cancellation_request(
    request_id: uuid.UUID,
    body: CancellationReviewRequest,
    principal: CurrentPrincipal,
    bookings: BookingServiceDep,
    payments: PaymentServiceDep,
) -> BookingResponse:
    _cancellation_request, booking = await bookings.review_cancellation_request(
        request_id,
        reviewer_id=principal.user_id,
        approve=body.approve,
        refund_eligible=body.refund_eligible,
        notes=body.notes,
    )
    await payments.create_refund_request_for_cancelled_booking(
        booking, requested_by=principal.user_id
    )
    passengers = await bookings.get_booking_passengers(booking.id)
    return BookingResponse(
        id=booking.id,
        booking_reference=booking.booking_reference,
        trip_id=booking.trip_id,
        status=booking.status,
        passenger_count=booking.passenger_count,
        origin_stop_id=booking.origin_stop_id,
        destination_stop_id=booking.destination_stop_id,
        fare_amount=booking.fare_amount,
        platform_fee=booking.platform_fee,
        total_amount=booking.total_amount,
        expires_at=booking.expires_at,
        created_at=booking.created_at,
        passengers=[BookingPassengerResponse.model_validate(p) for p in passengers],
    )


# ---------------------------------------------------------------------------
# Refund requests
# ---------------------------------------------------------------------------
@router.get(
    "/refund-requests",
    response_model=PaginatedResponse[RefundRequestResponse],
    dependencies=[Depends(require_permissions(Permission.REFUNDS_APPROVE))],
)
async def list_refund_requests(
    pagination: Pagination,
    refunds: RefundServiceDep,
    refund_status: RefundStatus | None = None,
) -> PaginatedResponse[RefundRequestResponse]:
    records, total = await refunds.list_refund_requests(
        status=refund_status, limit=pagination.limit, offset=pagination.offset
    )
    return PaginatedResponse(
        items=[RefundRequestResponse.model_validate(r) for r in records],
        total=total,
        limit=pagination.limit,
        offset=pagination.offset,
    )


@router.post(
    "/refund-requests/{refund_id}/approve",
    response_model=RefundRequestResponse,
    dependencies=[Depends(require_permissions(Permission.REFUNDS_APPROVE))],
)
async def approve_refund_request(
    refund_id: uuid.UUID,
    body: RefundDecisionRequest,
    principal: CurrentPrincipal,
    refunds: RefundServiceDep,
) -> RefundRequestResponse:
    """Approving immediately processes the payout (wallet credit, or a call
    to the payment provider's refund endpoint) — there is no separate
    "process" step for the MVP."""
    refund_request = await refunds.approve_and_process(
        refund_id, reviewer_id=principal.user_id, notes=body.notes
    )
    return RefundRequestResponse.model_validate(refund_request)


@router.post(
    "/refund-requests/{refund_id}/reject",
    response_model=RefundRequestResponse,
    dependencies=[Depends(require_permissions(Permission.REFUNDS_APPROVE))],
)
async def reject_refund_request(
    refund_id: uuid.UUID,
    body: RefundDecisionRequest,
    principal: CurrentPrincipal,
    refunds: RefundServiceDep,
) -> RefundRequestResponse:
    refund_request = await refunds.reject(
        refund_id, reviewer_id=principal.user_id, notes=body.notes
    )
    return RefundRequestResponse.model_validate(refund_request)


# ---------------------------------------------------------------------------
# Complaints
# ---------------------------------------------------------------------------
@router.get(
    "/complaints",
    response_model=PaginatedResponse[ComplaintResponse],
    dependencies=[Depends(require_permissions(Permission.COMPLAINTS_MANAGE))],
)
async def list_complaints(
    pagination: Pagination,
    complaints: ComplaintServiceDep,
    complaint_status: ComplaintStatus | None = None,
) -> PaginatedResponse[ComplaintResponse]:
    records, total = await complaints.list_all_complaints(
        status=complaint_status, limit=pagination.limit, offset=pagination.offset
    )
    return PaginatedResponse(
        items=[ComplaintResponse.model_validate(c) for c in records],
        total=total,
        limit=pagination.limit,
        offset=pagination.offset,
    )


@router.post(
    "/complaints/{complaint_id}/resolve",
    response_model=ComplaintResponse,
    dependencies=[Depends(require_permissions(Permission.COMPLAINTS_MANAGE))],
)
async def resolve_complaint(
    complaint_id: uuid.UUID,
    body: ComplaintDecisionRequest,
    principal: CurrentPrincipal,
    complaints: ComplaintServiceDep,
) -> ComplaintResponse:
    complaint = await complaints.resolve(
        complaint_id, reviewer_id=principal.user_id, notes=body.notes
    )
    return ComplaintResponse.model_validate(complaint)


@router.post(
    "/complaints/{complaint_id}/dismiss",
    response_model=ComplaintResponse,
    dependencies=[Depends(require_permissions(Permission.COMPLAINTS_MANAGE))],
)
async def dismiss_complaint(
    complaint_id: uuid.UUID,
    body: ComplaintDecisionRequest,
    principal: CurrentPrincipal,
    complaints: ComplaintServiceDep,
) -> ComplaintResponse:
    complaint = await complaints.dismiss(
        complaint_id, reviewer_id=principal.user_id, notes=body.notes
    )
    return ComplaintResponse.model_validate(complaint)


# ---------------------------------------------------------------------------
# Incidents
# ---------------------------------------------------------------------------
@router.get(
    "/incidents",
    response_model=PaginatedResponse[IncidentResponse],
    dependencies=[Depends(require_permissions(Permission.INCIDENTS_MANAGE))],
)
async def list_incidents(
    pagination: Pagination,
    safety: SafetyServiceDep,
    incident_status: IncidentStatus | None = None,
) -> PaginatedResponse[IncidentResponse]:
    records, total = await safety.list_incidents(
        status=incident_status, limit=pagination.limit, offset=pagination.offset
    )
    return PaginatedResponse(
        items=[IncidentResponse.model_validate(i) for i in records],
        total=total,
        limit=pagination.limit,
        offset=pagination.offset,
    )


@router.post(
    "/incidents/{incident_id}/resolve",
    response_model=IncidentResponse,
    dependencies=[Depends(require_permissions(Permission.INCIDENTS_MANAGE))],
)
async def resolve_incident(
    incident_id: uuid.UUID,
    body: IncidentDecisionRequest,
    principal: CurrentPrincipal,
    safety: SafetyServiceDep,
) -> IncidentResponse:
    incident = await safety.resolve_incident(
        incident_id, reviewer_id=principal.user_id, notes=body.notes
    )
    return IncidentResponse.model_validate(incident)


# ---------------------------------------------------------------------------
# SOS alerts
# ---------------------------------------------------------------------------
@router.get(
    "/sos-alerts",
    response_model=PaginatedResponse[SosAlertResponse],
    dependencies=[Depends(require_permissions(Permission.SOS_REVIEW))],
)
async def list_sos_alerts(
    pagination: Pagination,
    safety: SafetyServiceDep,
    alert_status: SosAlertStatus | None = None,
) -> PaginatedResponse[SosAlertResponse]:
    records, total = await safety.list_sos_alerts(
        status=alert_status, limit=pagination.limit, offset=pagination.offset
    )
    return PaginatedResponse(
        items=[SosAlertResponse.model_validate(a) for a in records],
        total=total,
        limit=pagination.limit,
        offset=pagination.offset,
    )


@router.post(
    "/sos-alerts/{alert_id}/acknowledge",
    response_model=SosAlertResponse,
    dependencies=[Depends(require_permissions(Permission.SOS_REVIEW))],
)
async def acknowledge_sos_alert(
    alert_id: uuid.UUID, principal: CurrentPrincipal, safety: SafetyServiceDep
) -> SosAlertResponse:
    alert = await safety.acknowledge_sos(alert_id, reviewer_id=principal.user_id)
    return SosAlertResponse.model_validate(alert)


@router.post(
    "/sos-alerts/{alert_id}/resolve",
    response_model=SosAlertResponse,
    dependencies=[Depends(require_permissions(Permission.SOS_REVIEW))],
)
async def resolve_sos_alert(
    alert_id: uuid.UUID,
    body: SosDecisionRequest,
    principal: CurrentPrincipal,
    safety: SafetyServiceDep,
) -> SosAlertResponse:
    alert = await safety.resolve_sos(
        alert_id, reviewer_id=principal.user_id, notes=body.notes, false_alarm=body.false_alarm
    )
    return SosAlertResponse.model_validate(alert)


# ---------------------------------------------------------------------------
# Driver rating summary
# ---------------------------------------------------------------------------
@router.get(
    "/drivers/{driver_id}/rating-summary",
    response_model=DriverRatingSummaryResponse,
    dependencies=[Depends(require_permissions(Permission.DRIVERS_APPROVE))],
)
async def get_driver_rating_summary(
    driver_id: uuid.UUID, ratings: RatingServiceDep
) -> DriverRatingSummaryResponse:
    average, count = await ratings.get_driver_average_rating(driver_id)
    return DriverRatingSummaryResponse(
        driver_id=driver_id, average_score=average, rating_count=count
    )


# ---------------------------------------------------------------------------
# User management
# ---------------------------------------------------------------------------
@router.get(
    "/users",
    response_model=PaginatedResponse[AdminUserSummaryResponse],
    dependencies=[Depends(require_permissions(Permission.USERS_MANAGE))],
)
async def list_users(
    pagination: Pagination, admin: AdminServiceDep, search: str | None = None
) -> PaginatedResponse[AdminUserSummaryResponse]:
    records, total = await admin.list_users(
        search=search, limit=pagination.limit, offset=pagination.offset
    )
    return PaginatedResponse(
        items=[AdminUserSummaryResponse.model_validate(u) for u in records],
        total=total,
        limit=pagination.limit,
        offset=pagination.offset,
    )


@router.post(
    "/users/{user_id}/suspend",
    response_model=AdminUserSummaryResponse,
    dependencies=[Depends(require_permissions(Permission.USERS_SUSPEND))],
)
async def suspend_user(
    user_id: uuid.UUID,
    body: SuspendUserRequest,
    principal: CurrentPrincipal,
    admin: AdminServiceDep,
) -> AdminUserSummaryResponse:
    user = await admin.suspend_user(user_id, reason=body.reason, actioned_by=principal.user_id)
    return AdminUserSummaryResponse.model_validate(user)


@router.post(
    "/users/{user_id}/reactivate",
    response_model=AdminUserSummaryResponse,
    dependencies=[Depends(require_permissions(Permission.USERS_SUSPEND))],
)
async def reactivate_user(
    user_id: uuid.UUID, principal: CurrentPrincipal, admin: AdminServiceDep
) -> AdminUserSummaryResponse:
    user = await admin.reactivate_user(user_id, actioned_by=principal.user_id)
    return AdminUserSummaryResponse.model_validate(user)


# ---------------------------------------------------------------------------
# Withdrawal review
# ---------------------------------------------------------------------------
@router.get(
    "/withdrawals",
    response_model=PaginatedResponse[WithdrawalResponse],
    dependencies=[Depends(require_permissions(Permission.WITHDRAWALS_REVIEW))],
)
async def list_withdrawals(
    pagination: Pagination,
    withdrawals: WithdrawalServiceDep,
    withdrawal_status: WithdrawalStatus | None = None,
) -> PaginatedResponse[WithdrawalResponse]:
    records, total = await withdrawals.list_all_withdrawals(
        status=withdrawal_status, limit=pagination.limit, offset=pagination.offset
    )
    return PaginatedResponse(
        items=[WithdrawalResponse.model_validate(w) for w in records],
        total=total,
        limit=pagination.limit,
        offset=pagination.offset,
    )


@router.post(
    "/withdrawals/{withdrawal_id}/approve",
    response_model=WithdrawalResponse,
    dependencies=[Depends(require_permissions(Permission.WITHDRAWALS_REVIEW))],
)
async def approve_withdrawal(
    withdrawal_id: uuid.UUID,
    body: WithdrawalDecisionRequest,
    principal: CurrentPrincipal,
    withdrawals: WithdrawalServiceDep,
) -> WithdrawalResponse:
    """Approving debits the requester's wallet immediately — see
    ``WithdrawalService`` for why that happens at approval, not request or
    completion, time."""
    withdrawal = await withdrawals.approve(
        withdrawal_id, reviewer_id=principal.user_id, notes=body.notes
    )
    return WithdrawalResponse.model_validate(withdrawal)


@router.post(
    "/withdrawals/{withdrawal_id}/reject",
    response_model=WithdrawalResponse,
    dependencies=[Depends(require_permissions(Permission.WITHDRAWALS_REVIEW))],
)
async def reject_withdrawal(
    withdrawal_id: uuid.UUID,
    body: WithdrawalDecisionRequest,
    principal: CurrentPrincipal,
    withdrawals: WithdrawalServiceDep,
) -> WithdrawalResponse:
    withdrawal = await withdrawals.reject(
        withdrawal_id, reviewer_id=principal.user_id, notes=body.notes
    )
    return WithdrawalResponse.model_validate(withdrawal)


@router.post(
    "/withdrawals/{withdrawal_id}/complete",
    response_model=WithdrawalResponse,
    dependencies=[Depends(require_permissions(Permission.WITHDRAWALS_REVIEW))],
)
async def complete_withdrawal(
    withdrawal_id: uuid.UUID,
    body: CompleteWithdrawalRequest,
    principal: CurrentPrincipal,
    withdrawals: WithdrawalServiceDep,
) -> WithdrawalResponse:
    """Confirms the payout was actually sent by some other means — this
    codebase has no automated mobile-money disbursement to call (see the
    ``WithdrawalRequest`` model docstring)."""
    withdrawal = await withdrawals.complete(
        withdrawal_id, reviewer_id=principal.user_id, provider_reference=body.provider_reference
    )
    return WithdrawalResponse.model_validate(withdrawal)


@router.post(
    "/withdrawals/{withdrawal_id}/fail",
    response_model=WithdrawalResponse,
    dependencies=[Depends(require_permissions(Permission.WITHDRAWALS_REVIEW))],
)
async def fail_withdrawal(
    withdrawal_id: uuid.UUID,
    body: FailWithdrawalRequest,
    principal: CurrentPrincipal,
    withdrawals: WithdrawalServiceDep,
) -> WithdrawalResponse:
    """The approved payout could not be completed — reverses the debit."""
    withdrawal = await withdrawals.mark_failed(
        withdrawal_id, reviewer_id=principal.user_id, reason=body.reason
    )
    return WithdrawalResponse.model_validate(withdrawal)


# ---------------------------------------------------------------------------
# Reports
# ---------------------------------------------------------------------------
@router.get(
    "/reports/overview",
    response_model=PlatformOverviewResponse,
    dependencies=[Depends(require_permissions(Permission.REPORTS_VIEW))],
)
async def get_platform_overview(analytics: AnalyticsServiceDep) -> PlatformOverviewResponse:
    overview = await analytics.get_platform_overview()
    return PlatformOverviewResponse.model_validate(overview)
