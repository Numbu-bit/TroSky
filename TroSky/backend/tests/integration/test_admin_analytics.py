"""Overview figures by period and city."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from decimal import Decimal

import pytest
from sqlalchemy import update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.payments import WalletReferenceType
from app.models.routes import Stop
from app.providers.payments.base import PaymentChannel
from app.services.admin_analytics_service import AdminAnalyticsService, Period
from app.services.payment_service import PaymentService
from app.services.trip_service import TripService
from app.services.wallet_service import WalletService
from tests.integration.scenarios import TripScenario, book, build_trip_scenario

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]


async def _completed_trip_with_a_paid_seat(session: AsyncSession, make_user) -> TripScenario:
    scenario = await build_trip_scenario(
        session, make_user, departure=datetime.now(UTC) - timedelta(minutes=30)
    )
    passenger = await make_user()
    booking = await book(session, passenger.id, scenario, seat=0, confirm=False)
    await WalletService(session).credit(
        passenger.id,
        amount=Decimal("20.00"),
        reference_type=WalletReferenceType.WALLET_TOPUP,
        reference_id=None,
        description="Test top-up",
    )
    await PaymentService(session).pay_for_booking(
        passenger.id,
        booking.id,
        channel=PaymentChannel.WALLET,
        payer_phone=None,
        idempotency_key=None,
    )
    trips = TripService(session)
    await trips.start_trip(scenario.trip_id, scenario.driver_user_id)
    await trips.end_trip(scenario.trip_id, scenario.driver_user_id)
    return scenario


async def _figures(session: AsyncSession, city: str | None = None):
    # Yesterday too: the trip left 30 minutes ago, which just after midnight
    # is still yesterday.
    today = datetime.now(UTC).date()
    period = Period(today - timedelta(days=1), today)
    return await AdminAnalyticsService(session).overview_figures(period, city)


class TestOverviewFigures:
    async def test_todays_activity_is_counted_against_yesterday(
        self, db_session: AsyncSession, make_user
    ) -> None:
        before = await _figures(db_session)
        await _completed_trip_with_a_paid_seat(db_session, make_user)

        after = await _figures(db_session)

        assert after["paid_bookings"].value == before["paid_bookings"].value + 1
        assert after["completed_trips"].value == before["completed_trips"].value + 1
        assert after["booking_payments"].value - before["booking_payments"].value == Decimal(
            "8.50"
        )  # 8.00 fare + 0.50 fee
        assert after["new_users"].value > before["new_users"].value
        assert len(after["paid_bookings"].series) == 2

    async def test_a_city_counts_only_trips_starting_there(
        self, db_session: AsyncSession, make_user
    ) -> None:
        scenario = await _completed_trip_with_a_paid_seat(db_session, make_user)
        await db_session.execute(
            update(Stop).where(Stop.id == scenario.stop_ids[0]).values(city="Testville")
        )

        here = await _figures(db_session, city="testville")
        elsewhere = await _figures(db_session, city="Nowhere")

        assert here["paid_bookings"].value == 1
        assert here["completed_trips"].value == 1
        assert elsewhere["paid_bookings"].value == 0
        assert "new_users" not in here  # sign-ups have no city
