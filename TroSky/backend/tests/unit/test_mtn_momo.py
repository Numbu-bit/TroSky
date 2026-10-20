"""The MTN MoMo Collections adapter against a stand-in for MTN's sandbox:
what it sends, and what it makes of the answers."""

from __future__ import annotations

import base64
import json
import uuid
from collections.abc import Iterator
from decimal import Decimal

import httpx
import pytest

from app.core.config import Settings
from app.core.exceptions import ProviderError
from app.providers.payments import mtn_momo
from app.providers.payments.base import PaymentProviderStatus
from app.providers.payments.mtn_momo import MtnMomoPaymentProvider, momo_reference
from tests.fake_mtn_momo import FakeMtn

BASE = "https://sandbox.momodeveloper.mtn.com"


@pytest.fixture(autouse=True)
def _no_cached_token() -> Iterator[None]:
    mtn_momo._tokens.clear()
    yield
    mtn_momo._tokens.clear()


def _settings(**overrides: object) -> Settings:
    values: dict[str, object] = {
        "SECRET_KEY": "x" * 32,
        "JWT_SECRET_KEY": "y" * 32,
        "PAYMENTS_WEBHOOK_SIGNING_SECRET": "z" * 32,
        "TICKET_QR_SIGNING_SECRET": "w" * 32,
        "PAYMENTS_MTN_MOMO_API_KEY": "api-user-id",
        "PAYMENTS_MTN_MOMO_API_SECRET": "api-key",
        "PAYMENTS_MTN_MOMO_SUBSCRIPTION_KEY": "subscription-key",
        "PAYMENTS_MTN_MOMO_CURRENCY": "EUR",
        "PAYMENTS_MTN_MOMO_CALLBACK_URL": "https://api.example/api/v1/payments/webhooks/mtn_momo",
    }
    return Settings.model_validate({**values, **overrides})


def _provider(mtn: FakeMtn, **overrides: object) -> MtnMomoPaymentProvider:
    return MtnMomoPaymentProvider(_settings(**overrides), transport=httpx.MockTransport(mtn))


async def _pay(
    provider: MtnMomoPaymentProvider, reference: str = "PAY-A1B2C3", phone: str = "0241234567"
):
    return await provider.initialize_payment(
        reference=reference,
        amount=Decimal("8.50"),
        currency="GHS",
        payer_phone=phone,
        narration="TroSky booking TS-8KQ2",
    )


async def test_a_payment_is_asked_for_the_way_the_sandbox_wants() -> None:
    mtn = FakeMtn()
    result = await _pay(_provider(mtn))

    token, ask = mtn.requests
    assert token.headers["Ocp-Apim-Subscription-Key"] == "subscription-key"
    assert (
        token.headers["Authorization"]
        == "Basic " + base64.b64encode(b"api-user-id:api-key").decode()
    )

    # MTN wants a UUID: one made from our reference, the same every time.
    assert ask.headers["X-Reference-Id"] == momo_reference("PAY-A1B2C3")
    assert uuid.UUID(ask.headers["X-Reference-Id"]).version == 5
    assert ask.headers["X-Target-Environment"] == "sandbox"
    assert ask.headers["X-Callback-Url"] == "https://api.example/api/v1/payments/webhooks/mtn_momo"
    assert ask.headers["Authorization"] == "Bearer token-1"
    body = json.loads(ask.content)
    assert body["amount"] == "8.50"
    assert body["currency"] == "EUR"  # the sandbox's only currency
    assert body["externalId"] == "PAY-A1B2C3"
    assert body["payer"] == {"partyIdType": "MSISDN", "partyId": "233241234567"}

    assert result.status == PaymentProviderStatus.PENDING
    assert result.provider_reference == momo_reference("PAY-A1B2C3")


async def test_the_live_environment_and_currency_are_settings() -> None:
    mtn = FakeMtn()
    await _pay(
        _provider(
            mtn,
            PAYMENTS_MTN_MOMO_TARGET_ENVIRONMENT="mtnghana",
            PAYMENTS_MTN_MOMO_CURRENCY="",
            PAYMENTS_MTN_MOMO_CALLBACK_URL="",
        )
    )
    ask = mtn.requests[-1]
    assert ask.headers["X-Target-Environment"] == "mtnghana"
    assert json.loads(ask.content)["currency"] == "GHS"
    assert "X-Callback-Url" not in ask.headers  # no callback: confirmed by polling


async def test_a_sandbox_test_number_goes_as_typed() -> None:
    mtn = FakeMtn()
    await _pay(_provider(mtn), phone="46733123453")
    assert json.loads(mtn.requests[-1].content)["payer"]["partyId"] == "46733123453"


async def test_asking_again_for_the_same_payment_is_still_pending() -> None:
    mtn = FakeMtn()
    provider = _provider(mtn)
    first = await _pay(provider)
    again = await _pay(provider)  # MTN answers 409: the same reference
    assert again.provider_reference == first.provider_reference
    assert again.status == PaymentProviderStatus.PENDING


async def test_one_token_serves_many_payments() -> None:
    mtn = FakeMtn()
    await _pay(_provider(mtn), reference="PAY-1")
    await _pay(_provider(mtn), reference="PAY-2")  # a new adapter, as per request
    assert mtn.tokens_issued == 1


async def test_a_refusal_is_a_provider_error() -> None:
    def refusing(request: httpx.Request) -> httpx.Response:
        if request.url.path == "/collection/token/":
            return httpx.Response(200, json={"access_token": "t", "expires_in": 3600})
        return httpx.Response(400, json={"code": "PAYER_NOT_FOUND"})

    with pytest.raises(ProviderError, match="HTTP 400"):
        await _pay(MtnMomoPaymentProvider(_settings(), transport=httpx.MockTransport(refusing)))


@pytest.mark.parametrize(
    ("mtn_says", "status", "reason"),
    [
        ({"status": "PENDING"}, PaymentProviderStatus.PENDING, None),
        ({"status": "SUCCESSFUL"}, PaymentProviderStatus.SUCCESSFUL, None),
        (
            {"status": "FAILED", "reason": "PAYER_LIMIT_REACHED"},
            PaymentProviderStatus.FAILED,
            "PAYER_LIMIT_REACHED",
        ),
    ],
)
async def test_the_status_is_read_from_mtn(mtn_says, status, reason) -> None:
    mtn = FakeMtn()
    provider = _provider(mtn)
    paid = await _pay(provider)
    mtn.payments[paid.provider_reference].update(mtn_says)

    result = await provider.query_payment(paid.provider_reference)

    assert (result.status, result.failure_reason) == (status, reason)
