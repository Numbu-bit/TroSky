"""Request/response schemas for the booking lifecycle."""

from __future__ import annotations

import uuid
from datetime import datetime
from decimal import Decimal

from pydantic import Field, field_validator, model_validator

from app.models.bookings import BookingStatus, CancellationStatus
from app.models.trips import TripStatus
from app.schemas.common import ApiModel, RequestModel


class PassengerInput(RequestModel):
    seat_id: uuid.UUID
    full_name: str = Field(..., min_length=2, max_length=200)
    phone_number: str | None = Field(default=None, max_length=20)


class BookingCreateRequest(RequestModel):
    trip_id: uuid.UUID
    passengers: list[PassengerInput] = Field(..., min_length=1, max_length=10)
    origin_stop_id: uuid.UUID | None = Field(
        default=None, description="Boarding stop. Omit to ride the whole route."
    )
    destination_stop_id: uuid.UUID | None = Field(
        default=None, description="Alighting stop. Omit to ride the whole route."
    )
    pickup_latitude: float | None = Field(
        default=None,
        ge=-90,
        le=90,
        description=(
            "Device GPS position, used as the pickup by default: it is snapped to "
            "the nearest stop on this trip's route within walking distance. "
            "Ignored when origin_stop_id is given, because a pickup chosen by hand "
            "always wins."
        ),
    )
    pickup_longitude: float | None = Field(default=None, ge=-180, le=180)

    @model_validator(mode="after")
    def _pickup_point_is_complete(self) -> BookingCreateRequest:
        if (self.pickup_latitude is None) != (self.pickup_longitude is None):
            raise ValueError("Provide both pickup_latitude and pickup_longitude, or neither.")
        return self

    @field_validator("passengers")
    @classmethod
    def _unique_seats(cls, passengers: list[PassengerInput]) -> list[PassengerInput]:
        seat_ids = [p.seat_id for p in passengers]
        if len(seat_ids) != len(set(seat_ids)):
            raise ValueError("Each passenger must occupy a distinct seat.")
        return passengers


class BookingPassengerResponse(ApiModel):
    id: uuid.UUID
    seat_id: uuid.UUID
    full_name: str
    phone_number: str | None


class BookingTripSummaryResponse(ApiModel):
    """The trip a booking is for, enough for a booking card."""

    scheduled_departure_at: datetime
    route_name: str
    origin_stop_name: str = Field(..., description="Where the trip's route starts.")
    destination_stop_name: str = Field(..., description="Where the trip's route ends.")
    status: TripStatus
    vehicle_registration_number: str | None


class BookingResponse(ApiModel):
    id: uuid.UUID
    booking_reference: str
    trip_id: uuid.UUID
    status: BookingStatus
    passenger_count: int
    origin_stop_id: uuid.UUID | None
    destination_stop_id: uuid.UUID | None
    fare_amount: Decimal
    platform_fee: Decimal
    total_amount: Decimal
    expires_at: datetime | None
    created_at: datetime
    passengers: list[BookingPassengerResponse]
    trip: BookingTripSummaryResponse | None = None
    boarding_stop_name: str | None = Field(
        default=None,
        description="Where this booking boards: its origin stop, or the route's start.",
    )
    alighting_stop_name: str | None = Field(
        default=None,
        description="Where this booking gets off: its destination stop, or the route's end.",
    )


class CancelBookingRequest(RequestModel):
    reason: str | None = Field(default=None, max_length=500)


class CancellationRequestResponse(ApiModel):
    id: uuid.UUID
    booking_id: uuid.UUID
    requested_by: uuid.UUID | None
    reason: str | None
    status: CancellationStatus
    refund_eligible: bool
    decided_by: uuid.UUID | None
    decided_at: datetime | None
    decision_notes: str | None
    created_at: datetime
