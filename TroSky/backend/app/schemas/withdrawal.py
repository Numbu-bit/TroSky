"""Request/response schemas for wallet withdrawals."""

from __future__ import annotations

import uuid
from datetime import datetime
from decimal import Decimal

from pydantic import Field

from app.models.payments import WithdrawalStatus
from app.providers.payments.base import PaymentChannel
from app.schemas.common import ApiModel, RequestModel


class RequestWithdrawalRequest(RequestModel):
    amount: Decimal = Field(..., gt=0, max_digits=12, decimal_places=2)
    channel: PaymentChannel
    destination_phone_number: str = Field(..., min_length=1, max_length=20)


class WithdrawalResponse(ApiModel):
    id: uuid.UUID
    user_id: uuid.UUID
    amount: Decimal
    channel: PaymentChannel
    destination_phone_number: str
    status: WithdrawalStatus
    reviewed_by: uuid.UUID | None
    reviewed_at: datetime | None
    decision_notes: str | None
    provider_reference: str | None
    failure_reason: str | None
    created_at: datetime


class WithdrawalDecisionRequest(RequestModel):
    notes: str | None = Field(default=None, max_length=1000)


class CompleteWithdrawalRequest(RequestModel):
    provider_reference: str | None = Field(default=None, max_length=100)


class FailWithdrawalRequest(RequestModel):
    reason: str = Field(..., min_length=1, max_length=500)
