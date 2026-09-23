"""Configuration-ready skeleton for payment channels whose vendor API this
codebase has not verified against current documentation.

Telecel Cash (formerly Vodafone Cash) and AirtelTigo Money are
telco-operated mobile-money products whose merchant-collection API contracts
are not consistently public and typically require a signed commercial
agreement to access; a generic card-gateway integration likewise depends on
which specific processor is contracted. Fabricating request/response shapes
for any of them would mean shipping "payment logic" that has never been
checked against a real contract — exactly the kind of fake implementation
this project does not ship (see ``HubtelSmsProvider`` for the same policy
applied to SMS).

Every method raises :class:`ProviderError` with a pointer to what's needed
before the channel can go live; the domain model, migration, repository,
service, API routes, webhook pipeline, and wallet ledger are all fully
implemented and channel-agnostic, so wiring in a real adapter later is a
matter of implementing this class's four methods against verified vendor
docs and swapping it in via ``app.providers.payments.factory`` — no other
code changes.
"""

from __future__ import annotations

from collections.abc import Mapping
from decimal import Decimal
from typing import Any

from app.core.exceptions import ProviderError
from app.providers.payments.base import (
    PaymentInitResult,
    PaymentStatusResult,
    RefundResult,
    WebhookEvent,
)


class UnavailablePaymentProvider:
    def __init__(self, channel_label: str, docs_hint: str) -> None:
        self._channel_label = channel_label
        self._docs_hint = docs_hint

    def _unavailable(self) -> ProviderError:
        return ProviderError(
            f"{self._channel_label} is not yet integrated in this deployment — its "
            f"request/response contract has not been verified against current vendor "
            f"documentation ({self._docs_hint}). Implement and verify a real adapter "
            f"before selecting this channel outside PAYMENTS_ACTIVE_PROVIDER=sandbox."
        )

    async def initialize_payment(
        self,
        *,
        reference: str,
        amount: Decimal,
        currency: str,
        payer_phone: str | None,
        narration: str,
    ) -> PaymentInitResult:
        raise self._unavailable()

    async def query_payment(self, provider_reference: str) -> PaymentStatusResult:
        raise self._unavailable()

    async def refund(
        self, *, provider_reference: str, amount: Decimal, reason: str
    ) -> RefundResult:
        raise self._unavailable()

    def verify_webhook_signature(self, headers: Mapping[str, str], raw_body: bytes) -> bool:
        return False

    def parse_webhook_event(
        self, headers: Mapping[str, str], payload: dict[str, Any]
    ) -> WebhookEvent:
        raise self._unavailable()
