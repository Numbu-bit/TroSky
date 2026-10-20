"""Passenger accounts and work accounts are separate: a passenger cannot
become a driver or fleet owner, nor a driver or fleet owner a passenger. An
owner may drive, and anyone may join the team."""

from __future__ import annotations

import uuid
from datetime import date, timedelta

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ConflictError
from app.core.permissions import SystemRole
from app.models.identity import User
from app.repositories.driver_repository import DriverRepository
from app.repositories.fleet_repository import FleetOwnerRepository
from app.repositories.user_repository import UserRepository
from app.schemas.driver import DriverRegisterRequest
from app.schemas.fleet import FleetOwnerRegisterRequest
from app.services.role_service import grant_role
from tests.integration.scenarios import driver_service, fleet_service

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]


async def _account(session: AsyncSession, make_user, *roles: SystemRole) -> User:
    user = await make_user()
    for role in roles:
        await grant_role(session, user.id, role)
    return user


async def _roles(session: AsyncSession, user: User) -> set[str]:
    return set(await UserRepository(session).get_roles_for_user(user.id))


def _licence() -> DriverRegisterRequest:
    return DriverRegisterRequest(
        license_number=f"GHA-{uuid.uuid4().hex[:8]}",
        license_expiry=date.today() + timedelta(days=365),
    )


def _business() -> FleetOwnerRegisterRequest:
    return FleetOwnerRegisterRequest(business_name=f"Co {uuid.uuid4().hex[:6]}")


class TestPassengerAccounts:
    async def test_cannot_become_a_driver(self, db_session: AsyncSession, make_user) -> None:
        passenger = await _account(db_session, make_user, SystemRole.PASSENGER)

        with pytest.raises(ConflictError) as raised:
            await driver_service(db_session).register(passenger.id, _licence())

        assert raised.value.code == "PASSENGER_ACCOUNT"
        assert await DriverRepository(db_session).get_by_user_id(passenger.id) is None
        assert await _roles(db_session, passenger) == {"passenger"}

    async def test_nor_a_fleet_owner(self, db_session: AsyncSession, make_user) -> None:
        passenger = await _account(db_session, make_user, SystemRole.PASSENGER)

        with pytest.raises(ConflictError) as raised:
            await fleet_service(db_session).register(passenger.id, _business())

        assert raised.value.code == "PASSENGER_ACCOUNT"
        assert await FleetOwnerRepository(db_session).get_by_user_id(passenger.id) is None

    async def test_may_join_the_team(self, db_session: AsyncSession, make_user) -> None:
        passenger = await _account(db_session, make_user, SystemRole.PASSENGER)
        await grant_role(db_session, passenger.id, SystemRole.STAFF)
        assert await _roles(db_session, passenger) == {"passenger", "staff"}


class TestWorkAccounts:
    async def test_a_driver_may_also_own_a_fleet(self, db_session: AsyncSession, make_user) -> None:
        driver = await _account(db_session, make_user, SystemRole.DRIVER)
        await driver_service(db_session).register(driver.id, _licence())
        await fleet_service(db_session).register(driver.id, _business())
        assert await _roles(db_session, driver) == {"driver", "fleet_owner"}

    async def test_and_an_owner_may_drive(self, db_session: AsyncSession, make_user) -> None:
        owner = await _account(db_session, make_user, SystemRole.FLEET_OWNER)
        await fleet_service(db_session).register(owner.id, _business())
        await driver_service(db_session).register(owner.id, _licence())
        assert await _roles(db_session, owner) == {"driver", "fleet_owner"}

    async def test_never_takes_the_passenger_role(
        self, db_session: AsyncSession, make_user
    ) -> None:
        driver = await _account(db_session, make_user, SystemRole.DRIVER)
        with pytest.raises(ConflictError) as raised:
            await grant_role(db_session, driver.id, SystemRole.PASSENGER)
        assert raised.value.code == "WORK_ACCOUNT"
        assert await _roles(db_session, driver) == {"driver"}
