"""Production SMS adapters.

``TwilioSmsProvider`` calls Twilio's stable, publicly documented REST API
(https://www.twilio.com/docs/sms/api) and is genuinely production-ready once
credentials are supplied — it makes no assumptions beyond that documented
contract.

``HubtelSmsProvider`` is a **configuration-ready skeleton**, not a finished
integration: Hubtel's SMS API request/response shape must be confirmed
against https://developers.hubtel.com (current account-specific base URL,
auth scheme, and payload fields) before this class sends anything. Calling
it without that confirmation raises :class:`ProviderError` rather than
silently emitting a best-guess request — this codebase does not invent
undocumented vendor endpoints.
"""

from __future__ import annotations

import httpx

from app.core.config import Settings
from app.core.exceptions import ProviderError
from app.core.logging import get_logger
from app.providers.sms.base import SmsSendResult

logger = get_logger(__name__)


class TwilioSmsProvider:
    """Twilio SMS adapter.

    # PRODUCTION CREDENTIALS REQUIRED
    Configure ``PAYMENTS_*``-style env vars is not applicable here — this
    reads ``SMS_API_KEY`` (Account SID), ``SMS_API_SECRET`` (Auth Token),
    and ``SMS_SENDER_ID`` (a Twilio-verified sending number) from settings.
    See https://www.twilio.com/docs/sms/api for the account setup, sender
    verification, and messaging-service configuration steps required before
    this adapter can send in production.
    """

    _API_BASE = "https://api.twilio.com/2010-04-01"

    def __init__(self, settings: Settings) -> None:
        self._account_sid = settings.SMS_API_KEY.get_secret_value()
        self._auth_token = settings.SMS_API_SECRET.get_secret_value()
        self._from_number = settings.SMS_SENDER_ID
        if not (self._account_sid and self._auth_token and self._from_number):
            raise ProviderError(
                "Twilio SMS provider selected but SMS_API_KEY / SMS_API_SECRET / "
                "SMS_SENDER_ID are not fully configured."
            )

    async def send_sms(self, to: str, message: str) -> SmsSendResult:
        url = f"{self._API_BASE}/Accounts/{self._account_sid}/Messages.json"
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                response = await client.post(
                    url,
                    auth=(self._account_sid, self._auth_token),
                    data={"To": to, "From": self._from_number, "Body": message},
                )
        except httpx.HTTPError as exc:
            logger.error("twilio_sms_transport_error", error=str(exc))
            raise ProviderError("Failed to reach the SMS provider.") from exc

        if response.status_code >= 400:
            logger.warning("twilio_sms_send_failed", status_code=response.status_code, to=to)
            return SmsSendResult(
                success=False,
                provider_reference=None,
                error=f"Twilio returned HTTP {response.status_code}",
            )

        body = response.json()
        return SmsSendResult(success=True, provider_reference=body.get("sid"))


class HubtelSmsProvider:
    """Hubtel SMS adapter skeleton.

    # PRODUCTION CREDENTIALS REQUIRED
    Confirm the current request/response contract at
    https://developers.hubtel.com before enabling this provider — the base
    URL, authentication scheme, and payload field names below are
    configuration placeholders (``SMS_BASE_URL``, ``SMS_API_KEY``,
    ``SMS_API_SECRET``), not a verified integration.
    """

    def __init__(self, settings: Settings) -> None:
        self._base_url = settings.SMS_BASE_URL
        self._api_key = settings.SMS_API_KEY.get_secret_value()
        self._api_secret = settings.SMS_API_SECRET.get_secret_value()

    async def send_sms(self, to: str, message: str) -> SmsSendResult:
        raise ProviderError(
            "Hubtel SMS integration is not yet confirmed against current provider "
            "documentation (https://developers.hubtel.com). Configure and verify "
            "the request contract, implement it in HubtelSmsProvider.send_sms, "
            "and remove this guard before enabling SMS_PROVIDER=hubtel in production."
        )
