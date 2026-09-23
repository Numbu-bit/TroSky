"""Integration tests for TripService: assignment, the driver-facing state
machine (start/pause/resume/end), idempotency, and conflict detection —
against a real Postgres."""

from __future__ import annotations

import uuid
from datetime import UTC, date, datetime, timedelta
from decimal import Decimal

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import (
    ConflictError,
    ForbiddenError,
    InvalidStateTransitionError,
    NotFoundError,
)
from app.models.routes import Route, Stop
from app.models.trips import TripStatus
from app.models.vehicles import VehicleType
from app.providers.storage.malware_scan import NoOpMalwareScanner
from app.providers.storage.sandbox import SandboxStorageProvider
from app.schemas.driver import DriverRegisterRequest
from app.schemas.fleet import FleetCreateRequest, FleetOwnerRegisterRequest, VehicleCreateRequest
from app.services.driver_service import DriverService
from app.services.fleet_service import FleetService
from app.services.trip_service import TripService
from app.utilities.geo import latlng_to_wkt

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]


@pytest.fixture(autouse=True)
def _clear_storage():
    SandboxStorageProvider.clear()
    yield
    SandboxStorageProvider.clear()


async def _make_route(db_session: AsyncSession, make_user) -> Route:
    origin = Stop(name="Circle", location=latlng_to_wkt(5.5713, -0.2051))
    destination = Stop(name="Kejetia", location=latlng_to_wkt(6.6935, -1.6291))
    db_session.add_all([origin, destination])
    await db_session.flush()
    route = Route(
        name=f"Accra-Kumasi-{uuid.uuid4().hex[:8]}",
        origin_stop_id=origin.id,
        destination_stop_id=destination.id,
        estimated_duration_minutes=240,
    )
    db_session.add(route)
    await db_session.flush()
    return route


async def _make_approved_driver_and_vehicle(
    db_session: AsyncSession, make_user
) -> tuple[uuid.UUID, uuid.UUID, uuid.UUID]:
    """Returns (driver_user_id, driver_id, vehicle_id) — an approved driver
    and an approved vehicle, ready to be assigned to a trip."""
    driver_service = DriverService(db_session, SandboxStorageProvider(), NoOpMalwareScanner())
    driver_user_id = (await make_user()).id
    driver = await driver_service.register(
        driver_user_id,
        DriverRegisterRequest(
            license_number=f"GHA-{uuid.uuid4().hex[:8]}",
            license_expiry=date.today() + timedelta(days=365),
        ),
    )
    await driver_service.approve(driver.id, reviewer_id=(await make_user()).id, notes=None)

    fleet_service = FleetService(db_session, SandboxStorageProvider(), NoOpMalwareScanner())
    owner_user_id = (await make_user()).id
    await fleet_service.register(owner_user_id, FleetOwnerRegisterRequest(business_name="Test Co"))
    fleet = await fleet_service.create_fleet(owner_user_id, FleetCreateRequest(name="Fleet A"))
    vehicle = await fleet_service.create_vehicle(
        owner_user_id,
        fleet.id,
        VehicleCreateRequest(
            registration_number=f"GR-{uuid.uuid4().hex[:6].upper()}",
            vehicle_type=VehicleType.BUS,
            capacity=30,
        ),
    )
    await fleet_service.approve_vehicle(vehicle.id, reviewer_id=(await make_user()).id, notes=None)

    return driver_user_id, driver.id, vehicle.id


class TestTripAssignment:
    async def test_assign_driver_requires_approved_driver(
        self, db_session: AsyncSession, make_user
    ) -> None:
        route = await _make_route(db_session, make_user=make_user)
        trip_service = TripService(db_session)
        trip = await trip_service.create_trip(
            route_id=route.id,
            route_schedule_id=None,
            scheduled_departure_at=datetime.now(UTC) + timedelta(hours=1),
            scheduled_arrival_at=None,
            fare_amount=Decimal("25.00"),
            created_by=None,
        )

        driver_service = DriverService(db_session, SandboxStorageProvider(), NoOpMalwareScanner())
        driver = await driver_service.register(
            (await make_user()).id,
            DriverRegisterRequest(
                license_number=f"GHA-{uuid.uuid4().hex[:8]}",
                license_expiry=date.today() + timedelta(days=365),
            ),
        )
        with pytest.raises(ForbiddenError):
            await trip_service.assign_driver(trip.id, driver.id, assigned_by=None)


class TestTripLifecycle:
    async def _scheduled_trip_with_assignments(self, db_session: AsyncSession, make_user):
        route = await _make_route(db_session, make_user=make_user)
        driver_user_id, driver_id, vehicle_id = await _make_approved_driver_and_vehicle(
            db_session, make_user=make_user
        )
        trip_service = TripService(db_session)
        trip = await trip_service.create_trip(
            route_id=route.id,
            route_schedule_id=None,
            scheduled_departure_at=datetime.now(UTC) + timedelta(hours=1),
            scheduled_arrival_at=None,
            fare_amount=Decimal("25.00"),
            created_by=None,
        )
        await trip_service.assign_driver(trip.id, driver_id, assigned_by=None)
        await trip_service.assign_vehicle(trip.id, vehicle_id, assigned_by=None)
        return trip_service, trip, driver_user_id

    async def test_start_trip_succeeds_for_assigned_driver(
        self, db_session: AsyncSession, make_user
    ) -> None:
        trip_service, trip, driver_user_id = await self._scheduled_trip_with_assignments(
            db_session, make_user=make_user
        )
        started = await trip_service.start_trip(trip.id, driver_user_id)
        assert started.status == TripStatus.IN_PROGRESS
        assert started.actual_departure_at is not None

    async def test_start_trip_is_idempotent(self, db_session: AsyncSession, make_user) -> None:
        trip_service, trip, driver_user_id = await self._scheduled_trip_with_assignments(
            db_session, make_user=make_user
        )
        first = await trip_service.start_trip(trip.id, driver_user_id)
        second = await trip_service.start_trip(trip.id, driver_user_id)
        assert first.id == second.id
        assert second.status == TripStatus.IN_PROGRESS

    async def test_unassigned_driver_cannot_start_trip(
        self, db_session: AsyncSession, make_user
    ) -> None:
        trip_service, trip, _ = await self._scheduled_trip_with_assignments(
            db_session, make_user=make_user
        )
        other_driver_user_id = (await make_user()).id
        with pytest.raises(ForbiddenError):
            await trip_service.start_trip(trip.id, other_driver_user_id)

    async def test_start_trip_rejects_conflicting_active_trip(
        self, db_session: AsyncSession, make_user
    ) -> None:
        route = await _make_route(db_session, make_user=make_user)
        driver_user_id, driver_id, vehicle_id_1 = await _make_approved_driver_and_vehicle(
            db_session, make_user
        )
        _, _, vehicle_id_2 = await _make_approved_driver_and_vehicle(
            db_session, make_user=make_user
        )
        trip_service = TripService(db_session)

        trip1 = await trip_service.create_trip(
            route_id=route.id,
            route_schedule_id=None,
            scheduled_departure_at=datetime.now(UTC) + timedelta(hours=1),
            scheduled_arrival_at=None,
            fare_amount=Decimal("25.00"),
            created_by=None,
        )
        await trip_service.assign_driver(trip1.id, driver_id, assigned_by=None)
        await trip_service.assign_vehicle(trip1.id, vehicle_id_1, assigned_by=None)
        await trip_service.start_trip(trip1.id, driver_user_id)

        trip2 = await trip_service.create_trip(
            route_id=route.id,
            route_schedule_id=None,
            scheduled_departure_at=datetime.now(UTC) + timedelta(hours=2),
            scheduled_arrival_at=None,
            fare_amount=Decimal("25.00"),
            created_by=None,
        )
        await trip_service.assign_driver(trip2.id, driver_id, assigned_by=None)
        await trip_service.assign_vehicle(trip2.id, vehicle_id_2, assigned_by=None)

        with pytest.raises(ConflictError) as exc_info:
            await trip_service.start_trip(trip2.id, driver_user_id)
        assert exc_info.value.code == "DRIVER_HAS_CONFLICTING_TRIP"

    async def test_pause_and_resume_trip(self, db_session: AsyncSession, make_user) -> None:
        trip_service, trip, driver_user_id = await self._scheduled_trip_with_assignments(
            db_session, make_user=make_user
        )
        await trip_service.start_trip(trip.id, driver_user_id)

        paused = await trip_service.pause_trip(trip.id, driver_user_id, "Traffic")
        assert paused.status == TripStatus.PAUSED

        resumed = await trip_service.resume_trip(trip.id, driver_user_id)
        assert resumed.status == TripStatus.IN_PROGRESS

    async def test_end_trip_succeeds_and_is_idempotent(
        self, db_session: AsyncSession, make_user
    ) -> None:
        trip_service, trip, driver_user_id = await self._scheduled_trip_with_assignments(
            db_session, make_user=make_user
        )
        await trip_service.start_trip(trip.id, driver_user_id)

        ended = await trip_service.end_trip(
            trip.id, driver_user_id, latitude=Decimal("6.5"), longitude=Decimal("-1.6")
        )
        assert ended.status == TripStatus.COMPLETED
        assert ended.actual_arrival_at is not None

        ended_again = await trip_service.end_trip(trip.id, driver_user_id)
        assert ended_again.status == TripStatus.COMPLETED

    async def test_cannot_pause_a_scheduled_trip(self, db_session: AsyncSession, make_user) -> None:
        trip_service, trip, driver_user_id = await self._scheduled_trip_with_assignments(
            db_session, make_user=make_user
        )
        with pytest.raises(InvalidStateTransitionError):
            await trip_service.pause_trip(trip.id, driver_user_id, None)

    async def test_cancel_trip_from_scheduled(self, db_session: AsyncSession, make_user) -> None:
        route = await _make_route(db_session, make_user=make_user)
        trip_service = TripService(db_session)
        trip = await trip_service.create_trip(
            route_id=route.id,
            route_schedule_id=None,
            scheduled_departure_at=datetime.now(UTC) + timedelta(hours=1),
            scheduled_arrival_at=None,
            fare_amount=Decimal("25.00"),
            created_by=None,
        )
        cancelled = await trip_service.cancel_trip(trip.id, cancelled_by=None, reason="No demand")
        assert cancelled.status == TripStatus.CANCELLED

    async def test_cannot_cancel_a_completed_trip(
        self, db_session: AsyncSession, make_user
    ) -> None:
        trip_service, trip, driver_user_id = await self._scheduled_trip_with_assignments(
            db_session, make_user=make_user
        )
        await trip_service.start_trip(trip.id, driver_user_id)
        await trip_service.end_trip(trip.id, driver_user_id)

        with pytest.raises(InvalidStateTransitionError):
            await trip_service.cancel_trip(trip.id, cancelled_by=None, reason="Too late")

    async def test_get_trip_not_found(self, db_session: AsyncSession, make_user) -> None:
        trip_service = TripService(db_session)
        with pytest.raises(NotFoundError):
            await trip_service.get_trip((await make_user()).id)
