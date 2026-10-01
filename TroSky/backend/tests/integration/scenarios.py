"""A realistic trip for tests of the list and read endpoints.

Built through the services an admin, a fleet owner and a driver would use: a
three-stop route (Madina -> Legon -> Circle), an approved driver and an
approved 4-seat minibus with a seat layout, and a trip with both assigned.
Not a test module itself (no ``test_`` prefix), so pytest does not collect
it.
"""

from __future__ import annotations

import uuid
from dataclasses import dataclass
from datetime import date, datetime, timedelta
from decimal import Decimal

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.bookings import Booking
from app.models.vehicles import VehicleType
from app.providers.storage.malware_scan import NoOpMalwareScanner
from app.providers.storage.sandbox import SandboxStorageProvider
from app.schemas.booking import BookingCreateRequest, PassengerInput
from app.schemas.driver import DriverRegisterRequest
from app.schemas.fleet import (
    FleetCreateRequest,
    FleetOwnerRegisterRequest,
    SeatInput,
    SeatLayoutRequest,
    VehicleCreateRequest,
)
from app.services.booking_service import BookingService
from app.services.driver_service import DriverService
from app.services.fleet_service import FleetService
from app.services.route_service import RouteService
from app.services.trip_service import TripService


@dataclass(frozen=True)
class TripScenario:
    trip_id: uuid.UUID
    route_id: uuid.UUID
    route_name: str
    stop_ids: list[uuid.UUID]  # along the route: Madina, Legon, Circle
    stop_names: list[str]
    driver_user_id: uuid.UUID
    driver_id: uuid.UUID
    owner_user_id: uuid.UUID
    fleet_id: uuid.UUID
    vehicle_id: uuid.UUID
    registration_number: str
    seat_ids: list[uuid.UUID]  # labelled A1, A2, ...


def fleet_service(session: AsyncSession) -> FleetService:
    return FleetService(session, SandboxStorageProvider(), NoOpMalwareScanner())


def driver_service(session: AsyncSession) -> DriverService:
    return DriverService(session, SandboxStorageProvider(), NoOpMalwareScanner())


async def approved_driver(session: AsyncSession, make_user, **user_fields: object):
    """An approved driver; returns ``(user, driver)``."""
    user = await make_user(**user_fields)
    drivers = driver_service(session)
    driver = await drivers.register(
        user.id,
        DriverRegisterRequest(
            license_number=f"GHA-{uuid.uuid4().hex[:8]}",
            license_expiry=date.today() + timedelta(days=365),
        ),
    )
    await drivers.approve(driver.id, reviewer_id=(await make_user()).id, notes=None)
    return user, driver


async def build_trip_scenario(
    session: AsyncSession, make_user, *, departure: datetime, seats: int = 4
) -> TripScenario:
    suffix = uuid.uuid4().hex[:6]
    routes = RouteService(session)
    stops = [
        await routes.create_stop(
            name=f"{name}-{suffix}",
            code=None,
            latitude=5.6 + index / 10,
            longitude=-1.0,
            address=None,
            city=None,
            region=None,
        )
        for index, name in enumerate(("Madina", "Legon", "Circle"))
    ]
    route = await routes.create_route(
        name=f"Madina-Circle-{suffix}",
        origin_stop_id=stops[0].id,
        destination_stop_id=stops[2].id,
        distance_km=Decimal("20"),
        estimated_duration_minutes=40,
        intermediate_stop_ids=[stops[1].id],
        created_by=None,
    )

    driver_user, driver = await approved_driver(session, make_user)

    fleets = fleet_service(session)
    owner = await make_user()
    await fleets.register(owner.id, FleetOwnerRegisterRequest(business_name=f"Co {suffix}"))
    fleet = await fleets.create_fleet(owner.id, FleetCreateRequest(name=f"Fleet {suffix}"))
    registration = f"GR-{uuid.uuid4().hex[:6].upper()}"
    vehicle = await fleets.create_vehicle(
        owner.id,
        fleet.id,
        VehicleCreateRequest(
            registration_number=registration, vehicle_type=VehicleType.MINIBUS, capacity=seats
        ),
    )
    _, seat_rows = await fleets.set_seat_layout(
        owner.id,
        vehicle.id,
        SeatLayoutRequest(
            rows=1,
            columns=seats,
            seats=[
                SeatInput(seat_number=f"A{i + 1}", row_number=1, column_number=i + 1)
                for i in range(seats)
            ],
        ),
    )
    await fleets.approve_vehicle(vehicle.id, reviewer_id=(await make_user()).id, notes=None)

    trips = TripService(session)
    trip = await trips.create_trip(
        route_id=route.id,
        route_schedule_id=None,
        scheduled_departure_at=departure,
        scheduled_arrival_at=None,
        fare_amount=Decimal("8.00"),
        created_by=None,
    )
    await trips.assign_vehicle(trip.id, vehicle.id, assigned_by=None)
    await trips.assign_driver(trip.id, driver.id, assigned_by=None)

    return TripScenario(
        trip_id=trip.id,
        route_id=route.id,
        route_name=route.name,
        stop_ids=[stop.id for stop in stops],
        stop_names=[stop.name for stop in stops],
        driver_user_id=driver_user.id,
        driver_id=driver.id,
        owner_user_id=owner.id,
        fleet_id=fleet.id,
        vehicle_id=vehicle.id,
        registration_number=registration,
        seat_ids=[seat.id for seat in seat_rows],
    )


async def book(
    session: AsyncSession,
    passenger_id: uuid.UUID,
    scenario: TripScenario,
    *,
    seat: int,
    origin: uuid.UUID | None = None,
    destination: uuid.UUID | None = None,
    name: str = "Ama Owusu",
    phone: str | None = None,
    confirm: bool = True,
) -> Booking:
    """Book one seat; confirmed (paid, ticket issued) unless ``confirm`` is
    False, in which case the seat is only held."""
    service = BookingService(session)
    booking = await service.create_booking(
        passenger_id,
        BookingCreateRequest(
            trip_id=scenario.trip_id,
            passengers=[
                PassengerInput(seat_id=scenario.seat_ids[seat], full_name=name, phone_number=phone)
            ],
            origin_stop_id=origin,
            destination_stop_id=destination,
        ),
        idempotency_key=None,
    )
    if confirm:
        booking = await service.confirm_booking(booking.id)
    return booking
