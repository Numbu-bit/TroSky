"""Integration tests for distance-based fare sharing through BookingService.

``tests/unit/test_fare_service.py`` covers the arithmetic in isolation.
These exercise the parts only a database can answer: reading stop offsets
off a real route, and counting how many already-booked seats overlap the
segment being priced.

The route here is a 200km Accra->Kumasi service with a stop every 50km, so
a quarter of the route is a quarter of the fare and the numbers stay
readable.
"""

from __future__ import annotations

import uuid
from datetime import UTC, datetime, timedelta
from decimal import Decimal

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.routes import Route, Stop
from app.models.vehicles import VehicleType
from app.providers.storage.malware_scan import NoOpMalwareScanner
from app.providers.storage.sandbox import SandboxStorageProvider
from app.repositories.route_repository import RouteRepository
from app.schemas.booking import BookingCreateRequest, PassengerInput
from app.schemas.fleet import (
    FleetCreateRequest,
    FleetOwnerRegisterRequest,
    SeatInput,
    SeatLayoutRequest,
    VehicleCreateRequest,
)
from app.services.booking_service import BookingService
from app.services.fleet_service import FleetService
from app.services.route_service import RouteService
from app.services.trip_service import TripService
from app.utilities.geo import latlng_to_wkt

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]

FULL_FARE = Decimal("40.00")
ROUTE_KM = Decimal("200")
STOP_KM = [Decimal("0"), Decimal("50"), Decimal("100"), Decimal("150"), Decimal("200")]


async def _build_route_with_stops(
    session: AsyncSession, make_user, *, seat_count: int = 8
) -> tuple[uuid.UUID, list[uuid.UUID], list[uuid.UUID]]:
    """A measured route plus a bookable trip on it.

    Returns (trip_id, stop_ids in route order, seat_ids).
    """
    stops = []
    for i in range(len(STOP_KM)):
        stop = Stop(
            name=f"S{i}-{uuid.uuid4().hex[:6]}",
            location=latlng_to_wkt(5.6 + float(i) / 10, -0.2 - float(i) / 10),
        )
        session.add(stop)
        stops.append(stop)
    await session.flush()

    route = Route(
        name=f"Accra-Kumasi-{uuid.uuid4().hex[:8]}",
        origin_stop_id=stops[0].id,
        destination_stop_id=stops[-1].id,
        distance_km=ROUTE_KM,
    )
    session.add(route)
    await session.flush()

    routes = RouteRepository(session)
    for i, (stop, km) in enumerate(zip(stops, STOP_KM, strict=True)):
        await routes.add_route_stop(
            route_id=route.id,
            stop_id=stop.id,
            sequence_number=i,
            distance_from_origin_km=km,
            estimated_offset_minutes=i * 45,
        )

    trip_id, seat_ids = await _bookable_trip_on(session, make_user, route.id, seat_count)
    return trip_id, [s.id for s in stops], seat_ids


async def _bookable_trip_on(
    session: AsyncSession, make_user, route_id: uuid.UUID, seat_count: int
) -> tuple[uuid.UUID, list[uuid.UUID]]:
    """A trip on ``route_id`` with an approved bus of ``seat_count`` seats.
    Returns (trip_id, seat_ids)."""
    fleet_service = FleetService(session, SandboxStorageProvider(), NoOpMalwareScanner())
    owner_id = (await make_user()).id
    await fleet_service.register(owner_id, FleetOwnerRegisterRequest(business_name="Kumasi Line"))
    fleet = await fleet_service.create_fleet(owner_id, FleetCreateRequest(name="Main Fleet"))
    vehicle = await fleet_service.create_vehicle(
        owner_id,
        fleet.id,
        VehicleCreateRequest(
            registration_number=f"GR-{uuid.uuid4().hex[:6].upper()}",
            vehicle_type=VehicleType.BUS,
            capacity=seat_count,
        ),
    )
    seats = [
        SeatInput(seat_number=f"S{i}", row_number=1, column_number=i + 1) for i in range(seat_count)
    ]
    _, seat_rows = await fleet_service.set_seat_layout(
        owner_id, vehicle.id, SeatLayoutRequest(rows=1, columns=seat_count, seats=seats)
    )
    await fleet_service.approve_vehicle(vehicle.id, reviewer_id=(await make_user()).id, notes=None)

    trips = TripService(session)
    trip = await trips.create_trip(
        route_id=route_id,
        route_schedule_id=None,
        scheduled_departure_at=datetime.now(UTC) + timedelta(hours=3),
        scheduled_arrival_at=None,
        fare_amount=FULL_FARE,
        created_by=None,
    )
    await trips.assign_vehicle(trip.id, vehicle.id, assigned_by=None)
    return trip.id, [s.id for s in seat_rows]


async def _book(
    service: BookingService,
    make_user,
    *,
    trip_id: uuid.UUID,
    seat_ids: list[uuid.UUID],
    origin: uuid.UUID | None = None,
    destination: uuid.UUID | None = None,
):
    request = BookingCreateRequest(
        trip_id=trip_id,
        passengers=[PassengerInput(seat_id=s, full_name="Ama Mensah") for s in seat_ids],
        origin_stop_id=origin,
        destination_stop_id=destination,
    )
    return await service.create_booking((await make_user()).id, request, idempotency_key=None)


class TestDistancePricing:
    async def test_quarter_of_the_route_costs_a_quarter_of_the_fare(
        self, db_session: AsyncSession, make_user
    ) -> None:
        trip_id, stops, seats = await _build_route_with_stops(db_session, make_user)
        service = BookingService(db_session)
        booking = await _book(
            service,
            make_user,
            trip_id=trip_id,
            seat_ids=seats[:1],
            origin=stops[0],
            destination=stops[1],
        )
        assert booking.fare_amount == Decimal("10.00")

    async def test_omitting_stops_charges_the_whole_route(
        self, db_session: AsyncSession, make_user
    ) -> None:
        trip_id, _, seats = await _build_route_with_stops(db_session, make_user)
        service = BookingService(db_session)
        booking = await _book(service, make_user, trip_id=trip_id, seat_ids=seats[:1])
        assert booking.fare_amount == FULL_FARE

    async def test_the_segment_is_stored_on_the_booking(
        self, db_session: AsyncSession, make_user
    ) -> None:
        trip_id, stops, seats = await _build_route_with_stops(db_session, make_user)
        service = BookingService(db_session)
        booking = await _book(
            service,
            make_user,
            trip_id=trip_id,
            seat_ids=seats[:1],
            origin=stops[1],
            destination=stops[3],
        )
        assert booking.origin_stop_id == stops[1]
        assert booking.destination_stop_id == stops[3]
        assert booking.fare_amount == Decimal("20.00")


class TestSharingByDistance:
    """The trip's cost is apportioned across everyone aboard in proportion
    to the distance each rides. Sharing only bites once the passengers
    aboard between them cover more than the route's own length — below
    that the operator has not yet been made whole, so each passenger still
    pays their distance fare."""

    async def test_two_seats_on_one_booking_split_the_fare(
        self, db_session: AsyncSession, make_user
    ) -> None:
        trip_id, stops, seats = await _build_route_with_stops(db_session, make_user)
        service = BookingService(db_session)
        booking = await _book(
            service,
            make_user,
            trip_id=trip_id,
            seat_ids=seats[:2],
            origin=stops[0],
            destination=stops[-1],
        )
        # 400 passenger-km aboard, so each of the two seats carries half
        # of the 40.00 fare.
        assert booking.fare_amount == Decimal("40.00")
        assert booking.fare_amount / 2 == Decimal("20.00")

    async def test_a_later_passenger_on_the_same_segment_pays_less(
        self, db_session: AsyncSession, make_user
    ) -> None:
        trip_id, stops, seats = await _build_route_with_stops(db_session, make_user)
        service = BookingService(db_session)
        first = await _book(
            service,
            make_user,
            trip_id=trip_id,
            seat_ids=seats[:1],
            origin=stops[0],
            destination=stops[-1],
        )
        second = await _book(
            service,
            make_user,
            trip_id=trip_id,
            seat_ids=seats[1:2],
            origin=stops[0],
            destination=stops[-1],
        )
        assert first.fare_amount == FULL_FARE
        assert second.fare_amount == Decimal("20.00")

    async def test_the_longer_rider_carries_proportionally_more(
        self, db_session: AsyncSession, make_user
    ) -> None:
        """The heart of the model: 200km and 100km of a 300km total pay two
        thirds and one third, and together still fund the operator's fare."""
        trip_id, stops, seats = await _build_route_with_stops(db_session, make_user)
        service = BookingService(db_session)
        await _book(
            service,
            make_user,
            trip_id=trip_id,
            seat_ids=seats[:1],
            origin=stops[0],
            destination=stops[-1],
        )
        short = await _book(
            service,
            make_user,
            trip_id=trip_id,
            seat_ids=seats[1:2],
            origin=stops[0],
            destination=stops[2],
        )
        # The 100km rider joins 200 already-committed passenger-km:
        # 40.00 x 100/300 = 13.33.
        assert short.fare_amount == Decimal("13.33")

    async def test_two_half_route_riders_together_fund_the_trip(
        self, db_session: AsyncSession, make_user
    ) -> None:
        """One rides the first half, one the second. Between them they cover
        the route exactly once, so neither gets a discount and the operator
        collects the whole fare."""
        trip_id, stops, seats = await _build_route_with_stops(db_session, make_user)
        service = BookingService(db_session)
        first = await _book(
            service,
            make_user,
            trip_id=trip_id,
            seat_ids=seats[:1],
            origin=stops[0],
            destination=stops[2],
        )
        second = await _book(
            service,
            make_user,
            trip_id=trip_id,
            seat_ids=seats[1:2],
            origin=stops[2],
            destination=stops[4],
        )
        assert first.fare_amount == Decimal("20.00")
        assert second.fare_amount == Decimal("20.00")
        assert first.fare_amount + second.fare_amount == FULL_FARE

    async def test_a_third_passenger_makes_it_cheaper_for_the_next(
        self, db_session: AsyncSession, make_user
    ) -> None:
        trip_id, stops, seats = await _build_route_with_stops(db_session, make_user)
        service = BookingService(db_session)
        for i in range(2):
            await _book(
                service,
                make_user,
                trip_id=trip_id,
                seat_ids=seats[i : i + 1],
                origin=stops[0],
                destination=stops[-1],
            )
        third = await _book(
            service,
            make_user,
            trip_id=trip_id,
            seat_ids=seats[2:3],
            origin=stops[0],
            destination=stops[-1],
        )
        # 600 passenger-km aboard: 40.00 x 200/600 = 13.33.
        assert third.fare_amount == Decimal("13.33")


class TestAdminBuiltRoutes:
    async def test_part_of_an_admin_built_route_costs_its_share(
        self, db_session: AsyncSession, make_user
    ) -> None:
        """POST /admin/routes gives no stop distances; the service measures
        them from the map, so a quarter of the way costs a quarter of the
        fare rather than all of it."""
        service = RouteService(db_session)
        stops = [
            await service.create_stop(
                name=f"A{i}-{uuid.uuid4().hex[:6]}",
                code=None,
                latitude=5.6 + i / 10,
                longitude=-1.0,
                address=None,
                city=None,
                region=None,
            )
            for i in range(5)
        ]
        route = await service.create_route(
            name=f"Admin-{uuid.uuid4().hex[:8]}",
            origin_stop_id=stops[0].id,
            destination_stop_id=stops[-1].id,
            distance_km=ROUTE_KM,
            estimated_duration_minutes=240,
            intermediate_stop_ids=[s.id for s in stops[1:-1]],
            created_by=None,
        )
        trip_id, seats = await _bookable_trip_on(db_session, make_user, route.id, 2)

        booking = await _book(
            BookingService(db_session),
            make_user,
            trip_id=trip_id,
            seat_ids=seats[:1],
            origin=stops[0].id,
            destination=stops[1].id,
        )
        assert booking.fare_amount == Decimal("10.00")
