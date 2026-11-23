"""Request/response schemas for profile, emergency contacts, and
notification preferences."""

from __future__ import annotations

import uuid
from datetime import datetime
from decimal import Decimal

from pydantic import EmailStr, Field, field_validator, model_validator

from app.models.identity import FavouritePlaceKind
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
    """A notification goes out by push, SMS or email only when that channel
    and its topic are both on. Safety and account notifications always go
    out. The in-app inbox gets every notification whatever these say."""

    push_enabled: bool
    sms_enabled: bool
    email_enabled: bool
    booking_updates_enabled: bool = Field(
        ..., description="Bookings and trips: accepted, moved, confirmed, cancelled, arrived."
    )
    payment_enabled: bool = Field(..., description="Payments, refunds, top-ups and payouts.")
    promotions_enabled: bool = Field(..., description="Offers and news. Off until turned on.")
    safety_enabled: bool = Field(
        default=True, description="Always true: safety notifications can't be turned off."
    )
    account_enabled: bool = Field(
        default=True,
        description=(
            "Always true: account notifications (password or email changed, "
            "documents, support replies) can't be turned off."
        ),
    )
    promotional_opt_in: bool = Field(
        ..., description="Deprecated: the same as `promotions_enabled`."
    )


def _cannot_be_off(value: bool | None, what: str) -> bool | None:
    if value is False:
        raise ValueError(f"{what} notifications can't be turned off.")
    return value


class NotificationPreferencesUpdateRequest(RequestModel):
    """Send only the switches that change."""

    push_enabled: bool | None = None
    sms_enabled: bool | None = None
    email_enabled: bool | None = None
    booking_updates_enabled: bool | None = None
    payment_enabled: bool | None = None
    promotions_enabled: bool | None = None
    safety_enabled: bool | None = Field(default=None, description="Only `true` is accepted.")
    account_enabled: bool | None = Field(default=None, description="Only `true` is accepted.")
    promotional_opt_in: bool | None = Field(
        default=None, description="Deprecated: use `promotions_enabled`."
    )

    @field_validator("safety_enabled")
    @classmethod
    def _safety_stays_on(cls, value: bool | None) -> bool | None:
        return _cannot_be_off(value, "Safety")

    @field_validator("account_enabled")
    @classmethod
    def _account_stays_on(cls, value: bool | None) -> bool | None:
        return _cannot_be_off(value, "Account")

    @model_validator(mode="after")
    def _one_promotions_answer(self) -> NotificationPreferencesUpdateRequest:
        both = self.promotions_enabled is not None and self.promotional_opt_in is not None
        if both and self.promotions_enabled != self.promotional_opt_in:
            raise ValueError("promotions_enabled and promotional_opt_in disagree; send one.")
        return self

    def stored_fields(self) -> dict[str, bool]:
        """The columns to change, by their names on NotificationPreference."""
        fields = self.model_dump(
            exclude_unset=True,
            exclude_none=True,
            exclude={"safety_enabled", "account_enabled", "promotions_enabled"},
        )
        if self.promotions_enabled is not None:
            fields["promotional_opt_in"] = self.promotions_enabled
        return fields


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


# ---------------------------------------------------------------------------
# Favourite places (Home and Work shortcuts)
# ---------------------------------------------------------------------------
def _blank_is_none(value: str | None) -> str | None:
    return value.strip() or None if value is not None else None


def _check_location(
    stop_id: uuid.UUID | None, latitude: float | None, longitude: float | None
) -> None:
    if (latitude is None) != (longitude is None):
        raise ValueError("Send latitude and longitude together.")
    if stop_id is None and latitude is None:
        raise ValueError("Send a stop_id, or a latitude and longitude, or both.")


class FavouritePlaceCreateRequest(RequestModel):
    """A stop, a point, or both. Given only a stop, the place takes the
    stop's coordinates. A user has at most one `home` and one `work`."""

    kind: FavouritePlaceKind
    label: str | None = Field(
        default=None,
        max_length=60,
        description='Required for `custom`. Defaults to "Home" or "Work".',
        examples=["Mum's house"],
    )
    stop_id: uuid.UUID | None = None
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)

    @field_validator("label")
    @classmethod
    def _label_or_none(cls, value: str | None) -> str | None:
        return _blank_is_none(value)

    @model_validator(mode="after")
    def _complete(self) -> FavouritePlaceCreateRequest:
        if self.kind == FavouritePlaceKind.CUSTOM and self.label is None:
            raise ValueError("A custom place needs a label.")
        _check_location(self.stop_id, self.latitude, self.longitude)
        return self


class FavouritePlaceUpdateRequest(RequestModel):
    """Change the label, the location, or both. Any of `stop_id`, `latitude`
    and `longitude` replaces the whole location, by the same rules as when
    saving it: send only `latitude` and `longitude` to drop the stop."""

    label: str | None = Field(default=None, max_length=60)
    stop_id: uuid.UUID | None = None
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)

    @field_validator("label")
    @classmethod
    def _label_or_none(cls, value: str | None) -> str | None:
        return _blank_is_none(value)

    @property
    def moves(self) -> bool:
        return bool({"stop_id", "latitude", "longitude"} & self.model_fields_set)

    @model_validator(mode="after")
    def _complete(self) -> FavouritePlaceUpdateRequest:
        if self.moves:
            _check_location(self.stop_id, self.latitude, self.longitude)
        return self


class FavouritePlaceResponse(ApiModel):
    id: uuid.UUID
    kind: FavouritePlaceKind
    label: str
    stop_id: uuid.UUID | None
    stop_name: str | None
    latitude: float
    longitude: float
    created_at: datetime
    updated_at: datetime


# ---------------------------------------------------------------------------
# Changing the password and the email address
# ---------------------------------------------------------------------------
class ChangePasswordRequest(RequestModel):
    current_password: str = Field(..., min_length=1, max_length=128)
    new_password: str = Field(
        ...,
        min_length=8,
        max_length=128,
        description=(
            "At least 8 characters, with an uppercase letter, a lowercase letter and a digit."
        ),
    )


class ChangeEmailRequest(RequestModel):
    new_email: EmailStr = Field(..., examples=["ama.mensah@gmail.com"])
    current_password: str = Field(..., min_length=1, max_length=128)


class ChangeEmailConfirmRequest(RequestModel):
    new_email: EmailStr = Field(..., description="The address the code was sent to.")
    code: str = Field(..., min_length=4, max_length=10)


class EmailChangeStartedResponse(ApiModel):
    message: str
    otp_sent_to: str = Field(..., description="The new address, where the code went.")
    expires_in_seconds: int
