"""Administrator endpoints.

Grows substantially in Phase 10 (dashboard, user/payment/report
management); this phase adds driver/vehicle approval review, route/stop/
schedule/trip management, and read-only booking review.
"""

from __future__ import annotations

import uuid
from dataclasses import asdict
from datetime import date
from decimal import Decimal
from typing import Annotated

from fastapi import APIRouter, Depends, Query, Response, status

from app.api.common_dependencies import DbSession
from app.api.dependencies import (
    AdminServiceDep,
    AnalyticsServiceDep,
    BookingServiceDep,
    CurrentPrincipal,
    DriverServiceDep,
    FleetServiceDep,
    Pagination,
    PaymentServiceDep,
    RatingServiceDep,
    RefundServiceDep,
    RouteServiceDep,
    SafetyServiceDep,
    StorageProviderDep,
    TrackingServiceDep,
    TripServiceDep,
    WithdrawalServiceDep,
)
from app.api.v1.analytics_views import count_figure, money_figure, period_response
from app.api.v1.listing import (
    CSV_RESPONSE,
    ExportFormat,
    FormatQuery,
    csv_response,
    export_window,
)
from app.api.v1.views import (
    booking_responses,
    driver_response,
    driver_responses,
    incident_response,
    live_trip_response,
    rating_summary,
)
from app.core.permissions import Permission, require_permissions
from app.models.bookings import BookingStatus, CancellationStatus
from app.models.payments import RefundStatus, WithdrawalStatus
from app.models.routes import Stop
from app.models.safety import IncidentStatus, SosAlertStatus
from app.models.trips import TripStatus
from app.schemas.admin import AdminUserSummaryResponse, SuspendUserRequest
from app.schemas.analytics import (
    CountFigure,
    MoneyFigure,
    OverviewFiguresResponse,
    PlatformOverviewResponse,
)
from app.schemas.booking import (
    BookingResponse,
    CancellationRequestResponse,
)
from app.schemas.common import MessageResponse, PaginatedResponse
from app.schemas.driver import ApprovalReviewRequest, DriverResponse
from app.schemas.feedback import (
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
    RouteUpdateRequest,
    ScheduleTripRequest,
    StopCreateRequest,
    StopResponse,
    StopUpdateRequest,
)
from app.schemas.safety import (
    IncidentDecisionRequest,
    IncidentResponse,
    SosAlertResponse,
    SosDecisionRequest,
)
from app.schemas.trip import (
    AdminTripSummaryResponse,
    AssignTripDriverRequest,
    AssignTripVehicleRequest,
    CancelTripRequest,
    LiveTripResponse,
    TripCancellationResponse,
    TripCreateRequest,
    TripResponse,
)
from app.schemas.withdrawal import (
    CompleteWithdrawalRequest,
    FailWithdrawalRequest,
    WithdrawalDecisionRequest,
    WithdrawalResponse,
)
from app.services.admin_analytics_service import AdminAnalyticsService, Figure, Period
from app.utilities.geo import wkb_to_latlng
from app.utilities.query_params import parse_enum_list

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
        items=await driver_responses(records, drivers),
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
    return await driver_response(driver, drivers)


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
    return await driver_response(driver, drivers)


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


@router.get(
    "/routes/{route_id}/schedules",
    response_model=list[RouteScheduleResponse],
    dependencies=[Depends(require_permissions(Permission.ROUTES_MANAGE, Permission.TRIPS_MANAGE))],
)
async def list_route_schedules(
    route_id: uuid.UUID, service: RouteServiceDep
) -> list[RouteScheduleResponse]:
    """The route's timetable: its active entries, earliest departure first.
    For showing it, and for scheduling trips from it
    (``POST /admin/trips/from-schedule``)."""
    return [
        RouteScheduleResponse.model_validate(schedule)
        for schedule in await service.list_schedules(route_id)
    ]


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


@router.patch(
    "/stops/{stop_id}",
    response_model=StopResponse,
    dependencies=[Depends(require_permissions(Permission.ROUTES_MANAGE))],
)
async def update_stop(
    stop_id: uuid.UUID, body: StopUpdateRequest, service: RouteServiceDep
) -> StopResponse:
    """Change the fields sent. Moving a stop re-measures distances along
    every active route that uses it. 409 STOP_CODE_TAKEN on a duplicate
    code."""
    stop = await service.update_stop(stop_id, **body.model_dump(exclude_unset=True))
    return _stop_response(stop)


@router.delete(
    "/stops/{stop_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    response_model=None,
    dependencies=[Depends(require_permissions(Permission.ROUTES_MANAGE))],
)
async def deactivate_stop(stop_id: uuid.UUID, service: RouteServiceDep) -> None:
    """Retire a stop: it disappears from search and new bookings; past
    bookings keep it. 409 STOP_IN_USE while an active route uses it."""
    await service.deactivate_stop(stop_id)


@router.patch(
    "/routes/{route_id}",
    response_model=RouteResponse,
    dependencies=[Depends(require_permissions(Permission.ROUTES_MANAGE))],
)
async def update_route(
    route_id: uuid.UUID, body: RouteUpdateRequest, service: RouteServiceDep
) -> RouteResponse:
    """Change the name, length or duration. A new length or duration
    re-measures the distance and time to each stop. 409 ROUTE_NAME_TAKEN on
    a duplicate name."""
    route = await service.update_route(route_id, **body.model_dump(exclude_unset=True))
    return RouteResponse.model_validate(route)


@router.delete(
    "/routes/{route_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    response_model=None,
    dependencies=[Depends(require_permissions(Permission.ROUTES_MANAGE))],
)
async def deactivate_route(route_id: uuid.UUID, service: RouteServiceDep) -> None:
    """Retire a route and its timetable. 409 ROUTE_HAS_ACTIVE_TRIPS while it
    still has trips scheduled or under way -- cancel or finish them first."""
    await service.deactivate_route(route_id)


# ---------------------------------------------------------------------------
# Trips
# ---------------------------------------------------------------------------
@router.get(
    "/trips",
    responses=CSV_RESPONSE,
    response_model=PaginatedResponse[AdminTripSummaryResponse],
    dependencies=[
        Depends(require_permissions(Permission.TRIPS_MANAGE, Permission.TRIPS_MONITOR_LIVE))
    ],
)
async def list_trips(
    pagination: Pagination,
    service: TripServiceDep,
    status_filter: Annotated[
        str | None,
        Query(alias="status", description="Comma-separated trip statuses."),
    ] = None,
    on_date: Annotated[
        date | None, Query(alias="date", description="Departing on this day (YYYY-MM-DD).")
    ] = None,
    route_id: uuid.UUID | None = None,
    driver_id: uuid.UUID | None = None,
    export: ExportFormat = FormatQuery,
) -> PaginatedResponse[AdminTripSummaryResponse] | Response:
    """Trips matching every filter given, soonest departure first."""
    limit, offset = export_window(pagination, export)
    summaries, total = await service.list_trips(
        statuses=parse_enum_list(status_filter, TripStatus, param="status"),
        on_date=on_date,
        route_id=route_id,
        driver_id=driver_id,
        limit=limit,
        offset=offset,
    )
    items = [AdminTripSummaryResponse.model_validate(s) for s in summaries]
    if export == "csv":
        return csv_response(items, name="trips")
    return PaginatedResponse(
        items=items,
        total=total,
        limit=pagination.limit,
        offset=pagination.offset,
    )


@router.get(
    "/live-trips",
    response_model=list[LiveTripResponse],
    dependencies=[
        Depends(require_permissions(Permission.TRIPS_MONITOR_LIVE, Permission.TRIPS_MANAGE))
    ],
)
async def list_live_trips(tracking: TrackingServiceDep) -> list[LiveTripResponse]:
    """Every trip out on the road now (boarding, in progress, paused) with
    its last GPS position -- null until the driver's phone reports one."""
    live = await tracking.list_live_trips()
    return [live_trip_response(summary, location) for summary, location in live]


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
    response_model=TripCancellationResponse,
    dependencies=[Depends(require_permissions(Permission.TRIPS_MANAGE))],
)
async def cancel_trip(
    trip_id: uuid.UUID,
    body: CancelTripRequest,
    principal: CurrentPrincipal,
    service: TripServiceDep,
    bookings: BookingServiceDep,
    payments: PaymentServiceDep,
) -> TripCancellationResponse:
    """Cancel the trip and, in the same transaction, every booking still
    holding seats on it. Paid bookings get a refund request each (approve
    them at ``/admin/refund-requests``); every passenger is notified."""
    trip = await service.cancel_trip(trip_id, cancelled_by=principal.user_id, reason=body.reason)
    cancelled = await bookings.cancel_all_for_trip(
        trip.id, cancelled_by=principal.user_id, reason=body.reason
    )
    refunds = await payments.queue_refunds(cancelled, requested_by=principal.user_id)
    return TripCancellationResponse(
        **TripResponse.model_validate(trip).model_dump(),
        bookings_cancelled=len(cancelled),
        refunds_queued=len(refunds),
        refund_amount=sum((refund.amount for refund in refunds), Decimal("0.00")),
    )


# ---------------------------------------------------------------------------
# Bookings (read-only review)
# ---------------------------------------------------------------------------
@router.get(
    "/bookings",
    responses=CSV_RESPONSE,
    response_model=PaginatedResponse[BookingResponse],
    dependencies=[Depends(require_permissions(Permission.BOOKINGS_VIEW_ANY))],
)
async def list_all_bookings(
    pagination: Pagination,
    service: BookingServiceDep,
    booking_status: BookingStatus | None = None,
    export: ExportFormat = FormatQuery,
) -> PaginatedResponse[BookingResponse] | Response:
    limit, offset = export_window(pagination, export)
    records, total = await service.list_all_bookings(
        status=booking_status, limit=limit, offset=offset
    )
    items = await booking_responses(service, records)
    if export == "csv":
        return csv_response(items, name="bookings")
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
    [response] = await booking_responses(bookings, [booking])
    return response


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
# Incidents
# ---------------------------------------------------------------------------
@router.get(
    "/incidents",
    responses=CSV_RESPONSE,
    response_model=PaginatedResponse[IncidentResponse],
    dependencies=[Depends(require_permissions(Permission.INCIDENTS_MANAGE))],
)
async def list_incidents(
    pagination: Pagination,
    safety: SafetyServiceDep,
    storage: StorageProviderDep,
    incident_status: IncidentStatus | None = None,
    export: ExportFormat = FormatQuery,
) -> PaginatedResponse[IncidentResponse] | Response:
    limit, offset = export_window(pagination, export)
    records, total = await safety.list_incidents(status=incident_status, limit=limit, offset=offset)
    items = [await incident_response(i, storage) for i in records]
    if export == "csv":
        return csv_response(items, name="incidents")
    return PaginatedResponse(
        items=items,
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
    storage: StorageProviderDep,
) -> IncidentResponse:
    incident = await safety.resolve_incident(
        incident_id, reviewer_id=principal.user_id, notes=body.notes
    )
    return await incident_response(incident, storage)


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
    return await rating_summary(driver_id, ratings)


# ---------------------------------------------------------------------------
# User management
# ---------------------------------------------------------------------------
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
    responses=CSV_RESPONSE,
    response_model=PaginatedResponse[WithdrawalResponse],
    dependencies=[Depends(require_permissions(Permission.WITHDRAWALS_REVIEW))],
)
async def list_withdrawals(
    pagination: Pagination,
    withdrawals: WithdrawalServiceDep,
    withdrawal_status: WithdrawalStatus | None = None,
    export: ExportFormat = FormatQuery,
) -> PaginatedResponse[WithdrawalResponse] | Response:
    limit, offset = export_window(pagination, export)
    records, total = await withdrawals.list_all_withdrawals(
        status=withdrawal_status, limit=limit, offset=offset
    )
    items = [WithdrawalResponse.model_validate(w) for w in records]
    if export == "csv":
        return csv_response(items, name="payouts")
    return PaginatedResponse(
        items=items,
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
async def get_platform_overview(
    analytics: AnalyticsServiceDep,
    db: DbSession,
    date_from: Annotated[
        date | None, Query(alias="from", description="Inclusive. Default: 29 days before 'to'.")
    ] = None,
    date_to: Annotated[date | None, Query(alias="to", description="Inclusive. Default: today.")] = (
        None
    ),
    city: Annotated[str | None, Query(max_length=100)] = None,
) -> PlatformOverviewResponse:
    """The KPI tiles: all-time totals and live counts, and per-period
    figures (value, previous period, change, daily series) for the period
    and city asked for. Dates are Ghana dates."""
    period = Period.resolve(date_from, date_to)
    overview = await analytics.get_platform_overview()
    figures = await AdminAnalyticsService(db).overview_figures(period, city)
    return PlatformOverviewResponse(
        **asdict(overview),
        period=period_response(period, city),
        figures=OverviewFiguresResponse(
            **{
                name: _figure_response(figures.get(name), money=name == "booking_payments")
                for name in OverviewFiguresResponse.model_fields
            }
        ),
    )


def _figure_response(figure: Figure | None, *, money: bool) -> CountFigure | MoneyFigure | None:
    if figure is None:
        return None
    return money_figure(figure) if money else count_figure(figure)
