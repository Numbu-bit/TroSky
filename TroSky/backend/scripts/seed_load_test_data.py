"""Load-test-only seed data: a pool of pre-verified passenger accounts (so
Locust can log in without needing to intercept an OTP SMS — it runs as a
separate process against a live server, with no access to the sandbox
SMS outbox) plus one bookable trip with real seat capacity.

Run via ``python -m scripts.seed_load_test_data`` against a disposable
environment only — never production. Idempotent (safe to re-run).

This is the one place in the codebase that sets ``phone_verified_at``
directly without going through the OTP flow — a deliberate, narrowly
-scoped exception for load-testing purposes, not a pattern to reuse
elsewhere. Real user registration always requires OTP verification
(``app.services.auth_service``); this script exists precisely because
that's correct and therefore inconvenient for a load generator.
"""

from __future__ import annotations

import asyncio
import uuid
from datetime import UTC, date, datetime, timedelta
from decimal import Decimal

from app.core.database import dispose_engine, transactional_session
from app.core.logging import configure_logging, get_logger
from app.core.permissions import SystemRole
from app.core.security import hash_password
from app.models.identity import NotificationPreference, User, UserProfile, UserRole
from app.models.vehicles import VehicleType
from app.providers.storage.malware_scan import NoOpMalwareScanner
from app.providers.storage.sandbox import SandboxStorageProvider
from app.repositories.route_repository import RouteRepository, StopRepository
from app.repositories.user_repository import UserRepository
from app.schemas.driver import DriverRegisterRequest
from app.schemas.fleet import (
    FleetCreateRequest,
    FleetOwnerRegisterRequest,
    SeatInput,
    SeatLayoutRequest,
    VehicleCreateRequest,
)
from app.services.driver_service import DriverService
from app.services.fleet_service import FleetService
from app.services.trip_service import TripService
from scripts.seed_dev_data import ensure_permissions, ensure_roles

logger = get_logger(__name__)

_PASSENGER_COUNT = 50
_PASSENGER_PHONE_PREFIX = "+23320000"  # + a 4-digit suffix -> +233200001000.._1049
_PASSENGER_PASSWORD = "LoadTestPass!2026"  # noqa: S105 - load-test-only fixed credential
_LOAD_TEST_ROUTE_NAME = "Load Test — Accra Circle to Kumasi Kejetia"


async def ensure_passenger_pool(session, passenger_role_id: uuid.UUID) -> list[str]:  # type: ignore[no-untyped-def]
    users = UserRepository(session)
    phones: list[str] = []
    for i in range(_PASSENGER_COUNT):
        phone = f"{_PASSENGER_PHONE_PREFIX}{1000 + i}"
        phones.append(phone)
        existing = await users.get_by_phone(phone)
        if existing is not None:
            continue
        user = User(
            phone_number=phone,
            email=None,
            password_hash=hash_password(_PASSENGER_PASSWORD),
            is_active=True,
        )
        user.profile = UserProfile(full_name=f"Load Test Passenger {i}", preferred_language="en")
        user.phone_verified_at = datetime.now(UTC)
        session.add(user)
        await session.flush()
        session.add(UserRole(user_id=user.id, role_id=passenger_role_id))
        session.add(NotificationPreference(user_id=user.id))
        await session.flush()
    logger.info("seed_load_test_passengers_ready", count=len(phones))
    return phones


async def ensure_bookable_trip(session) -> uuid.UUID:  # type: ignore[no-untyped-def]
    from sqlalchemy import select

    from app.models.trips import Trip

    existing = await session.execute(select(Trip).where(Trip.fare_amount == Decimal("20.00")))
    trip = existing.scalars().first()
    if trip is not None:
        logger.info("seed_load_test_trip_already_exists", trip_id=str(trip.id))
        return trip.id  # type: ignore[no-any-return]

    stops = StopRepository(session)
    routes = RouteRepository(session)
    origin = await stops.create(
        name="Load Test Origin",
        code="LT-ORIGIN",
        latitude=5.5713,
        longitude=-0.2051,
        address=None,
        city="Accra",
        region=None,
    )
    destination = await stops.create(
        name="Load Test Destination",
        code="LT-DEST",
        latitude=6.6935,
        longitude=-1.6291,
        address=None,
        city="Kumasi",
        region=None,
    )
    route = await routes.create(
        name=_LOAD_TEST_ROUTE_NAME,
        origin_stop_id=origin.id,
        destination_stop_id=destination.id,
        distance_km=Decimal("250.00"),
        estimated_duration_minutes=240,
        created_by=None,
    )

    driver_service = DriverService(session, SandboxStorageProvider(), NoOpMalwareScanner())
    driver_user_id = uuid.uuid4()
    driver = await driver_service.register(
        driver_user_id,
        DriverRegisterRequest(
            license_number=f"LOADTEST-{uuid.uuid4().hex[:8]}",
            license_expiry=date.today() + timedelta(days=365),
        ),
    )
    await driver_service.approve(driver.id, reviewer_id=uuid.uuid4(), notes="Load test seed")

    fleet_service = FleetService(session, SandboxStorageProvider(), NoOpMalwareScanner())
    owner_user_id = uuid.uuid4()
    await fleet_service.register(
        owner_user_id, FleetOwnerRegisterRequest(business_name="Load Test Fleet Co")
    )
    fleet = await fleet_service.create_fleet(
        owner_user_id, FleetCreateRequest(name="Load Test Fleet")
    )
    vehicle = await fleet_service.create_vehicle(
        owner_user_id,
        fleet.id,
        VehicleCreateRequest(
            registration_number=f"LT-{uuid.uuid4().hex[:6].upper()}",
            vehicle_type=VehicleType.BUS,
            capacity=50,
        ),
    )
    await fleet_service.approve_vehicle(
        vehicle.id, reviewer_id=uuid.uuid4(), notes="Load test seed"
    )
    await fleet_service.set_seat_layout(
        owner_user_id,
        vehicle.id,
        SeatLayoutRequest(
            rows=10,
            columns=5,
            seats=[
                SeatInput(seat_number=f"S{i}", row_number=(i // 5) + 1, column_number=(i % 5) + 1)
                for i in range(50)
            ],
        ),
    )

    trip_service = TripService(session)
    new_trip = await trip_service.create_trip(
        route_id=route.id,
        route_schedule_id=None,
        scheduled_departure_at=datetime.now(UTC) + timedelta(days=1),
        scheduled_arrival_at=None,
        fare_amount=Decimal("20.00"),
        created_by=None,
    )
    await trip_service.assign_driver(new_trip.id, driver.id, assigned_by=None)
    await trip_service.assign_vehicle(new_trip.id, vehicle.id, assigned_by=None)
    logger.info("seed_load_test_trip_created", trip_id=str(new_trip.id))
    return new_trip.id


async def seed_load_test_data() -> None:
    async with transactional_session() as session:
        roles = await ensure_roles(session)
        await ensure_permissions(session)
        phones = await ensure_passenger_pool(session, roles[SystemRole.PASSENGER.value].id)
        trip_id = await ensure_bookable_trip(session)
    logger.info(
        "seed_load_test_data_complete",
        passenger_count=len(phones),
        trip_id=str(trip_id),
        password=_PASSENGER_PASSWORD,
    )


async def main() -> None:
    configure_logging(log_level="INFO", json_logs=False)
    try:
        await seed_load_test_data()
    finally:
        await dispose_engine()


if __name__ == "__main__":
    asyncio.run(main())
