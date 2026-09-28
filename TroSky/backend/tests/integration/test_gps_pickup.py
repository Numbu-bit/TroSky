"""Integration tests for GPS-default pickup.

A passenger's device location is the default pickup: it resolves to the
nearest stop within walking distance, and a stop chosen by hand always
overrides it. These tests run against real PostGIS, because "nearest" is
decided by ``ST_DWithin``/``ST_Distance`` on geography, not by Python.

The fixture is a Circle -> Madina -> Adenta -> Aburi service with one trap:
"Madina Market" sits *closer* to the passenger than Madina itself but is
not on the route. That is the case where "the nearest stop" and "the
nearest stop this trip actually serves" differ, and the code must pick the
second.
"""

from __future__ import annotations

import uuid
from datetime import UTC, datetime, timedelta
from decimal import Decimal

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import NoPickupNearbyError, StopNotOnRouteError
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

# (name, latitude, longitude, km from the route's origin)
ROUTE_STOPS = [
    ("Circle", 5.5717, -0.2170, Decimal("0")),
    ("Madina", 5.6804, -0.1654, Decimal("12")),
    ("Adenta", 5.7076, -0.1575, Decimal("16")),
    ("Aburi", 5.8480, -0.1750, Decimal("32")),
]
# ~25m from the passenger, nearer than Madina (~62m) -- but off the route.
MADINA_MARKET = ("Madina Market", 5.6806, -0.1651)
PASSENGER_NEAR_MADINA = (5.6808, -0.1650)
# Kilometres from every stop above.
PASSENGER_FAR_AWAY = (5.6000, -0.1000)
FULL_FARE = Decimal("32.00")


async def _build(session: AsyncSession, make_user) -> dict:
    """The service above, a stop off it, and a bookable trip on it."""
    suffix = uuid.uuid4().hex[:6]
    stops: dict[str, Stop] = {}
    for name, lat, lng, _ in ROUTE_STOPS:
        stops[name] = Stop(name=f"{name}-{suffix}", location=latlng_to_wkt(lat, lng))
    market_name, m_lat, m_lng = MADINA_MARKET
    stops[market_name] = Stop(name=f"{market_name}-{suffix}", location=latlng_to_wkt(m_lat, m_lng))
    session.add_all(stops.values())
    await session.flush()

    route = Route(
        name=f"Circle-Aburi-{suffix}",
        origin_stop_id=stops["Circle"].id,
        destination_stop_id=stops["Aburi"].id,
        distance_km=ROUTE_STOPS[-1][3],
    )
    session.add(route)
    await session.flush()
    routes = RouteRepository(session)
    for sequence, (name, _, _, km) in enumerate(ROUTE_STOPS):
        await routes.add_route_stop(
            route_id=route.id,
            stop_id=stops[name].id,
            sequence_number=sequence,
            distance_from_origin_km=km,
            estimated_offset_minutes=sequence * 20,
        )

    fleets = FleetService(session, SandboxStorageProvider(), NoOpMalwareScanner())
    owner_id = (await make_user()).id
    await fleets.register(owner_id, FleetOwnerRegisterRequest(business_name="Aburi Line"))
    fleet = await fleets.create_fleet(owner_id, FleetCreateRequest(name="Main Fleet"))
    vehicle = await fleets.create_vehicle(
        owner_id,
        fleet.id,
        VehicleCreateRequest(
            registration_number=f"GR-{suffix.upper()}",
            vehicle_type=VehicleType.BUS,
            capacity=4,
        ),
    )
    _, seats = await fleets.set_seat_layout(
        owner_id,
        vehicle.id,
        SeatLayoutRequest(
            rows=1,
            columns=4,
            seats=[
                SeatInput(seat_number=f"S{i}", row_number=1, column_number=i + 1) for i in range(4)
            ],
        ),
    )
    await fleets.approve_vehicle(vehicle.id, reviewer_id=(await make_user()).id, notes=None)

    trips = TripService(session)
    trip = await trips.create_trip(
        route_id=route.id,
        route_schedule_id=None,
        scheduled_departure_at=datetime.now(UTC) + timedelta(hours=3),
        scheduled_arrival_at=None,
        fare_amount=FULL_FARE,
        created_by=None,
    )
    await trips.assign_vehicle(trip.id, vehicle.id, assigned_by=None)
    return {"stops": stops, "trip": trip, "seats": [s.id for s in seats]}


async def _book(session: AsyncSession, make_user, world: dict, **segment):
    request = BookingCreateRequest(
        trip_id=world["trip"].id,
        passengers=[PassengerInput(seat_id=world["seats"][0], full_name="Ama Mensah")],
        **segment,
    )
    return await BookingService(session).create_booking(
        (await make_user()).id, request, idempotency_key=None
    )


class TestNearbyStops:
    async def test_stops_within_walking_distance_come_back_nearest_first(
        self, db_session: AsyncSession, make_user
    ) -> None:
        world = await _build(db_session, make_user)
        nearby = await RouteService(db_session).find_nearby_stops(
            latitude=PASSENGER_NEAR_MADINA[0], longitude=PASSENGER_NEAR_MADINA[1]
        )
        ids = [stop.id for stop, _ in nearby]
        market = world["stops"]["Madina Market"].id
        madina = world["stops"]["Madina"].id
        assert ids.index(market) < ids.index(madina)
        distances = [d for _, d in nearby]
        assert distances == sorted(distances)
        assert all(d <= 1000 for d in distances)

    async def test_stops_beyond_walking_distance_are_left_out(
        self, db_session: AsyncSession, make_user
    ) -> None:
        world = await _build(db_session, make_user)
        nearby = await RouteService(db_session).find_nearby_stops(
            latitude=PASSENGER_NEAR_MADINA[0], longitude=PASSENGER_NEAR_MADINA[1]
        )
        # Adenta is about 3km away: a real stop, but not a walk.
        assert world["stops"]["Adenta"].id not in [stop.id for stop, _ in nearby]

    async def test_a_passenger_far_from_every_stop_gets_a_clear_refusal(
        self, db_session: AsyncSession, make_user
    ) -> None:
        await _build(db_session, make_user)
        with pytest.raises(NoPickupNearbyError):
            await RouteService(db_session).pickup_candidates(
                latitude=PASSENGER_FAR_AWAY[0], longitude=PASSENGER_FAR_AWAY[1]
            )


class TestSearchAlongTheRoute:
    """Search used to match only a route's *first* stop, so a passenger at
    Madina could never find the Circle -> Aburi service passing through."""

    async def _search(self, session: AsyncSession, world: dict, origins, destination):
        trips, _ = await RouteService(session).search_trips(
            origin_stop_ids=origins,
            destination_stop_id=destination,
            travel_date=world["trip"].scheduled_departure_at.date(),
            departure_after=None,
            departure_before=None,
            limit=20,
            offset=0,
        )
        return [t.id for t in trips]

    async def test_boarding_at_an_intermediate_stop_finds_the_trip(
        self, db_session: AsyncSession, make_user
    ) -> None:
        world = await _build(db_session, make_user)
        found = await self._search(
            db_session, world, [world["stops"]["Madina"].id], world["stops"]["Aburi"].id
        )
        assert world["trip"].id in found

    async def test_boarding_after_the_destination_is_not_offered(
        self, db_session: AsyncSession, make_user
    ) -> None:
        """Adenta comes after Madina on this route, so it cannot take you
        from Adenta back to Madina."""
        world = await _build(db_session, make_user)
        found = await self._search(
            db_session, world, [world["stops"]["Adenta"].id], world["stops"]["Madina"].id
        )
        assert world["trip"].id not in found

    async def test_gps_finds_the_trip_through_the_stop_it_serves(
        self, db_session: AsyncSession, make_user
    ) -> None:
        """The nearest stop overall is Madina Market, which this route skips.
        The trip must still be found, boarding at Madina."""
        world = await _build(db_session, make_user)
        service = RouteService(db_session)
        candidates = await service.pickup_candidates(
            latitude=PASSENGER_NEAR_MADINA[0], longitude=PASSENGER_NEAR_MADINA[1]
        )
        assert candidates[0][0].id == world["stops"]["Madina Market"].id

        found = await self._search(
            db_session, world, [s.id for s, _ in candidates], world["stops"]["Aburi"].id
        )
        assert world["trip"].id in found

        pickup = await service.pickup_for_trip(
            world["trip"], candidates, world["stops"]["Aburi"].id
        )
        assert pickup is not None
        stop, distance = pickup
        assert stop.id == world["stops"]["Madina"].id
        assert 30 < distance < 120


class TestBookingPickup:
    async def test_gps_pickup_snaps_to_the_nearest_stop_on_the_route(
        self, db_session: AsyncSession, make_user
    ) -> None:
        world = await _build(db_session, make_user)
        booking = await _book(
            db_session,
            make_user,
            world,
            pickup_latitude=PASSENGER_NEAR_MADINA[0],
            pickup_longitude=PASSENGER_NEAR_MADINA[1],
            destination_stop_id=world["stops"]["Aburi"].id,
        )
        assert booking.origin_stop_id == world["stops"]["Madina"].id

    async def test_gps_pickup_prices_the_segment_actually_ridden(
        self, db_session: AsyncSession, make_user
    ) -> None:
        """Madina (km 12) to Aburi (km 32) is 20 of 32km: 20.00 of 32.00."""
        world = await _build(db_session, make_user)
        booking = await _book(
            db_session,
            make_user,
            world,
            pickup_latitude=PASSENGER_NEAR_MADINA[0],
            pickup_longitude=PASSENGER_NEAR_MADINA[1],
            destination_stop_id=world["stops"]["Aburi"].id,
        )
        assert booking.fare_amount == Decimal("20.00")

    async def test_a_stop_chosen_by_hand_overrides_gps(
        self, db_session: AsyncSession, make_user
    ) -> None:
        world = await _build(db_session, make_user)
        booking = await _book(
            db_session,
            make_user,
            world,
            origin_stop_id=world["stops"]["Adenta"].id,
            pickup_latitude=PASSENGER_NEAR_MADINA[0],
            pickup_longitude=PASSENGER_NEAR_MADINA[1],
        )
        assert booking.origin_stop_id == world["stops"]["Adenta"].id

    async def test_no_route_stop_within_walking_distance_is_refused(
        self, db_session: AsyncSession, make_user
    ) -> None:
        world = await _build(db_session, make_user)
        with pytest.raises(NoPickupNearbyError):
            await _book(
                db_session,
                make_user,
                world,
                pickup_latitude=PASSENGER_FAR_AWAY[0],
                pickup_longitude=PASSENGER_FAR_AWAY[1],
            )

    async def test_a_stop_off_the_route_is_refused(
        self, db_session: AsyncSession, make_user
    ) -> None:
        """Previously this was silently priced as the whole route."""
        world = await _build(db_session, make_user)
        with pytest.raises(StopNotOnRouteError):
            await _book(
                db_session, make_user, world, origin_stop_id=world["stops"]["Madina Market"].id
            )

    async def test_a_pickup_after_the_destination_is_refused(
        self, db_session: AsyncSession, make_user
    ) -> None:
        world = await _build(db_session, make_user)
        with pytest.raises(StopNotOnRouteError):
            await _book(
                db_session,
                make_user,
                world,
                origin_stop_id=world["stops"]["Adenta"].id,
                destination_stop_id=world["stops"]["Madina"].id,
            )

    async def test_no_pickup_at_all_still_books_the_whole_route(
        self, db_session: AsyncSession, make_user
    ) -> None:
        """Clients that send neither a stop nor a location keep working."""
        world = await _build(db_session, make_user)
        booking = await _book(db_session, make_user, world)
        assert booking.origin_stop_id is None
        assert booking.fare_amount == FULL_FARE
