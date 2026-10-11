"""Paying for a booking with MTN MoMo, end to end against a stand-in for
MTN's sandbox: the request to pay, a callback that is checked rather than
believed, and the booking confirmed once MTN says the payment succeeded.
"""

from __future__ import annotations

import json
from collections.abc import Iterator
from datetime import UTC, datetime, timedelta

import httpx
import pytest
from httpx import ASGITransport, AsyncClient
from pydantic import SecretStr
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import PaymentProviderName, get_settings
from app.models.bookings import BookingStatus
from app.models.payments import PaymentStatus
from app.providers.payments import mtn_momo
from app.providers.payments.base import PaymentChannel
from app.providers.payments.mtn_momo import MtnMomoPaymentProvider, momo_reference
from app.services.payment_service import PaymentService
from tests.fake_mtn_momo import FakeMtn
from tests.integration.scenarios import book, build_trip_scenario

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]


@pytest.fixture
def mtn(monkeypatch: pytest.MonkeyPatch) -> Iterator[FakeMtn]:
    fake = FakeMtn()
    monkeypatch.setattr(
        MtnMomoPaymentProvider,
        "_client",
        lambda self: httpx.AsyncClient(transport=httpx.MockTransport(fake)),
    )
    mtn_momo._tokens.clear()
    yield fake
    mtn_momo._tokens.clear()


def _service(session: AsyncSession) -> PaymentService:
    return PaymentService(
        session,
        get_settings().model_copy(
            update={
                "PAYMENTS_ACTIVE_PROVIDER": PaymentProviderName.MTN_MOMO,
                "PAYMENTS_MTN_MOMO_API_KEY": SecretStr("api-user-id"),
                "PAYMENTS_MTN_MOMO_API_SECRET": SecretStr("api-key"),
                "PAYMENTS_MTN_MOMO_SUBSCRIPTION_KEY": SecretStr("subscription-key"),
                "PAYMENTS_MTN_MOMO_CURRENCY": "EUR",
            }
        ),
    )


async def _callback(service: PaymentService, reference: str, status: str) -> None:
    body = json.dumps({"externalId": reference, "status": status}).encode()
    await service.process_webhook(PaymentChannel.MTN_MOMO, {}, body)


async def test_a_booking_paid_by_momo_is_confirmed_once_mtn_says_so(
    db_session: AsyncSession, make_user, mtn: FakeMtn
) -> None:
    scenario = await build_trip_scenario(
        db_session, make_user, departure=datetime.now(UTC) + timedelta(hours=3)
    )
    passenger = await make_user()
    booking = await book(db_session, passenger.id, scenario, seat=0, confirm=False)
    service = _service(db_session)

    payment = await service.pay_for_booking(
        passenger.id,
        booking.id,
        channel=PaymentChannel.MTN_MOMO,
        payer_phone="0241234567",
        idempotency_key=None,
    )

    assert payment.status == PaymentStatus.PROCESSING
    assert payment.provider_reference == momo_reference(payment.internal_reference)
    asked = mtn.payments[payment.provider_reference]
    assert (asked["currency"], asked["payer"]["partyId"]) == ("EUR", "233241234567")

    # A forged callback, before the payer has approved anything: MTN still
    # says pending, so nothing changes.
    await _callback(service, payment.internal_reference, "SUCCESSFUL")
    await db_session.refresh(payment)
    await db_session.refresh(booking)
    assert payment.status == PaymentStatus.PROCESSING
    assert booking.status != BookingStatus.CONFIRMED

    # The payer approves; MTN's own callback says the same as the forged
    # one did, and is not taken for a repeat of it.
    mtn.payments[payment.provider_reference]["status"] = "SUCCESSFUL"
    await _callback(service, payment.internal_reference, "SUCCESSFUL")
    await db_session.refresh(payment)
    await db_session.refresh(booking)
    assert payment.status == PaymentStatus.SUCCESSFUL
    assert booking.status == BookingStatus.CONFIRMED


async def test_a_declined_momo_payment_leaves_the_booking_payable(
    db_session: AsyncSession, make_user, mtn: FakeMtn
) -> None:
    scenario = await build_trip_scenario(
        db_session, make_user, departure=datetime.now(UTC) + timedelta(hours=3)
    )
    passenger = await make_user()
    booking = await book(db_session, passenger.id, scenario, seat=0, confirm=False)
    service = _service(db_session)
    payment = await service.pay_for_booking(
        passenger.id,
        booking.id,
        channel=PaymentChannel.MTN_MOMO,
        payer_phone="0241234567",
        idempotency_key=None,
    )

    mtn.payments[payment.provider_reference].update(status="FAILED", reason="APPROVAL_REJECTED")
    await _callback(service, payment.internal_reference, "FAILED")

    await db_session.refresh(payment)
    await db_session.refresh(booking)
    assert payment.status == PaymentStatus.FAILED
    assert booking.status == BookingStatus.PENDING  # pay again, the same or another way


async def test_mtn_may_call_back_with_put(require_redis: None) -> None:
    from app.main import create_app

    async with AsyncClient(
        transport=ASGITransport(app=create_app()), base_url="http://localhost"
    ) as c:
        # The test server pays through the sandbox provider; a reference it
        # doesn't know is simply acknowledged.
        response = await c.put(
            "/api/v1/payments/webhooks/mtn_momo",
            json={"reference": "PAY-UNKNOWN", "status": "successful"},
        )
    assert response.status_code == 200, response.text
