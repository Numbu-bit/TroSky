"""Request/response schemas for payments, wallet, and refunds."""

from __future__ import annotations

import uuid
from datetime import datetime
from decimal import Decimal

from pydantic import Field, model_validator

from app.models.payments import (
    PaymentPurpose,
    PaymentStatus,
    RefundStatus,
    WalletEntryType,
    WalletReferenceType,
)
from app.providers.payments.base import PaymentChannel
from app.schemas.common import ApiModel, RequestModel


class _PayWith(RequestModel):
    """Either a saved method, or a channel (plus the number to charge for
    mobile money)."""

    payment_method_id: uuid.UUID | None = Field(
        default=None, description="A saved method (GET /users/me/payment-methods)."
    )
    channel: PaymentChannel | None = None
    payer_phone_number: str | None = Field(default=None, max_length=20)

    @model_validator(mode="after")
    def _one_way_to_pay(self) -> _PayWith:
        if (self.payment_method_id is None) == (self.channel is None):
            raise ValueError("Send either payment_method_id or channel, not both.")
        if self.payment_method_id is not None and self.payer_phone_number is not None:
            raise ValueError("A saved method already has its number; leave it out.")
        return self


class PayBookingRequest(_PayWith):
    pass


class WalletTopupRequest(_PayWith):
    amount: Decimal = Field(..., gt=0, max_digits=12, decimal_places=2)


class PaymentMethodCreateRequest(RequestModel):
    channel: PaymentChannel = Field(
        ..., description="mtn_momo, telecel_cash or airteltigo_money: cards cannot be saved yet."
    )
    phone_number: str = Field(..., max_length=20, examples=["0241234567"])
    label: str | None = Field(default=None, max_length=60, examples=["My MTN"])
    is_default: bool = Field(
        default=False, description="The first method saved is the default regardless."
    )


class PaymentMethodUpdateRequest(RequestModel):
    label: str | None = Field(default=None, max_length=60)
    is_default: bool | None = Field(
        default=None,
        description="true makes this the default; to change the default, set it on the new one.",
    )


class PaymentMethodResponse(ApiModel):
    id: uuid.UUID
    channel: PaymentChannel
    masked_number: str = Field(..., examples=["+23324•••4567"])
    label: str | None
    is_default: bool
    created_at: datetime


class PaymentResponse(ApiModel):
    id: uuid.UUID
    booking_id: uuid.UUID | None
    purpose: PaymentPurpose
    channel: PaymentChannel
    status: PaymentStatus
    amount: Decimal
    currency: str
    refunded_amount: Decimal
    provider_reference: str | None
    failure_reason: str | None
    initiated_at: datetime | None
    completed_at: datetime | None
    created_at: datetime


class WalletResponse(ApiModel):
    balance: Decimal
    currency: str = "GHS"


class WalletTransactionResponse(ApiModel):
    id: uuid.UUID
    entry_type: WalletEntryType
    amount: Decimal
    balance_after: Decimal
    reference_type: WalletReferenceType
    reference_id: uuid.UUID | None
    description: str
    created_at: datetime


class RefundRequestResponse(ApiModel):
    id: uuid.UUID
    payment_id: uuid.UUID
    booking_id: uuid.UUID | None
    amount: Decimal
    reason: str | None
    status: RefundStatus
    reviewed_by: uuid.UUID | None
    reviewed_at: datetime | None
    decision_notes: str | None
    provider_refund_reference: str | None
    failure_reason: str | None
    created_at: datetime


class RefundDecisionRequest(RequestModel):
    notes: str | None = Field(default=None, max_length=1000)


class CancellationReviewRequest(RequestModel):
    approve: bool
    refund_eligible: bool = False
    notes: str | None = Field(default=None, max_length=1000)
