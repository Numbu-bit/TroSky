"""MTN Mobile Money (MoMo) Collections adapter.

Implements the publicly documented MTN MoMo Open API Collections product
(https://momodeveloper.mtn.com — "Collection" product): OAuth-style bearer
token exchange, Request-to-Pay (push-USSD collection), and status polling.
Genuinely production-ready once real subscription/API-user credentials are
supplied — this makes no assumptions beyond that documented contract, same
as ``TwilioSmsProvider``.

Flow:

1. ``POST {base}/collection/token/`` with HTTP Basic auth
   (``PAYMENTS_MTN_MOMO_API_KEY`` : ``PAYMENTS_MTN_MOMO_API_SECRET``) and the
   ``Ocp-Apim-Subscription-Key`` header — returns a short-lived bearer token.
2. ``POST {base}/collection/v1_0/requesttopay`` with ``X-Reference-Id`` (our
   own reference, becomes the payment's identity for every later lookup) —
   returns ``202 Accepted`` with no body; the request is now pending
   customer approval on their phone.
3. ``GET {base}/collection/v1_0/requesttopay/{referenceId}`` — returns
   ``{"status": "PENDING"|"SUCCESSFUL"|"FAILED", ...}``, used both for
   webhook-triggered confirmation and for the reconciliation poll.

Refunds: the Collections product has no refund endpoint of its own — a real
MoMo refund is a *disbursement* (a transfer back to the customer), which
requires a separate Disbursements subscription this backend does not
provision. ``refund`` therefore raises :class:`ProviderError` rather than
fabricating a call against an endpoint this product doesn't expose; route
MoMo-funded refunds through manual disbursement or credit the passenger's
in-app wallet instead until that integration is scoped.

Webhook authentication: MTN's callback-host registration does not sign each
delivery with a per-payload HMAC (unlike, say, Stripe) — the merchant's
registered callback URL is itself the trust boundary, conventionally
protected by a bearer token issued at registration time. This adapter
verifies that shared secret (``PAYMENTS_WEBHOOK_SIGNING_SECRET``) via the
``Authorization`` header rather than inventing a signing scheme MTN doesn't
actually implement.
"""

from __future__ import annotations

import hmac
import time
from collections.abc import Mapping
from decimal import Decimal
from typing import Any

import httpx

from app.core.config import Settings
from app.core.exceptions import ProviderError
from app.core.logging import get_logger
from app.providers.payments.base import (
    PaymentInitResult,
    PaymentProviderStatus,
    PaymentStatusResult,
    RefundResult,
    WebhookEvent,
)

logger = get_logger(__name__)

_STATUS_MAP = {
    "PENDING": PaymentProviderStatus.PENDING,
    "SUCCESSFUL": PaymentProviderStatus.SUCCESSFUL,
    "FAILED": PaymentProviderStatus.FAILED,
}


class MtnMomoPaymentProvider:
    def __init__(self, settings: Settings) -> None:
        self._base_url = settings.PAYMENTS_MTN_MOMO_BASE_URL.rstrip("/")
        self._api_user = settings.PAYMENTS_MTN_MOMO_API_KEY.get_secret_value()
        self._api_key = settings.PAYMENTS_MTN_MOMO_API_SECRET.get_secret_value()
        self._subscription_key = settings.PAYMENTS_MTN_MOMO_SUBSCRIPTION_KEY.get_secret_value()
        self._target_environment = "sandbox" if not settings.is_production else "production"
        self._webhook_secret = settings.PAYMENTS_WEBHOOK_SIGNING_SECRET.get_secret_value()
        if not (self._base_url and self._api_user and self._api_key and self._subscription_key):
            raise ProviderError(
                "MTN MoMo provider selected but PAYMENTS_MTN_MOMO_BASE_URL / "
                "PAYMENTS_MTN_MOMO_API_KEY / PAYMENTS_MTN_MOMO_API_SECRET / "
                "PAYMENTS_MTN_MOMO_SUBSCRIPTION_KEY are not fully configured."
            )
        self._token: str | None = None
        self._token_expires_at: float = 0.0

    async def _get_access_token(self, client: httpx.AsyncClient) -> str:
        if self._token is not None and time.monotonic() < self._token_expires_at:
            return self._token
        try:
            response = await client.post(
                f"{self._base_url}/collection/token/",
                auth=(self._api_user, self._api_key),
                headers={"Ocp-Apim-Subscription-Key": self._subscription_key},
            )
        except httpx.HTTPError as exc:
            raise ProviderError("Failed to reach the MTN MoMo authentication endpoint.") from exc
        if response.status_code >= 400:
            raise ProviderError(f"MTN MoMo token request failed with HTTP {response.status_code}.")
        body = response.json()
        token = body.get("access_token")
        if not token:
            raise ProviderError("MTN MoMo token response did not include an access_token.")
        # Refresh a little early rather than racing the vendor's own expiry.
        self._token_expires_at = time.monotonic() + max(int(body.get("expires_in", 3600)) - 30, 0)
        self._token = str(token)
        return self._token

    def _headers(self, token: str, *, reference: str | None = None) -> dict[str, str]:
        headers = {
            "Authorization": f"Bearer {token}",
            "X-Target-Environment": self._target_environment,
            "Ocp-Apim-Subscription-Key": self._subscription_key,
            "Content-Type": "application/json",
        }
        if reference is not None:
            headers["X-Reference-Id"] = reference
        return headers

    async def initialize_payment(
        self,
        *,
        reference: str,
        amount: Decimal,
        currency: str,
        payer_phone: str | None,
        narration: str,
    ) -> PaymentInitResult:
        if not payer_phone:
            raise ProviderError("MTN MoMo requires the payer's MSISDN (payer_phone).")
        async with httpx.AsyncClient(timeout=15.0) as client:
            token = await self._get_access_token(client)
            try:
                response = await client.post(
                    f"{self._base_url}/collection/v1_0/requesttopay",
                    headers=self._headers(token, reference=reference),
                    json={
                        "amount": str(amount),
                        "currency": currency,
                        "externalId": reference,
                        "payer": {
                            "partyIdType": "MSISDN",
                            "partyId": payer_phone.lstrip("+"),
                        },
                        "payerMessage": narration[:160],
                        "payeeNote": narration[:160],
                    },
                )
            except httpx.HTTPError as exc:
                raise ProviderError("Failed to reach MTN MoMo request-to-pay endpoint.") from exc

        if response.status_code != 202:
            logger.warning(
                "mtn_momo_requesttopay_rejected",
                status_code=response.status_code,
                reference=reference,
            )
            raise ProviderError(f"MTN MoMo rejected the request (HTTP {response.status_code}).")

        return PaymentInitResult(
            provider_reference=reference,
            status=PaymentProviderStatus.PENDING,
            instructions="Approve the payment prompt sent to your phone.",
        )

    async def query_payment(self, provider_reference: str) -> PaymentStatusResult:
        async with httpx.AsyncClient(timeout=15.0) as client:
            token = await self._get_access_token(client)
            try:
                response = await client.get(
                    f"{self._base_url}/collection/v1_0/requesttopay/{provider_reference}",
                    headers=self._headers(token),
                )
            except httpx.HTTPError as exc:
                raise ProviderError("Failed to reach MTN MoMo status endpoint.") from exc

        if response.status_code >= 400:
            raise ProviderError(f"MTN MoMo status query failed (HTTP {response.status_code}).")

        body = response.json()
        raw_status = str(body.get("status", "")).upper()
        status = _STATUS_MAP.get(raw_status, PaymentProviderStatus.PENDING)
        failure_reason = None
        if status is PaymentProviderStatus.FAILED:
            reason = body.get("reason")
            failure_reason = (
                reason.get("message") if isinstance(reason, dict) else str(reason or "Declined")
            )
        return PaymentStatusResult(
            provider_reference=provider_reference,
            status=status,
            failure_reason=failure_reason,
            raw=body,
        )

    async def refund(
        self, *, provider_reference: str, amount: Decimal, reason: str
    ) -> RefundResult:
        raise ProviderError(
            "MTN MoMo Collections has no refund endpoint — a real refund requires the "
            "Disbursements product (a separate subscription/credential set) which is not "
            "configured. Process this refund via manual disbursement or the passenger's "
            "in-app wallet instead."
        )

    def verify_webhook_signature(self, headers: Mapping[str, str], raw_body: bytes) -> bool:
        provided = headers.get("authorization") or headers.get("Authorization") or ""
        expected = f"Bearer {self._webhook_secret}"
        return hmac.compare_digest(provided, expected)

    def parse_webhook_event(
        self, headers: Mapping[str, str], payload: dict[str, Any]
    ) -> WebhookEvent:
        raw_status = str(payload.get("status", "")).upper()
        status = _STATUS_MAP.get(raw_status, PaymentProviderStatus.PENDING)
        reference = str(payload.get("externalId") or payload.get("referenceId") or "")
        failure_reason = None
        if status is PaymentProviderStatus.FAILED:
            reason = payload.get("reason")
            failure_reason = (
                reason.get("message") if isinstance(reason, dict) else str(reason or "Declined")
            )
        return WebhookEvent(
            provider_reference=reference, status=status, failure_reason=failure_reason, raw=payload
        )
