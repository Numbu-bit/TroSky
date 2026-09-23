"""Request/response schemas for payments, wallet, and refunds."""

from __future__ import annotations

import uuid
from datetime import datetime
from decimal import Decimal

from pydantic import Field

from app.models.payments import (
    PaymentPurpose,
    PaymentStatus,
    RefundStatus,
    WalletEntryType,
    WalletReferenceType,
)
from app.providers.payments.base import PaymentChannel
from app.schemas.common import ApiModel, RequestModel


class PayBookingRequest(RequestModel):
    channel: PaymentChannel
    payer_phone_number: str | None = Field(default=None, max_length=20)


class WalletTopupRequest(RequestModel):
    amount: Decimal = Field(..., gt=0, max_digits=12, decimal_places=2)
    channel: PaymentChannel
    payer_phone_number: str | None = Field(default=None, max_length=20)


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
