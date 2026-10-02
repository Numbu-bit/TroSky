"""Incident reporting and SOS distress alerts. Any authenticated trip
participant (its assigned driver, or a passenger with an active booking on
it — enforced by ``SafetyService``) can report an incident or trigger SOS
for that trip. Admin review lives in ``app.api.v1.admin``.
"""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, File, UploadFile, status

from app.api.dependencies import (
    CurrentPrincipal,
    MalwareScannerDep,
    SafetyServiceDep,
    StorageProviderDep,
)
from app.api.v1.views import incident_response
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
    storage: StorageProviderDep,
) -> IncidentResponse:
    """Report an incident on a trip the caller is part of. Add a photo
    afterwards with ``POST /incidents/{incident_id}/photo``."""
    incident = await service.report_incident(
        trip_id,
        reported_by=principal.user_id,
        incident_type=body.incident_type,
        severity=body.severity,
        description=body.description,
        latitude=body.latitude,
        longitude=body.longitude,
    )
    return await incident_response(incident, storage)


@router.get("/incidents/{incident_id}", response_model=IncidentResponse)
async def get_incident(
    incident_id: uuid.UUID,
    principal: CurrentPrincipal,
    service: SafetyServiceDep,
    storage: StorageProviderDep,
) -> IncidentResponse:
    is_privileged = principal.has_permission(Permission.INCIDENTS_MANAGE)
    incident = await service.get_incident(
        incident_id, requesting_user_id=principal.user_id, is_privileged=is_privileged
    )
    return await incident_response(incident, storage)


@router.post("/incidents/{incident_id}/photo", response_model=IncidentResponse)
async def upload_incident_photo(
    incident_id: uuid.UUID,
    principal: CurrentPrincipal,
    service: SafetyServiceDep,
    storage: StorageProviderDep,
    scanner: MalwareScannerDep,
    file: UploadFile = File(..., description="JPEG or PNG, up to 8 MB."),
) -> IncidentResponse:
    """Attach a photo of the scene to an incident you reported. An incident
    holds one photo: uploading again replaces it."""
    incident = await service.attach_incident_photo(
        incident_id,
        reported_by=principal.user_id,
        filename=file.filename or "photo",
        content_type=file.content_type or "application/octet-stream",
        data=await file.read(),
        storage=storage,
        scanner=scanner,
    )
    return await incident_response(incident, storage)


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


@router.post(
    "/sos",
    response_model=SosAlertResponse,
    status_code=status.HTTP_201_CREATED,
    dependencies=[Depends(rate_limit("sos:trigger"))],
)
async def trigger_sos_without_trip(
    body: TriggerSosRequest, principal: CurrentPrincipal, service: SafetyServiceDep
) -> SosAlertResponse:
    """Emergency alert when the caller is not on a trip (the Home screen's
    SOS button). Send the phone's position: with no trip it is the only
    clue to where they are. Emergency contacts are texted straight away,
    exactly as for an SOS during a trip."""
    alert = await service.trigger_sos_without_trip(
        triggered_by=principal.user_id, latitude=body.latitude, longitude=body.longitude
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
