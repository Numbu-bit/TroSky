"""Request/response schemas for driver registration, documents, and
approval review."""

from __future__ import annotations

import uuid
from datetime import date, datetime
from decimal import Decimal
from typing import Literal

from pydantic import Field

from app.models.drivers import ApprovalStatus, DocumentStatus, DocumentType
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


class DriverAssignmentResponse(ApiModel):
    id: uuid.UUID
    driver_id: uuid.UUID
    vehicle_id: uuid.UUID
    fleet_id: uuid.UUID
    is_active: bool
    assigned_at: datetime


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
