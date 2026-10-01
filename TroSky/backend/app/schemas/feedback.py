"""Request/response schemas for ratings and complaints."""

from __future__ import annotations

import uuid
from datetime import datetime
from decimal import Decimal

from pydantic import Field

from app.models.feedback import ComplaintCategory, ComplaintStatus
from app.schemas.common import ApiModel, RequestModel


class RateBookingRequest(RequestModel):
    score: int = Field(..., ge=1, le=5, description="The overall rating.")
    comment: str | None = Field(default=None, max_length=1000)
    safety: int | None = Field(default=None, ge=1, le=5)
    cleanliness: int | None = Field(default=None, ge=1, le=5)
    professionalism: int | None = Field(default=None, ge=1, le=5)
    timeliness: int | None = Field(default=None, ge=1, le=5)

    def categories(self) -> dict[str, int | None]:
        return {
            "safety": self.safety,
            "cleanliness": self.cleanliness,
            "professionalism": self.professionalism,
            "timeliness": self.timeliness,
        }


class RatingResponse(ApiModel):
    id: uuid.UUID
    booking_id: uuid.UUID
    trip_id: uuid.UUID
    driver_id: uuid.UUID | None
    score: int
    comment: str | None
    safety: int | None = None
    cleanliness: int | None = None
    professionalism: int | None = None
    timeliness: int | None = None
    created_at: datetime


class DriverRatingSummaryResponse(ApiModel):
    driver_id: uuid.UUID
    average_score: Decimal | None
    rating_count: int
    safety_average: Decimal | None = None
    cleanliness_average: Decimal | None = None
    professionalism_average: Decimal | None = None
    timeliness_average: Decimal | None = None


class FileComplaintRequest(RequestModel):
    booking_id: uuid.UUID | None = None
    trip_id: uuid.UUID | None = None
    category: ComplaintCategory
    subject: str = Field(..., min_length=1, max_length=200)
    description: str = Field(..., min_length=1, max_length=2000)


class ComplaintResponse(ApiModel):
    id: uuid.UUID
    filed_by: uuid.UUID
    booking_id: uuid.UUID | None
    trip_id: uuid.UUID | None
    category: ComplaintCategory
    subject: str
    description: str
    status: ComplaintStatus
    resolved_by: uuid.UUID | None
    resolved_at: datetime | None
    resolution_notes: str | None
    created_at: datetime


class ComplaintDecisionRequest(RequestModel):
    notes: str | None = Field(default=None, max_length=1000)
