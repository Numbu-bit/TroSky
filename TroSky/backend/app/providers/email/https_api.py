"""Email through an HTTPS API rather than SMTP: Brevo or Resend.

Some hosts block outgoing SMTP (Render's free plan blocks ports 25, 465 and
587), so the SMTP provider can't reach a mail server from there. These send
the same message with one HTTPS request each. Both services have a free
tier; the sender (``EMAIL_FROM_ADDRESS``) must first be verified with them:
on Brevo, a single address is enough; Resend wants a domain.

* Brevo: ``POST https://api.brevo.com/v3/smtp/email`` with the ``api-key``
  header (https://developers.brevo.com/reference/sendtransacemail).
* Resend: ``POST https://api.resend.com/emails`` with a bearer token
  (https://resend.com/docs/api-reference/emails/send-email).

A refusal (a bad key, an unverified sender, a quota reached) comes back as a
failed :class:`EmailSendResult` carrying the service's own message, as the
interface asks; the key itself is never logged.
"""

from __future__ import annotations

from typing import Any

import httpx

from app.core.config import Settings
from app.core.logging import get_logger
from app.providers.email.base import EmailSendResult

logger = get_logger(__name__)

_TIMEOUT_SECONDS = 15.0


class _HttpsApiEmailProvider:
    name: str
    url: str

    def __init__(
        self, settings: Settings, transport: httpx.AsyncBaseTransport | None = None
    ) -> None:
        self._api_key = settings.EMAIL_API_KEY.get_secret_value()
        self._from_address = settings.EMAIL_FROM_ADDRESS
        self._from_name = settings.EMAIL_FROM_NAME
        self._transport = transport

    def _headers(self) -> dict[str, str]:
        raise NotImplementedError

    def _payload(
        self, to: str, subject: str, body_text: str, body_html: str | None
    ) -> dict[str, Any]:
        raise NotImplementedError

    def _reference(self, body: dict[str, Any]) -> str | None:
        raise NotImplementedError

    async def send_email(
        self, to: str, subject: str, body_text: str, body_html: str | None = None
    ) -> EmailSendResult:
        try:
            async with httpx.AsyncClient(
                timeout=_TIMEOUT_SECONDS, transport=self._transport
            ) as client:
                response = await client.post(
                    self.url,
                    headers=self._headers(),
                    json=self._payload(to, subject, body_text, body_html),
                )
        except httpx.HTTPError as exc:
            logger.warning("email_api_unreachable", provider=self.name, error=type(exc).__name__)
            return EmailSendResult(
                success=False, provider_reference=None, error=f"{self.name} unreachable"
            )
        if response.is_success:
            return EmailSendResult(
                success=True, provider_reference=self._reference(_json(response))
            )
        message = str(_json(response).get("message") or response.reason_phrase)
        logger.warning(
            "email_api_refused",
            provider=self.name,
            status_code=response.status_code,
            message=message,
        )
        return EmailSendResult(
            success=False,
            provider_reference=None,
            error=f"{self.name} refused it (HTTP {response.status_code}): {message}",
        )


class BrevoEmailProvider(_HttpsApiEmailProvider):
    name = "Brevo"
    url = "https://api.brevo.com/v3/smtp/email"

    def _headers(self) -> dict[str, str]:
        return {"api-key": self._api_key, "accept": "application/json"}

    def _payload(
        self, to: str, subject: str, body_text: str, body_html: str | None
    ) -> dict[str, Any]:
        payload: dict[str, Any] = {
            "sender": {"name": self._from_name, "email": self._from_address},
            "to": [{"email": to}],
            "subject": subject,
            "textContent": body_text,
        }
        if body_html:
            payload["htmlContent"] = body_html
        return payload

    def _reference(self, body: dict[str, Any]) -> str | None:
        reference = body.get("messageId")
        return str(reference) if reference else None


class ResendEmailProvider(_HttpsApiEmailProvider):
    name = "Resend"
    url = "https://api.resend.com/emails"

    def _headers(self) -> dict[str, str]:
        return {"Authorization": f"Bearer {self._api_key}"}

    def _payload(
        self, to: str, subject: str, body_text: str, body_html: str | None
    ) -> dict[str, Any]:
        payload: dict[str, Any] = {
            "from": f"{self._from_name} <{self._from_address}>",
            "to": [to],
            "subject": subject,
            "text": body_text,
        }
        if body_html:
            payload["html"] = body_html
        return payload

    def _reference(self, body: dict[str, Any]) -> str | None:
        reference = body.get("id")
        return str(reference) if reference else None


def _json(response: httpx.Response) -> dict[str, Any]:
    try:
        body = response.json()
    except ValueError:
        return {}
    return body if isinstance(body, dict) else {}
