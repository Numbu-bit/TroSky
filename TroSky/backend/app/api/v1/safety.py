"""Incident reporting and SOS distress alerts. Any authenticated trip
participant (its assigned driver, or a passenger with an active booking on
it — enforced by ``SafetyService``) can report an incident or trigger SOS
for that trip. Admin review lives in ``app.api.v1.admin``.
"""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, status

from app.api.dependencies import CurrentPrincipal, SafetyServiceDep
from app.core.permissions import Permission
from app.core.ratelimit import rate_limit
from app.schemas.safety import (
    IncidentResponse,
    ReportIncidentRequest,
    SosAlertResponse,
    TriggerSosRequest,
)

router = APIRouter()


@router.post(
    "/trips/{trip_id}/incidents",
    response_model=IncidentResponse,
    status_code=status.HTTP_201_CREATED,
)
async def report_incident(
    trip_id: uuid.UUID,
    body: ReportIncidentRequest,
    principal: CurrentPrincipal,
    service: SafetyServiceDep,
) -> IncidentResponse:
    incident = await service.report_incident(
        trip_id,
        reported_by=principal.user_id,
        incident_type=body.incident_type,
        severity=body.severity,
        description=body.description,
        latitude=body.latitude,
        longitude=body.longitude,
    )
    return IncidentResponse.model_validate(incident)


@router.get("/incidents/{incident_id}", response_model=IncidentResponse)
async def get_incident(
    incident_id: uuid.UUID, principal: CurrentPrincipal, service: SafetyServiceDep
) -> IncidentResponse:
    is_privileged = principal.has_permission(Permission.INCIDENTS_MANAGE)
    incident = await service.get_incident(
        incident_id, requesting_user_id=principal.user_id, is_privileged=is_privileged
    )
    return IncidentResponse.model_validate(incident)


@router.post(
    "/trips/{trip_id}/sos",
    response_model=SosAlertResponse,
    status_code=status.HTTP_201_CREATED,
    dependencies=[Depends(rate_limit("sos:trigger"))],
)
async def trigger_sos(
    trip_id: uuid.UUID,
    body: TriggerSosRequest,
    principal: CurrentPrincipal,
    service: SafetyServiceDep,
) -> SosAlertResponse:
    """Triggers an emergency alert for the caller's own participation in
    this trip and immediately SMSes every registered emergency contact —
    never gated by notification preferences (see
    ``SafetyService._notify_emergency_contacts``)."""
    alert = await service.trigger_sos(
        trip_id, triggered_by=principal.user_id, latitude=body.latitude, longitude=body.longitude
    )
    return SosAlertResponse.model_validate(alert)


@router.get("/sos/{alert_id}", response_model=SosAlertResponse)
async def get_sos_alert(
    alert_id: uuid.UUID, principal: CurrentPrincipal, service: SafetyServiceDep
) -> SosAlertResponse:
    is_privileged = principal.has_permission(Permission.SOS_REVIEW)
    alert = await service.get_sos_alert(
        alert_id, requesting_user_id=principal.user_id, is_privileged=is_privileged
    )
    return SosAlertResponse.model_validate(alert)
