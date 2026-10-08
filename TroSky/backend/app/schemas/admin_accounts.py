"""Responses and requests for people (section 11 of the admin requests):
users, their sessions, the admin team, and approval requests."""

from __future__ import annotations

import uuid
from datetime import date, datetime
from decimal import Decimal
from typing import Literal

from pydantic import EmailStr, Field, field_validator

from app.core.permissions import Permission
from app.models.drivers import DocumentStatus, DocumentType
from app.schemas.auth import _validate_phone
from app.schemas.common import ApiModel, RequestModel


class AdminUserResponse(ApiModel):
    id: uuid.UUID
    phone_number: str
    email: str | None
    full_name: str | None
    roles: list[str]
    is_active: bool
    is_suspended: bool
    suspended_reason: str | None
    created_at: datetime
    last_login_at: datetime | None


class MaskedPaymentMethod(ApiModel):
    id: uuid.UUID
    channel: str
    number: str = Field(..., examples=["+23324•••0201"])
    label: str | None
    is_default: bool


class FavouriteRoute(ApiModel):
    route_id: uuid.UUID
    route_name: str
    paid_bookings: int


class AdminUserDetailResponse(AdminUserResponse):
    preferred_language: str | None
    phone_verified: bool
    email_verified: bool
    payment_methods: list[MaskedPaymentMethod]
    favourite_routes: list[FavouriteRoute] = Field(..., description="Most paid bookings, up to 3.")
    bookings: dict[str, int] = Field(..., examples=[{"total": 12, "paid": 10}])
    complaints: dict[str, int] = Field(..., examples=[{"total": 2, "open": 1}])
    wallet_balance: Decimal
    wallet_frozen_at: datetime | None
    active_sessions: int
    driver_id: uuid.UUID | None
    fleet_owner_id: uuid.UUID | None
    open_fraud_flags: int


class AdminSessionResponse(ApiModel):
    id: uuid.UUID
    device_id: str | None
    device_name: str | None
    ip_address: str | None
    user_agent: str | None
    created_at: datetime
    last_seen_at: datetime


class TeamMemberResponse(ApiModel):
    id: uuid.UUID
    full_name: str | None
    phone_number: str
    email: str | None
    role: Literal["super_admin", "admin", "staff"]
    permissions: list[str] = Field(..., description="Everything the member may do.")
    granted_permissions: list[str] = Field(
        ..., description="Granted to the member directly (staff), on top of their role."
    )
    is_active: bool
    is_suspended: bool
    last_login_at: datetime | None
    created_at: datetime


class AdminMeResponse(ApiModel):
    """The signed-in admin, and everything they may do: what the dashboard
    shows them."""

    id: uuid.UUID
    full_name: str | None
    phone_number: str
    email: str | None
    role: Literal["super_admin", "admin", "staff"]
    permissions: list[str] = Field(
        ..., description="Every permission they hold; a super admin holds them all."
    )


class TeamInviteRequest(RequestModel):
    full_name: str = Field(..., min_length=1, max_length=120)
    phone_number: str = Field(..., min_length=7, max_length=20)
    email: EmailStr | None = Field(
        default=None, description="Where the code to set a password goes, while codes go by email."
    )
    role: Literal["admin", "staff"]
    permissions: list[Permission] = Field(
        default_factory=list, description="For staff: exactly what they may do."
    )
    reason: str | None = Field(default=None, max_length=1000, description="For the audit log.")

    @field_validator("phone_number")
    @classmethod
    def _phone(cls, value: str) -> str:
        return _validate_phone(value)


class TeamInviteResponse(ApiModel):
    member: TeamMemberResponse
    new_account: bool = Field(..., description="False: an existing account joined the team.")
    invitation_sent: bool = Field(..., description="A code to set a password was sent.")


class TeamUpdateRequest(RequestModel):
    role: Literal["super_admin", "admin", "staff"] | None = None
    permissions: list[Permission] | None = Field(
        default=None, description="For staff: replaces what they were granted."
    )
    active: bool | None = Field(
        default=None, description="False takes them off the team and signs them out."
    )
    reason: str | None = Field(default=None, max_length=1000, description="For the audit log.")


class TeamUpdateResponse(ApiModel):
    on_team: bool
    member: TeamMemberResponse | None


class InfoRequestBody(RequestModel):
    document_types: list[DocumentType] = Field(..., min_length=1, max_length=8)
    note: str = Field(
        ..., min_length=5, max_length=500, description="Shown to them with the documents."
    )


class InfoRequestResponse(ApiModel):
    subject_type: Literal["driver", "vehicle"]
    subject_id: uuid.UUID
    document_types: list[DocumentType]
    note: str
    documents_returned: list[uuid.UUID] = Field(
        ..., description="Their documents of those types, now marked for uploading again."
    )
    notified_user_id: uuid.UUID | None
    requested_at: datetime


class DocumentLinkResponse(ApiModel):
    document_id: uuid.UUID
    owner_type: Literal["driver", "vehicle"]
    owner_id: uuid.UUID
    document_type: DocumentType
    status: DocumentStatus
    expiry_date: date | None
    original_filename: str
    mime_type: str
    file_size_bytes: int
    url: str = Field(..., description="Valid until expires_at (five minutes).")
    expires_at: datetime
