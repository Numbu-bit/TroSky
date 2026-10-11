"""Drivers (and admins) accepting trips and bookings, passengers getting
off, and the log of what drivers did."""

from __future__ import annotations

import uuid
from datetime import datetime
from decimal import Decimal
from typing import Any

from pydantic import Field

from app.models.bookings import AlightedHow, BookingStatus
from app.models.driver_actions import ActedAs, DriverActionKind
from app.models.trips import AssignmentResponse
from app.schemas.common import ApiModel, RequestModel


class DeclineRequest(RequestModel):
    reason: str = Field(..., min_length=3, max_length=500)


class AdminDeclineBookingRequest(RequestModel):
    reason: str = Field(..., min_length=3, max_length=500)
    move_to_another_trip: bool = Field(
        default=True,
        description=(
            "Put the booking to another vehicle from the same pickup to the same destination, "
            "if one has seats. False: the booking ends here."
        ),
    )


class MoveBookingRequest(RequestModel):
    trip_id: uuid.UUID = Field(
        ..., description="A trip from the booking's pickup to its destination, with a driver."
    )


class TripAnswerResponse(ApiModel):
    trip_id: uuid.UUID
    driver_id: uuid.UUID
    response: AssignmentResponse
    responded_at: datetime | None
    response_reason: str | None
    is_active: bool = Field(..., description="False once declined: the trip has no driver.")


class BookingRequestResponse(ApiModel):
    """A booking waiting for its driver (or an admin) to accept it."""

    offer_id: uuid.UUID
    booking_id: uuid.UUID
    booking_reference: str
    trip_id: uuid.UUID
    trip_departure_at: datetime
    driver_id: uuid.UUID | None
    expires_at: datetime = Field(..., description="Unanswered by then, it goes to another vehicle.")
    seconds_left: int
    passenger_count: int
    passenger_name: str | None
    seat_numbers: list[str]
    origin_stop_id: uuid.UUID | None
    origin_stop_name: str | None = Field(..., description="None: from the route's first stop.")
    destination_stop_id: uuid.UUID | None
    destination_stop_name: str | None = Field(..., description="None: to the route's last stop.")
    fare_amount: Decimal
    attempt: int = Field(
        ..., description="1 on the trip the passenger chose; 2 or more once moved to another."
    )


class AlightRequest(RequestModel):
    stop_id: uuid.UUID | None = Field(
        default=None,
        description="Where they got off. Left out: the stop the vehicle is nearest now.",
    )


class AlightResponse(ApiModel):
    booking_passenger_id: uuid.UUID
    booking_id: uuid.UUID
    alighted_at: datetime | None
    alighted_stop_id: uuid.UUID | None
    alighted_how: AlightedHow | None
    booking_status: BookingStatus = Field(
        ..., description="completed once everyone on the booking is off."
    )


class DriverActionResponse(ApiModel):
    id: uuid.UUID
    created_at: datetime
    kind: DriverActionKind
    acted_as: ActedAs = Field(
        ..., description="driver; admin (for the driver); system (nobody answered, or arrival)."
    )
    driver_id: uuid.UUID | None
    driver_name: str | None
    actor_id: uuid.UUID | None
    actor_name: str | None
    trip_id: uuid.UUID
    booking_id: uuid.UUID | None
    reason: str | None
    details: dict[str, Any] | None
