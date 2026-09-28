"""Request/response schemas for stops, routes, and route schedules."""

from __future__ import annotations

import uuid
from datetime import date, datetime, time
from decimal import Decimal

from pydantic import Field, ValidationInfo, field_validator

from app.models.routes import DayOfWeek
from app.schemas.common import ApiModel, RequestModel


class StopCreateRequest(RequestModel):
    name: str = Field(..., min_length=2, max_length=200)
    code: str | None = Field(default=None, max_length=20)
    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)
    address: str | None = Field(default=None, max_length=500)
    city: str | None = Field(default=None, max_length=100)
    region: str | None = Field(default=None, max_length=100)


class StopResponse(ApiModel):
    id: uuid.UUID
    name: str
    code: str | None
    address: str | None
    city: str | None
    region: str | None
    latitude: float
    longitude: float


class NearbyStopResponse(StopResponse):
    distance_m: float = Field(
        ..., description="Walking-scale distance from the given point, metres."
    )


class RouteCreateRequest(RequestModel):
    name: str = Field(..., min_length=2, max_length=200)
    origin_stop_id: uuid.UUID
    destination_stop_id: uuid.UUID
    intermediate_stop_ids: list[uuid.UUID] = Field(default_factory=list)
    distance_km: Decimal | None = Field(default=None, ge=0, max_digits=8, decimal_places=2)
    estimated_duration_minutes: int | None = Field(default=None, gt=0)

    @field_validator("destination_stop_id")
    @classmethod
    def _distinct_from_origin(cls, value: uuid.UUID, info: ValidationInfo) -> uuid.UUID:
        origin = info.data.get("origin_stop_id")
        if origin is not None and value == origin:
            raise ValueError("origin_stop_id and destination_stop_id must be different.")
        return value


class RouteResponse(ApiModel):
    id: uuid.UUID
    name: str
    origin_stop_id: uuid.UUID
    destination_stop_id: uuid.UUID
    distance_km: Decimal | None
    estimated_duration_minutes: int | None
    is_active: bool
    created_at: datetime


class RouteDetailResponse(RouteResponse):
    stops: list[StopResponse]


class RouteScheduleCreateRequest(RequestModel):
    departure_time: time
    days_of_week: list[DayOfWeek] = Field(..., min_length=1)
    fare_amount: Decimal = Field(..., ge=0, max_digits=12, decimal_places=2)


class RouteScheduleResponse(ApiModel):
    id: uuid.UUID
    route_id: uuid.UUID
    departure_time: time
    days_of_week: list[DayOfWeek]
    fare_amount: Decimal
    is_active: bool


class ScheduleTripRequest(RequestModel):
    """Admin/fleet-owner request to schedule a concrete trip from a
    recurring route schedule for a specific calendar date."""

    schedule_id: uuid.UUID
    travel_date: date
