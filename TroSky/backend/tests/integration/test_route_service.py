"""Integration tests for RouteService: stops, routes, schedules, trip
search, and trip-seat lookup — against a real Postgres."""

from __future__ import annotations

import uuid
from datetime import UTC, date, datetime, time, timedelta
from decimal import Decimal

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ConflictError
from app.models.vehicles import VehicleType
from app.providers.storage.malware_scan import NoOpMalwareScanner
from app.providers.storage.sandbox import SandboxStorageProvider
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
            origin_stop_id=origin.id,
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
        other_stop_id = (await make_user()).id
        trips, total = await route_service.search_trips(
            origin_stop_id=other_stop_id,
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
