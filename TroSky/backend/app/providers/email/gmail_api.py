"""Email through Gmail's own HTTPS API, sent as TroSky's Gmail account.

Render's free plan blocks SMTP, and a Gmail address used as a Brevo sender
goes out under an address of Brevo's own, more often into spam (Gmail's
sender rules of February 2024). Gmail's API sends over HTTPS as the Gmail
account itself, so a code arrives as an ordinary Gmail message. It's free,
within Gmail's daily sending limit, and needs no domain of our own.

Access is by OAuth: a Google Cloud OAuth client (``GMAIL_CLIENT_ID``,
``GMAIL_CLIENT_SECRET``) and the sending account's refresh token
(``GMAIL_REFRESH_TOKEN``), made once with ``scripts/gmail_refresh_token.py``.
A send trades the refresh token for an access token, kept until a minute
before it expires, and posts the message:

* ``POST https://oauth2.googleapis.com/token``
  (https://developers.google.com/identity/protocols/oauth2/native-app)
* ``POST https://gmail.googleapis.com/gmail/v1/users/me/messages/send``
  (https://developers.google.com/gmail/api/reference/rest/v1/users.messages/send)

Mail goes out from the account the refresh token belongs to, so
``EMAIL_FROM_ADDRESS`` should be that address (Gmail puts the account's own
address in place of any other). A refusal comes back as a failed
:class:`EmailSendResult` with Google's reason, as the interface asks; the
tokens and the client secret are never logged.
"""

from __future__ import annotations

import base64
import hashlib
import time
from collections.abc import Callable
from email.message import EmailMessage
from email.utils import formataddr, parseaddr
from typing import Any

import httpx

from app.core.config import Settings
from app.core.logging import get_logger
from app.providers.email.base import EmailSendResult

logger = get_logger(__name__)

TOKEN_URL = "https://oauth2.googleapis.com/token"  # noqa: S105 - a URL, not a password
SEND_URL = "https://gmail.googleapis.com/gmail/v1/users/me/messages/send"

_TIMEOUT_SECONDS = 15.0
_EXPIRY_MARGIN_SECONDS = 60.0

# Access tokens, by client and refresh token. A provider is made for each
# request, so the token has to outlive it; each one lasts about an hour.
_access_tokens: dict[str, tuple[str, float]] = {}


class _TokenRefusedError(Exception):
    def __init__(self, status_code: int, reason: str) -> None:
        super().__init__(reason)
        self.status_code = status_code
        self.reason = reason


class GmailApiEmailProvider:
    name = "Gmail"

    def __init__(
        self,
        *,
        client_id: str,
        client_secret: str,
        refresh_token: str,
        sender: str,
        transport: httpx.AsyncBaseTransport | None = None,
        clock: Callable[[], float] = time.monotonic,
    ) -> None:
        self._client_id = client_id
        self._client_secret = client_secret
        self._refresh_token = refresh_token
        self._sender = sender
        self._transport = transport
        self._clock = clock
        self._cache_key = hashlib.sha256(f"{client_id}\n{refresh_token}".encode()).hexdigest()

    @classmethod
    def from_settings(
        cls, settings: Settings, transport: httpx.AsyncBaseTransport | None = None
    ) -> GmailApiEmailProvider:
        # EMAIL_FROM_ADDRESS may carry its own name ("TroSky <a@gmail.com>",
        # as the SMTP provider takes it); otherwise EMAIL_FROM_NAME is used.
        name, address = parseaddr(settings.EMAIL_FROM_ADDRESS)
        return cls(
            client_id=settings.GMAIL_CLIENT_ID,
            client_secret=settings.GMAIL_CLIENT_SECRET.get_secret_value(),
            refresh_token=settings.GMAIL_REFRESH_TOKEN.get_secret_value(),
            sender=formataddr((name or settings.EMAIL_FROM_NAME, address)),
            transport=transport,
        )

    async def send_email(
        self, to: str, subject: str, body_text: str, body_html: str | None = None
    ) -> EmailSendResult:
        raw = raw_message(self._sender, to, subject, body_text, body_html)
        try:
            async with httpx.AsyncClient(
                timeout=_TIMEOUT_SECONDS, transport=self._transport
            ) as client:
                response = await self._post(client, raw)
                if response.status_code == httpx.codes.UNAUTHORIZED:
                    # The kept access token stopped working (revoked early):
                    # get a new one and try once more.
                    _access_tokens.pop(self._cache_key, None)
                    response = await self._post(client, raw)
        except httpx.HTTPError as exc:
            logger.warning("email_api_unreachable", provider=self.name, error=type(exc).__name__)
            return EmailSendResult(
                success=False, provider_reference=None, error=f"{self.name} unreachable"
            )
        except _TokenRefusedError as exc:
            return self._refused(exc.status_code, exc.reason)
        if response.is_success:
            reference = _json(response).get("id")
            return EmailSendResult(
                success=True, provider_reference=str(reference) if reference else None
            )
        return self._refused(response.status_code, _gmail_reason(response))

    async def _post(self, client: httpx.AsyncClient, raw: str) -> httpx.Response:
        token = await self._access_token(client)
        return await client.post(
            SEND_URL, headers={"Authorization": f"Bearer {token}"}, json={"raw": raw}
        )

    async def _access_token(self, client: httpx.AsyncClient) -> str:
        now = self._clock()
        kept = _access_tokens.get(self._cache_key)
        if kept is not None and kept[1] > now:
            return kept[0]
        response = await client.post(
            TOKEN_URL,
            data={
                "client_id": self._client_id,
                "client_secret": self._client_secret,
                "refresh_token": self._refresh_token,
                "grant_type": "refresh_token",
            },
        )
        body = _json(response)
        token = body.get("access_token")
        if not response.is_success or not isinstance(token, str):
            raise _TokenRefusedError(response.status_code, _token_reason(body, response))
        lifetime = float(body.get("expires_in") or 3600)
        _access_tokens[self._cache_key] = (token, now + lifetime - _EXPIRY_MARGIN_SECONDS)
        return token

    def _refused(self, status_code: int, reason: str) -> EmailSendResult:
        logger.warning(
            "email_api_refused", provider=self.name, status_code=status_code, message=reason
        )
        return EmailSendResult(
            success=False,
            provider_reference=None,
            error=f"{self.name} refused it (HTTP {status_code}): {reason}",
        )


def raw_message(sender: str, to: str, subject: str, body_text: str, body_html: str | None) -> str:
    """The message as Gmail's API takes it: the whole RFC 5322 message,
    base64url-encoded."""
    message = EmailMessage()
    message["From"] = sender
    message["To"] = to
    message["Subject"] = subject
    message.set_content(body_text)
    if body_html:
        message.add_alternative(body_html, subtype="html")
    return base64.urlsafe_b64encode(message.as_bytes()).decode("ascii")


def _token_reason(body: dict[str, Any], response: httpx.Response) -> str:
    error = str(body.get("error") or response.reason_phrase)
    description = body.get("error_description")
    reason = f"{error}: {description}" if description else error
    if error == "invalid_grant":
        # Revoked, or expired: a client still in "Testing" gets refresh
        # tokens that last 7 days.
        reason += " (make a new GMAIL_REFRESH_TOKEN with scripts/gmail_refresh_token.py)"
    elif error in ("invalid_client", "unauthorized_client"):
        reason += " (check GMAIL_CLIENT_ID and GMAIL_CLIENT_SECRET)"
    return reason


def _gmail_reason(response: httpx.Response) -> str:
    error = _json(response).get("error")
    if isinstance(error, dict) and error.get("message"):
        return str(error["message"])
    return response.reason_phrase


def _json(response: httpx.Response) -> dict[str, Any]:
    try:
        body = response.json()
    except ValueError:
        return {}
    return body if isinstance(body, dict) else {}
