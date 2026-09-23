"""Request/response schemas for profile, emergency contacts, and
notification preferences."""

from __future__ import annotations

import uuid
from datetime import datetime

from pydantic import Field

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
