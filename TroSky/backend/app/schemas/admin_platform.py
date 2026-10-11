"""Responses and requests for platform administration: the audit log,
system settings, feature flags and wallet adjustments."""

from __future__ import annotations

import uuid
from datetime import datetime
from decimal import Decimal
from typing import Any, Literal

from pydantic import Field

from app.schemas.common import ApiModel, RequestModel
from app.schemas.payment import WalletTransactionResponse


class AuditLogResponse(ApiModel):
    id: uuid.UUID
    created_at: datetime
    actor_user_id: uuid.UUID | None
    actor_name: str | None = None
    action: str = Field(..., examples=["cancel_trip"])
    method: str
    path: str = Field(..., examples=["/api/v1/admin/trips/{trip_id}/cancel"])
    entity_type: str = Field(..., description="The table changed; 'request' if nothing was.")
    entity_id: str | None
    before: dict[str, Any] | None = Field(..., description="Changed columns, before.")
    after: dict[str, Any] | None = Field(..., description="Changed columns, after.")
    reason: str | None
    ip_address: str | None
    user_agent: str | None
    request_id: str | None


class SettingResponse(ApiModel):
    key: str
    value: Any
    overridden: bool = Field(..., description="Changed by an admin; false = the default.")
    updated_by: uuid.UUID | None
    updated_at: datetime | None


class SettingsUpdateRequest(RequestModel):
    """Any of the settings; ``null`` puts one back to its default."""

    platform_fee_flat_per_seat: Decimal | None = None
    platform_fee_percent: Decimal | None = None
    driver_earnings_share_percent: Decimal | None = None
    reservation_hold_seconds: int | None = None
    live_update_interval_seconds: int | None = None
    complaint_sla_hours: dict[str, int] | None = Field(
        default=None, examples=[{"low": 72, "medium": 48, "high": 24, "urgent": 4}]
    )
    approval_target_hours: int | None = None
    sos_escalation_contacts: list[dict[str, str]] | None = Field(
        default=None,
        examples=[[{"name": "Ghana Police", "phone_number": "191", "role": "police"}]],
    )
    enabled_cities: list[str] | None = None
    reason: str | None = Field(default=None, max_length=1000, description="For the audit log.")


class FeatureFlagResponse(ApiModel):
    key: str
    description: str
    enabled: bool
    rollout_percent: int
    updated_by: uuid.UUID | None
    updated_at: datetime


class FeatureFlagUpdateRequest(RequestModel):
    enabled: bool | None = None
    rollout_percent: int | None = Field(default=None, ge=0, le=100)
    reason: str | None = Field(default=None, max_length=1000, description="For the audit log.")


class WalletOwner(ApiModel):
    id: uuid.UUID
    full_name: str | None
    phone_number: str


class AdminWalletResponse(ApiModel):
    user: WalletOwner
    balance: Decimal
    currency: str
    held_for_withdrawals: Decimal = Field(
        ..., description="Withdrawals requested and not paid out yet."
    )
    frozen_at: datetime | None = Field(
        default=None, description="Set while frozen: no payments or payouts leave the wallet."
    )
    frozen_reason: str | None = None
    transactions: list[WalletTransactionResponse]
    transactions_total: int
    limit: int
    offset: int


class WalletAdjustmentRequest(RequestModel):
    direction: Literal["credit", "debit"]
    amount: Decimal = Field(..., gt=0, max_digits=12, decimal_places=2)
    reason: str = Field(..., min_length=5, max_length=500)
    reference: str | None = Field(
        default=None, max_length=100, description="A ticket or case number, say."
    )


class WalletAdjustmentResponse(ApiModel):
    transaction: WalletTransactionResponse
    balance: Decimal
