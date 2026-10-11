"""Email through Brevo's and Resend's HTTPS APIs: what is sent, and what a
refusal or an outage comes back as."""

from __future__ import annotations

import json

import httpx
import pytest
from pydantic import ValidationError

from app.core.config import EmailProviderName, Settings
from app.providers.email.factory import get_email_provider
from app.providers.email.https_api import BrevoEmailProvider, ResendEmailProvider

_KEY = "test-key-not-real"


def _settings(provider: EmailProviderName = EmailProviderName.BREVO, key: str = _KEY) -> Settings:
    return Settings.model_validate(
        {
            "SECRET_KEY": "x" * 32,
            "JWT_SECRET_KEY": "y" * 32,
            "PAYMENTS_WEBHOOK_SIGNING_SECRET": "z" * 32,
            "TICKET_QR_SIGNING_SECRET": "w" * 32,
            "EMAIL_PROVIDER": provider,
            "EMAIL_API_KEY": key,
            "EMAIL_FROM_ADDRESS": "codes@trosky.example",
            "EMAIL_FROM_NAME": "TroSky",
        }
    )


class _Recorder:
    def __init__(self, status: int, body: object) -> None:
        self.status, self.body = status, body
        self.requests: list[httpx.Request] = []

    def __call__(self, request: httpx.Request) -> httpx.Response:
        self.requests.append(request)
        return httpx.Response(self.status, json=self.body)


async def test_brevo_sends_the_code_from_the_verified_sender() -> None:
    api = _Recorder(201, {"messageId": "<abc@smtp-relay.brevo.com>"})
    provider = BrevoEmailProvider(_settings(), transport=httpx.MockTransport(api))

    result = await provider.send_email("ama@gmail.com", "Your code", "Your code is 123456.")

    assert result.success
    assert result.provider_reference == "<abc@smtp-relay.brevo.com>"
    [request] = api.requests
    assert str(request.url) == "https://api.brevo.com/v3/smtp/email"
    assert request.headers["api-key"] == _KEY
    assert json.loads(request.content) == {
        "sender": {"name": "TroSky", "email": "codes@trosky.example"},
        "to": [{"email": "ama@gmail.com"}],
        "subject": "Your code",
        "textContent": "Your code is 123456.",
    }


async def test_resend_sends_the_code_with_a_bearer_key() -> None:
    api = _Recorder(200, {"id": "re-1"})
    provider = ResendEmailProvider(
        _settings(EmailProviderName.RESEND), transport=httpx.MockTransport(api)
    )

    result = await provider.send_email("ama@gmail.com", "Your code", "Your code is 1.", "<p>1</p>")

    assert (result.success, result.provider_reference) == (True, "re-1")
    [request] = api.requests
    assert str(request.url) == "https://api.resend.com/emails"
    assert request.headers["authorization"] == f"Bearer {_KEY}"
    body = json.loads(request.content)
    assert body["from"] == "TroSky <codes@trosky.example>"
    assert (body["to"], body["text"], body["html"]) == (
        ["ama@gmail.com"],
        "Your code is 1.",
        "<p>1</p>",
    )


@pytest.mark.parametrize("provider_class", [BrevoEmailProvider, ResendEmailProvider])
async def test_a_refusal_comes_back_with_the_services_reason(provider_class) -> None:
    api = _Recorder(401, {"code": "unauthorized", "message": "Key not found"})
    provider = provider_class(_settings(), transport=httpx.MockTransport(api))

    result = await provider.send_email("ama@gmail.com", "Your code", "123456")

    assert not result.success
    assert "HTTP 401" in result.error
    assert "Key not found" in result.error
    assert _KEY not in result.error


async def test_an_outage_is_a_failed_send_not_a_crash() -> None:
    def unreachable(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectError("no route to host")

    provider = BrevoEmailProvider(_settings(), transport=httpx.MockTransport(unreachable))

    result = await provider.send_email("ama@gmail.com", "Your code", "123456")

    assert not result.success
    assert result.error == "Brevo unreachable"


def test_the_setting_chooses_the_provider() -> None:
    assert isinstance(get_email_provider(_settings()), BrevoEmailProvider)
    assert isinstance(get_email_provider(_settings(EmailProviderName.RESEND)), ResendEmailProvider)


@pytest.mark.parametrize("provider", [EmailProviderName.BREVO, EmailProviderName.RESEND])
def test_no_key_means_no_start(provider: EmailProviderName) -> None:
    with pytest.raises(ValidationError, match="needs EMAIL_API_KEY"):
        _settings(provider, key="")
