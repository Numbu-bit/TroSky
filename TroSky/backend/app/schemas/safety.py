"""Request/response schemas for incidents and SOS alerts."""

from __future__ import annotations

import uuid
from datetime import datetime

from pydantic import Field

from app.models.safety import IncidentSeverity, IncidentStatus, IncidentType, SosAlertStatus
from app.schemas.common import ApiModel, RequestModel


class ReportIncidentRequest(RequestModel):
    incident_type: IncidentType
    severity: IncidentSeverity
    description: str = Field(..., min_length=1, max_length=2000)
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)


class IncidentResponse(ApiModel):
    id: uuid.UUID
    trip_id: uuid.UUID
    reported_by: uuid.UUID
    incident_type: IncidentType
    severity: IncidentSeverity
    description: str
    status: IncidentStatus
    resolved_by: uuid.UUID | None
    resolved_at: datetime | None
    resolution_notes: str | None
    created_at: datetime


class IncidentDecisionRequest(RequestModel):
    notes: str | None = Field(default=None, max_length=1000)


class TriggerSosRequest(RequestModel):
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)


class SosAlertResponse(ApiModel):
    id: uuid.UUID
    trip_id: uuid.UUID
    triggered_by: uuid.UUID
    status: SosAlertStatus
    acknowledged_by: uuid.UUID | None
    acknowledged_at: datetime | None
    resolved_by: uuid.UUID | None
    resolved_at: datetime | None
    resolution_notes: str | None
    created_at: datetime


class SosDecisionRequest(RequestModel):
    notes: str | None = Field(default=None, max_length=1000)
    false_alarm: bool = False
