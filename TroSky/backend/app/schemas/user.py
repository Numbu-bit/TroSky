"""Request/response schemas for profile, emergency contacts, and
notification preferences."""

from __future__ import annotations

import uuid
from datetime import datetime
from decimal import Decimal

from pydantic import Field, field_validator, model_validator

from app.schemas.common import ApiModel, RequestModel


class UserProfileResponse(ApiModel):
    full_name: str
    date_of_birth: datetime | None
    gender: str | None
    preferred_language: str
    avatar_url: str | None
    ghana_card_number: str | None
    ghana_card_verified: bool


class UserResponse(ApiModel):
    id: uuid.UUID
    phone_number: str
    email: str | None
    is_active: bool
    phone_verified: bool
    email_verified: bool
    roles: list[str]
    created_at: datetime
    profile: UserProfileResponse | None


class UserProfileUpdateRequest(RequestModel):
    full_name: str | None = Field(default=None, min_length=2, max_length=200)
    date_of_birth: datetime | None = None
    gender: str | None = Field(default=None, max_length=20)
    preferred_language: str | None = Field(default=None, max_length=10)
    avatar_url: str | None = Field(default=None, max_length=1000)


class EmergencyContactCreateRequest(RequestModel):
    name: str = Field(..., min_length=2, max_length=200)
    phone_number: str = Field(...)
    relationship_label: str | None = Field(default=None, max_length=100)
    is_primary: bool = False


class EmergencyContactUpdateRequest(RequestModel):
    name: str | None = Field(default=None, min_length=2, max_length=200)
    phone_number: str | None = None
    relationship_label: str | None = Field(default=None, max_length=100)
    is_primary: bool | None = None


class EmergencyContactResponse(ApiModel):
    id: uuid.UUID
    name: str
    phone_number: str
    relationship_label: str | None
    is_primary: bool
    created_at: datetime


class NotificationPreferencesResponse(ApiModel):
    push_enabled: bool
    sms_enabled: bool
    email_enabled: bool
    promotional_opt_in: bool


class NotificationPreferencesUpdateRequest(RequestModel):
    push_enabled: bool | None = None
    sms_enabled: bool | None = None
    email_enabled: bool | None = None
    promotional_opt_in: bool | None = None


class AccountDeletionRequest(RequestModel):
    password: str = Field(..., min_length=1, max_length=128)
    reason: str | None = Field(default=None, max_length=500)


class FavouriteRouteCreateRequest(RequestModel):
    origin_stop_id: uuid.UUID
    destination_stop_id: uuid.UUID
    label: str | None = Field(default=None, max_length=60, examples=["Home to work"])

    @field_validator("label")
    @classmethod
    def _blank_label_is_none(cls, value: str | None) -> str | None:
        return value.strip() or None if value is not None else None

    @model_validator(mode="after")
    def _distinct_stops(self) -> FavouriteRouteCreateRequest:
        if self.origin_stop_id == self.destination_stop_id:
            raise ValueError("origin_stop_id and destination_stop_id must be different.")
        return self


class NextTripResponse(ApiModel):
    trip_id: uuid.UUID
    scheduled_departure_at: datetime
    available_seats: int
    fare: Decimal = Field(..., description="Per seat right now, before the platform fee.")
    currency: str


class FavouriteRouteResponse(ApiModel):
    id: uuid.UUID
    origin_stop_id: uuid.UUID
    origin_stop_name: str
    destination_stop_id: uuid.UUID
    destination_stop_name: str
    label: str | None
    created_at: datetime
    next_trip: NextTripResponse | None = Field(
        default=None,
        description="The soonest trip in the next 7 days with a free seat; null if none.",
    )
