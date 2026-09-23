"""Sandbox payment provider: never makes a network call.

Used for every channel (``PAYMENTS_ACTIVE_PROVIDER=sandbox``, the default)
in development and tests. Outcome is deterministic and controllable so tests
can exercise the full initiate -> webhook -> confirm/credit pipeline without
touching a real vendor:

* ``payer_phone`` ending in ``"0000"`` simulates a customer-declined payment
  (a common mobile-money sandbox convention) — ``initialize_payment`` still
  succeeds (the request was accepted), but the eventual status is ``FAILED``.
* Every other request lands in ``PENDING`` until the test calls
  :meth:`SandboxPaymentProvider.simulate_webhook_payload` (or
  :meth:`resolve`) to move it to its terminal state, mirroring how a real
  webhook arrives asynchronously after ``initialize_payment`` returns.

State is a class variable (like ``SandboxSmsProvider``) so a provider
instantiated inside a service and inspected from a test both see the same
in-memory ledger of sandbox payments without sharing an instance.
"""

from __future__ import annotations

import uuid
from collections.abc import Mapping
from dataclasses import dataclass
from decimal import Decimal
from typing import Any, ClassVar

from app.providers.payments.base import (
    PaymentInitResult,
    PaymentProviderStatus,
    PaymentStatusResult,
    RefundResult,
    WebhookEvent,
)

_DECLINE_SUFFIX = "0000"


@dataclass
class _SandboxPaymentRecord:
    reference: str
    amount: Decimal
    status: PaymentProviderStatus
    failure_reason: str | None = None


class SandboxPaymentProvider:
    _payments: ClassVar[dict[str, _SandboxPaymentRecord]] = {}

    async def initialize_payment(
        self,
        *,
        reference: str,
        amount: Decimal,
        currency: str,
        payer_phone: str | None,
        narration: str,
    ) -> PaymentInitResult:
        will_decline = payer_phone is not None and payer_phone.endswith(_DECLINE_SUFFIX)
        status = PaymentProviderStatus.FAILED if will_decline else PaymentProviderStatus.PENDING
        self._payments[reference] = _SandboxPaymentRecord(
            reference=reference,
            amount=amount,
            status=status,
            failure_reason="Customer declined the payment prompt." if will_decline else None,
        )
        return PaymentInitResult(
            provider_reference=reference,
            status=status,
            instructions="Approve the prompt sent to your phone (sandbox: instant).",
        )

    async def query_payment(self, provider_reference: str) -> PaymentStatusResult:
        record = self._payments.get(provider_reference)
        if record is None:
            return PaymentStatusResult(
                provider_reference=provider_reference,
                status=PaymentProviderStatus.FAILED,
                failure_reason="Unknown sandbox payment reference.",
            )
        return PaymentStatusResult(
            provider_reference=provider_reference,
            status=record.status,
            failure_reason=record.failure_reason,
        )

    async def refund(
        self, *, provider_reference: str, amount: Decimal, reason: str
    ) -> RefundResult:
        if provider_reference not in self._payments:
            return RefundResult(success=False, error="Unknown sandbox payment reference.")
        return RefundResult(
            success=True, provider_refund_reference=f"sandbox-refund-{uuid.uuid4().hex[:12]}"
        )

    def verify_webhook_signature(self, headers: Mapping[str, str], raw_body: bytes) -> bool:
        # The sandbox never receives a real inbound webhook over the network
        # (tests call `process_webhook` directly with a synthesized payload),
        # so there is no external caller to authenticate.
        return True

    def parse_webhook_event(
        self, headers: Mapping[str, str], payload: dict[str, Any]
    ) -> WebhookEvent:
        status = PaymentProviderStatus(payload["status"])
        return WebhookEvent(
            provider_reference=str(payload["reference"]),
            status=status,
            failure_reason=payload.get("failure_reason"),
        )

    # ------------------------------------------------------------------
    # Test/dev helpers
    # ------------------------------------------------------------------
    @classmethod
    def resolve(
        cls, reference: str, status: PaymentProviderStatus, *, failure_reason: str | None = None
    ) -> None:
        """Move a pending sandbox payment to a terminal state."""
        record = cls._payments.get(reference)
        if record is not None:
            record.status = status
            record.failure_reason = failure_reason

    @classmethod
    def simulate_webhook_payload(
        cls,
        reference: str,
        status: PaymentProviderStatus,
        *,
        failure_reason: str | None = None,
    ) -> dict[str, Any]:
        """Builds the JSON body a real webhook delivery for this event would
        carry, and records the corresponding terminal state — for tests
        exercising ``PaymentService.process_webhook`` end-to-end."""
        cls.resolve(reference, status, failure_reason=failure_reason)
        return {"reference": reference, "status": status.value, "failure_reason": failure_reason}

    @classmethod
    def clear(cls) -> None:
        cls._payments.clear()
