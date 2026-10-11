"""Operations views for the admin dashboard: the alerts feed, global search,
SOS details and escalations, and trip replay. Mounted under ``/admin``.
"""

from __future__ import annotations

import uuid
from datetime import datetime
from typing import Annotated

from fastapi import APIRouter, Depends, Query, Response, status

from app.api.auth_dependencies import CurrentPrincipal
from app.api.common_dependencies import DbSession
from app.api.dependencies import SafetyServiceDep
from app.api.v1.listing import CSV_RESPONSE, ExportFormat, FormatQuery, csv_response
from app.core.permissions import Permission, require_permissions
from app.repositories.admin_live_repository import Hit, Point
from app.schemas.admin_workflow import (
    AdminSosAlertDetailResponse,
    AlertResponse,
    AlertsResponse,
    EscalationContactResponse,
    SearchHit,
    SearchResponse,
    SosEscalationRequest,
    SosEscalationResponse,
    SosTripResponse,
    TrackPoint,
    TripTrackResponse,
)
from app.schemas.safety import SosAlertResponse
from app.services.admin_ops_service import (
    ALERT_PERMISSIONS,
    SEARCH_PERMISSIONS,
    AdminOpsService,
)
from app.services.system_settings_service import EscalationContact

router = APIRouter()


def get_ops(db: DbSession) -> AdminOpsService:
    return AdminOpsService(db)


Ops = Annotated[AdminOpsService, Depends(get_ops)]

_SEARCHERS = sorted(
    {permission for permissions in SEARCH_PERMISSIONS.values() for permission in permissions}
)


def _point(point: Point) -> TrackPoint:
    return TrackPoint(
        latitude=point.latitude,
        longitude=point.longitude,
        speed_kmh=point.speed_kmh,
        heading_degrees=point.heading_degrees,
        accuracy_meters=point.accuracy_meters,
        recorded_at=point.recorded_at,
    )


def _hits(hits: list[Hit]) -> list[SearchHit]:
    return [
        SearchHit(id=hit.id, title=hit.title, subtitle=hit.subtitle, status=hit.status)
        for hit in hits
    ]


def _contact(contact: EscalationContact) -> EscalationContactResponse:
    return EscalationContactResponse(
        name=contact.name, phone_number=contact.phone_number, role=contact.role
    )


# ------------------------------------------------------------------- alerts
@router.get(
    "/alerts",
    response_model=AlertsResponse,
    dependencies=[Depends(require_permissions(*ALERT_PERMISSIONS))],
)
async def list_alerts(
    principal: CurrentPrincipal,
    ops: Ops,
    limit: Annotated[int, Query(ge=1, le=500)] = 100,
) -> AlertsResponse:
    """One feed of what needs attention, most severe first and then oldest:
    SOS alerts nobody has picked up (``sos:review``), complaints past their
    due time (``complaints:manage``), documents expiring within 30 days or
    expired, and approvals waiting longer than the approval target
    (``drivers:approve`` / ``vehicles:approve``). Each admin sees the types
    their permissions cover."""
    alerts, counts = await ops.alerts(principal, limit=limit)
    return AlertsResponse(
        items=[
            AlertResponse(
                type=alert.type,
                severity=alert.severity,
                title=alert.title,
                entity_type=alert.entity_type,
                entity_id=alert.entity_id,
                since=alert.since,
                details=alert.details,
            )
            for alert in alerts
        ],
        counts=counts,
        total=sum(counts.values()),
    )


# ------------------------------------------------------------------- search
@router.get(
    "/search",
    response_model=SearchResponse,
    dependencies=[Depends(require_permissions(*_SEARCHERS))],
)
async def search(
    principal: CurrentPrincipal,
    ops: Ops,
    q: Annotated[
        str,
        Query(
            min_length=2, max_length=100, description="Name, phone, email, plate, reference or id."
        ),
    ],
    limit: Annotated[int, Query(ge=1, le=20, description="Per kind of record.")] = 5,
) -> SearchResponse:
    """Users, drivers, vehicles (by plate), trips, bookings and payments
    matching ``q`` by name, phone number, email, plate, reference or id.
    Each kind is searched only for an admin who may see it; ``searched``
    says which were."""
    query = q.strip()
    searched, results = await ops.search(principal, query, limit=limit)
    return SearchResponse(
        query=query,
        searched=searched,
        users=_hits(results["users"]),
        drivers=_hits(results["drivers"]),
        vehicles=_hits(results["vehicles"]),
        trips=_hits(results["trips"]),
        bookings=_hits(results["bookings"]),
        payments=_hits(results["payments"]),
    )


# ---------------------------------------------------------------------- SOS
_SOS = [Depends(require_permissions(Permission.SOS_REVIEW))]


@router.get("/sos-alerts/{alert_id}", response_model=AdminSosAlertDetailResponse, dependencies=_SOS)
async def get_sos_alert(alert_id: uuid.UUID, ops: Ops) -> AdminSosAlertDetailResponse:
    """Everything needed to act on an SOS: where it was raised, who raised
    it, the trip (vehicle, driver and fleet owner with their numbers, and
    the vehicle's last position), the escalations so far, and who to call
    (the ``sos_escalation_contacts`` setting)."""
    detail = await ops.sos_detail(alert_id)
    trip = None
    if detail.trip is not None:
        summary = detail.trip.summary
        trip = SosTripResponse(
            trip_id=summary.trip_id,
            status=summary.status,
            route_name=summary.route_name,
            scheduled_departure_at=summary.scheduled_departure_at,
            vehicle_registration_number=summary.vehicle_registration_number,
            driver_name=summary.driver_name,
            driver_phone=detail.trip.driver_phone,
            fleet_owner_name=detail.trip.fleet_owner_name,
            fleet_owner_phone=detail.trip.fleet_owner_phone,
            last_position=(
                _point(detail.trip.last_position) if detail.trip.last_position else None
            ),
        )
    return AdminSosAlertDetailResponse(
        **SosAlertResponse.model_validate(detail.alert).model_dump(),
        latitude=detail.latitude,
        longitude=detail.longitude,
        triggered_by_name=detail.triggered_by_name,
        triggered_by_phone=detail.triggered_by_phone,
        trip=trip,
        escalations=[
            SosEscalationResponse.model_validate(escalation).model_copy(
                update={"logged_by_name": name}
            )
            for escalation, name in detail.escalations
        ],
        escalation_contacts=[_contact(contact) for contact in detail.escalation_contacts],
    )


@router.post(
    "/sos-alerts/{alert_id}/escalations",
    response_model=SosEscalationResponse,
    status_code=status.HTTP_201_CREATED,
    dependencies=_SOS,
)
async def escalate_sos_alert(
    alert_id: uuid.UUID,
    body: SosEscalationRequest,
    principal: CurrentPrincipal,
    safety: SafetyServiceDep,
) -> SosEscalationResponse:
    """Record who was contacted about the alert (police, ambulance, fire
    service, the fleet owner, the passenger's emergency contact...) and
    when (default now). An alert still waiting is acknowledged by the same
    admin."""
    escalation = await safety.escalate_sos(
        alert_id,
        logged_by=principal.user_id,
        contact_type=body.contact_type,
        contact_name=body.contact_name,
        phone_number=body.phone_number,
        contacted_at=body.contacted_at,
        notes=body.notes,
    )
    return SosEscalationResponse.model_validate(escalation)


# -------------------------------------------------------------- trip replay
@router.get(
    "/trips/{trip_id}/track",
    response_model=TripTrackResponse,
    responses=CSV_RESPONSE,
    dependencies=[
        Depends(require_permissions(Permission.TRIPS_MONITOR_LIVE, Permission.TRIPS_MANAGE))
    ],
)
async def get_trip_track(
    trip_id: uuid.UUID,
    ops: Ops,
    since: Annotated[datetime | None, Query(description="Points recorded from this time.")] = None,
    until: Annotated[
        datetime | None, Query(description="Points recorded before this time.")
    ] = None,
    export: ExportFormat = FormatQuery,
) -> TripTrackResponse | Response:
    """The positions recorded during a trip, oldest first, for replay and
    investigations, with the distance they cover and the top speed. Up to
    20,000 points (``truncated`` says if there were more: narrow with
    ``since`` / ``until``). Positions are kept for
    ``GPS_RAW_RETENTION_DAYS``. ``?format=csv`` returns the points."""
    track = await ops.track(trip_id, since=since, until=until)
    points = [_point(point) for point in track.points]
    if export == "csv":
        return csv_response(points, name=f"trip-{trip_id}-track")
    return TripTrackResponse(
        trip_id=track.trip.id,
        status=track.trip.status,
        actual_departure_at=track.trip.actual_departure_at,
        actual_arrival_at=track.trip.actual_arrival_at,
        point_count=len(points),
        truncated=track.truncated,
        distance_km=track.distance_km,
        max_speed_kmh=track.max_speed_kmh,
        first_at=points[0].recorded_at if points else None,
        last_at=points[-1].recorded_at if points else None,
        points=points,
    )
