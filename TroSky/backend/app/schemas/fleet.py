"""Request/response schemas for fleet owners, fleets, vehicles, vehicle
documents, and seat layouts."""

from __future__ import annotations

import uuid
from datetime import datetime

from pydantic import Field, field_validator

from app.models.drivers import ApprovalStatus
from app.models.vehicles import SeatType, VehicleType
from app.schemas.common import ApiModel, RequestModel


class FleetOwnerRegisterRequest(RequestModel):
    business_name: str = Field(..., min_length=2, max_length=200)
    business_registration_number: str | None = Field(default=None, max_length=50)


class FleetOwnerResponse(ApiModel):
    id: uuid.UUID
    user_id: uuid.UUID
    business_name: str
    business_registration_number: str | None
    status: ApprovalStatus
    created_at: datetime


class FleetCreateRequest(RequestModel):
    name: str = Field(..., min_length=2, max_length=200)
    description: str | None = Field(default=None, max_length=1000)


class FleetUpdateRequest(RequestModel):
    name: str | None = Field(default=None, min_length=2, max_length=200)
    description: str | None = Field(default=None, max_length=1000)
    is_active: bool | None = None


class FleetResponse(ApiModel):
    id: uuid.UUID
    fleet_owner_id: uuid.UUID
    name: str
    description: str | None
    is_active: bool
    created_at: datetime


class VehicleCreateRequest(RequestModel):
    registration_number: str = Field(..., min_length=3, max_length=20)
    vehicle_type: VehicleType
    make: str | None = Field(default=None, max_length=100)
    model: str | None = Field(default=None, max_length=100)
    year: int | None = Field(default=None, ge=1970, le=2100)
    capacity: int = Field(..., gt=0, le=200)

    @field_validator("registration_number")
    @classmethod
    def _normalize_registration_number(cls, value: str) -> str:
        return value.strip().upper()


class VehicleUpdateRequest(RequestModel):
    make: str | None = Field(default=None, max_length=100)
    model: str | None = Field(default=None, max_length=100)
    year: int | None = Field(default=None, ge=1970, le=2100)
    capacity: int | None = Field(default=None, gt=0, le=200)


class VehicleResponse(ApiModel):
    id: uuid.UUID
    fleet_id: uuid.UUID
    registration_number: str
    vehicle_type: VehicleType
    make: str | None
    model: str | None
    year: int | None
    capacity: int
    status: ApprovalStatus
    created_at: datetime


class SeatInput(RequestModel):
    seat_number: str = Field(..., min_length=1, max_length=10)
    row_number: int = Field(..., gt=0)
    column_number: int = Field(..., gt=0)
    seat_type: SeatType = SeatType.STANDARD


class SeatLayoutRequest(RequestModel):
    name: str | None = Field(default=None, max_length=100)
    rows: int = Field(..., gt=0)
    columns: int = Field(..., gt=0)
    seats: list[SeatInput] = Field(..., min_length=1, max_length=200)

    @field_validator("seats")
    @classmethod
    def _seat_numbers_unique(cls, seats: list[SeatInput]) -> list[SeatInput]:
        numbers = [s.seat_number for s in seats]
        if len(numbers) != len(set(numbers)):
            raise ValueError("Seat numbers must be unique within a layout.")
        return seats


class SeatResponse(ApiModel):
    id: uuid.UUID
    seat_number: str
    row_number: int
    column_number: int
    seat_type: SeatType
    is_active: bool


class SeatLayoutResponse(ApiModel):
    id: uuid.UUID
    vehicle_id: uuid.UUID
    name: str | None
    rows: int
    columns: int
    total_seats: int
    seats: list[SeatResponse]


class AssignDriverRequest(RequestModel):
    driver_id: uuid.UUID


class FleetDriverVehicleResponse(ApiModel):
    vehicle_id: uuid.UUID
    registration_number: str
    assigned_at: datetime


class FleetDriverResponse(ApiModel):
    """A driver currently assigned to one or more of the fleet's vehicles."""

    driver_id: uuid.UUID
    full_name: str | None
    phone_number: str
    approval_status: ApprovalStatus
    vehicles: list[FleetDriverVehicleResponse]


class DriverLookupResponse(ApiModel):
    driver_id: uuid.UUID
    full_name: str | None
    phone_number: str = Field(..., description="Masked, e.g. +23324•••4567.")
    approval_status: ApprovalStatus
