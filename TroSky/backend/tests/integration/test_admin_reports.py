"""Admin reports over real rows: revenue, the funnel, driver performance,
user growth and the payments list.

Each test names its own city (on the route's first stop) and filters by
it, so other tests' data never changes the figures.
"""

from __future__ import annotations

import json
import secrets
import uuid
from datetime import UTC, datetime, timedelta
from decimal import Decimal

import pytest
from sqlalchemy import func, select, text, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.redis import get_redis_client
from app.models.analytics import SearchEvent
from app.models.feedback import Complaint, ComplaintCategory
from app.models.identity import User, UserSession
from app.models.payments import WalletReferenceType
from app.models.routes import Stop
from app.models.tickets import Ticket
from app.providers.payments.base import PaymentChannel, PaymentProviderStatus
from app.providers.payments.sandbox import SandboxPaymentProvider
from app.repositories.admin_finance_repository import AdminFinanceRepository, PaymentFilters
from app.repositories.admin_growth_repository import AdminGrowthRepository
from app.repositories.admin_performance_repository import (
    AdminPerformanceRepository,
    PeriodTrips,
)
from app.services.admin_analytics_service import (
    PAID_BOOKING_STATUSES,
    AdminAnalyticsService,
    Period,
)
from app.services.booking_service import BookingService
from app.services.payment_service import PaymentService
from app.services.rating_service import RatingService
from app.services.refund_service import RefundService
from app.services.ticket_service import TicketService
from app.services.trip_search_service import TripSearchService
from app.services.trip_service import TripService
from app.services.wallet_service import WalletService
from app.utilities.geo import latlng_to_wkt
from tests.integration.scenarios import TripScenario, book, build_trip_scenario

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]

LEGON, CIRCLE = 1, 2


def _today_and_yesterday() -> Period:
    today = datetime.now(UTC).date()
    return Period(today - timedelta(days=1), today)


async def _scenario(
    session: AsyncSession, make_user, *, minutes: int = -30
) -> tuple[TripScenario, str]:
    scenario = await build_trip_scenario(
        session, make_user, departure=datetime.now(UTC) + timedelta(minutes=minutes)
    )
    city = f"City-{uuid.uuid4().hex[:8]}"
    await session.execute(update(Stop).where(Stop.id == scenario.stop_ids[0]).values(city=city))
    return scenario, city


async def _wallet_paid(session: AsyncSession, make_user, scenario: TripScenario, *, seat: int):
    passenger = await make_user()
    booking = await book(session, passenger.id, scenario, seat=seat, confirm=False)
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
    return passenger, booking


class TestRevenue:
    async def test_gross_fees_refunds_net_and_failures(
        self, db_session: AsyncSession, make_user
    ) -> None:
        scenario, city = await _scenario(db_session, make_user, minutes=120)
        _, kept = await _wallet_paid(db_session, make_user, scenario, seat=0)
        refunded_passenger, refunded = await _wallet_paid(db_session, make_user, scenario, seat=1)
        # A third seat: mobile money that fails.
        payer = await make_user()
        failing = await book(db_session, payer.id, scenario, seat=2, confirm=False)
        payments = PaymentService(db_session)
        attempt = await payments.pay_for_booking(
            payer.id,
            failing.id,
            channel=PaymentChannel.MTN_MOMO,
            payer_phone="0244000001",
            idempotency_key=None,
        )
        payload = SandboxPaymentProvider.simulate_webhook_payload(
            attempt.internal_reference, PaymentProviderStatus.FAILED
        )
        await payments.process_webhook(PaymentChannel.MTN_MOMO, {}, json.dumps(payload).encode())
        # The second passenger cancels and is refunded.
        cancelled = await BookingService(db_session).cancel_booking(
            refunded.id, requesting_user_id=refunded_passenger.id, reason=None
        )
        refund = await payments.create_refund_request_for_cancelled_booking(
            cancelled, requested_by=refunded_passenger.id
        )
        assert refund is not None
        await RefundService(db_session).approve_and_process(
            refund.id, reviewer_id=(await make_user()).id, notes=None
        )

        report = await AdminAnalyticsService(db_session).revenue(_today_and_yesterday(), city)

        two_seats = kept.total_amount + refunded.total_amount
        assert report.gross.value == two_seats
        assert report.platform_fees.value == Decimal("1.00")
        assert report.refunds.value == refunded.total_amount
        assert report.net.value == kept.total_amount
        assert report.paid_bookings.value == 2
        assert report.average_fare.value == (two_seats / 2).quantize(Decimal("0.01"))
        assert report.failed_payment_rate.value == Decimal("0.3333")  # 1 of 3 attempts
        assert {m: f.value for m, f in report.by_method.items()} == {"wallet": two_seats}
        assert [(s.label, s.amount) for s in report.by_route] == [(scenario.route_name, two_seats)]
        assert sum(s.amount for s in report.by_hour) == two_seats


class TestFunnel:
    async def test_searches_reserved_paid_boarded(
        self, db_session: AsyncSession, make_user, require_redis: None
    ) -> None:
        scenario, city = await _scenario(db_session, make_user, minutes=-5)
        searches = TripSearchService(db_session, get_redis_client())
        for _ in range(2):
            await searches.search(
                origin_stop_id=scenario.stop_ids[0],
                destination_stop_id=scenario.stop_ids[CIRCLE],
                travel_date=datetime.now(UTC).date(),
                departure_after=None,
                departure_before=None,
                pickup_latitude=None,
                pickup_longitude=None,
                vehicle_type=None,
                sort="departure",
                seats=1,
                limit=20,
                offset=0,
            )
        await _wallet_paid(db_session, make_user, scenario, seat=0)
        _, boarding = await _wallet_paid(db_session, make_user, scenario, seat=1)
        await book(db_session, (await make_user()).id, scenario, seat=2, confirm=False)
        await TripService(db_session).start_trip(scenario.trip_id, scenario.driver_user_id)
        tickets = TicketService(db_session)
        [ticket] = (
            await db_session.scalars(select(Ticket).where(Ticket.booking_id == boarding.id))
        ).all()
        await tickets.validate_qr(
            tickets.get_qr_token(ticket),
            trip_id=scenario.trip_id,
            validated_by=scenario.driver_user_id,
        )

        funnel = await AdminAnalyticsService(db_session).funnel(_today_and_yesterday(), city)

        assert {stage: int(f.value) for stage, f in funnel.items()} == {
            "searches": 2,
            "reserved": 3,
            "paid": 2,
            "boarded": 1,
        }

    async def test_a_search_records_what_it_found(
        self, db_session: AsyncSession, make_user, require_redis: None
    ) -> None:
        scenario, _ = await _scenario(db_session, make_user, minutes=60)
        # Every scenario's stops sit at the same spot; move this one's out of
        # the crowd so the GPS search finds them and nobody else's.
        base = 7.0 + secrets.randbelow(10_000) / 10_000
        for index, stop_id in enumerate(scenario.stop_ids):
            await db_session.execute(
                update(Stop)
                .where(Stop.id == stop_id)
                .values(location=latlng_to_wkt(base + index / 10, -2.0))
            )

        await TripSearchService(db_session, get_redis_client()).search(
            origin_stop_id=None,
            destination_stop_id=scenario.stop_ids[CIRCLE],
            travel_date=(datetime.now(UTC) + timedelta(minutes=60)).date(),
            departure_after=None,
            departure_before=None,
            pickup_latitude=base + 0.0001,
            pickup_longitude=-2.0002,
            vehicle_type=None,
            sort="departure",
            seats=1,
            limit=20,
            offset=0,
        )

        event = (
            await db_session.scalars(
                select(SearchEvent)
                .where(SearchEvent.destination_stop_id == scenario.stop_ids[CIRCLE])
                .order_by(SearchEvent.searched_at.desc())
            )
        ).first()
        assert event is not None
        assert event.origin_stop_id == scenario.stop_ids[0]  # the nearest stop
        expected_cell = (Decimal(str(base + 0.0001)) / Decimal("0.005")).to_integral_value()
        assert event.cell_latitude == (expected_cell * Decimal("0.005")).quantize(Decimal("0.001"))
        assert event.cell_longitude == Decimal("-2.000")
        assert event.results_count >= 1
        assert event.bookable_count >= 1
        assert event.outcome == "ok"


class TestDriverPerformance:
    async def test_counts_behind_the_score(self, db_session: AsyncSession, make_user) -> None:
        scenario, _ = await _scenario(db_session, make_user, minutes=-30)  # will start late
        passenger, booking = await _wallet_paid(db_session, make_user, scenario, seat=0)
        trips = TripService(db_session)
        await trips.start_trip(scenario.trip_id, scenario.driver_user_id)
        await trips.end_trip(scenario.trip_id, scenario.driver_user_id)
        await RatingService(db_session).rate_booking(
            booking.id, passenger_id=passenger.id, score=3, comment="Late"
        )
        db_session.add(
            Complaint(
                filed_by=passenger.id,
                trip_id=scenario.trip_id,
                category=ComplaintCategory.OTHER,
                subject="Late",
                description="Left half an hour late",
            )
        )
        cancelled = await trips.create_trip(
            route_id=scenario.route_id,
            route_schedule_id=None,
            scheduled_departure_at=datetime.now(UTC) - timedelta(minutes=10),
            scheduled_arrival_at=None,
            fare_amount=Decimal("8.00"),
            created_by=None,
        )
        await trips.assign_driver(cancelled.id, scenario.driver_id, assigned_by=None)
        await trips.cancel_trip(cancelled.id, cancelled_by=None, reason="Breakdown")
        await db_session.flush()

        period = _today_and_yesterday()
        counts = (
            await AdminPerformanceRepository(db_session).counts(
                PeriodTrips(period.since, period.until, driver_ids=[scenario.driver_id]),
                grace=timedelta(minutes=5),
            )
        )[scenario.driver_id]

        assert (counts.trips_assigned, counts.trips_completed, counts.trips_cancelled) == (2, 1, 1)
        assert counts.on_time == 0
        assert (counts.ratings, counts.rating_total) == (1, 3)
        assert counts.complaints == 1
        assert (counts.tickets_issued, counts.tickets_scanned) == (1, 0)

    async def test_starting_within_five_minutes_is_on_time(
        self, db_session: AsyncSession, make_user
    ) -> None:
        scenario, _ = await _scenario(db_session, make_user, minutes=2)
        trips = TripService(db_session)
        await trips.start_trip(scenario.trip_id, scenario.driver_user_id)
        await trips.end_trip(scenario.trip_id, scenario.driver_user_id)

        period = _today_and_yesterday()
        counts = (
            await AdminPerformanceRepository(db_session).counts(
                PeriodTrips(period.since, period.until, driver_ids=[scenario.driver_id]),
                grace=timedelta(minutes=5),
            )
        )[scenario.driver_id]

        assert (counts.trips_completed, counts.on_time) == (1, 1)


class TestUserGrowth:
    async def test_activation_and_where_passengers_travel(
        self, db_session: AsyncSession, make_user
    ) -> None:
        scenario, city = await _scenario(db_session, make_user, minutes=60)
        await _wallet_paid(db_session, make_user, scenario, seat=0)
        await make_user()  # signs up, never books
        # Rows made in this transaction share its timestamp: a window around
        # it holds only them.
        started = await db_session.scalar(text("select now()"))
        window = (started, started + timedelta(microseconds=1))
        growth = AdminGrowthRepository(db_session)
        made_here = await db_session.scalar(
            select(func.count(User.id)).where(User.created_at == started)
        )

        signed_up, activated = await growth.activation(
            *window, within=timedelta(days=7), paid_statuses=PAID_BOOKING_STATUSES
        )
        travellers = await growth.travellers_by_city(
            *window, paid_statuses=PAID_BOOKING_STATUSES, limit=50
        )

        assert signed_up == made_here
        assert activated == 1
        assert (city, 1) in travellers

    async def test_a_first_booking_after_a_week_is_not_activation(
        self, db_session: AsyncSession, make_user
    ) -> None:
        scenario, _ = await _scenario(db_session, make_user, minutes=60)
        joined = datetime.now(UTC) - timedelta(days=10) + timedelta(microseconds=7)
        late = await make_user(created_at=joined)
        await book(db_session, late.id, scenario, seat=0)  # paid, 10 days after joining

        signed_up, activated = await AdminGrowthRepository(db_session).activation(
            joined,
            joined + timedelta(microseconds=1),
            within=timedelta(days=7),
            paid_statuses=PAID_BOOKING_STATUSES,
        )

        assert (signed_up, activated) == (1, 0)

    async def test_weekly_retention(self, db_session: AsyncSession, make_user) -> None:
        now = datetime.now(UTC)
        joined = now - timedelta(days=now.weekday() + 21)  # a Monday, 3 weeks back
        user = await make_user(created_at=joined)
        quiet = await make_user(created_at=joined)
        db_session.add(UserSession(user_id=user.id, created_at=joined + timedelta(days=8)))
        await db_session.flush()

        cohorts = await AdminGrowthRepository(db_session).retention(
            joined - timedelta(seconds=1), joined + timedelta(seconds=1)
        )

        [cohort] = cohorts
        assert cohort.size == 2
        assert quiet.id != user.id
        # The window ends right after they joined, so no later week is in it.
        assert cohort.retained == []

        cohorts = await AdminGrowthRepository(db_session).retention(
            joined - timedelta(seconds=1), now
        )
        mine = next(c for c in cohorts if c.week == joined.date())
        assert mine.retained[0] >= 1  # active in the week after joining


class TestPaymentsList:
    async def test_filters(self, db_session: AsyncSession, make_user) -> None:
        scenario, city = await _scenario(db_session, make_user, minutes=60)
        _, booking = await _wallet_paid(db_session, make_user, scenario, seat=0)
        finance = AdminFinanceRepository(db_session)

        async def ids(**filters):
            rows, _ = await finance.list_payments(
                PaymentFilters(**filters), sort="created_at", descending=True, limit=50, offset=0
            )
            return [row.booking_reference for row in rows]

        assert await ids(city=city) == [booking.booking_reference]
        assert await ids(city=city, channels=[PaymentChannel.MTN_MOMO]) == []
        assert await ids(query=booking.booking_reference) == [booking.booking_reference]
        assert await ids(route_id=scenario.route_id) == [booking.booking_reference]
        assert await ids(fleet_id=scenario.fleet_id) == [booking.booking_reference]
