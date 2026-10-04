"""Responses and requests for the admin dashboard's step 4: the complaint
workflow, SOS escalations, the alerts feed, global search and trip replay.
"""

from __future__ import annotations

import uuid
from datetime import datetime
from decimal import Decimal
from typing import Any, Literal

from pydantic import Field

from app.models.feedback import (
    ComplaintCategory,
    ComplaintNoteKind,
    ComplaintPriority,
)
from app.models.safety import EscalationContactType
from app.models.trips import TripStatus
from app.schemas.admin_analytics import Compared
from app.schemas.analytics import CountFigure, PeriodResponse
from app.schemas.common import ApiModel, RequestModel
from app.schemas.feedback import ComplaintResponse
from app.schemas.safety import SosAlertResponse


# --------------------------------------------------------------- complaints
class AdminComplaintResponse(ComplaintResponse):
    priority: ComplaintPriority
    filed_by_name: str | None
    filed_by_phone: str | None
    assigned_to: uuid.UUID | None
    assignee_name: str | None
    assigned_at: datetime | None
    first_response_at: datetime | None = Field(
        ..., description="When the passenger first heard back: a message, review, or a decision."
    )
    due_at: datetime = Field(..., description="Filed + the resolution time for its priority.")
    is_overdue: bool = Field(..., description="Still open or in review after its due time.")


class ComplaintNoteResponse(ApiModel):
    id: uuid.UUID
    kind: ComplaintNoteKind
    body: str
    author_id: uuid.UUID | None
    author_name: str | None
    created_at: datetime


class AdminComplaintDetailResponse(AdminComplaintResponse):
    notes: list[ComplaintNoteResponse] = Field(
        ..., description="Internal notes and messages to the passenger, oldest first."
    )


class ComplaintUpdateRequest(RequestModel):
    """Any of: assign (``null`` unassigns), set the priority, start review."""

    assigned_to: uuid.UUID | None = Field(
        default=None, description="An admin who handles complaints; null to unassign."
    )
    priority: ComplaintPriority | None = None
    status: Literal["in_review"] | None = Field(
        default=None, description="Move an open complaint into review."
    )
    reason: str | None = Field(default=None, max_length=1000, description="For the audit log.")


class ComplaintNoteRequest(RequestModel):
    kind: ComplaintNoteKind = Field(
        ..., description="'internal' for the team; 'message' is sent to the passenger."
    )
    body: str = Field(..., min_length=1, max_length=2000)


class PriorityCount(ApiModel):
    priority: ComplaintPriority
    resolution_hours: int = Field(..., description="The resolution time for this priority.")
    open: int
    overdue: int
    unassigned: int


class CategoryCount(ApiModel):
    category: ComplaintCategory
    filed: int
    previous: int


class ComplaintStatsResponse(ApiModel):
    period: PeriodResponse
    open: int = Field(..., description="Open or in review now.")
    overdue: int = Field(..., description="Of those, past their due time.")
    unassigned: int
    by_priority: list[PriorityCount]
    filed: CountFigure
    per_1000_trips: Compared = Field(
        ..., description="Complaints filed per 1,000 trips completed in the period."
    )
    avg_first_response_hours: Compared = Field(
        ..., description="For complaints filed in the period that got a response."
    )
    avg_resolution_hours: Compared = Field(
        ..., description="For complaints resolved or dismissed in the period."
    )
    by_category: list[CategoryCount]


# ---------------------------------------------------------------------- SOS
class SosEscalationRequest(RequestModel):
    contact_type: EscalationContactType
    contact_name: str | None = Field(default=None, max_length=100, examples=["Legon Police"])
    phone_number: str | None = Field(default=None, max_length=20)
    contacted_at: datetime | None = Field(default=None, description="Default: now.")
    notes: str | None = Field(default=None, max_length=1000)


class SosEscalationResponse(ApiModel):
    id: uuid.UUID
    sos_alert_id: uuid.UUID
    contact_type: EscalationContactType
    contact_name: str | None
    phone_number: str | None
    contacted_at: datetime
    notes: str | None
    logged_by: uuid.UUID | None
    logged_by_name: str | None = None
    created_at: datetime


class TrackPoint(ApiModel):
    latitude: float
    longitude: float
    speed_kmh: Decimal | None = None
    heading_degrees: Decimal | None = None
    accuracy_meters: Decimal | None = None
    recorded_at: datetime


class SosTripResponse(ApiModel):
    trip_id: uuid.UUID
    status: TripStatus
    route_name: str
    scheduled_departure_at: datetime
    vehicle_registration_number: str | None
    driver_name: str | None
    driver_phone: str | None
    fleet_owner_name: str | None
    fleet_owner_phone: str | None
    last_position: TrackPoint | None = Field(
        ..., description="The vehicle's last recorded position."
    )


class EscalationContactResponse(ApiModel):
    name: str
    phone_number: str
    role: str


class AdminSosAlertDetailResponse(SosAlertResponse):
    latitude: float | None
    longitude: float | None
    triggered_by_name: str | None
    triggered_by_phone: str
    trip: SosTripResponse | None
    escalations: list[SosEscalationResponse]
    escalation_contacts: list[EscalationContactResponse] = Field(
        ..., description="Who to call, from the sos_escalation_contacts setting."
    )


# ------------------------------------------------------------------- alerts
AlertType = Literal[
    "sos_active", "complaint_overdue", "document_expiring", "approval_waiting", "fraud_high_risk"
]
AlertSeverity = Literal["critical", "high", "medium", "low"]


class AlertResponse(ApiModel):
    type: AlertType
    severity: AlertSeverity
    title: str
    entity_type: str = Field(..., examples=["sos_alert", "complaint", "driver", "vehicle"])
    entity_id: uuid.UUID
    since: datetime = Field(..., description="How long this has been waiting.")
    details: dict[str, Any]


class AlertsResponse(ApiModel):
    items: list[AlertResponse] = Field(..., description="Most severe first, then oldest.")
    counts: dict[str, int] = Field(..., description="Per alert type, before the limit.")
    total: int


# ------------------------------------------------------------------- search
SearchKind = Literal["users", "drivers", "vehicles", "trips", "bookings", "payments"]


class SearchHit(ApiModel):
    id: uuid.UUID
    title: str
    subtitle: str | None
    status: str | None


class SearchResponse(ApiModel):
    query: str
    searched: list[SearchKind] = Field(
        ..., description="What the caller's permissions let this search cover."
    )
    users: list[SearchHit]
    drivers: list[SearchHit]
    vehicles: list[SearchHit]
    trips: list[SearchHit]
    bookings: list[SearchHit]
    payments: list[SearchHit]


# -------------------------------------------------------------- trip replay
class TripTrackResponse(ApiModel):
    trip_id: uuid.UUID
    status: TripStatus
    actual_departure_at: datetime | None
    actual_arrival_at: datetime | None
    point_count: int
    truncated: bool = Field(..., description="More points were recorded than returned.")
    distance_km: Decimal = Field(..., description="Along the returned points.")
    max_speed_kmh: Decimal | None
    first_at: datetime | None
    last_at: datetime | None
    points: list[TrackPoint]
