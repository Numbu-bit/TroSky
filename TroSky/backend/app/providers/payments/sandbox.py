"""Sandbox payment provider: never makes a network call.

Used for every channel (``PAYMENTS_ACTIVE_PROVIDER=sandbox``, the default)
in development, tests and staging. The outcome depends on the payer number:

* ending in ``"0000"``: the customer declines -- ``initialize_payment``
  succeeds (the request was accepted) and the first status check says
  ``FAILED``, as a real provider's answer arrives after the request;
* ending in ``"9999"``: nobody answers -- the payment stays ``PENDING``
  (for testing what the app does when a prompt is never approved);
* any other number: approved ``auto_approve_seconds`` after it started
  (``PAYMENTS_SANDBOX_AUTO_APPROVE_SECONDS``, 5 by default), or only when a
  test calls :meth:`SandboxPaymentProvider.resolve` /
  :meth:`simulate_webhook_payload` when that is ``None``. The factory
  passes ``None`` in production, so a sandbox payment there never succeeds.

The state travels in the provider reference itself (``SANDBOX:<outcome>:
<started epoch>:<internal reference>``), which the payment service stores
on the ``payments`` row. Any process -- the API, the Celery worker, a server
woken from sleep -- reads the same answer from it; nothing lives only in
one process's memory.

A class-level ledger remains for the test helpers: :meth:`resolve`
overrides the outcome of a payment, and plain references (not made here)
are answered from it as before.
"""

from __future__ import annotations

import uuid
from collections.abc import Callable, Mapping
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
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
_NO_ANSWER_SUFFIX = "9999"
_DECLINED = "Customer declined the payment prompt."

_PREFIX = "SANDBOX"
_APPROVE = "approve"
_DECLINE = "decline"
_NO_ANSWER = "silent"


def _encode(reference: str, outcome: str, started: datetime) -> str:
    return f"{_PREFIX}:{outcome}:{int(started.timestamp())}:{reference}"


def _decode(provider_reference: str) -> tuple[str, str, datetime] | None:
    """``(internal reference, outcome, started)``, or None for a reference
    this provider didn't make."""
    parts = provider_reference.split(":", 3)
    if len(parts) != 4 or parts[0] != _PREFIX:
        return None
    _, outcome, started, reference = parts
    if outcome not in (_APPROVE, _DECLINE, _NO_ANSWER) or not started.isdigit():
        return None
    return reference, outcome, datetime.fromtimestamp(int(started), UTC)


def _now() -> datetime:
    return datetime.now(UTC)


@dataclass
class _SandboxPaymentRecord:
    reference: str
    amount: Decimal
    status: PaymentProviderStatus
    failure_reason: str | None = None


class SandboxPaymentProvider:
    _payments: ClassVar[dict[str, _SandboxPaymentRecord]] = {}

    def __init__(
        self,
        *,
        auto_approve_seconds: int | None = None,
        clock: Callable[[], datetime] = _now,
    ) -> None:
        self._auto_approve_seconds = auto_approve_seconds
        self._clock = clock

    async def initialize_payment(
        self,
        *,
        reference: str,
        amount: Decimal,
        currency: str,
        payer_phone: str | None,
        narration: str,
    ) -> PaymentInitResult:
        phone = payer_phone or ""
        outcome = (
            _DECLINE
            if phone.endswith(_DECLINE_SUFFIX)
            else _NO_ANSWER
            if phone.endswith(_NO_ANSWER_SUFFIX)
            else _APPROVE
        )
        # A decline arrives later, as from a real provider: the first status
        # check says so, and the payment service puts the booking back to
        # be paid again.
        self._payments[reference] = _SandboxPaymentRecord(
            reference=reference,
            amount=amount,
            status=PaymentProviderStatus.FAILED
            if outcome == _DECLINE
            else PaymentProviderStatus.PENDING,
            failure_reason=_DECLINED if outcome == _DECLINE else None,
        )
        return PaymentInitResult(
            provider_reference=_encode(reference, outcome, self._clock()),
            status=PaymentProviderStatus.PENDING,
            instructions="Approve the prompt sent to your phone (sandbox: approved on its own).",
        )

    async def query_payment(self, provider_reference: str) -> PaymentStatusResult:
        decoded = _decode(provider_reference)
        reference = decoded[0] if decoded is not None else provider_reference
        record = self._payments.get(reference)
        # A test's resolve() wins; a plain reference has only the ledger.
        if record is not None and (
            decoded is None or record.status != PaymentProviderStatus.PENDING
        ):
            return PaymentStatusResult(
                provider_reference=provider_reference,
                status=record.status,
                failure_reason=record.failure_reason,
            )
        if decoded is None:
            return PaymentStatusResult(
                provider_reference=provider_reference,
                status=PaymentProviderStatus.FAILED,
                failure_reason="Unknown sandbox payment reference.",
            )
        _, outcome, started = decoded
        if outcome == _DECLINE:
            return PaymentStatusResult(
                provider_reference=provider_reference,
                status=PaymentProviderStatus.FAILED,
                failure_reason=_DECLINED,
            )
        due = (
            outcome == _APPROVE
            and self._auto_approve_seconds is not None
            and self._clock() - started >= timedelta(seconds=self._auto_approve_seconds)
        )
        return PaymentStatusResult(
            provider_reference=provider_reference,
            status=PaymentProviderStatus.SUCCESSFUL if due else PaymentProviderStatus.PENDING,
        )

    async def refund(
        self, *, provider_reference: str, amount: Decimal, reason: str
    ) -> RefundResult:
        if _decode(provider_reference) is None and provider_reference not in self._payments:
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
