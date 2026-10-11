"""MTN Mobile Money (MoMo) Collections adapter.

Implements the publicly documented MTN MoMo Open API Collections product
(https://momodeveloper.mtn.com — "Collection" product): OAuth-style bearer
token exchange, Request-to-Pay (push-USSD collection), and status polling.
Works against MTN's sandbox as configured by default; the live environment
needs MTN's production credentials and ``PAYMENTS_MTN_MOMO_TARGET_ENVIRONMENT``
(``mtnghana`` for Ghana). ``scripts/momo_sandbox_setup.py`` makes the sandbox
API user and key; ``docs/deploy-render.md`` ("Payments: MTN MoMo sandbox")
has the whole setup.

Flow:

1. ``POST {base}/collection/token/`` with HTTP Basic auth
   (``PAYMENTS_MTN_MOMO_API_KEY`` : ``PAYMENTS_MTN_MOMO_API_SECRET``) and the
   ``Ocp-Apim-Subscription-Key`` header — returns a short-lived bearer token,
   kept until shortly before it expires.
2. ``POST {base}/collection/v1_0/requesttopay`` with ``X-Reference-Id``, which
   MTN requires to be a UUID: one made from our payment reference, so asking
   again for the same payment is the same request (MTN answers 409). Our
   reference goes as ``externalId``. With ``PAYMENTS_MTN_MOMO_CALLBACK_URL``
   set, ``X-Callback-Url`` asks MTN to post the outcome there. ``202
   Accepted``: the payer now has a prompt on their phone.
3. ``GET {base}/collection/v1_0/requesttopay/{referenceId}`` — returns
   ``{"status": "PENDING"|"SUCCESSFUL"|"FAILED", ...}``: the only status this
   backend acts on.

Callbacks: MTN doesn't sign the outcomes it posts, so their content is never
trusted. A callback names the payment (``externalId``); the payment service
then asks MTN for that payment's status (``trusts_webhook_status = False``)
and applies that. A forged callback can at most make it ask. Payments are
also confirmed by the reconciliation sweep, so they complete without
callbacks too.

Sandbox: MTN's sandbox accepts only EUR (``PAYMENTS_MTN_MOMO_CURRENCY=EUR``),
and a few test numbers give fixed outcomes; any other number is approved.

Refunds: the Collections product has no refund endpoint of its own — a real
MoMo refund is a *disbursement* (a transfer back to the customer), which
requires a separate Disbursements subscription this backend does not
provision. ``refund`` therefore raises :class:`ProviderError` rather than
fabricating a call against an endpoint this product doesn't expose; route
MoMo-funded refunds through manual disbursement or credit the passenger's
in-app wallet instead until that integration is scoped.
"""

from __future__ import annotations

import contextlib
import time
import uuid
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
from app.utilities.phone import InvalidPhoneNumberError, normalize_phone_number

logger = get_logger(__name__)

_STATUS_MAP = {
    "PENDING": PaymentProviderStatus.PENDING,
    "SUCCESSFUL": PaymentProviderStatus.SUCCESSFUL,
    "FAILED": PaymentProviderStatus.FAILED,
}
# Request-to-pay references, made from our own payment references: the same
# payment always gets the same one.
_REFERENCE_NAMESPACE = uuid.UUID("5c1c3f5e-8f4e-4c39-9f4b-9d5f3c6e0a11")

# Bearer tokens by (base URL, API user), shared by every adapter in the
# process: one is made per request that pays.
_tokens: dict[tuple[str, str], tuple[str, float]] = {}


def momo_reference(reference: str) -> str:
    """The X-Reference-Id (a UUID, as MTN requires) for our payment
    ``reference``."""
    return str(uuid.uuid5(_REFERENCE_NAMESPACE, reference))


def _msisdn(phone: str) -> str:
    """The payer's number as MTN wants it, international digits without the
    plus (233241234567). Numbers that aren't Ghanaian (the sandbox's test
    numbers) go as typed, digits only."""
    with contextlib.suppress(InvalidPhoneNumberError):
        phone = normalize_phone_number(phone)
    return "".join(ch for ch in phone if ch.isdigit())


class MtnMomoPaymentProvider:
    # A callback's content is not trusted: see the module docstring.
    trusts_webhook_status = False

    def __init__(
        self, settings: Settings, transport: httpx.AsyncBaseTransport | None = None
    ) -> None:
        self._base_url = settings.PAYMENTS_MTN_MOMO_BASE_URL.rstrip("/")
        self._api_user = settings.PAYMENTS_MTN_MOMO_API_KEY.get_secret_value()
        self._api_key = settings.PAYMENTS_MTN_MOMO_API_SECRET.get_secret_value()
        self._subscription_key = settings.PAYMENTS_MTN_MOMO_SUBSCRIPTION_KEY.get_secret_value()
        self._target_environment = settings.PAYMENTS_MTN_MOMO_TARGET_ENVIRONMENT
        self._currency = settings.PAYMENTS_MTN_MOMO_CURRENCY.strip().upper()
        self._callback_url = settings.PAYMENTS_MTN_MOMO_CALLBACK_URL.strip()
        self._transport = transport
        if not (self._base_url and self._api_user and self._api_key and self._subscription_key):
            raise ProviderError(
                "MTN MoMo provider selected but PAYMENTS_MTN_MOMO_BASE_URL / "
                "PAYMENTS_MTN_MOMO_API_KEY / PAYMENTS_MTN_MOMO_API_SECRET / "
                "PAYMENTS_MTN_MOMO_SUBSCRIPTION_KEY are not fully configured."
            )

    def _client(self) -> httpx.AsyncClient:
        return httpx.AsyncClient(timeout=15.0, transport=self._transport)

    async def _get_access_token(self, client: httpx.AsyncClient) -> str:
        key = (self._base_url, self._api_user)
        cached = _tokens.get(key)
        if cached is not None and time.monotonic() < cached[1]:
            return cached[0]
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
        expires_at = time.monotonic() + max(int(body.get("expires_in", 3600)) - 30, 0)
        _tokens[key] = (str(token), expires_at)
        return str(token)

    def _headers(self, token: str, *, reference: str | None = None) -> dict[str, str]:
        headers = {
            "Authorization": f"Bearer {token}",
            "X-Target-Environment": self._target_environment,
            "Ocp-Apim-Subscription-Key": self._subscription_key,
            "Content-Type": "application/json",
        }
        if reference is not None:
            headers["X-Reference-Id"] = reference
            if self._callback_url:
                headers["X-Callback-Url"] = self._callback_url
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
        momo_id = momo_reference(reference)
        async with self._client() as client:
            token = await self._get_access_token(client)
            try:
                response = await client.post(
                    f"{self._base_url}/collection/v1_0/requesttopay",
                    headers=self._headers(token, reference=momo_id),
                    json={
                        "amount": str(amount),
                        "currency": self._currency or currency,
                        "externalId": reference,
                        "payer": {"partyIdType": "MSISDN", "partyId": _msisdn(payer_phone)},
                        "payerMessage": narration[:160],
                        "payeeNote": narration[:160],
                    },
                )
            except httpx.HTTPError as exc:
                raise ProviderError("Failed to reach MTN MoMo request-to-pay endpoint.") from exc

        # 409: this payment was asked for already (a retry): still pending.
        if response.status_code not in (202, 409):
            logger.warning(
                "mtn_momo_requesttopay_rejected",
                status_code=response.status_code,
                reference=reference,
                detail=response.text[:300],
            )
            raise ProviderError(f"MTN MoMo rejected the request (HTTP {response.status_code}).")

        return PaymentInitResult(
            provider_reference=momo_id,
            status=PaymentProviderStatus.PENDING,
            instructions="Approve the payment prompt sent to your phone.",
        )

    async def query_payment(self, provider_reference: str) -> PaymentStatusResult:
        async with self._client() as client:
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
        """MTN signs nothing, so there is nothing to verify: every callback
        is accepted as a prompt to ask MTN, never believed itself."""
        return True

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
