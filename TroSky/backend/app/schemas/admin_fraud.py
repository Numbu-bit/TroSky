"""Responses and requests for fraud detection (section 7 of the admin
requests): flags, their review, actions, statistics and the rules."""

from __future__ import annotations

import uuid
from datetime import datetime
from decimal import Decimal
from typing import Any, Literal

from pydantic import Field

from app.models.fraud import FraudFlagStatus, FraudSeverity
from app.schemas.admin_analytics import Compared
from app.schemas.analytics import CountFigure, PeriodResponse
from app.schemas.common import ApiModel, RequestModel

FraudActionName = Literal[
    "suspend_account", "freeze_wallet", "unfreeze_wallet", "block_device", "unblock_device"
]


class FraudFlagResponse(ApiModel):
    id: uuid.UUID
    rule: str
    rule_title: str
    severity: FraudSeverity
    risk_score: int = Field(..., ge=0, le=100)
    entity_type: str = Field(
        ..., examples=["user", "ticket", "trip", "driver", "device", "phone_number"]
    )
    entity_id: str
    subject_user_id: uuid.UUID | None = Field(
        ..., description="The account mainly concerned, which actions act on by default."
    )
    subject_name: str | None
    summary: str
    amount_at_risk: Decimal | None
    status: FraudFlagStatus
    assigned_to: uuid.UUID | None
    assignee_name: str | None
    first_detected_at: datetime
    last_detected_at: datetime
    occurrences: int


class LinkedUser(ApiModel):
    id: uuid.UUID
    full_name: str | None
    phone_number: str | None
    is_suspended: bool | None
    wallet_frozen: bool


class LinkedTrip(ApiModel):
    id: uuid.UUID
    route_name: str | None
    scheduled_departure_at: datetime | None
    status: str | None


class LinkedBooking(ApiModel):
    id: uuid.UUID
    booking_reference: str | None
    status: str | None
    fare_amount: Decimal | None


class LinkedPayment(ApiModel):
    id: uuid.UUID
    internal_reference: str | None
    amount: Decimal | None
    status: str | None
    channel: str | None


class FraudFlagEventResponse(ApiModel):
    id: uuid.UUID
    kind: str = Field(
        ..., examples=["detected", "detected_again", "assigned", "status_changed", "action"]
    )
    actor_id: uuid.UUID | None = Field(..., description="Null: the detection job.")
    actor_name: str | None
    details: dict[str, Any]
    created_at: datetime


class FraudFlagDetailResponse(FraudFlagResponse):
    evidence: dict[str, Any]
    reviewed_by: uuid.UUID | None
    reviewed_at: datetime | None
    review_reason: str | None
    device_blocked: bool | None = Field(
        ..., description="For a device flag: whether the device is blocked now."
    )
    users: list[LinkedUser]
    trips: list[LinkedTrip]
    bookings: list[LinkedBooking]
    payments: list[LinkedPayment]
    timeline: list[FraudFlagEventResponse]


class FraudFlagUpdateRequest(RequestModel):
    status: FraudFlagStatus | None = None
    assigned_to: uuid.UUID | None = Field(
        default=None, description="An admin who reviews fraud; null to unassign."
    )
    reason: str | None = Field(
        default=None,
        max_length=1000,
        description="Required to confirm a flag or call it a false positive.",
    )


class FraudActionRequest(RequestModel):
    action: FraudActionName
    reason: str = Field(..., min_length=3, max_length=500)
    user_id: uuid.UUID | None = Field(
        default=None, description="Default: the flag's subject account."
    )
    device_id: str | None = Field(
        default=None, max_length=255, description="Default: the flag's device."
    )


class FraudActionResponse(ApiModel):
    flag: FraudFlagResponse
    event: FraudFlagEventResponse


class RuleCount(ApiModel):
    rule: str
    rule_title: str
    detected: int
    confirmed: int
    false_positive: int


class FraudStatsResponse(ApiModel):
    period: PeriodResponse
    open: int = Field(..., description="Open or under investigation now.")
    high_risk: int = Field(..., description="Of those, with a risk score of 70 or more.")
    amount_at_risk: Decimal = Field(..., description="Over the open flags, now.")
    detected: CountFigure
    confirmed: int
    false_positive: int
    precision: Compared = Field(
        ..., description="Confirmed / (confirmed + false positive), of flags reviewed."
    )
    by_rule: list[RuleCount]


class FraudRuleResponse(ApiModel):
    key: str
    title: str
    threshold_means: str
    enabled: bool
    threshold: Decimal
    window_minutes: int
    severity: FraudSeverity
    changed: bool = Field(..., description="An admin changed it from the defaults.")
    updated_by: uuid.UUID | None
    updated_at: datetime | None


class FraudRuleUpdateRequest(RequestModel):
    enabled: bool | None = None
    threshold: Decimal | None = Field(default=None, ge=0, le=1_000_000)
    window_minutes: int | None = Field(default=None, ge=5, le=90 * 24 * 60)
    severity: FraudSeverity | None = None
    reason: str | None = Field(default=None, max_length=1000, description="For the audit log.")


class DetectionRunResponse(ApiModel):
    raised: int
    updated: int
    by_rule: dict[str, int] = Field(..., description="Findings per rule this run.")
