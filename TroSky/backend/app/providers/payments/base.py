"""Payment provider interface.

Every payment channel (MTN MoMo, Telecel Cash, AirtelTigo Money, card
gateway) is accessed through this single interface — services never talk to
a vendor SDK/HTTP API directly, and never trust a client-submitted
"payment succeeded" flag. The wallet channel is deliberately *not* modeled
here: it never leaves our own database, so ``PaymentService`` handles it
directly via ``WalletService`` rather than forcing an artificial
initialize/webhook round trip onto an operation that is really just a
row-locked balance mutation.

Every method must translate vendor-specific failure shapes into either a
non-raising result object (an expected, business-level failure — e.g. the
customer declined the USSD prompt) or :class:`app.core.exceptions.ProviderError`
(a transport/vendor-outage failure the caller cannot otherwise interpret).
Never let a raw vendor SDK exception escape a provider adapter.
"""

from __future__ import annotations

from collections.abc import Mapping
from dataclasses import dataclass, field
from decimal import Decimal
from enum import StrEnum
from typing import Any, Protocol


class PaymentChannel(StrEnum):
    MTN_MOMO = "mtn_momo"
    TELECEL_CASH = "telecel_cash"
    AIRTELTIGO_MONEY = "airteltigo_money"
    CARD = "card"
    WALLET = "wallet"


class PaymentProviderStatus(StrEnum):
    """Coarse, provider-facing status. ``app.models.payments.PaymentStatus``
    is the richer domain status (which also covers refund states) that
    services derive from this."""

    PENDING = "pending"
    SUCCESSFUL = "successful"
    FAILED = "failed"


@dataclass(frozen=True, slots=True)
class PaymentInitResult:
    provider_reference: str
    status: PaymentProviderStatus
    instructions: str | None = None
    raw: dict[str, Any] = field(default_factory=dict)


@dataclass(frozen=True, slots=True)
class PaymentStatusResult:
    provider_reference: str
    status: PaymentProviderStatus
    failure_reason: str | None = None
    raw: dict[str, Any] = field(default_factory=dict)


@dataclass(frozen=True, slots=True)
class RefundResult:
    success: bool
    provider_refund_reference: str | None = None
    error: str | None = None


@dataclass(frozen=True, slots=True)
class WebhookEvent:
    """A normalized inbound webhook notification.

    ``provider_reference`` correlates back to the reference this backend
    generated at ``initialize_payment`` time (``Payment.internal_reference``).
    """

    provider_reference: str
    status: PaymentProviderStatus
    failure_reason: str | None = None
    raw: dict[str, Any] = field(default_factory=dict)


class PaymentProvider(Protocol):
    """Interface every non-wallet payment channel adapter implements."""

    async def initialize_payment(
        self,
        *,
        reference: str,
        amount: Decimal,
        currency: str,
        payer_phone: str | None,
        narration: str,
    ) -> PaymentInitResult:
        """Start a payment. ``reference`` is our own idempotent reference
        (used as the vendor's external/reference id where supported) — the
        caller has already persisted a ``Payment`` row before calling this."""
        ...

    async def query_payment(self, provider_reference: str) -> PaymentStatusResult:
        """Poll the current status directly from the provider — the
        reconciliation fallback for a lost or delayed webhook."""
        ...

    async def refund(
        self, *, provider_reference: str, amount: Decimal, reason: str
    ) -> RefundResult:
        """Refund (all or part of) a previously successful payment."""
        ...

    def verify_webhook_signature(self, headers: Mapping[str, str], raw_body: bytes) -> bool:
        """Verify an inbound webhook actually originated from this provider
        before any of its contents are trusted."""
        ...

    def parse_webhook_event(
        self, headers: Mapping[str, str], payload: dict[str, Any]
    ) -> WebhookEvent:
        """Extract a normalized :class:`WebhookEvent` from an
        already-signature-verified webhook payload."""
        ...
