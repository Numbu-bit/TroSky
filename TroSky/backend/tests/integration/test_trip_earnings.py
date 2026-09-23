"""Integration test for the driver-earnings side effect of
``TripService.end_trip``: the assigned driver's wallet is credited with
their configured revenue share of each completed booking's fare —
against a real Postgres."""

from __future__ import annotations

import uuid
from decimal import Decimal

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.services.wallet_service import WalletService
from tests.integration.test_rating_service import _make_completed_booking

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]


class TestDriverEarnings:
    async def test_driver_wallet_credited_on_trip_completion(
        self, db_session: AsyncSession
    ) -> None:
        passenger_id = uuid.uuid4()
        _booking_id, driver_user_id = await _make_completed_booking(
            db_session, passenger_id=passenger_id
        )

        settings = get_settings()
        expected_share = (Decimal("25.00") * settings.DRIVER_EARNINGS_SHARE_PERCENT / 100).quantize(
            Decimal("0.01")
        )

        balance = await WalletService(db_session).get_balance(driver_user_id)
        assert balance == expected_share
