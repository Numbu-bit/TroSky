"""Responses for the admin directory: every vehicle, driver and fleet."""

from __future__ import annotations

import uuid
from datetime import date, datetime
from decimal import Decimal
from typing import Literal

from pydantic import Field

from app.models.drivers import ApprovalStatus, DocumentStatus, DocumentType
from app.models.safety import IncidentSeverity, IncidentStatus, IncidentType
from app.models.vehicles import VehicleType
from app.schemas.common import ApiModel

LiveStatus = Literal["on_trip", "idle", "offline"]
LIVE_STATUS_HELP = (
    "on_trip: on a trip that is boarding, under way or paused. idle: not on a trip now "
    "but with one still to run today. offline: neither."
)


class Ref(ApiModel):
    id: uuid.UUID
    name: str | None


class VehicleRef(ApiModel):
    id: uuid.UUID
    registration_number: str


class DocumentSummary(ApiModel):
    id: uuid.UUID
    document_type: DocumentType
    status: DocumentStatus
    expiry_date: date | None
    original_filename: str
    rejection_reason: str | None
    uploaded_at: datetime = Field(..., validation_alias="created_at")


class AdminVehicleResponse(ApiModel):
    id: uuid.UUID
    registration_number: str
    vehicle_type: VehicleType
    make_model: str | None
    year: int | None
    capacity: int
    status: ApprovalStatus = Field(..., description="Approval status.")
    fleet: Ref
    fleet_owner: Ref
    driver: Ref | None = Field(..., description="The driver currently assigned to it.")
    live_status: LiveStatus = Field(..., description=LIVE_STATUS_HELP)
    current_trip_id: uuid.UUID | None
    insurance_expiry: date | None = Field(
        ..., description="From the latest approved insurance document; null if none."
    )
    roadworthy_expiry: date | None
    created_at: datetime


class VehicleActivity(ApiModel):
    trips: int
    completed_trips: int
    revenue: Decimal = Field(..., description="Fares of completed bookings, fees excluded.")


class IncidentSummary(ApiModel):
    id: uuid.UUID
    trip_id: uuid.UUID
    incident_type: IncidentType
    severity: IncidentSeverity
    status: IncidentStatus
    created_at: datetime


class AdminVehicleDetailResponse(AdminVehicleResponse):
    documents: list[DocumentSummary]
    last_30_days: VehicleActivity
    recent_incidents: list[IncidentSummary]


class AdminDriverResponse(ApiModel):
    id: uuid.UUID
    user_id: uuid.UUID
    full_name: str | None
    phone_number: str
    email: str | None
    status: ApprovalStatus = Field(..., description="Approval status.")
    license_number: str
    license_expiry: date
    fleet: Ref | None
    vehicle: VehicleRef | None
    live_status: LiveStatus = Field(..., description=LIVE_STATUS_HELP)
    current_trip_id: uuid.UUID | None
    average_rating: Decimal | None
    rating_count: int
    last_active_at: datetime | None = Field(
        ..., description="Latest of their last sign-in and their last trip."
    )
    created_at: datetime


class AssignedVehicle(ApiModel):
    id: uuid.UUID
    registration_number: str
    vehicle_type: VehicleType
    fleet_id: uuid.UUID
    assigned_at: datetime


class AdminDriverDetailResponse(AdminDriverResponse):
    license_class: str | None
    years_of_experience: int | None
    documents: list[DocumentSummary]
    vehicles: list[AssignedVehicle]


class FleetOwnerRef(ApiModel):
    id: uuid.UUID
    business_name: str
    status: ApprovalStatus
    name: str | None
    phone_number: str


class AdminFleetResponse(ApiModel):
    id: uuid.UUID
    name: str
    is_active: bool
    owner: FleetOwnerRef
    vehicle_count: int
    approved_vehicles: int
    active_now: int = Field(..., description="Vehicles on a trip right now.")
    driver_count: int
    utilization_7d: Decimal | None = Field(
        ...,
        description="Share (0-1) of approved vehicles that completed a trip in the last 7 days.",
    )
    revenue_30d: Decimal = Field(
        ..., description="Fares of completed bookings on trips departing in the last 30 days."
    )
    average_rating: Decimal | None
    created_at: datetime


class AdminFleetDetailResponse(AdminFleetResponse):
    vehicles: list[AdminVehicleResponse]
    drivers: list[AdminDriverResponse]
