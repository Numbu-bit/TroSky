"""Integration tests for FleetService: fleet-owner/fleet/vehicle CRUD, seat
layouts, driver assignment, and tenant isolation between fleet owners."""

from __future__ import annotations

from datetime import date, timedelta

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ConflictError, ForbiddenError, NotFoundError
from app.models.drivers import ApprovalStatus
from app.models.vehicles import SeatType, VehicleType
from app.providers.storage.malware_scan import NoOpMalwareScanner
from app.providers.storage.sandbox import SandboxStorageProvider
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

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]


@pytest.fixture(autouse=True)
def _clear_storage():
    SandboxStorageProvider.clear()
    yield
    SandboxStorageProvider.clear()


def _fleet_service(db_session: AsyncSession) -> FleetService:
    return FleetService(db_session, SandboxStorageProvider(), NoOpMalwareScanner())


def _driver_service(db_session: AsyncSession) -> DriverService:
    return DriverService(db_session, SandboxStorageProvider(), NoOpMalwareScanner())


async def _make_owner_with_fleet(service: FleetService, make_user) -> tuple:
    owner_user_id = (await make_user()).id
    owner = await service.register(
        owner_user_id, FleetOwnerRegisterRequest(business_name="Accra Express")
    )
    fleet = await service.create_fleet(
        owner_user_id, FleetCreateRequest(name="Main Fleet", description=None)
    )
    return owner_user_id, owner, fleet


class TestFleetOwnerAndFleets:
    async def test_register_fleet_owner_and_create_fleet(
        self, db_session: AsyncSession, make_user
    ) -> None:
        service = _fleet_service(db_session)
        owner_user_id, owner, fleet = await _make_owner_with_fleet(service, make_user)

        assert owner.status == ApprovalStatus.PENDING
        assert fleet.fleet_owner_id == owner.id

        fleets = await service.list_own_fleets(owner_user_id)
        assert [f.id for f in fleets] == [fleet.id]

    async def test_duplicate_registration_rejected(
        self, db_session: AsyncSession, make_user
    ) -> None:
        service = _fleet_service(db_session)
        owner_user_id, _, _ = await _make_owner_with_fleet(service, make_user)
        with pytest.raises(ConflictError):
            await service.register(owner_user_id, FleetOwnerRegisterRequest(business_name="XY Co"))


class TestVehicles:
    async def test_create_vehicle_and_registration_number_uniqueness(
        self, db_session: AsyncSession, make_user
    ) -> None:
        service = _fleet_service(db_session)
        owner_user_id, _, fleet = await _make_owner_with_fleet(service, make_user)

        vehicle = await service.create_vehicle(
            owner_user_id,
            fleet.id,
            VehicleCreateRequest(
                registration_number="GR-1234-24",
                vehicle_type=VehicleType.BUS,
                capacity=45,
            ),
        )
        assert vehicle.status == ApprovalStatus.PENDING

        with pytest.raises(ConflictError):
            await service.create_vehicle(
                owner_user_id,
                fleet.id,
                VehicleCreateRequest(
                    registration_number="gr-1234-24",  # normalized to same uppercase
                    vehicle_type=VehicleType.BUS,
                    capacity=45,
                ),
            )

    async def test_approve_vehicle(self, db_session: AsyncSession, make_user) -> None:
        service = _fleet_service(db_session)
        owner_user_id, _, fleet = await _make_owner_with_fleet(service, make_user)
        vehicle = await service.create_vehicle(
            owner_user_id,
            fleet.id,
            VehicleCreateRequest(
                registration_number="GR-5555-24", vehicle_type=VehicleType.BUS, capacity=30
            ),
        )
        reviewer_id = (await make_user()).id
        approved = await service.approve_vehicle(vehicle.id, reviewer_id=reviewer_id, notes=None)
        assert approved.status == ApprovalStatus.APPROVED

        eligible = await service.assert_eligible_for_trip_assignment(vehicle.id)
        assert eligible.id == vehicle.id


class TestSeatLayout:
    async def test_set_and_get_seat_layout(self, db_session: AsyncSession, make_user) -> None:
        service = _fleet_service(db_session)
        owner_user_id, _, fleet = await _make_owner_with_fleet(service, make_user)
        vehicle = await service.create_vehicle(
            owner_user_id,
            fleet.id,
            VehicleCreateRequest(
                registration_number="GR-7777-24", vehicle_type=VehicleType.BUS, capacity=4
            ),
        )

        request = SeatLayoutRequest(
            name="Standard 2x2",
            rows=2,
            columns=2,
            seats=[
                SeatInput(seat_number="1A", row_number=1, column_number=1),
                SeatInput(seat_number="1B", row_number=1, column_number=2),
                SeatInput(seat_number="2A", row_number=2, column_number=1, seat_type=SeatType.VIP),
                SeatInput(seat_number="2B", row_number=2, column_number=2),
            ],
        )
        layout, seats = await service.set_seat_layout(owner_user_id, vehicle.id, request)
        assert layout.total_seats == 4
        assert {s.seat_number for s in seats} == {"1A", "1B", "2A", "2B"}

        fetched_layout, fetched_seats = await service.get_seat_layout(owner_user_id, vehicle.id)
        assert fetched_layout.id == layout.id
        assert len(fetched_seats) == 4

    async def test_seat_layout_exceeding_capacity_rejected(
        self, db_session: AsyncSession, make_user
    ) -> None:
        service = _fleet_service(db_session)
        owner_user_id, _, fleet = await _make_owner_with_fleet(service, make_user)
        vehicle = await service.create_vehicle(
            owner_user_id,
            fleet.id,
            VehicleCreateRequest(
                registration_number="GR-8888-24", vehicle_type=VehicleType.BUS, capacity=1
            ),
        )
        request = SeatLayoutRequest(
            rows=1,
            columns=2,
            seats=[
                SeatInput(seat_number="1A", row_number=1, column_number=1),
                SeatInput(seat_number="1B", row_number=1, column_number=2),
            ],
        )
        with pytest.raises(ConflictError):
            await service.set_seat_layout(owner_user_id, vehicle.id, request)


class TestDriverAssignment:
    async def test_assign_requires_approved_driver(
        self, db_session: AsyncSession, make_user
    ) -> None:
        fleet_service = _fleet_service(db_session)
        driver_service = _driver_service(db_session)
        owner_user_id, _, fleet = await _make_owner_with_fleet(fleet_service, make_user)
        vehicle = await fleet_service.create_vehicle(
            owner_user_id,
            fleet.id,
            VehicleCreateRequest(
                registration_number="GR-9999-24", vehicle_type=VehicleType.BUS, capacity=30
            ),
        )
        driver = await driver_service.register(
            (await make_user()).id,
            DriverRegisterRequest(
                license_number="GHA-ASSIGN-1",
                license_expiry=date.today() + timedelta(days=365),
            ),
        )

        with pytest.raises(ForbiddenError):
            await fleet_service.assign_driver(owner_user_id, vehicle.id, driver.id)

        await driver_service.approve(driver.id, reviewer_id=(await make_user()).id, notes=None)
        await fleet_service.assign_driver(owner_user_id, vehicle.id, driver.id)

        assignments = await driver_service.list_own_assignments(driver.user_id)
        assert [a.vehicle_id for a, _ in assignments] == [vehicle.id]


class TestFleetOwnerTenantIsolation:
    async def test_owner_cannot_see_another_owners_fleet_or_vehicle(
        self, db_session: AsyncSession, make_user
    ) -> None:
        service = _fleet_service(db_session)
        owner_a_user_id, _, fleet_a = await _make_owner_with_fleet(service, make_user)
        vehicle_a = await service.create_vehicle(
            owner_a_user_id,
            fleet_a.id,
            VehicleCreateRequest(
                registration_number="GR-1111-24", vehicle_type=VehicleType.BUS, capacity=20
            ),
        )

        owner_b_user_id = (await make_user()).id
        await service.register(owner_b_user_id, FleetOwnerRegisterRequest(business_name="B Co"))

        with pytest.raises(NotFoundError):
            await service.get_own_fleet(owner_b_user_id, fleet_a.id)

        with pytest.raises(NotFoundError):
            await service.get_own_vehicle(owner_b_user_id, vehicle_a.id)
