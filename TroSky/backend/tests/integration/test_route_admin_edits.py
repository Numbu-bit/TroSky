"""Frontend request G9: admins editing and retiring stops and routes --
against a real Postgres."""

from __future__ import annotations

import uuid
from datetime import UTC, datetime, timedelta
from decimal import Decimal

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ConflictError, NotFoundError
from app.models.routes import DayOfWeek, Route
from app.repositories.route_repository import RouteRepository, StopRepository
from app.services.route_service import RouteService
from app.services.trip_service import TripService

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]


async def _meridian_route(service: RouteService, *, km: str = "200") -> tuple[Route, list]:
    """Three stops 0.1 degrees apart on one meridian -- equal legs -- and a
    route through them."""
    suffix = uuid.uuid4().hex[:6]
    stops = [
        await service.create_stop(
            name=f"M{i}-{suffix}",
            code=f"M{i}{suffix}",
            latitude=5.6 + i / 10,
            longitude=-1.0,
            address=None,
            city=None,
            region=None,
        )
        for i in range(3)
    ]
    route = await service.create_route(
        name=f"Meridian-{suffix}",
        origin_stop_id=stops[0].id,
        destination_stop_id=stops[2].id,
        distance_km=Decimal(km),
        estimated_duration_minutes=120,
        intermediate_stop_ids=[stops[1].id],
        created_by=None,
    )
    return route, stops


async def _offsets(db_session: AsyncSession, route_id: uuid.UUID) -> list:
    return [
        (rs.distance_from_origin_km, rs.estimated_offset_minutes)
        for rs in await RouteRepository(db_session).list_route_stops(route_id)
    ]


class TestEditStops:
    async def test_renaming_a_stop(self, db_session: AsyncSession) -> None:
        service = RouteService(db_session)
        _, stops = await _meridian_route(service)
        updated = await service.update_stop(stops[1].id, name="Legon Junction", city="Accra")
        assert (updated.name, updated.city) == ("Legon Junction", "Accra")

    async def test_moving_a_stop_re_measures_its_routes(self, db_session: AsyncSession) -> None:
        service = RouteService(db_session)
        route, stops = await _meridian_route(service)
        assert await _offsets(db_session, route.id) == [
            (Decimal("0.00"), 0),
            (Decimal("100.00"), 60),
            (Decimal("200.00"), 120),
        ]

        # From halfway to a quarter of the way along.
        await service.update_stop(stops[1].id, latitude=5.65, longitude=-1.0)

        assert await _offsets(db_session, route.id) == [
            (Decimal("0.00"), 0),
            (Decimal("50.00"), 30),
            (Decimal("200.00"), 120),
        ]

    async def test_a_code_already_in_use_is_refused(self, db_session: AsyncSession) -> None:
        service = RouteService(db_session)
        _, stops = await _meridian_route(service)
        with pytest.raises(ConflictError) as exc_info:
            await service.update_stop(stops[1].id, code=stops[0].code)
        assert exc_info.value.code == "STOP_CODE_TAKEN"

    async def test_a_stop_on_an_active_route_cannot_be_retired(
        self, db_session: AsyncSession
    ) -> None:
        service = RouteService(db_session)
        route, stops = await _meridian_route(service)

        with pytest.raises(ConflictError) as exc_info:
            await service.deactivate_stop(stops[1].id)
        assert exc_info.value.code == "STOP_IN_USE"
        assert exc_info.value.details == {"routes": [route.name]}

        await service.deactivate_route(route.id)
        await service.deactivate_stop(stops[1].id)
        assert await StopRepository(db_session).get_by_id(stops[1].id) is None
        with pytest.raises(NotFoundError):
            await service.update_stop(stops[1].id, name="Gone")


class TestEditRoutes:
    async def test_a_new_length_re_measures_the_stops(self, db_session: AsyncSession) -> None:
        service = RouteService(db_session)
        route, _ = await _meridian_route(service)

        updated = await service.update_route(
            route.id, distance_km=Decimal("300"), estimated_duration_minutes=180
        )

        assert updated.distance_km == Decimal("300")
        assert await _offsets(db_session, route.id) == [
            (Decimal("0.00"), 0),
            (Decimal("150.00"), 90),
            (Decimal("300.00"), 180),
        ]

    async def test_a_name_already_in_use_is_refused(self, db_session: AsyncSession) -> None:
        service = RouteService(db_session)
        first, _ = await _meridian_route(service)
        second, _ = await _meridian_route(service)
        with pytest.raises(ConflictError) as exc_info:
            await service.update_route(second.id, name=first.name)
        assert exc_info.value.code == "ROUTE_NAME_TAKEN"

    async def test_a_route_with_trips_to_run_cannot_be_retired(
        self, db_session: AsyncSession
    ) -> None:
        service = RouteService(db_session)
        route, _ = await _meridian_route(service)
        trips = TripService(db_session)
        trip = await trips.create_trip(
            route_id=route.id,
            route_schedule_id=None,
            scheduled_departure_at=datetime.now(UTC) + timedelta(days=1),
            scheduled_arrival_at=None,
            fare_amount=Decimal("10.00"),
            created_by=None,
        )

        with pytest.raises(ConflictError) as exc_info:
            await service.deactivate_route(route.id)
        assert exc_info.value.code == "ROUTE_HAS_ACTIVE_TRIPS"
        assert exc_info.value.details == {"unfinished_trips": 1}

        await trips.cancel_trip(trip.id, cancelled_by=None, reason="Route closed")
        await service.deactivate_route(route.id)
        assert await RouteRepository(db_session).get_by_id(route.id) is None

    async def test_retiring_a_route_stops_its_timetable(self, db_session: AsyncSession) -> None:
        service = RouteService(db_session)
        route, _ = await _meridian_route(service)
        schedule = await service.create_schedule(
            route_id=route.id,
            departure_time=datetime(2031, 1, 1, 6, 30).time(),
            days_of_week=[DayOfWeek.MONDAY],
            fare_amount=Decimal("10.00"),
        )
        await service.deactivate_route(route.id)
        await db_session.refresh(schedule)
        assert schedule.is_active is False
