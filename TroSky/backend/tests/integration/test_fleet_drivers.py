"""Frontend request G10: a fleet owner listing their drivers and finding a
driver to assign by phone number -- against a real Postgres."""

from __future__ import annotations

import secrets
import uuid
from datetime import UTC, datetime, timedelta

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import NotFoundError, ValidationAppError
from app.models.drivers import ApprovalStatus
from app.models.vehicles import VehicleType
from app.schemas.driver import DriverRegisterRequest
from app.schemas.fleet import VehicleCreateRequest
from tests.integration.scenarios import (
    approved_driver,
    build_trip_scenario,
    driver_service,
    fleet_service,
)

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]

DEPARTURE = datetime.now(UTC) + timedelta(days=30)


def _mtn_number() -> str:
    return f"+23324{secrets.randbelow(10**7):07d}"


class TestFleetDrivers:
    async def test_lists_assigned_drivers_with_their_vehicles(
        self, db_session: AsyncSession, make_user
    ) -> None:
        s = await build_trip_scenario(db_session, make_user, departure=DEPARTURE)
        fleets = fleet_service(db_session)
        second = await fleets.create_vehicle(
            s.owner_user_id,
            s.fleet_id,
            VehicleCreateRequest(
                registration_number=f"GR-{uuid.uuid4().hex[:6].upper()}",
                vehicle_type=VehicleType.MINIBUS,
                capacity=14,
            ),
        )
        for vehicle_id in (s.vehicle_id, second.id):
            await fleets.assign_driver(s.owner_user_id, vehicle_id, s.driver_id)

        [driver] = await fleets.list_fleet_drivers(s.owner_user_id, s.fleet_id)
        assert driver.driver_id == s.driver_id
        assert driver.full_name == "Test User"
        assert driver.approval_status == ApprovalStatus.APPROVED
        assert {v.vehicle_id for v in driver.vehicles} == {s.vehicle_id, second.id}

    async def test_an_unassigned_driver_drops_off(
        self, db_session: AsyncSession, make_user
    ) -> None:
        s = await build_trip_scenario(db_session, make_user, departure=DEPARTURE)
        fleets = fleet_service(db_session)
        await fleets.assign_driver(s.owner_user_id, s.vehicle_id, s.driver_id)
        await fleets.unassign_driver(s.owner_user_id, s.vehicle_id, s.driver_id)
        assert await fleets.list_fleet_drivers(s.owner_user_id, s.fleet_id) == []

    async def test_another_owner_cannot_list_them(
        self, db_session: AsyncSession, make_user
    ) -> None:
        mine = await build_trip_scenario(db_session, make_user, departure=DEPARTURE)
        theirs = await build_trip_scenario(db_session, make_user, departure=DEPARTURE)
        with pytest.raises(NotFoundError):
            await fleet_service(db_session).list_fleet_drivers(theirs.owner_user_id, mine.fleet_id)


class TestDriverLookup:
    async def test_finds_an_approved_driver_by_their_local_number(
        self, db_session: AsyncSession, make_user
    ) -> None:
        phone = _mtn_number()
        _, driver = await approved_driver(db_session, make_user, phone_number=phone)

        found = await fleet_service(db_session).lookup_driver("0" + phone[4:])

        assert found.driver_id == driver.id
        assert found.full_name == "Test User"
        assert found.approval_status == ApprovalStatus.APPROVED
        assert found.phone_number == f"{phone[:6]}•••{phone[-4:]}"

    async def test_a_driver_awaiting_approval_is_not_found(
        self, db_session: AsyncSession, make_user
    ) -> None:
        phone = _mtn_number()
        user = await make_user(phone_number=phone)
        await driver_service(db_session).register(
            user.id,
            DriverRegisterRequest(
                license_number=f"GHA-{uuid.uuid4().hex[:8]}",
                license_expiry=datetime.now(UTC).date() + timedelta(days=365),
            ),
        )
        with pytest.raises(NotFoundError):
            await fleet_service(db_session).lookup_driver(phone)

    async def test_unknown_and_invalid_numbers(self, db_session: AsyncSession) -> None:
        fleets = fleet_service(db_session)
        with pytest.raises(NotFoundError):
            await fleets.lookup_driver(_mtn_number())
        with pytest.raises(ValidationAppError):
            await fleets.lookup_driver("12")
