"""Email through Gmail's HTTPS API: what is sent, how the access token is
got and kept, and what a refusal or an outage comes back as."""

from __future__ import annotations

import base64
import email
import json
from collections.abc import Iterator
from email import policy
from email.message import EmailMessage
from urllib.parse import parse_qs

import httpx
import pytest
from pydantic import ValidationError

from app.core.config import EmailProviderName, Settings
from app.providers.email import gmail_api
from app.providers.email.factory import get_email_provider
from app.providers.email.gmail_api import SEND_URL, TOKEN_URL, GmailApiEmailProvider

_CLIENT_ID = "123-test.apps.googleusercontent.com"
_CLIENT_SECRET = "client-secret-not-real"
_REFRESH_TOKEN = "1//refresh-token-not-real"
_SENDER = "TroSky <troskynoreply@gmail.com>"


@pytest.fixture(autouse=True)
def _no_kept_tokens() -> Iterator[None]:
    gmail_api._access_tokens.clear()
    yield
    gmail_api._access_tokens.clear()


class _Google:
    """Answers the token and send endpoints; records every request."""

    def __init__(
        self,
        *,
        token: tuple[int, object] = (200, {"access_token": "at-1", "expires_in": 3599}),
        sends: list[tuple[int, object]] | None = None,
    ) -> None:
        self.token = token
        self.sends = sends or [(200, {"id": "msg-1", "labelIds": ["SENT"]})]
        self.token_requests: list[httpx.Request] = []
        self.send_requests: list[httpx.Request] = []

    def __call__(self, request: httpx.Request) -> httpx.Response:
        if str(request.url) == TOKEN_URL:
            self.token_requests.append(request)
            status, body = self.token
        else:
            assert str(request.url) == SEND_URL
            self.send_requests.append(request)
            status, body = self.sends[min(len(self.send_requests), len(self.sends)) - 1]
        return httpx.Response(status, json=body)


def _provider(google: _Google, clock: list[float] | None = None) -> GmailApiEmailProvider:
    now = clock if clock is not None else [1000.0]
    return GmailApiEmailProvider(
        client_id=_CLIENT_ID,
        client_secret=_CLIENT_SECRET,
        refresh_token=_REFRESH_TOKEN,
        sender=_SENDER,
        transport=httpx.MockTransport(google),
        clock=lambda: now[0],
    )


def _sent_message(request: httpx.Request) -> EmailMessage:
    raw = json.loads(request.content)["raw"]
    message = email.message_from_bytes(base64.urlsafe_b64decode(raw), policy=policy.default)
    assert isinstance(message, EmailMessage)
    return message


async def test_sends_the_code_as_the_gmail_account() -> None:
    google = _Google()

    result = await _provider(google).send_email(
        "ama@gmail.com", "Your code", "Your code is 123456."
    )

    assert result.success
    assert result.provider_reference == "msg-1"
    [token_request] = google.token_requests
    assert parse_qs(token_request.content.decode()) == {
        "client_id": [_CLIENT_ID],
        "client_secret": [_CLIENT_SECRET],
        "refresh_token": [_REFRESH_TOKEN],
        "grant_type": ["refresh_token"],
    }
    [send_request] = google.send_requests
    assert send_request.headers["Authorization"] == "Bearer at-1"
    message = _sent_message(send_request)
    assert message["From"] == _SENDER
    assert message["To"] == "ama@gmail.com"
    assert message["Subject"] == "Your code"
    body = message.get_body(("plain",))
    assert body is not None
    assert body.get_content().strip() == "Your code is 123456."


async def test_an_html_body_goes_with_the_text_one() -> None:
    google = _Google()

    await _provider(google).send_email("ama@gmail.com", "Code", "Code: 1", "<b>Code: 1</b>")

    message = _sent_message(google.send_requests[0])
    plain, html = message.get_body(("plain",)), message.get_body(("html",))
    assert plain is not None
    assert html is not None
    assert html.get_content().strip() == "<b>Code: 1</b>"


async def test_the_access_token_is_kept_until_a_minute_before_it_expires() -> None:
    google = _Google()
    clock = [1000.0]
    provider = _provider(google, clock)

    await provider.send_email("a@gmail.com", "1", "1")
    clock[0] += 3599 - 61  # just inside the hour, less the minute's margin
    await _provider(google, clock).send_email("b@gmail.com", "2", "2")  # a new request's provider
    assert len(google.token_requests) == 1

    clock[0] += 2
    await provider.send_email("c@gmail.com", "3", "3")
    assert len(google.token_requests) == 2
    assert len(google.send_requests) == 3


async def test_an_access_token_google_stops_taking_is_replaced_once() -> None:
    google = _Google(sends=[(401, {"error": {"code": 401, "message": "Invalid Credentials"}})])
    google.sends.append((200, {"id": "msg-2"}))

    result = await _provider(google).send_email("ama@gmail.com", "Code", "Code: 1")

    assert result.success
    assert result.provider_reference == "msg-2"
    assert len(google.token_requests) == 2
    assert len(google.send_requests) == 2


async def test_a_second_refusal_of_the_token_is_a_failed_send_not_a_loop() -> None:
    google = _Google(sends=[(401, {"error": {"code": 401, "message": "Invalid Credentials"}})])

    result = await _provider(google).send_email("ama@gmail.com", "Code", "Code: 1")

    assert not result.success
    assert result.error == "Gmail refused it (HTTP 401): Invalid Credentials"
    assert len(google.send_requests) == 2


async def test_a_refused_refresh_token_says_how_to_make_a_new_one() -> None:
    google = _Google(
        token=(400, {"error": "invalid_grant", "error_description": "Token has been expired."})
    )

    result = await _provider(google).send_email("ama@gmail.com", "Code", "Code: 1")

    assert not result.success
    assert result.error is not None
    assert "invalid_grant: Token has been expired." in result.error
    assert "scripts/gmail_refresh_token.py" in result.error
    assert _REFRESH_TOKEN not in result.error
    assert _CLIENT_SECRET not in result.error
    assert google.send_requests == []


async def test_a_wrong_client_points_at_its_settings() -> None:
    google = _Google(token=(401, {"error": "invalid_client", "error_description": "Unauthorized"}))

    result = await _provider(google).send_email("ama@gmail.com", "Code", "Code: 1")

    assert result.error is not None
    assert "check GMAIL_CLIENT_ID and GMAIL_CLIENT_SECRET" in result.error


async def test_gmail_refusing_the_message_carries_googles_reason() -> None:
    google = _Google(
        sends=[(403, {"error": {"code": 403, "message": "Daily user sending limit exceeded."}})]
    )

    result = await _provider(google).send_email("ama@gmail.com", "Code", "Code: 1")

    assert not result.success
    assert result.error == "Gmail refused it (HTTP 403): Daily user sending limit exceeded."


async def test_an_outage_is_a_failed_send_not_an_exception() -> None:
    def down(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectError("no route", request=request)

    provider = GmailApiEmailProvider(
        client_id=_CLIENT_ID,
        client_secret=_CLIENT_SECRET,
        refresh_token=_REFRESH_TOKEN,
        sender=_SENDER,
        transport=httpx.MockTransport(down),
    )

    result = await provider.send_email("ama@gmail.com", "Code", "Code: 1")

    assert not result.success
    assert result.error == "Gmail unreachable"


def _settings(**overrides: str) -> Settings:
    values = {
        "SECRET_KEY": "x" * 32,
        "JWT_SECRET_KEY": "y" * 32,
        "PAYMENTS_WEBHOOK_SIGNING_SECRET": "z" * 32,
        "TICKET_QR_SIGNING_SECRET": "w" * 32,
        "EMAIL_PROVIDER": EmailProviderName.GMAIL_API,
        "EMAIL_FROM_ADDRESS": "troskynoreply@gmail.com",
        "EMAIL_FROM_NAME": "TroSky",
        "GMAIL_CLIENT_ID": _CLIENT_ID,
        "GMAIL_CLIENT_SECRET": _CLIENT_SECRET,
        "GMAIL_REFRESH_TOKEN": _REFRESH_TOKEN,
    }
    return Settings.model_validate({**values, **overrides})


def test_the_server_refuses_to_start_without_the_gmail_credentials() -> None:
    with pytest.raises(ValidationError, match="needs GMAIL_CLIENT_SECRET, GMAIL_REFRESH_TOKEN"):
        _settings(GMAIL_CLIENT_SECRET="", GMAIL_REFRESH_TOKEN=" ")


@pytest.mark.parametrize(
    ("from_address", "from_name", "sender"),
    [
        ("troskynoreply@gmail.com", "TroSky", _SENDER),
        # The SMTP provider's spelling, with the name in the address.
        (
            "TroSky Codes <troskynoreply@gmail.com>",
            "TroSky",
            "TroSky Codes <troskynoreply@gmail.com>",
        ),
    ],
)
async def test_the_factory_builds_it_from_the_settings(
    from_address: str, from_name: str, sender: str
) -> None:
    settings = _settings(EMAIL_FROM_ADDRESS=from_address, EMAIL_FROM_NAME=from_name)
    provider = get_email_provider(settings)

    assert isinstance(provider, GmailApiEmailProvider)
    google = _Google()
    provider._transport = httpx.MockTransport(google)
    await provider.send_email("ama@gmail.com", "Code", "Code: 1")
    assert _sent_message(google.send_requests[0])["From"] == sender
