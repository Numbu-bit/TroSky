"""Frontend requests G8 (live trip maps for admins and fleet owners) and
G16 (vehicles near me) -- against a real Postgres and Redis."""

from __future__ import annotations

import uuid
from datetime import UTC, datetime, timedelta
from decimal import Decimal

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.redis import get_redis_client
from app.models.trips import TripStatus
from app.repositories.trip_repository import TripRepository
from app.services.tracking_service import _GEO_SET_KEY, TrackingService
from app.services.trip_service import TripService
from tests.integration.scenarios import TripScenario, build_trip_scenario

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]

# The scenario's first stop, Madina, sits at 5.6N 1.0W.
LATITUDE, LONGITUDE = 5.6, -1.0


def _tracking(db_session: AsyncSession) -> TrackingService:
    return TrackingService(db_session, get_redis_client())


async def _on_the_road(
    db_session: AsyncSession, make_user, *, ping_age: timedelta | None = timedelta(0)
) -> TripScenario:
    """A trip the driver has started, with one GPS ping at Madina (none
    when ``ping_age`` is None)."""
    s = await build_trip_scenario(
        db_session, make_user, departure=datetime.now(UTC) + timedelta(minutes=5)
    )
    await TripService(db_session).start_trip(s.trip_id, s.driver_user_id)
    if ping_age is not None:
        await _tracking(db_session).record_location(
            s.trip_id,
            latitude=LATITUDE,
            longitude=LONGITUDE,
            speed_kmh=None,
            heading_degrees=Decimal("90.00"),
            accuracy_meters=None,
            recorded_at=datetime.now(UTC) - ping_age,
        )
    return s


async def _set_status(db_session: AsyncSession, trip_id: uuid.UUID, status: TripStatus) -> None:
    trip = await TripRepository(db_session).get_by_id(trip_id)
    assert trip is not None
    trip.status = status
    await db_session.flush()


class TestLiveTrips:
    async def test_an_active_trip_shows_its_last_position(
        self, db_session: AsyncSession, make_user, require_redis: None
    ) -> None:
        s = await _on_the_road(db_session, make_user)
        tracking = _tracking(db_session)

        live = {
            summary.trip_id: (summary, location)
            for summary, location in await tracking.list_live_trips()
        }
        summary, location = live[s.trip_id]
        assert summary.status == TripStatus.IN_PROGRESS
        assert summary.vehicle_registration_number == s.registration_number
        assert summary.driver_name == "Test User"
        assert location is not None
        assert (location.latitude, location.longitude) == (LATITUDE, LONGITUDE)
        assert location.heading_degrees == Decimal("90.00")

    async def test_a_fleet_sees_only_its_own_vehicles(
        self, db_session: AsyncSession, make_user, require_redis: None
    ) -> None:
        mine = await _on_the_road(db_session, make_user)
        await _on_the_road(db_session, make_user)  # someone else's fleet
        tracking = _tracking(db_session)

        assert [s.trip_id for s, _ in await tracking.list_live_trips(fleet_id=mine.fleet_id)] == [
            mine.trip_id
        ]
        assert await tracking.list_live_trips(fleet_id=uuid.uuid4()) == []

    async def test_a_trip_not_yet_reporting_is_listed_without_a_position(
        self, db_session: AsyncSession, make_user, require_redis: None
    ) -> None:
        s = await build_trip_scenario(
            db_session, make_user, departure=datetime.now(UTC) + timedelta(minutes=5)
        )
        await _set_status(db_session, s.trip_id, TripStatus.BOARDING)

        [(summary, location)] = await _tracking(db_session).list_live_trips(fleet_id=s.fleet_id)
        assert summary.trip_id == s.trip_id
        assert location is None

    async def test_the_position_survives_losing_the_cache(
        self, db_session: AsyncSession, make_user, require_redis: None
    ) -> None:
        s = await _on_the_road(db_session, make_user)
        await get_redis_client().flushdb()  # as after a Redis restart

        [(_, location)] = await _tracking(db_session).list_live_trips(fleet_id=s.fleet_id)
        assert location is not None
        assert (location.latitude, location.longitude) == (LATITUDE, LONGITUDE)

    async def test_finished_trips_leave_the_map(
        self, db_session: AsyncSession, make_user, require_redis: None
    ) -> None:
        s = await _on_the_road(db_session, make_user)
        await _set_status(db_session, s.trip_id, TripStatus.COMPLETED)
        assert await _tracking(db_session).list_live_trips(fleet_id=s.fleet_id) == []


class TestNearbyVehicles:
    async def test_finds_a_vehicle_near_the_point(
        self, db_session: AsyncSession, make_user, require_redis: None
    ) -> None:
        s = await _on_the_road(db_session, make_user)

        [vehicle] = await _tracking(db_session).find_nearby_vehicles(
            latitude=LATITUDE + 0.0005, longitude=LONGITUDE, radius_m=500, limit=10
        )
        assert vehicle.summary.trip_id == s.trip_id
        assert vehicle.summary.route_name == s.route_name
        assert vehicle.summary.available_seats == 4
        assert 40 < vehicle.distance_m < 70  # 0.0005 degrees of latitude ~ 55 m
        assert vehicle.location.heading_degrees == Decimal("90.00")

    async def test_nothing_is_near_a_far_away_point(
        self, db_session: AsyncSession, make_user, require_redis: None
    ) -> None:
        await _on_the_road(db_session, make_user)
        assert (
            await _tracking(db_session).find_nearby_vehicles(
                latitude=LATITUDE + 1.0, longitude=LONGITUDE, radius_m=5_000, limit=10
            )
            == []
        )

    async def test_old_pings_are_left_out(
        self, db_session: AsyncSession, make_user, require_redis: None
    ) -> None:
        await _on_the_road(db_session, make_user, ping_age=timedelta(minutes=10))
        assert (
            await _tracking(db_session).find_nearby_vehicles(
                latitude=LATITUDE, longitude=LONGITUDE, radius_m=500, limit=10
            )
            == []
        )

    async def test_finished_trips_are_left_out(
        self, db_session: AsyncSession, make_user, require_redis: None
    ) -> None:
        s = await _on_the_road(db_session, make_user)
        await _set_status(db_session, s.trip_id, TripStatus.COMPLETED)
        assert (
            await _tracking(db_session).find_nearby_vehicles(
                latitude=LATITUDE, longitude=LONGITUDE, radius_m=500, limit=10
            )
            == []
        )

    async def test_positions_that_expired_are_pruned_from_the_index(
        self, db_session: AsyncSession, make_user, require_redis: None
    ) -> None:
        redis = get_redis_client()
        gone = str(uuid.uuid4())  # in the index, but its cached position expired
        await redis.geoadd(_GEO_SET_KEY, (LONGITUDE, LATITUDE, gone))

        assert (
            await _tracking(db_session).find_nearby_vehicles(
                latitude=LATITUDE, longitude=LONGITUDE, radius_m=500, limit=10
            )
            == []
        )
        assert await redis.zscore(_GEO_SET_KEY, gone) is None
