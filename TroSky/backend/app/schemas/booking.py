"""Request/response schemas for the booking lifecycle."""

from __future__ import annotations

import uuid
from datetime import datetime
from decimal import Decimal

from pydantic import Field, field_validator

from app.models.bookings import BookingStatus, CancellationStatus
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
