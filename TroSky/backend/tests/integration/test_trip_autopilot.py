"""Trips change status on their own, from their vehicle's positions and the
clock, as the driver's phone and the worker drive them in production.

Uses the Madina -> Legon -> Circle scenario: stops at (5.6, -1.0),
(5.7, -1.0) and (5.8, -1.0), about 11 km apart.
"""

from __future__ import annotations

import uuid
from datetime import UTC, datetime, timedelta
from decimal import Decimal

import pytest
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings, get_settings
from app.core.exceptions import ConflictError
from app.core.permissions import Permission, Principal
from app.core.redis import get_redis_client
from app.models.bookings import BookingStatus
from app.models.driver_actions import ActedAs, DriverAction, DriverActionKind
from app.models.notifications import Notification
from app.models.payments import RefundRequest, RefundStatus, WalletReferenceType
from app.models.trips import Trip, TripEvent, TripEventType, TripStatus, TripStatusHistory
from app.providers.payments.base import PaymentChannel
from app.services.admin_ops_service import AdminOpsService
from app.services.alighting_service import AlightingService
from app.services.payment_service import PaymentService
from app.services.tracking_service import TrackingService
from app.services.trip_autopilot import TripAutopilot
from app.services.trip_service import TripService
from app.services.wallet_service import WalletService
from tests.integration.scenarios import TripScenario, book, build_trip_scenario

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]

MADINA, LEGON, CIRCLE = (5.6, -1.0), (5.7, -1.0), (5.8, -1.0)
BETWEEN = (5.65, -1.0)  # halfway to Legon, nowhere near a stop


def _settings(**changes: object) -> Settings:
    return get_settings().model_copy(update={"TRIP_AUTO_STATUS_ENABLED": True, **changes})


def _north(point: tuple[float, float], metres: float) -> tuple[float, float]:
    return point[0] + metres / 111_320, point[1]


async def _ping(
    session: AsyncSession,
    scenario: TripScenario,
    point: tuple[float, float],
    at: datetime,
    settings: Settings | None = None,
) -> TripStatus:
    """What ``POST /driver-trips/{id}/location`` does with a position: the
    trip's status afterwards."""
    settings = settings or _settings()
    redis = get_redis_client()
    live = await TrackingService(session, redis, settings).record_location(
        scenario.trip_id,
        latitude=point[0],
        longitude=point[1],
        speed_kmh=None,
        heading_degrees=None,
        accuracy_meters=Decimal("10"),
        recorded_at=at,
    )
    await AlightingService(session, redis, settings).on_vehicle_moved(
        scenario.trip_id, live.latitude, live.longitude
    )
    await TripAutopilot(session, redis, settings).after_position(
        scenario.trip_id,
        latitude=live.latitude,
        longitude=live.longitude,
        recorded_at=live.recorded_at,
        accuracy_meters=Decimal("10"),
    )
    return await _status(session, scenario.trip_id)


async def _status(session: AsyncSession, trip_id: uuid.UUID) -> TripStatus:
    trip = await session.get(Trip, trip_id, populate_existing=True)
    assert trip is not None
    return trip.status


async def _history(session: AsyncSession, trip_id: uuid.UUID) -> list[TripStatusHistory]:
    rows = await session.execute(
        select(TripStatusHistory)
        .where(TripStatusHistory.trip_id == trip_id)
        .order_by(TripStatusHistory.created_at)
    )
    return list(rows.scalars())


async def _scenario(session: AsyncSession, make_user, *, departs_in: timedelta) -> TripScenario:
    return await build_trip_scenario(session, make_user, departure=datetime.now(UTC) + departs_in)


async def _paid(session: AsyncSession, make_user, scenario: TripScenario, *, seat: int, **kw):
    """A passenger who booked a seat and paid from their wallet."""
    passenger = await make_user()
    booking = await book(session, passenger.id, scenario, seat=seat, confirm=False, **kw)
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


async def _depart_at(session: AsyncSession, scenario: TripScenario, when: datetime) -> None:
    """Move the departure time (bookings are taken before it is in the past)."""
    trip = await session.get(Trip, scenario.trip_id)
    assert trip is not None
    trip.scheduled_departure_at = when
    await session.flush()


class TestFromPositions:
    async def test_boards_starts_and_arrives_with_nobody_pressing_a_button(
        self, db_session: AsyncSession, make_user, require_redis: None
    ) -> None:
        scenario = await _scenario(db_session, make_user, departs_in=timedelta(minutes=20))
        _, booking = await _paid(db_session, make_user, scenario, seat=0)
        t0 = datetime.now(UTC)

        assert await _ping(db_session, scenario, MADINA, t0) == TripStatus.BOARDING
        left = _north(MADINA, 500)
        assert await _ping(db_session, scenario, left, t0 + timedelta(minutes=2)) == (
            TripStatus.IN_PROGRESS
        )
        assert await _ping(db_session, scenario, LEGON, t0 + timedelta(minutes=15)) == (
            TripStatus.IN_PROGRESS
        )
        assert await _ping(db_session, scenario, CIRCLE, t0 + timedelta(minutes=30)) == (
            TripStatus.IN_PROGRESS
        )
        assert await _ping(db_session, scenario, CIRCLE, t0 + timedelta(minutes=34)) == (
            TripStatus.COMPLETED
        )

        history = await _history(db_session, scenario.trip_id)
        assert [(h.to_status, h.changed_by, h.reason) for h in history] == [
            (TripStatus.BOARDING, None, "Vehicle at the first stop"),
            (TripStatus.IN_PROGRESS, None, "Vehicle left the first stop"),
            (TripStatus.COMPLETED, None, "At the last stop for 3 minutes"),
        ]
        trip = await db_session.get(Trip, scenario.trip_id)
        assert trip is not None
        assert trip.actual_departure_at is not None
        assert trip.actual_arrival_at is not None
        await db_session.refresh(booking)
        assert booking.status == BookingStatus.COMPLETED
        actions = (
            await db_session.execute(
                select(DriverAction.kind, DriverAction.acted_as).where(
                    DriverAction.trip_id == scenario.trip_id
                )
            )
        ).all()
        assert (DriverActionKind.TRIP_STARTED, ActedAs.SYSTEM) in actions
        assert (DriverActionKind.TRIP_ENDED, ActedAs.SYSTEM) in actions
        events = (
            await db_session.execute(
                select(TripEvent.event_type).where(TripEvent.trip_id == scenario.trip_id)
            )
        ).scalars()
        assert TripEventType.BOARDING_STARTED in set(events)

    async def test_positions_long_before_departure_are_refused(
        self, db_session: AsyncSession, make_user, require_redis: None
    ) -> None:
        scenario = await _scenario(db_session, make_user, departs_in=timedelta(hours=2))
        with pytest.raises(ConflictError) as raised:
            await _ping(db_session, scenario, MADINA, datetime.now(UTC))
        assert raised.value.code == "TRIP_NOT_IN_PROGRESS"
        assert "30 minutes before departure" in raised.value.message

    async def test_switched_off_only_trips_in_progress_take_positions(
        self, db_session: AsyncSession, make_user, require_redis: None
    ) -> None:
        scenario = await _scenario(db_session, make_user, departs_in=timedelta(minutes=10))
        off = _settings(TRIP_AUTO_STATUS_ENABLED=False)
        with pytest.raises(ConflictError, match="only accepted while a trip is in progress"):
            await _ping(db_session, scenario, MADINA, datetime.now(UTC), off)

        await TripService(db_session).start_trip(scenario.trip_id, scenario.driver_user_id)
        for minutes in (0, 30):  # standing still: nothing happens on its own
            status = await _ping(
                db_session, scenario, BETWEEN, datetime.now(UTC) + timedelta(minutes=minutes), off
            )
            assert status == TripStatus.IN_PROGRESS

    async def test_passing_a_passengers_stop_on_the_way_to_the_first_lands_nobody(
        self, db_session: AsyncSession, make_user, require_redis: None
    ) -> None:
        scenario = await _scenario(db_session, make_user, departs_in=timedelta(minutes=25))
        _, booking = await _paid(
            db_session,
            make_user,
            scenario,
            seat=0,
            origin=scenario.stop_ids[0],
            destination=scenario.stop_ids[1],
        )

        status = await _ping(db_session, scenario, LEGON, datetime.now(UTC))

        assert status == TripStatus.SCHEDULED  # before departure: maybe on its way
        await db_session.refresh(booking)
        assert booking.status == BookingStatus.CONFIRMED

    async def test_standing_still_pauses_and_moving_resumes(
        self, db_session: AsyncSession, make_user, require_redis: None
    ) -> None:
        scenario = await _scenario(db_session, make_user, departs_in=timedelta(minutes=5))
        await TripService(db_session).start_trip(scenario.trip_id, scenario.driver_user_id)
        t0 = datetime.now(UTC)

        assert await _ping(db_session, scenario, BETWEEN, t0) == TripStatus.IN_PROGRESS
        assert await _ping(db_session, scenario, BETWEEN, t0 + timedelta(minutes=10)) == (
            TripStatus.IN_PROGRESS
        )
        assert await _ping(db_session, scenario, BETWEEN, t0 + timedelta(minutes=21)) == (
            TripStatus.PAUSED
        )
        moved = _north(BETWEEN, 200)
        assert await _ping(db_session, scenario, moved, t0 + timedelta(minutes=23)) == (
            TripStatus.IN_PROGRESS
        )

        reasons = [(h.to_status, h.reason) for h in await _history(db_session, scenario.trip_id)]
        assert reasons[-2:] == [
            (TripStatus.PAUSED, "Not moved for 20 minutes"),
            (TripStatus.IN_PROGRESS, "Vehicle moving again"),
        ]

    async def test_resumed_by_hand_where_it_stands_it_gets_the_full_time_again(
        self, db_session: AsyncSession, make_user, require_redis: None
    ) -> None:
        scenario = await _scenario(db_session, make_user, departs_in=timedelta(minutes=5))
        trips = TripService(db_session)
        await trips.start_trip(scenario.trip_id, scenario.driver_user_id)
        t0 = datetime.now(UTC)
        await _ping(db_session, scenario, BETWEEN, t0)
        assert await _ping(db_session, scenario, BETWEEN, t0 + timedelta(minutes=20)) == (
            TripStatus.PAUSED
        )

        await trips.resume_trip(scenario.trip_id, scenario.driver_user_id)

        assert await _ping(db_session, scenario, BETWEEN, t0 + timedelta(minutes=25)) == (
            TripStatus.IN_PROGRESS
        )

    async def test_a_change_it_cannot_make_does_not_fail_the_position(
        self, db_session: AsyncSession, make_user, require_redis: None
    ) -> None:
        busy = await _scenario(db_session, make_user, departs_in=timedelta(minutes=-30))
        trips = TripService(db_session)
        await trips.start_trip(busy.trip_id, busy.driver_user_id)
        # The same driver's next trip, while the first is still going.
        nxt = await _scenario(db_session, make_user, departs_in=timedelta(minutes=10))
        await trips.assign_driver(nxt.trip_id, busy.driver_id, assigned_by=None)
        nxt = TripScenario(**{**nxt.__dict__, "driver_user_id": busy.driver_user_id})
        t0 = datetime.now(UTC)

        assert await _ping(db_session, nxt, MADINA, t0) == TripStatus.BOARDING
        left = _north(MADINA, 500)
        assert await _ping(db_session, nxt, left, t0 + timedelta(minutes=1)) == (
            TripStatus.BOARDING
        )


class TestTicketScans:
    async def test_the_first_ticket_scanned_starts_boarding(
        self, db_session: AsyncSession, make_user
    ) -> None:
        scenario = await _scenario(db_session, make_user, departs_in=timedelta(hours=1))
        booking = await book(db_session, (await make_user()).id, scenario, seat=0)
        trips = TripService(db_session, _settings())

        for _ in range(2):  # the second scan changes nothing more
            await trips.record_ticket_scan(
                scenario.trip_id,
                driver_id=scenario.driver_id,
                actor_id=scenario.driver_user_id,
                booking_id=booking.id,
                ticket_reference="TKT-1",
            )

        assert await _status(db_session, scenario.trip_id) == TripStatus.BOARDING
        [boarding] = await _history(db_session, scenario.trip_id)
        assert boarding.reason == "First ticket scanned"

    async def test_not_when_switched_off(self, db_session: AsyncSession, make_user) -> None:
        scenario = await _scenario(db_session, make_user, departs_in=timedelta(hours=1))
        booking = await book(db_session, (await make_user()).id, scenario, seat=0)
        await TripService(db_session).record_ticket_scan(
            scenario.trip_id,
            driver_id=scenario.driver_id,
            actor_id=scenario.driver_user_id,
            booking_id=booking.id,
            ticket_reference="TKT-1",
        )
        assert await _status(db_session, scenario.trip_id) == TripStatus.SCHEDULED


class TestTheClock:
    async def test_quiet_on_the_road_is_paused_and_quiet_at_the_end_is_arrived(
        self, db_session: AsyncSession, make_user, require_redis: None
    ) -> None:
        now = datetime.now(UTC)
        stuck = await _scenario(db_session, make_user, departs_in=timedelta(minutes=-40))
        there = await _scenario(db_session, make_user, departs_in=timedelta(minutes=-40))
        trips = TripService(db_session)
        for scenario in (stuck, there):
            await trips.start_trip(scenario.trip_id, scenario.driver_user_id)
        await _ping(db_session, stuck, BETWEEN, now - timedelta(minutes=25))
        await _ping(db_session, there, CIRCLE, now - timedelta(minutes=12))

        result = await TripAutopilot(db_session, get_redis_client(), _settings()).sweep(now)

        # Only these two trips' vehicles were ever heard from.
        assert (result.paused, result.completed) == (1, 1)
        assert await _status(db_session, stuck.trip_id) == TripStatus.PAUSED
        assert await _status(db_session, there.trip_id) == TripStatus.COMPLETED
        [*_, arrived] = await _history(db_session, there.trip_id)
        assert arrived.reason == "GPS went quiet at the last stop"

    async def test_a_trip_that_never_started_is_cancelled_and_its_passengers_refunded(
        self, db_session: AsyncSession, make_user, require_redis: None
    ) -> None:
        scenario = await _scenario(db_session, make_user, departs_in=timedelta(hours=3))
        passenger, booking = await _paid(db_session, make_user, scenario, seat=0)
        now = datetime.now(UTC)
        await _depart_at(db_session, scenario, now - timedelta(hours=2, minutes=1))

        result = await TripAutopilot(db_session, get_redis_client(), _settings()).sweep(now)

        assert result.cancelled >= 1
        assert await _status(db_session, scenario.trip_id) == TripStatus.CANCELLED
        [cancelled] = await _history(db_session, scenario.trip_id)
        assert cancelled.changed_by is None
        assert cancelled.reason == "Not started 2 hours after its departure time"
        await db_session.refresh(booking)
        assert booking.status == BookingStatus.REFUND_PENDING
        refund = (
            await db_session.execute(
                select(RefundRequest).where(RefundRequest.booking_id == booking.id)
            )
        ).scalar_one()
        assert refund.status == RefundStatus.PENDING  # an admin approves it
        told = (
            await db_session.execute(
                select(Notification.user_id).where(Notification.title == "Trip cancelled")
            )
        ).scalars()
        assert {passenger.id, scenario.driver_user_id} <= set(told)

    async def test_trips_with_a_vehicle_about_are_left_to_the_team(
        self, db_session: AsyncSession, make_user, require_redis: None
    ) -> None:
        now = datetime.now(UTC)
        late = now - timedelta(hours=3)
        boarding = await _scenario(db_session, make_user, departs_in=timedelta(hours=1))
        heard_from = await _scenario(db_session, make_user, departs_in=timedelta(hours=1))
        too_old = await _scenario(db_session, make_user, departs_in=timedelta(hours=1))
        await TripService(db_session).begin_boarding(
            boarding.trip_id, reason="First ticket scanned"
        )
        for scenario in (boarding, heard_from):
            await _depart_at(db_session, scenario, late)
        await _depart_at(db_session, too_old, now - timedelta(hours=30))
        autopilot = TripAutopilot(db_session, get_redis_client(), _settings())
        # Its phone sent a position from somewhere off the route recently.
        await autopilot.after_position(
            heard_from.trip_id, latitude=6.2, longitude=-1.0, recorded_at=now - timedelta(minutes=5)
        )

        await autopilot.sweep(now)

        assert await _status(db_session, boarding.trip_id) == TripStatus.BOARDING
        assert await _status(db_session, heard_from.trip_id) == TripStatus.SCHEDULED
        assert await _status(db_session, too_old.trip_id) == TripStatus.SCHEDULED

    async def test_never_cancelled_when_switched_off(
        self, db_session: AsyncSession, make_user, require_redis: None
    ) -> None:
        scenario = await _scenario(db_session, make_user, departs_in=timedelta(hours=1))
        now = datetime.now(UTC)
        await _depart_at(db_session, scenario, now - timedelta(hours=3))

        for settings in (
            _settings(TRIP_AUTO_STATUS_ENABLED=False),
            _settings(TRIP_NOT_STARTED_CANCEL_MINUTES=0),
        ):
            await TripAutopilot(db_session, get_redis_client(), settings).sweep(now)

        assert await _status(db_session, scenario.trip_id) == TripStatus.SCHEDULED


class TestNotStartedAlert:
    async def test_the_team_is_alerted_to_trips_not_started(
        self, db_session: AsyncSession, make_user
    ) -> None:
        now = datetime.now(UTC)
        late = await _scenario(db_session, make_user, departs_in=timedelta(hours=1))
        on_time = await _scenario(db_session, make_user, departs_in=timedelta(hours=1))
        await _depart_at(db_session, late, now - timedelta(minutes=16))
        await _depart_at(db_session, on_time, now - timedelta(minutes=10))
        watcher = Principal(
            user_id=uuid.uuid4(),
            session_id=uuid.uuid4(),
            roles=frozenset({"admin"}),
            permissions=frozenset({Permission.TRIPS_MONITOR_LIVE.value}),
        )

        alerts, counts = await AdminOpsService(db_session).alerts(watcher, limit=500)

        mine = {a.entity_id: a for a in alerts if a.type == "trip_not_started"}
        assert late.trip_id in mine
        assert on_time.trip_id not in mine
        alert = mine[late.trip_id]
        assert alert.severity == "high"
        assert alert.entity_type == "trip"
        assert alert.details["route_name"] == late.route_name
        assert alert.details["status"] == "scheduled"
        assert counts["trip_not_started"] >= 1

    async def test_admins_without_trip_permissions_do_not_see_them(
        self, db_session: AsyncSession, make_user
    ) -> None:
        late = await _scenario(db_session, make_user, departs_in=timedelta(hours=1))
        await _depart_at(db_session, late, datetime.now(UTC) - timedelta(minutes=30))
        reviewer = Principal(
            user_id=uuid.uuid4(),
            session_id=uuid.uuid4(),
            roles=frozenset({"admin"}),
            permissions=frozenset({Permission.COMPLAINTS_MANAGE.value}),
        )
        _, counts = await AdminOpsService(db_session).alerts(reviewer, limit=500)
        assert "trip_not_started" not in counts
