"""Request/response schemas for authentication and session management."""

from __future__ import annotations

import uuid
from datetime import datetime
from enum import StrEnum

from pydantic import EmailStr, Field, field_validator, model_validator

from app.models.identity import DevicePlatform, OtpChannel, OtpPurpose
from app.schemas.common import ApiModel, RequestModel
from app.utilities.phone import InvalidPhoneNumberError, normalize_phone_number


class RegistrableRole(StrEnum):
    """Roles selectable at public self-registration. Admin accounts are
    never created through this endpoint (see README security notes)."""

    PASSENGER = "passenger"
    DRIVER = "driver"
    FLEET_OWNER = "fleet_owner"


def _validate_phone(value: str) -> str:
    try:
        return normalize_phone_number(value)
    except InvalidPhoneNumberError as exc:
        raise ValueError(str(exc)) from exc


class RegisterRequest(RequestModel):
    phone_number: str = Field(..., examples=["0241234567"])
    email: EmailStr | None = Field(
        default=None,
        description=(
            "Where verification codes are sent. The server can require one on "
            "specific domains; by default a Gmail address (@gmail.com)."
        ),
        examples=["ama.mensah@gmail.com"],
    )
    password: str = Field(..., min_length=8, max_length=128)
    full_name: str = Field(..., min_length=2, max_length=200)
    role: RegistrableRole = RegistrableRole.PASSENGER
    preferred_language: str = Field(default="en", max_length=10)

    _normalize_phone = field_validator("phone_number")(_validate_phone)


class RegisterResponse(ApiModel):
    user_id: uuid.UUID
    phone_number: str
    otp_sent_to: str
    message: str = "Registration successful. Verify your phone number with the OTP sent."


class VerifyOtpRequest(RequestModel):
    target: str = Field(..., description="Phone (E.164) or email the OTP was sent to.")
    purpose: OtpPurpose
    code: str = Field(..., min_length=4, max_length=10)


class ResendOtpRequest(RequestModel):
    target: str
    purpose: OtpPurpose
    channel: OtpChannel = OtpChannel.SMS


class DeviceContext(RequestModel):
    device_id: str | None = Field(default=None, max_length=255)
    device_name: str | None = Field(default=None, max_length=255)
    platform: DevicePlatform | None = None
    push_token: str | None = Field(default=None, max_length=500)


class LoginRequest(RequestModel):
    identifier: str = Field(..., description="Phone number (E.164 or local) or email.")
    password: str = Field(..., min_length=1, max_length=128)
    device: DeviceContext | None = None


class OtpLoginRequest(RequestModel):
    target: str
    code: str = Field(..., min_length=4, max_length=10)
    device: DeviceContext | None = None


class RefreshRequest(RequestModel):
    refresh_token: str = Field(..., min_length=20)


class TokenPairResponse(ApiModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int
    session_id: uuid.UUID


class ForgotPasswordRequest(RequestModel):
    identifier: str = Field(..., description="Phone number or email to send a reset code to.")


class ResetPasswordRequest(RequestModel):
    """Prove it is you with the 6-digit ``code`` sent by ``/password/forgot``
    (plus the ``target`` you asked it for), or with an older long ``token``."""

    target: str | None = Field(
        default=None,
        description="The phone number or email the code was requested for.",
        examples=["+233241234567"],
    )
    code: str | None = Field(default=None, min_length=4, max_length=10, examples=["482913"])
    token: str | None = Field(
        default=None, min_length=20, description="Older reset links' long token."
    )
    new_password: str = Field(..., min_length=8, max_length=128)

    @model_validator(mode="after")
    def _one_proof(self) -> ResetPasswordRequest:
        with_code = self.target is not None or self.code is not None
        if self.token is not None and with_code:
            raise ValueError("Send either target and code, or token -- not both.")
        if self.token is None and (self.target is None or self.code is None):
            raise ValueError("Send target and code (or the older token).")
        return self


class SessionResponse(ApiModel):
    id: uuid.UUID
    device_name: str | None
    ip_address: str | None
    user_agent: str | None
    created_at: datetime
    last_seen_at: datetime
    is_current: bool = False
