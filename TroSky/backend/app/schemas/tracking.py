"""Request/response schemas for GPS tracking and ETA."""

from __future__ import annotations

import uuid
from datetime import datetime
from decimal import Decimal

from pydantic import Field

from app.models.trips import TripStatus
from app.models.vehicles import VehicleType
from app.schemas.common import ApiModel, RequestModel


class LocationPingRequest(RequestModel):
    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)
    speed_kmh: Decimal | None = Field(default=None, ge=0, max_digits=6, decimal_places=2)
    heading_degrees: Decimal | None = Field(
        default=None, ge=0, le=360, max_digits=5, decimal_places=2
    )
    accuracy_meters: Decimal | None = Field(default=None, ge=0, max_digits=8, decimal_places=2)
    recorded_at: datetime | None = Field(
        default=None, description="Defaults to server-received time if omitted."
    )


class LiveLocationResponse(ApiModel):
    trip_id: uuid.UUID
    latitude: float
    longitude: float
    speed_kmh: Decimal | None
    heading_degrees: Decimal | None
    recorded_at: datetime
    is_stale: bool
    trip_status: TripStatus | None = Field(
        default=None,
        description=(
            "The trip's status after this position, when the driver sent it. Positions "
            "change it on their own: at the first stop the trip is boarding, leaving it "
            "starts it, standing still a long time pauses it, moving resumes it, and "
            "staying at the last stop completes it."
        ),
    )


class EtaResponse(ApiModel):
    distance_km: Decimal
    duration_minutes: int
    eta_at: datetime


class NearbyVehicleResponse(ApiModel):
    """A vehicle out on a trip near the given point, from its last GPS ping."""

    trip_id: uuid.UUID
    vehicle_id: uuid.UUID
    vehicle_registration_number: str
    vehicle_type: VehicleType
    route_id: uuid.UUID
    route_name: str
    latitude: float
    longitude: float
    heading: Decimal | None
    distance_m: float
    available_seats: int
    updated_at: datetime
