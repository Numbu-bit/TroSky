"""Request/response schemas for trip scheduling, search, and lifecycle."""

from __future__ import annotations

import uuid
from datetime import datetime
from decimal import Decimal
from typing import Literal

from pydantic import Field

from app.models.trips import TripStatus
from app.models.vehicles import SeatType, VehicleType
from app.schemas.common import ApiModel, RequestModel


class TripCreateRequest(RequestModel):
    route_id: uuid.UUID
    scheduled_departure_at: datetime
    scheduled_arrival_at: datetime | None = None
    fare_amount: Decimal = Field(..., ge=0, max_digits=12, decimal_places=2)


class TripResponse(ApiModel):
    id: uuid.UUID
    route_id: uuid.UUID
    route_schedule_id: uuid.UUID | None
    scheduled_departure_at: datetime
    scheduled_arrival_at: datetime | None
    actual_departure_at: datetime | None
    actual_arrival_at: datetime | None
    status: TripStatus
    fare_amount: Decimal
    created_at: datetime


class TripSearchResultResponse(ApiModel):
    trip_id: uuid.UUID
    route_id: uuid.UUID
    route_name: str
    origin_stop_id: uuid.UUID
    destination_stop_id: uuid.UUID
    scheduled_departure_at: datetime
    scheduled_arrival_at: datetime | None
    estimated_duration_minutes: int | None
    distance_km: Decimal | None
    fare_amount: Decimal
    status: TripStatus
    available_seats: int
    vehicle_registration_number: str | None
    vehicle_type: VehicleType | None
    # Where this passenger boards this trip. For a GPS search it is the
    # nearest stop the trip actually serves, which is not always the
    # nearest stop overall -- so it is reported per trip.
    pickup_stop_id: uuid.UUID | None = None
    pickup_stop_name: str | None = None
    pickup_distance_m: float | None = None
    pickup_source: Literal["gps", "manual"] | None = None


class AssignTripDriverRequest(RequestModel):
    driver_id: uuid.UUID


class AssignTripVehicleRequest(RequestModel):
    vehicle_id: uuid.UUID


class CancelTripRequest(RequestModel):
    reason: str | None = Field(default=None, max_length=500)


class PauseTripRequest(RequestModel):
    reason: str | None = Field(default=None, max_length=500)


class EndTripRequest(RequestModel):
    latitude: Decimal | None = Field(default=None, ge=-90, le=90, max_digits=9, decimal_places=6)
    longitude: Decimal | None = Field(default=None, ge=-180, le=180, max_digits=9, decimal_places=6)


class TripSeatResponse(ApiModel):
    id: uuid.UUID
    seat_number: str
    row_number: int
    column_number: int
    seat_type: SeatType
    is_available: bool


class TripSeatsResponse(ApiModel):
    trip_id: uuid.UUID
    vehicle_id: uuid.UUID
    total_seats: int
    available_seats: int
    seats: list[TripSeatResponse]
