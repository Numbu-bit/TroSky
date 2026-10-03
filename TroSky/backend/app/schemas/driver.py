"""Request/response schemas for driver registration, documents, and
approval review."""

from __future__ import annotations

import uuid
from datetime import date, datetime
from decimal import Decimal
from typing import Literal

from pydantic import Field

from app.models.drivers import ApprovalStatus, DocumentStatus, DocumentType
from app.models.vehicles import VehicleType
from app.providers.payments.base import PaymentChannel
from app.schemas.common import ApiModel, RequestModel


class DriverRegisterRequest(RequestModel):
    license_number: str = Field(..., min_length=3, max_length=50)
    license_expiry: date
    license_class: str | None = Field(default=None, max_length=20)
    years_of_experience: int | None = Field(default=None, ge=0)


class DriverUpdateRequest(RequestModel):
    license_expiry: date | None = None
    license_class: str | None = Field(default=None, max_length=20)
    years_of_experience: int | None = Field(default=None, ge=0)


class DriverResponse(ApiModel):
    id: uuid.UUID
    user_id: uuid.UUID
    full_name: str | None = None
    phone_number: str | None = None
    license_number: str
    license_expiry: date
    license_class: str | None
    years_of_experience: int | None
    status: ApprovalStatus
    created_at: datetime


class DriverDocumentResponse(ApiModel):
    id: uuid.UUID
    document_type: DocumentType
    status: DocumentStatus
    original_filename: str
    mime_type: str
    file_size_bytes: int
    expiry_date: date | None
    rejection_reason: str | None
    created_at: datetime


class DocumentDownloadUrlResponse(ApiModel):
    download_url: str
    expires_in_seconds: int


class ApprovalReviewRequest(RequestModel):
    """Body for an admin approve/reject decision."""

    notes: str | None = Field(default=None, max_length=1000)
    rejection_reason: str | None = Field(default=None, max_length=500)


class AssignedVehicleResponse(ApiModel):
    id: uuid.UUID
    registration_number: str
    vehicle_type: VehicleType
    make_model: str | None = Field(default=None, examples=["Toyota Hiace"])
    capacity: int
    status: ApprovalStatus


class DriverAssignmentResponse(ApiModel):
    id: uuid.UUID
    driver_id: uuid.UUID
    vehicle_id: uuid.UUID
    fleet_id: uuid.UUID
    is_active: bool
    assigned_at: datetime
    vehicle: AssignedVehicleResponse | None = None


class ChannelTotalResponse(ApiModel):
    channel: PaymentChannel
    passengers: int
    amount: Decimal


class SeatReceiptResponse(ApiModel):
    booking_reference: str
    passenger_name: str
    seat_label: str
    amount: Decimal = Field(..., description="This seat's fare, TroSky's fee excluded.")
    channel: PaymentChannel
    paid_at: datetime | None


class TripPaymentsResponse(ApiModel):
    trip_id: uuid.UUID
    currency: str
    fare_per_seat: Decimal = Field(
        ...,
        description=(
            "The trip's listed fare for the whole route. Passengers sharing the trip or "
            "riding part of it pay less; see each receipt."
        ),
    )
    total_collected: Decimal = Field(..., description="Fares paid for this trip, fees excluded.")
    by_channel: list[ChannelTotalResponse]
    receipts: list[SeatReceiptResponse]


class EarningsBucketResponse(ApiModel):
    start: date = Field(..., description="First day of the period (weeks start on Monday).")
    total: Decimal
    trips_count: int


class EarningsSummaryResponse(ApiModel):
    period: Literal["day", "week", "month"]
    currency: str
    total: Decimal
    trips_count: int
    pending_withdrawals_total: Decimal = Field(
        ..., description="Withdrawals requested but not yet paid out."
    )
    buckets: list[EarningsBucketResponse]
