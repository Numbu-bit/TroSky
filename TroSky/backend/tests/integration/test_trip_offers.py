"""Search results with prices (G20), live pickup state and sorting (G21),
and the price a booking is then charged.

The scenario route is Madina -> Legon -> Circle: 20 km, Legon at 10 km, a
GHS 8.00 fare, a 4-seat minibus. With the default settings a seat alone
on half the route costs 4.00, sharing never takes it below a quarter of
that, and TroSky adds 0.50 a seat.
"""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from decimal import Decimal

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ConflictError
from app.core.redis import get_redis_client
from app.models.vehicles import VehicleType
from app.schemas.booking import BookingCreateRequest, PassengerInput
from app.services.booking_service import BookingService
from app.services.tracking_service import LiveLocation, TrackingService
from app.services.trip_search_service import TripSearchService
from app.services.trip_service import TripService
from tests.integration.scenarios import TripScenario, book, build_trip_scenario

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]

MADINA, LEGON, CIRCLE = 0, 1, 2


def _service(session: AsyncSession) -> TripSearchService:
    return TripSearchService(session, get_redis_client())


async def _scenario(session: AsyncSession, make_user, *, minutes_from_now: int = 120):
    departure = datetime.now(UTC) + timedelta(minutes=minutes_from_now)
    return await build_trip_scenario(session, make_user, departure=departure)


async def _search(session: AsyncSession, scenario: TripScenario, **options):
    defaults = {
        "origin_stop_id": scenario.stop_ids[LEGON],
        "destination_stop_id": scenario.stop_ids[CIRCLE],
        "travel_date": datetime.now(UTC).date(),
        "departure_after": None,
        "departure_before": None,
        "pickup_latitude": None,
        "pickup_longitude": None,
        "vehicle_type": None,
        "sort": "departure",
        "seats": 1,
        "limit": 20,
        "offset": 0,
    }
    offers, total = await _service(session).search(**{**defaults, **options})
    return offers, total


def _offer_for(offers, scenario: TripScenario):
    return next(offer for offer in offers if offer.summary.trip_id == scenario.trip_id)


class TestFareOnSearchResults:
    async def test_an_empty_bus_shows_the_solo_price_and_how_low_it_can_go(
        self, db_session: AsyncSession, make_user, require_redis: None
    ) -> None:
        scenario = await _scenario(db_session, make_user)

        offers, _ = await _search(db_session, scenario)

        fare = _offer_for(offers, scenario).fare
        assert fare.solo == Decimal("4.00")  # half of 20 km at GHS 8.00
        assert fare.current == Decimal("4.00")  # nobody to share with yet
        # Three more riders on the whole route: 8 x 10 / (10 + 60) = 1.14
        assert fare.minimum == Decimal("1.14")
        assert fare.platform_fee == Decimal("0.50")
        assert fare.total == Decimal("4.50")
        assert fare.riders_count == 0
        assert fare.currency == "GHS"

    async def test_the_price_falls_once_someone_else_books(
        self, db_session: AsyncSession, make_user, require_redis: None
    ) -> None:
        scenario = await _scenario(db_session, make_user)
        await book(db_session, (await make_user()).id, scenario, seat=0)  # whole route

        offers, _ = await _search(db_session, scenario)

        fare = _offer_for(offers, scenario).fare
        assert fare.riders_count == 1
        assert fare.current == Decimal("2.67")  # 8 x 10 / (20 + 10)
        assert fare.solo == Decimal("4.00")

    async def test_the_quoted_price_is_what_a_booking_is_charged(
        self, db_session: AsyncSession, make_user, require_redis: None
    ) -> None:
        scenario = await _scenario(db_session, make_user)
        await book(db_session, (await make_user()).id, scenario, seat=0)
        quote, _, _ = await _service(db_session).fare_quote(
            scenario.trip_id,
            origin_stop_id=scenario.stop_ids[LEGON],
            destination_stop_id=scenario.stop_ids[CIRCLE],
            seats=2,
        )

        booking = await BookingService(db_session).create_booking(
            (await make_user()).id,
            BookingCreateRequest(
                trip_id=scenario.trip_id,
                passengers=[
                    PassengerInput(seat_id=scenario.seat_ids[1], full_name="Esi Boateng"),
                    PassengerInput(seat_id=scenario.seat_ids[2], full_name="Kofi Boateng"),
                ],
                origin_stop_id=scenario.stop_ids[LEGON],
                destination_stop_id=scenario.stop_ids[CIRCLE],
            ),
            idempotency_key=None,
        )

        assert booking.fare_amount == quote.current * 2
        assert booking.platform_fee == quote.platform_fee
        assert booking.total_amount == quote.total
        assert booking.solo_fare_amount == quote.solo * 2

    async def test_boarding_at_the_start_and_leaving_early_pays_for_the_part_ridden(
        self, db_session: AsyncSession, make_user, require_redis: None
    ) -> None:
        """No boarding stop means the route's start, not the whole route:
        Madina to Legon is half the distance, so half the solo fare."""
        scenario = await _scenario(db_session, make_user)

        booking = await book(
            db_session,
            (await make_user()).id,
            scenario,
            seat=0,
            destination=scenario.stop_ids[LEGON],
        )

        assert booking.fare_amount == Decimal("4.00")


class TestSortingAndFilters:
    async def test_cheapest_puts_the_lower_fare_first_even_if_it_leaves_later(
        self, db_session: AsyncSession, make_user, require_redis: None
    ) -> None:
        scenario = await _scenario(db_session, make_user, minutes_from_now=180)
        trips = TripService(db_session)
        pricier = await trips.create_trip(
            route_id=scenario.route_id,
            route_schedule_id=None,
            scheduled_departure_at=datetime.now(UTC) + timedelta(minutes=90),
            scheduled_arrival_at=None,
            fare_amount=Decimal("12.00"),
            created_by=None,
        )
        await trips.assign_vehicle(pricier.id, scenario.vehicle_id, assigned_by=None)

        by_departure, _ = await _search(db_session, scenario, sort="departure")
        cheapest, _ = await _search(db_session, scenario, sort="cheapest")

        mine = {scenario.trip_id, pricier.id}
        assert [o.summary.trip_id for o in by_departure if o.summary.trip_id in mine] == [
            pricier.id,
            scenario.trip_id,
        ]
        assert [o.summary.trip_id for o in cheapest if o.summary.trip_id in mine] == [
            scenario.trip_id,
            pricier.id,
        ]

    async def test_vehicle_type_filter(
        self, db_session: AsyncSession, make_user, require_redis: None
    ) -> None:
        scenario = await _scenario(db_session, make_user)

        minibuses, _ = await _search(db_session, scenario, vehicle_type=VehicleType.MINIBUS)
        buses, _ = await _search(db_session, scenario, vehicle_type=VehicleType.BUS)

        assert scenario.trip_id in {o.summary.trip_id for o in minibuses}
        assert scenario.trip_id not in {o.summary.trip_id for o in buses}

    async def test_ride_minutes_are_for_the_searched_segment(
        self, db_session: AsyncSession, make_user, require_redis: None
    ) -> None:
        scenario = await _scenario(db_session, make_user)

        offers, _ = await _search(db_session, scenario)

        assert _offer_for(offers, scenario).ride_minutes == 20  # half of 40


async def _on_the_road_at(
    session: AsyncSession, scenario: TripScenario, latitude: float, *, speed: str = "30"
) -> None:
    """Start the trip and report the minibus at ``latitude`` on the route
    (Madina 5.6, Legon 5.7, Circle 5.8; all at longitude -1.0)."""
    await TripService(session).start_trip(scenario.trip_id, scenario.driver_user_id)
    await TrackingService(session, get_redis_client()).record_location(
        scenario.trip_id,
        latitude=latitude,
        longitude=-1.0,
        speed_kmh=Decimal(speed),
        heading_degrees=None,
        accuracy_meters=None,
        recorded_at=datetime.now(UTC),
    )


class TestVehiclesAlreadyOnTheRoad:
    async def test_a_bus_short_of_the_pickup_shows_when_it_arrives(
        self, db_session: AsyncSession, make_user, require_redis: None
    ) -> None:
        scenario = await _scenario(db_session, make_user, minutes_from_now=-5)
        await _on_the_road_at(db_session, scenario, 5.65)  # halfway to Legon

        offers, _ = await _search(db_session, scenario, departure_after=None)

        offer = _offer_for(offers, scenario)
        assert offer.has_passed_pickup is False
        # 5 km of the 20 km route at 30 km/h: 10 minutes.
        assert offer.vehicle_eta_to_pickup_minutes == 10

    async def test_a_bus_past_the_pickup_is_flagged_and_listed_last(
        self, db_session: AsyncSession, make_user, require_redis: None
    ) -> None:
        gone = await _scenario(db_session, make_user, minutes_from_now=-10)
        trips = TripService(db_session)
        next_one = await trips.create_trip(
            route_id=gone.route_id,
            route_schedule_id=None,
            scheduled_departure_at=datetime.now(UTC) + timedelta(minutes=30),
            scheduled_arrival_at=None,
            fare_amount=Decimal("8.00"),
            created_by=None,
        )
        await trips.assign_vehicle(next_one.id, gone.vehicle_id, assigned_by=None)
        await _on_the_road_at(db_session, gone, 5.75)  # between Legon and Circle

        offers, _ = await _search(db_session, gone)

        passed = _offer_for(offers, gone)
        assert passed.has_passed_pickup is True
        assert passed.vehicle_eta_to_pickup_minutes is None
        # It left first, but cannot be caught any more.
        assert [offer.summary.trip_id for offer in offers] == [next_one.id, gone.trip_id]

    async def test_booking_from_a_stop_the_bus_has_passed_is_refused(
        self, db_session: AsyncSession, make_user, require_redis: None
    ) -> None:
        scenario = await _scenario(db_session, make_user, minutes_from_now=-10)
        await _on_the_road_at(db_session, scenario, 5.75)

        with pytest.raises(ConflictError) as refused:
            await book(
                db_session,
                (await make_user()).id,
                scenario,
                seat=0,
                origin=scenario.stop_ids[LEGON],
                confirm=False,
            )

        assert refused.value.code == "PICKUP_ALREADY_PASSED"

    async def test_booking_from_a_stop_still_ahead_works(
        self, db_session: AsyncSession, make_user, require_redis: None
    ) -> None:
        scenario = await _scenario(db_session, make_user, minutes_from_now=-5)
        await _on_the_road_at(db_session, scenario, 5.65)

        booking = await book(
            db_session,
            (await make_user()).id,
            scenario,
            seat=0,
            origin=scenario.stop_ids[LEGON],
            confirm=False,
        )

        assert booking.origin_stop_id == scenario.stop_ids[LEGON]

    async def test_a_moving_bus_cannot_be_booked_from_its_first_stop(
        self, db_session: AsyncSession, make_user, require_redis: None
    ) -> None:
        scenario = await _scenario(db_session, make_user, minutes_from_now=-5)
        await _on_the_road_at(db_session, scenario, 5.65)

        with pytest.raises(ConflictError) as refused:
            await book(db_session, (await make_user()).id, scenario, seat=0, confirm=False)

        assert refused.value.code == "PICKUP_ALREADY_PASSED"


class TestBookingSeesTheLatestPosition:
    async def test_a_ping_not_yet_saved_to_the_database_still_counts(
        self, db_session: AsyncSession, make_user, require_redis: None
    ) -> None:
        """The database keeps a position only every few seconds; the live
        cache has every ping. Search reads the cache, so booking must too,
        or a bus search shows as gone could still be booked."""
        scenario = await _scenario(db_session, make_user, minutes_from_now=-5)
        await _on_the_road_at(db_session, scenario, 5.69)  # saved: just short of Legon
        tracking = TrackingService(db_session, get_redis_client())
        await tracking._cache_location(  # a later ping, cached but not yet saved
            LiveLocation(
                trip_id=scenario.trip_id,
                latitude=5.72,
                longitude=-1.0,
                speed_kmh=Decimal("30"),
                heading_degrees=None,
                recorded_at=datetime.now(UTC),
                is_stale=False,
            )
        )

        with pytest.raises(ConflictError) as refused:
            await BookingService(db_session, get_redis_client()).create_booking(
                (await make_user()).id,
                BookingCreateRequest(
                    trip_id=scenario.trip_id,
                    passengers=[PassengerInput(seat_id=scenario.seat_ids[0], full_name="Esi")],
                    origin_stop_id=scenario.stop_ids[LEGON],
                ),
                idempotency_key=None,
            )

        assert refused.value.code == "PICKUP_ALREADY_PASSED"
