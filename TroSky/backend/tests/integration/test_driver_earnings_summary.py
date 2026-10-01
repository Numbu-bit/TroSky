"""Frontend request G7: a driver's earnings by day/week/month, and wallet
transactions filtered by kind -- against a real Postgres."""

from __future__ import annotations

import uuid
from datetime import UTC, date, datetime, timedelta
from decimal import Decimal

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.payments import WalletReferenceType
from app.providers.payments.base import PaymentChannel
from app.services.trip_service import TripService
from app.services.wallet_service import WalletService
from app.services.withdrawal_service import WithdrawalService
from tests.integration.scenarios import book, build_trip_scenario

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]


async def _earn(
    db_session: AsyncSession,
    user_id: uuid.UUID,
    amount: str,
    *,
    booking_id: uuid.UUID,
    on: datetime,
) -> None:
    """A trip earning credited at ``on`` (as end-of-trip crediting does)."""
    transaction = await WalletService(db_session).credit(
        user_id,
        amount=Decimal(amount),
        reference_type=WalletReferenceType.TRIP_EARNING,
        reference_id=booking_id,
        description="Trip earning",
    )
    transaction.created_at = on
    await db_session.flush()


def _at(day: str) -> datetime:
    return datetime.fromisoformat(f"{day}T12:00:00+00:00")


class TestEarningsSummary:
    async def _two_trips(self, db_session: AsyncSession, make_user):
        """Bookings to credit earnings against: two on one trip, one on
        another."""
        first = await build_trip_scenario(db_session, make_user, departure=_at("2031-03-01"))
        second = await build_trip_scenario(db_session, make_user, departure=_at("2031-03-01"))
        return (
            await book(db_session, (await make_user()).id, first, seat=0),
            await book(db_session, (await make_user()).id, first, seat=1),
            await book(db_session, (await make_user()).id, second, seat=0),
        )

    async def test_totals_per_day_including_empty_days(
        self, db_session: AsyncSession, make_user
    ) -> None:
        driver = await make_user()
        a1, a2, _ = await self._two_trips(db_session, make_user)
        await _earn(db_session, driver.id, "10.00", booking_id=a1.id, on=_at("2031-03-03"))
        await _earn(db_session, driver.id, "5.00", booking_id=a2.id, on=_at("2031-03-05"))

        summary = await WalletService(db_session).earnings_summary(
            driver.id, period="day", start=date(2031, 3, 3), end=date(2031, 3, 5)
        )

        assert [(b.start, b.total, b.trips_count) for b in summary.buckets] == [
            (date(2031, 3, 3), Decimal("10.00"), 1),
            (date(2031, 3, 4), Decimal("0.00"), 0),
            (date(2031, 3, 5), Decimal("5.00"), 1),
        ]
        assert summary.total == Decimal("15.00")
        assert summary.trips_count == 1  # both bookings were on the same trip
        assert summary.currency == "GHS"

    async def test_weeks_start_on_monday_and_trips_are_counted_once(
        self, db_session: AsyncSession, make_user
    ) -> None:
        driver = await make_user()
        a1, a2, b1 = await self._two_trips(db_session, make_user)
        await _earn(db_session, driver.id, "10.00", booking_id=a1.id, on=_at("2031-03-03"))
        await _earn(db_session, driver.id, "5.00", booking_id=a2.id, on=_at("2031-03-05"))
        await _earn(db_session, driver.id, "7.50", booking_id=b1.id, on=_at("2031-03-12"))

        summary = await WalletService(db_session).earnings_summary(
            driver.id, period="week", start=date(2031, 3, 4), end=date(2031, 3, 16)
        )

        # 2031-03-03 and 2031-03-10 are Mondays. The first week's bucket
        # counts only 4 March onwards, where the range starts.
        assert [(b.start, b.total, b.trips_count) for b in summary.buckets] == [
            (date(2031, 3, 3), Decimal("5.00"), 1),
            (date(2031, 3, 10), Decimal("7.50"), 1),
        ]
        assert summary.total == Decimal("12.50")
        assert summary.trips_count == 2

    async def test_months_and_other_money_are_kept_apart(
        self, db_session: AsyncSession, make_user
    ) -> None:
        driver = await make_user()
        a1, _, b1 = await self._two_trips(db_session, make_user)
        await _earn(db_session, driver.id, "10.00", booking_id=a1.id, on=_at("2031-03-30"))
        await _earn(db_session, driver.id, "4.00", booking_id=b1.id, on=_at("2031-04-02"))
        top_up = await WalletService(db_session).credit(  # money in, but not earned
            driver.id,
            amount=Decimal("50.00"),
            reference_type=WalletReferenceType.WALLET_TOPUP,
            reference_id=None,
            description="Top-up",
        )
        top_up.created_at = _at("2031-03-15")  # inside the range asked about
        await db_session.flush()

        summary = await WalletService(db_session).earnings_summary(
            driver.id, period="month", start=date(2031, 3, 1), end=date(2031, 4, 30)
        )
        assert [(b.start, b.total) for b in summary.buckets] == [
            (date(2031, 3, 1), Decimal("10.00")),
            (date(2031, 4, 1), Decimal("4.00")),
        ]
        assert summary.total == Decimal("14.00")

    async def test_pending_withdrawals_are_reported(
        self, db_session: AsyncSession, make_user
    ) -> None:
        driver = await make_user()
        await WalletService(db_session).credit(
            driver.id,
            amount=Decimal("50.00"),
            reference_type=WalletReferenceType.WALLET_TOPUP,
            reference_id=None,
            description="Top-up",
        )
        await WithdrawalService(db_session).request_withdrawal(
            driver.id,
            amount=Decimal("20.00"),
            channel=PaymentChannel.MTN_MOMO,
            destination_phone_number="0244564567",
        )

        summary = await WalletService(db_session).earnings_summary(
            driver.id, period="day", start=date.today(), end=date.today()
        )
        assert summary.pending_withdrawals_total == Decimal("20.00")

    async def test_a_finished_trip_shows_up_as_earnings(
        self, db_session: AsyncSession, make_user
    ) -> None:
        s = await build_trip_scenario(
            db_session, make_user, departure=datetime.now(UTC) + timedelta(minutes=5)
        )
        await book(db_session, (await make_user()).id, s, seat=0)
        await book(db_session, (await make_user()).id, s, seat=1)
        trips = TripService(db_session)
        await trips.start_trip(s.trip_id, s.driver_user_id)
        await trips.end_trip(s.trip_id, s.driver_user_id)
        wallet = WalletService(db_session)
        earnings, _ = await wallet.list_transactions(
            s.driver_user_id,
            reference_type=WalletReferenceType.TRIP_EARNING,
            limit=10,
            offset=0,
        )
        today = datetime.now(UTC).date()

        summary = await wallet.earnings_summary(
            s.driver_user_id, period="day", start=today, end=today
        )
        assert len(earnings) == 2
        assert summary.total == sum(
            (Decimal(t.amount_minor_units) / 100 for t in earnings), Decimal("0")
        )
        assert summary.trips_count == 1


class TestTransactionFilter:
    async def test_transactions_can_be_narrowed_to_one_kind(
        self, db_session: AsyncSession, make_user
    ) -> None:
        user = await make_user()
        s = await build_trip_scenario(db_session, make_user, departure=_at("2031-03-01"))
        booking = await book(db_session, (await make_user()).id, s, seat=0)
        wallet = WalletService(db_session)
        await wallet.credit(
            user.id,
            amount=Decimal("50.00"),
            reference_type=WalletReferenceType.WALLET_TOPUP,
            reference_id=None,
            description="Top-up",
        )
        await _earn(db_session, user.id, "6.00", booking_id=booking.id, on=_at("2031-03-01"))

        earnings, total = await wallet.list_transactions(
            user.id, reference_type=WalletReferenceType.TRIP_EARNING, limit=10, offset=0
        )
        assert total == 1
        assert [t.reference_type for t in earnings] == [WalletReferenceType.TRIP_EARNING]
        _, everything = await wallet.list_transactions(user.id, limit=10, offset=0)
        assert everything == 2
