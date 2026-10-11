"""Demand heat maps against a real database: where and when people search
and book, what is withheld to protect them, and where searches go unmet.

Each test gives its stops a city of their own and filters by it, so other
tests' searches and bookings stay out of the figures.
"""

from __future__ import annotations

import secrets
from datetime import UTC, date, datetime, time, timedelta
from decimal import Decimal

import pytest
from sqlalchemy import update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.analytics import SearchEvent
from app.models.routes import Stop
from app.repositories.admin_demand_repository import AdminDemandRepository, DemandFilters
from app.schemas.booking import BookingCreateRequest, PassengerInput
from app.services.admin_analytics_service import AdminAnalyticsService, Period
from app.services.booking_service import BookingService
from tests.integration.scenarios import TripScenario, book, build_trip_scenario

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]

MADINA, LEGON, CIRCLE = 0, 1, 2  # the scenario's stops: 5.6, 5.7 and 5.8 north, 1.0 west


async def _place(session: AsyncSession, make_user) -> tuple[TripScenario, str]:
    scenario = await build_trip_scenario(
        session, make_user, departure=datetime.now(UTC) + timedelta(hours=2)
    )
    city = f"Demandville {secrets.token_hex(3)}"
    await session.execute(update(Stop).where(Stop.id.in_(scenario.stop_ids)).values(city=city))
    return scenario, city


def _at(day: date, hour: int, minute: int = 0) -> datetime:
    return datetime.combine(day, time(hour, minute), tzinfo=UTC)  # Ghana time is UTC


async def _search(
    session: AsyncSession,
    scenario: TripScenario,
    *,
    when: datetime,
    origin: int = LEGON,
    destination: int | None = CIRCLE,
    cell: tuple[str, str] | None = None,
    bookable: int = 1,
) -> None:
    session.add(
        SearchEvent(
            searched_at=when,
            travel_date=when.date(),
            origin_stop_id=scenario.stop_ids[origin],
            destination_stop_id=scenario.stop_ids[destination] if destination is not None else None,
            cell_latitude=Decimal(cell[0]) if cell else None,
            cell_longitude=Decimal(cell[1]) if cell else None,
            results_count=max(bookable, 1),
            bookable_count=bookable,
            outcome="ok",
        )
    )
    await session.flush()


def _yesterday() -> date:
    return datetime.now(UTC).date() - timedelta(days=1)


def _filters(
    city: str,
    *,
    days: list[int] | None = None,
    hour_from: int | None = None,
    hour_to: int | None = None,
) -> DemandFilters:
    day = _yesterday()
    return DemandFilters(
        since=_at(day - timedelta(days=6), 0),
        until=_at(day + timedelta(days=2), 0),
        city=city,
        days=days,
        hour_from=hour_from,
        hour_to=hour_to,
    )


class TestTheMap:
    async def test_cells_without_singling_anyone_out(
        self, db_session: AsyncSession, make_user
    ) -> None:
        scenario, city = await _place(db_session, make_user)
        when = _at(_yesterday(), 7, 30)
        for _ in range(4):
            await _search(db_session, scenario, when=when, cell=("5.650", "-0.185"))
        await _search(db_session, scenario, when=when, cell=("5.700", "-0.200"))  # alone
        for _ in range(2):  # by stop: placed at Madina, 5.6 N 1.0 W
            await _search(db_session, scenario, when=when, origin=MADINA)
        demand = AdminDemandRepository(db_session)

        cells, withheld = await demand.cells("searches", _filters(city))
        total = await demand.total("searches", _filters(city))

        assert [(c.latitude, c.longitude, c.weight) for c in cells] == [
            (Decimal("5.650"), Decimal("-0.185"), 4)
        ]
        assert withheld == 3  # one search alone in its cell, two at Madina
        assert total == 7

    async def test_a_stop_search_lands_on_the_same_grid(
        self, db_session: AsyncSession, make_user
    ) -> None:
        scenario, city = await _place(db_session, make_user)
        for minute in range(3):
            await _search(db_session, scenario, when=_at(_yesterday(), 9, minute), origin=MADINA)

        cells, _ = await AdminDemandRepository(db_session).cells("searches", _filters(city))

        assert [(c.latitude, c.longitude, c.weight) for c in cells] == [
            (Decimal("5.600"), Decimal("-1.000"), 3)
        ]

    async def test_bookings_count_seats_at_the_pickup_stop(
        self, db_session: AsyncSession, make_user
    ) -> None:
        scenario, city = await _place(db_session, make_user)
        bookings = BookingService(db_session)
        pair = await bookings.create_booking(  # two seats in one booking
            (await make_user()).id,
            BookingCreateRequest(
                trip_id=scenario.trip_id,
                passengers=[
                    PassengerInput(seat_id=scenario.seat_ids[0], full_name="Ama"),
                    PassengerInput(seat_id=scenario.seat_ids[1], full_name="Kofi"),
                ],
                origin_stop_id=scenario.stop_ids[LEGON],
                destination_stop_id=scenario.stop_ids[CIRCLE],
            ),
            idempotency_key=None,
        )
        await bookings.confirm_booking(pair.id)
        await book(db_session, (await make_user()).id, scenario, seat=2, confirm=False)  # unpaid
        today = datetime.now(UTC).date()
        filters = DemandFilters(
            since=_at(today, 0), until=_at(today + timedelta(days=1), 0), city=city
        )
        demand = AdminDemandRepository(db_session)

        cells, withheld = await demand.cells("bookings", filters)
        origins = await demand.top_origins("bookings", filters)
        pairs = await demand.top_pairs("bookings", filters)

        assert [(c.latitude, c.longitude, c.weight) for c in cells] == [
            (Decimal("5.700"), Decimal("-1.000"), 2)
        ]
        assert withheld == 0  # a stop is a public place
        assert [(o.stop_id, o.weight) for o in origins] == [(scenario.stop_ids[LEGON], 2)]
        assert [(p.origin_stop_id, p.destination_stop_id, p.weight) for p in pairs] == [
            (scenario.stop_ids[LEGON], scenario.stop_ids[CIRCLE], 2)
        ]


class TestWhereAndWhen:
    async def test_busiest_stops_and_journeys(self, db_session: AsyncSession, make_user) -> None:
        scenario, city = await _place(db_session, make_user)
        when = _at(_yesterday(), 8)
        for _ in range(3):
            await _search(db_session, scenario, when=when, origin=LEGON, destination=CIRCLE)
        await _search(db_session, scenario, when=when, origin=MADINA, destination=CIRCLE)
        await _search(db_session, scenario, when=when, origin=MADINA, destination=None)
        demand = AdminDemandRepository(db_session)

        origins = await demand.top_origins("searches", _filters(city))
        pairs = await demand.top_pairs("searches", _filters(city))

        assert [(o.stop_id, o.weight) for o in origins] == [
            (scenario.stop_ids[LEGON], 3),
            (scenario.stop_ids[MADINA], 2),
        ]
        assert origins[0].city == city
        assert [(p.origin_stop_id, p.weight) for p in pairs] == [
            (scenario.stop_ids[LEGON], 3),
            (scenario.stop_ids[MADINA], 1),  # a search with no destination is no journey
        ]

    async def test_the_week_hour_by_hour(self, db_session: AsyncSession, make_user) -> None:
        scenario, city = await _place(db_session, make_user)
        day = _yesterday()
        for hour in (7, 7, 18):
            await _search(db_session, scenario, when=_at(day, hour, 15))

        grid = await AdminDemandRepository(db_session).by_day_and_hour("searches", _filters(city))

        assert grid == {(day.isoweekday(), 7): 2, (day.isoweekday(), 18): 1}

    async def test_days_and_hours_narrow_it(self, db_session: AsyncSession, make_user) -> None:
        scenario, city = await _place(db_session, make_user)
        day = _yesterday()
        for hour in (2, 7, 12, 23):
            await _search(db_session, scenario, when=_at(day, hour))
        other_day = day - timedelta(days=1)
        await _search(db_session, scenario, when=_at(other_day, 7))
        demand = AdminDemandRepository(db_session)

        async def total(
            days: list[int] | None = None, hour_from: int | None = None, hour_to: int | None = None
        ) -> int:
            filters = _filters(city, days=days, hour_from=hour_from, hour_to=hour_to)
            return await demand.total("searches", filters)

        assert await total() == 5
        assert await total(days=[day.isoweekday()]) == 4
        assert await total(hour_from=6, hour_to=12) == 3  # both 07:00s and noon
        assert await total(hour_from=22, hour_to=5) == 2  # past midnight: 23:00 and 02:00
        assert await total(days=[other_day.isoweekday()], hour_from=7, hour_to=7) == 1


class TestUnmetDemand:
    async def test_where_searches_found_nothing_to_book(
        self, db_session: AsyncSession, make_user
    ) -> None:
        scenario, city = await _place(db_session, make_user)
        when = _at(_yesterday(), 17)
        for bookable in (0, 0, 0, 2, 1):
            await _search(db_session, scenario, when=when, origin=LEGON, bookable=bookable)
        await _search(db_session, scenario, when=when, origin=MADINA, bookable=0)
        await _search(db_session, scenario, when=when, origin=CIRCLE, bookable=3)  # all met
        demand = AdminDemandRepository(db_session)

        gaps = await demand.supply_gaps(_filters(city))
        unmet = await demand.total("unmet", _filters(city))

        assert [(g.stop_id, g.searches, g.unmet) for g in gaps] == [
            (scenario.stop_ids[LEGON], 5, 3),
            (scenario.stop_ids[MADINA], 1, 1),
        ]
        assert unmet == 4


class TestTheReport:
    async def test_against_the_period_before(self, db_session: AsyncSession, make_user) -> None:
        scenario, city = await _place(db_session, make_user)
        today = datetime.now(UTC).date()
        for _ in range(3):
            await _search(db_session, scenario, when=_at(today - timedelta(days=1), 10))
        await _search(db_session, scenario, when=_at(today - timedelta(days=9), 10))  # before

        report = await AdminAnalyticsService(db_session).demand(
            Period(today - timedelta(days=6), today),
            "searches",
            city=city,
            days=None,
            hour_from=None,
            hour_to=None,
        )

        assert (report.total, report.previous_total) == (3, 1)
        assert sum(report.by_day_and_hour.values()) == 3
        # Searches by stop, placed at Legon: three, enough to show.
        assert [(c.latitude, c.longitude, c.weight) for c in report.cells] == [
            (Decimal("5.700"), Decimal("-1.000"), 3)
        ]
        assert [(g.stop_id, g.unmet) for g in report.supply_gaps] == []
