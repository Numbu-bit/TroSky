"""Integration tests for RouteService: stops, routes, schedules, trip
search, and trip-seat lookup — against a real Postgres."""

from __future__ import annotations

import uuid
from datetime import UTC, date, datetime, time, timedelta
from decimal import Decimal

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ConflictError, NotFoundError
from app.models.vehicles import VehicleType
from app.providers.storage.malware_scan import NoOpMalwareScanner
from app.providers.storage.sandbox import SandboxStorageProvider
from app.repositories.route_repository import RouteRepository
from app.schemas.fleet import (
    FleetCreateRequest,
    FleetOwnerRegisterRequest,
    SeatInput,
    SeatLayoutRequest,
    VehicleCreateRequest,
)
from app.services.fleet_service import FleetService
from app.services.route_service import RouteService
from app.services.trip_service import TripService

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]


class TestStopsAndRoutes:
    async def test_create_stop(self, db_session: AsyncSession, make_user) -> None:
        service = RouteService(db_session)
        stop = await service.create_stop(
            name="Circle",
            code=f"CIR-{uuid.uuid4().hex[:6]}",
            latitude=5.5713,
            longitude=-0.2051,
            address="Circle Interchange",
            city="Accra",
            region="Greater Accra",
        )
        assert stop.name == "Circle"

    async def test_create_route_with_intermediate_stops(
        self, db_session: AsyncSession, make_user
    ) -> None:
        service = RouteService(db_session)
        origin = await service.create_stop(
            name="Circle",
            code=None,
            latitude=5.5713,
            longitude=-0.2051,
            address=None,
            city="Accra",
            region=None,
        )
        waypoint = await service.create_stop(
            name="Nkawkaw",
            code=None,
            latitude=6.5514,
            longitude=-0.7716,
            address=None,
            city="Nkawkaw",
            region=None,
        )
        destination = await service.create_stop(
            name="Kejetia",
            code=None,
            latitude=6.6935,
            longitude=-1.6291,
            address=None,
            city="Kumasi",
            region=None,
        )

        route = await service.create_route(
            name=f"Accra-Kumasi-{uuid.uuid4().hex[:8]}",
            origin_stop_id=origin.id,
            destination_stop_id=destination.id,
            distance_km=Decimal("250.00"),
            estimated_duration_minutes=240,
            intermediate_stop_ids=[waypoint.id],
            created_by=None,
        )
        stops = await service.get_route_stops(route.id)
        assert [s.id for s in stops] == [origin.id, waypoint.id, destination.id]


class TestSearch:
    async def _setup_searchable_trip(self, db_session: AsyncSession, make_user):
        route_service = RouteService(db_session)
        origin = await route_service.create_stop(
            name="Circle",
            code=None,
            latitude=5.5713,
            longitude=-0.2051,
            address=None,
            city="Accra",
            region=None,
        )
        destination = await route_service.create_stop(
            name="Kejetia",
            code=None,
            latitude=6.6935,
            longitude=-1.6291,
            address=None,
            city="Kumasi",
            region=None,
        )
        route = await route_service.create_route(
            name=f"Accra-Kumasi-{uuid.uuid4().hex[:8]}",
            origin_stop_id=origin.id,
            destination_stop_id=destination.id,
            distance_km=None,
            estimated_duration_minutes=240,
            intermediate_stop_ids=[],
            created_by=None,
        )

        fleet_service = FleetService(db_session, SandboxStorageProvider(), NoOpMalwareScanner())
        owner_user_id = (await make_user()).id
        await fleet_service.register(
            owner_user_id, FleetOwnerRegisterRequest(business_name="XY Co")
        )
        fleet = await fleet_service.create_fleet(owner_user_id, FleetCreateRequest(name="Fleet F"))
        vehicle = await fleet_service.create_vehicle(
            owner_user_id,
            fleet.id,
            VehicleCreateRequest(
                registration_number=f"GR-{uuid.uuid4().hex[:6].upper()}",
                vehicle_type=VehicleType.BUS,
                capacity=4,
            ),
        )
        await fleet_service.set_seat_layout(
            owner_user_id,
            vehicle.id,
            SeatLayoutRequest(
                rows=2,
                columns=2,
                seats=[
                    SeatInput(seat_number="1A", row_number=1, column_number=1),
                    SeatInput(seat_number="1B", row_number=1, column_number=2),
                    SeatInput(seat_number="2A", row_number=2, column_number=1),
                    SeatInput(seat_number="2B", row_number=2, column_number=2),
                ],
            ),
        )

        await fleet_service.approve_vehicle(
            vehicle.id, reviewer_id=(await make_user()).id, notes=None
        )

        trip_service = TripService(db_session)

        departure = datetime.combine(date.today() + timedelta(days=1), time(8, 0), tzinfo=UTC)
        trip = await trip_service.create_trip(
            route_id=route.id,
            route_schedule_id=None,
            scheduled_departure_at=departure,
            scheduled_arrival_at=None,
            fare_amount=Decimal("30.00"),
            created_by=None,
        )
        await trip_service.assign_vehicle(trip.id, vehicle.id, assigned_by=None)
        return route_service, route, trip, origin, destination

    async def test_search_returns_trip_within_window(
        self, db_session: AsyncSession, make_user
    ) -> None:
        route_service, route, trip, origin, destination = await self._setup_searchable_trip(
            db_session, make_user
        )
        trips, total = await route_service.search_trips(
            origin_stop_ids=[origin.id],
            destination_stop_id=destination.id,
            travel_date=trip.scheduled_departure_at.date(),
            departure_after=None,
            departure_before=None,
            limit=20,
            offset=0,
        )
        assert total >= 1
        assert trip.id in [t.id for t in trips]

    async def test_search_excludes_trips_outside_stop_filter(
        self, db_session: AsyncSession, make_user
    ) -> None:
        route_service, route, trip, origin, destination = await self._setup_searchable_trip(
            db_session, make_user
        )
        other_stop_id = uuid.uuid4()
        trips, total = await route_service.search_trips(
            origin_stop_ids=[other_stop_id],
            destination_stop_id=destination.id,
            travel_date=trip.scheduled_departure_at.date(),
            departure_after=None,
            departure_before=None,
            limit=20,
            offset=0,
        )
        assert trip.id not in [t.id for t in trips]

    async def test_get_trip_seats_returns_configured_layout(
        self, db_session: AsyncSession, make_user
    ) -> None:
        route_service, route, trip, origin, destination = await self._setup_searchable_trip(
            db_session, make_user
        )
        vehicle, seats, taken_seat_ids = await route_service.get_trip_seats(trip.id)
        assert len(seats) == 4
        assert taken_seat_ids == set()

    async def test_get_trip_seats_without_vehicle_assignment_raises(
        self, db_session: AsyncSession, make_user
    ) -> None:
        route_service = RouteService(db_session)
        origin = await route_service.create_stop(
            name="A", code=None, latitude=5.0, longitude=-0.5, address=None, city=None, region=None
        )
        destination = await route_service.create_stop(
            name="B", code=None, latitude=6.0, longitude=-1.5, address=None, city=None, region=None
        )
        route = await route_service.create_route(
            name=f"R-{uuid.uuid4().hex[:8]}",
            origin_stop_id=origin.id,
            destination_stop_id=destination.id,
            distance_km=None,
            estimated_duration_minutes=None,
            intermediate_stop_ids=[],
            created_by=None,
        )
        trip_service = TripService(db_session)

        trip = await trip_service.create_trip(
            route_id=route.id,
            route_schedule_id=None,
            scheduled_departure_at=datetime.now(UTC) + timedelta(hours=1),
            scheduled_arrival_at=None,
            fare_amount=Decimal("10.00"),
            created_by=None,
        )
        with pytest.raises(ConflictError):
            await route_service.get_trip_seats(trip.id)


async def _stops_on_a_meridian(service: RouteService, count: int = 5) -> list:
    """Stops 0.1 degrees of latitude apart on one meridian, so every leg is
    the same length."""
    return [
        await service.create_stop(
            name=f"M{i}-{uuid.uuid4().hex[:6]}",
            code=None,
            latitude=5.6 + i / 10,
            longitude=-1.0,
            address=None,
            city=None,
            region=None,
        )
        for i in range(count)
    ]


class TestRouteStopDistances:
    async def test_each_stop_gets_its_distance_and_time_along_the_route(
        self, db_session: AsyncSession
    ) -> None:
        service = RouteService(db_session)
        stops = await _stops_on_a_meridian(service)
        route = await service.create_route(
            name=f"Meridian-{uuid.uuid4().hex[:8]}",
            origin_stop_id=stops[0].id,
            destination_stop_id=stops[-1].id,
            distance_km=Decimal("200"),
            estimated_duration_minutes=240,
            intermediate_stop_ids=[s.id for s in stops[1:-1]],
            created_by=None,
        )
        route_stops = await RouteRepository(db_session).list_route_stops(route.id)
        assert [rs.distance_from_origin_km for rs in route_stops] == [
            Decimal(km) for km in ("0.00", "50.00", "100.00", "150.00", "200.00")
        ]
        assert [rs.estimated_offset_minutes for rs in route_stops] == [0, 60, 120, 180, 240]

    async def test_without_a_length_the_route_is_measured_from_the_map(
        self, db_session: AsyncSession
    ) -> None:
        service = RouteService(db_session)
        stops = await _stops_on_a_meridian(service, count=3)
        route = await service.create_route(
            name=f"Meridian-{uuid.uuid4().hex[:8]}",
            origin_stop_id=stops[0].id,
            destination_stop_id=stops[-1].id,
            distance_km=None,
            estimated_duration_minutes=None,
            intermediate_stop_ids=[stops[1].id],
            created_by=None,
        )
        route_stops = await RouteRepository(db_session).list_route_stops(route.id)
        assert route.distance_km is not None
        assert route.distance_km == route_stops[-1].distance_from_origin_km
        assert Decimal("22") < route.distance_km < Decimal("23")  # 0.2 degrees

    async def test_an_unknown_intermediate_stop_is_refused(self, db_session: AsyncSession) -> None:
        service = RouteService(db_session)
        stops = await _stops_on_a_meridian(service, count=2)
        with pytest.raises(NotFoundError):
            await service.create_route(
                name=f"Meridian-{uuid.uuid4().hex[:8]}",
                origin_stop_id=stops[0].id,
                destination_stop_id=stops[1].id,
                distance_km=Decimal("50"),
                estimated_duration_minutes=None,
                intermediate_stop_ids=[uuid.uuid4()],
                created_by=None,
            )
