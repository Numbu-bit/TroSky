"""Request/response schemas for trip scheduling, search, and lifecycle."""

from __future__ import annotations

import uuid
from datetime import datetime
from decimal import Decimal
from typing import Literal

from pydantic import Field

from app.models.trips import AssignmentResponse, TripStatus
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


class FareSummaryResponse(ApiModel):
    """A seat's price for one pickup and drop-off, as the bus stands now.

    A passenger's fare is fixed when they book: later riders make the trip
    cheaper for whoever books after them, not for those already aboard.
    """

    current: Decimal = Field(..., description="Per seat, right now, before TroSky's platform fee.")
    solo: Decimal = Field(
        ..., description="Per seat with nobody to share the trip: the crossed-out price."
    )
    minimum: Decimal = Field(
        ...,
        description=(
            "Lowest the per-seat price could reach if every free seat filled "
            '("Drops to GHS 6.00 as more riders join").'
        ),
    )
    platform_fee: Decimal = Field(..., description="TroSky's fee for all the seats asked for.")
    total: Decimal = Field(
        ..., description="What booking those seats costs now: current x seats + platform_fee."
    )
    currency: str
    riders_count: int = Field(..., description="Seats already taken on this trip.")
    seats: int


class FareQuoteResponse(FareSummaryResponse):
    trip_id: uuid.UUID
    origin_stop_id: uuid.UUID
    destination_stop_id: uuid.UUID


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
    fare: FareSummaryResponse = Field(
        ..., description="Price from this pickup to the searched destination."
    )
    ride_minutes: int | None = Field(
        default=None, description="Scheduled minutes from pickup to destination."
    )
    vehicle_eta_to_pickup_minutes: int | None = Field(
        default=None,
        description=(
            "For a vehicle already on the road with a recent GPS position: minutes until it "
            "reaches the pickup (0 = there now). Null for trips that have not set off."
        ),
    )
    has_passed_pickup: bool = Field(
        default=False,
        description="The vehicle has already gone past the pickup; it cannot be booked from there.",
    )


class TripVehicleResponse(ApiModel):
    registration_number: str
    type: VehicleType
    make_model: str | None = Field(default=None, examples=["Toyota Hiace"])
    capacity: int | None


class TripDriverResponse(ApiModel):
    id: uuid.UUID
    full_name: str | None
    avatar_url: str | None
    average_rating: Decimal | None = Field(default=None, description="1-5, null until rated.")
    rating_count: int


class TripDetailResponse(TripResponse):
    """A trip with what the Live Tracking, Boarding Pass and Rate Driver
    screens show about it."""

    route_name: str
    origin_stop_id: uuid.UUID
    origin_stop_name: str
    destination_stop_id: uuid.UUID
    destination_stop_name: str
    vehicle: TripVehicleResponse | None
    driver: TripDriverResponse | None
    riders_count: int = Field(..., description="Seats taken (paid or awaiting payment).")
    seats_total: int
    available_seats: int


class TripShareLinkResponse(ApiModel):
    url: str = Field(..., description="Open in any browser; no TroSky account needed.")
    token: str = Field(..., description="For building your own link: GET /shared-trips/{token}.")
    expires_at: datetime


class SharedTripLocationResponse(ApiModel):
    latitude: float
    longitude: float
    updated_at: datetime
    is_stale: bool = Field(..., description="True when the last position is too old to trust.")


class SharedTripResponse(ApiModel):
    """A shared trip as family and friends see it."""

    trip_id: uuid.UUID
    status: TripStatus
    route_name: str
    passenger_first_name: str | None
    driver_first_name: str | None
    boarding_stop_name: str
    alighting_stop_name: str
    scheduled_departure_at: datetime
    scheduled_arrival_at: datetime | None
    vehicle: TripVehicleResponse | None
    location: SharedTripLocationResponse | None = Field(
        default=None, description="While the trip is under way; null before and after."
    )
    minutes_to_dropoff: int | None = Field(
        default=None, description="Rough minutes until the passenger's stop, while moving."
    )
    expires_at: datetime


class AssignTripDriverRequest(RequestModel):
    driver_id: uuid.UUID


class AssignTripVehicleRequest(RequestModel):
    vehicle_id: uuid.UUID


class CancelTripRequest(RequestModel):
    reason: str | None = Field(default=None, max_length=500)


class TripCancellationResponse(TripResponse):
    """The cancelled trip, and what happened to its bookings."""

    bookings_cancelled: int = Field(..., description="Every booking that still held seats.")
    refunds_queued: int = Field(
        ..., description="Paid bookings now awaiting refund approval (/admin/refund-requests)."
    )
    refund_amount: Decimal = Field(..., description="What those refunds add up to.")


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


class TripSummaryResponse(ApiModel):
    """A trip as a list shows it (driver's trips, admin trip list)."""

    trip_id: uuid.UUID
    route_id: uuid.UUID
    route_name: str
    origin_stop_name: str
    destination_stop_name: str
    scheduled_departure_at: datetime
    scheduled_arrival_at: datetime | None
    status: TripStatus
    vehicle_id: uuid.UUID | None
    vehicle_registration_number: str | None
    seats_total: int
    seats_booked: int = Field(
        ...,
        description=(
            "Paid seats: the passengers on the trip's manifest, including those who have got "
            "off. A seat booked again after its passenger got off counts twice."
        ),
    )
    boarded_count: int = Field(..., description="Passengers whose ticket has been scanned.")
    driver_response: AssignmentResponse | None = Field(
        ..., description="The assigned driver's answer to the trip. None: no driver assigned."
    )


class AdminTripSummaryResponse(TripSummaryResponse):
    driver_id: uuid.UUID | None
    driver_name: str | None
    available_seats: int = Field(..., description="Seats nobody holds, paid or awaiting payment.")


class LiveTripResponse(ApiModel):
    """An active trip with its last reported GPS position (null until the
    driver's phone first reports one)."""

    trip_id: uuid.UUID
    route_name: str
    vehicle_registration_number: str | None
    driver_name: str | None
    status: TripStatus
    latitude: float | None
    longitude: float | None
    heading: Decimal | None
    updated_at: datetime | None
    is_stale: bool | None = Field(
        default=None, description="True when the last position is too old to trust."
    )


class ManifestEntryResponse(ApiModel):
    ticket_id: uuid.UUID
    booking_passenger_id: uuid.UUID = Field(
        ..., description="Who to mark off: POST .../passengers/{booking_passenger_id}/alight."
    )
    booking_reference: str
    seat_id: uuid.UUID
    seat_label: str
    passenger_full_name: str
    phone_number: str = Field(..., description="Masked, e.g. +23324•••4567.")
    pickup_stop_name: str
    dropoff_stop_name: str
    boarded: bool
    boarded_at: datetime | None
    alighted_at: datetime | None = Field(
        ..., description="When they got off; their seat is free from then on. None: aboard."
    )
