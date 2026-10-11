"""The six reports against a real database. Each test builds one route's
activity and reports on that route alone, so other tests' trips stay out."""

from __future__ import annotations

from datetime import UTC, date, datetime, time, timedelta
from decimal import Decimal

import pytest
from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.bookings import Booking, BookingStatus
from app.models.payments import Payment, RefundRequest, RefundStatus, WalletReferenceType
from app.models.tickets import Ticket
from app.models.trips import Trip, TripStatus
from app.providers.payments.base import PaymentChannel
from app.repositories.admin_reports_repository import Scope
from app.services.admin_analytics_service import Period
from app.services.admin_reports_service import AdminReportsService, buckets, truncate
from app.services.payment_service import PaymentService
from app.services.ticket_service import TicketService
from app.services.wallet_service import WalletService
from tests.integration.scenarios import TripScenario, book, build_trip_scenario

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]


async def _route_with_a_day_of_trips(session: AsyncSession, make_user) -> TripScenario:
    """Yesterday at 07:30: a completed trip (4 seats; 3 paid, 2 of them
    boarded, and 1 cancelled booking) and a cancelled trip on the route."""
    scenario = await build_trip_scenario(
        session, make_user, departure=datetime.now(UTC) + timedelta(hours=2), seats=4
    )
    wallets, payments = WalletService(session), PaymentService(session)
    tickets = TicketService(session)
    for seat in range(3):
        payer = await make_user()
        booking = await book(session, payer.id, scenario, seat=seat, confirm=False)
        await wallets.credit(
            payer.id,
            amount=Decimal("50.00"),
            reference_type=WalletReferenceType.WALLET_TOPUP,
            reference_id=None,
            description="Top-up",
        )
        await payments.pay_for_booking(
            payer.id,
            booking.id,
            channel=PaymentChannel.WALLET,
            payer_phone=None,
            idempotency_key=None,
        )
        if seat < 2:
            ticket = await session.scalar(select(Ticket).where(Ticket.booking_id == booking.id))
            assert ticket is not None
            await tickets.validate_qr(
                tickets.get_qr_token(ticket),
                trip_id=scenario.trip_id,
                validated_by=scenario.driver_user_id,
            )
    dropped = await book(session, (await make_user()).id, scenario, seat=3, confirm=False)
    dropped.status = BookingStatus.CANCELLED
    yesterday = _at(_yesterday(), 7, 30)
    await session.execute(
        update(Trip)
        .where(Trip.id == scenario.trip_id)
        .values(status=TripStatus.COMPLETED, scheduled_departure_at=yesterday)
    )
    session.add(
        Trip(
            route_id=scenario.route_id,
            scheduled_departure_at=yesterday + timedelta(hours=2),
            status=TripStatus.CANCELLED,
            fare_amount=Decimal("8.00"),
        )
    )
    await session.flush()
    return scenario


def _yesterday() -> date:
    return datetime.now(UTC).date() - timedelta(days=1)


def _at(day: date, hour: int, minute: int = 0) -> datetime:
    return datetime.combine(day, time(hour, minute), tzinfo=UTC)


def _two_days() -> Period:
    return Period(_yesterday(), _yesterday() + timedelta(days=1))


async def _report(session: AsyncSession, name: str, scenario: TripScenario, **options: object):
    return await AdminReportsService(session).build(
        name,  # type: ignore[arg-type]
        _two_days(),
        granularity=options.get("granularity", "day"),  # type: ignore[arg-type]
        scope=Scope(route_id=scenario.route_id),
    )


class TestTheReports:
    async def test_daily_rides(self, db_session: AsyncSession, make_user) -> None:
        scenario = await _route_with_a_day_of_trips(db_session, make_user)

        report = await _report(db_session, "daily_rides", scenario)

        [day, today] = report.rows
        assert day["period"] == _yesterday()
        assert (day["trips_completed"], day["trips_cancelled"]) == (1, 1)
        assert (day["seats_offered"], day["seats_booked"], day["passengers_boarded"]) == (4, 3, 2)
        assert day["occupancy"] == Decimal("0.7500")
        assert today["trips_completed"] == 0
        assert report.totals["occupancy"] == Decimal("0.7500")
        assert report.columns[0].key == "period"

    async def test_revenue(self, db_session: AsyncSession, make_user) -> None:
        scenario = await _route_with_a_day_of_trips(db_session, make_user)
        paid = await db_session.scalar(
            select(func.sum(Payment.amount))
            .join(Booking, Booking.id == Payment.booking_id)
            .where(Booking.trip_id == scenario.trip_id)
        )
        payment = await db_session.scalar(
            select(Payment)
            .join(Booking, Booking.id == Payment.booking_id)
            .where(Booking.trip_id == scenario.trip_id)
            .limit(1)
        )
        assert payment is not None
        db_session.add(
            RefundRequest(
                payment_id=payment.id,
                booking_id=payment.booking_id,
                amount=Decimal("2.00"),
                status=RefundStatus.COMPLETED,
                reviewed_at=datetime.now(UTC),
            )
        )
        await db_session.flush()

        report = await _report(db_session, "revenue", scenario)

        assert report.totals["paid_bookings"] == 3
        assert report.totals["gross"] == paid
        assert report.totals["refunds"] == Decimal("2.00")
        assert report.totals["net"] == paid - Decimal("2.00")
        assert report.totals["average_fare"] == (paid / 3).quantize(Decimal("0.01"))

    async def test_peak_hours(self, db_session: AsyncSession, make_user) -> None:
        scenario = await _route_with_a_day_of_trips(db_session, make_user)

        report = await _report(db_session, "peak_hours", scenario)

        seven = report.rows[7]
        assert seven["hour"] == "07:00"
        assert (seven["trips"], seven["seats_booked"], seven["passengers_boarded"]) == (1, 3, 2)
        assert report.rows[9]["trips"] == 0  # the cancelled one does not run
        assert report.totals["bookings_made"] == 4
        assert seven["searches"] is None  # searches have no route

    async def test_route_popularity(self, db_session: AsyncSession, make_user) -> None:
        scenario = await _route_with_a_day_of_trips(db_session, make_user)

        report = await _report(db_session, "route_popularity", scenario)

        [route] = report.rows
        assert route["route_name"] == scenario.route_name
        assert (route["trips_completed"], route["trips_cancelled"]) == (1, 1)
        assert (route["seats_booked"], route["occupancy"]) == (3, Decimal("0.7500"))
        assert route["bookings_cancelled"] == 1
        assert route["fares"] > 0

    async def test_passenger_growth(self, db_session: AsyncSession, make_user) -> None:
        scenario = await _route_with_a_day_of_trips(db_session, make_user)

        report = await _report(db_session, "passenger_growth", scenario)

        assert report.totals["first_time_bookers"] == 3
        assert report.rows[-1]["active_passengers"] == 3  # all paid today
        assert report.totals["new_passengers"] is None  # sign-ups have no route
        assert any("left out" in note for note in report.notes)

    async def test_cancellation_rates(self, db_session: AsyncSession, make_user) -> None:
        scenario = await _route_with_a_day_of_trips(db_session, make_user)

        report = await _report(db_session, "cancellation_rates", scenario)

        totals = report.totals
        assert (totals["bookings_made"], totals["cancelled_by_passengers"]) == (4, 1)
        assert (totals["trips_scheduled"], totals["trips_cancelled"]) == (2, 1)
        assert totals["passenger_cancellation_rate"] == Decimal("0.2500")
        assert totals["trip_cancellation_rate"] == Decimal("0.5000")
        assert report.rows[0]["trip_cancellation_rate"] == Decimal("0.5000")  # yesterday
        assert totals["cancelled_with_trip"] == 0

    async def test_a_week_at_a_time(self, db_session: AsyncSession, make_user) -> None:
        scenario = await _route_with_a_day_of_trips(db_session, make_user)

        report = await _report(db_session, "daily_rides", scenario, granularity="week")

        monday = truncate(_yesterday(), "week")
        found = {row["period"]: row["trips_completed"] for row in report.rows}
        assert found[monday] == 1
        assert all(day.weekday() == 0 for day in found)


class TestBuckets:
    async def test_days_weeks_and_months(self) -> None:
        period = Period(date(2026, 9, 28), date(2026, 10, 6))  # Monday to the next Tuesday

        assert len(buckets(period, "day")) == 9
        assert buckets(period, "week") == [date(2026, 9, 28), date(2026, 10, 5)]
        assert buckets(period, "month") == [date(2026, 9, 1), date(2026, 10, 1)]
        assert truncate(date(2026, 10, 3), "week") == date(2026, 9, 28)
        assert buckets(Period(date(2026, 1, 31), date(2026, 3, 1)), "month") == [
            date(2026, 1, 1),
            date(2026, 2, 1),
            date(2026, 3, 1),
        ]
