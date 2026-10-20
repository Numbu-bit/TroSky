"""Passenger accounts and work accounts (driver, fleet owner, or both) never
share roles; team roles sit alongside either."""

from __future__ import annotations

import pytest

from app.core.permissions import SystemRole
from app.services.role_service import account_kind_conflict

DRIVER, OWNER, PASSENGER = SystemRole.DRIVER, SystemRole.FLEET_OWNER, SystemRole.PASSENGER


@pytest.mark.parametrize("role", [DRIVER, OWNER])
def test_a_passenger_account_takes_no_work_role(role: SystemRole) -> None:
    conflict = account_kind_conflict({"passenger"}, role)
    assert conflict is not None
    assert conflict.code == "PASSENGER_ACCOUNT"
    assert "different phone number" in conflict.message


@pytest.mark.parametrize("held", [{"driver"}, {"fleet_owner"}, {"driver", "fleet_owner"}])
def test_a_work_account_never_becomes_a_passenger(held: set[str]) -> None:
    conflict = account_kind_conflict(held, PASSENGER)
    assert conflict is not None
    assert conflict.code == "WORK_ACCOUNT"


@pytest.mark.parametrize(("held", "role"), [({"driver"}, OWNER), ({"fleet_owner"}, DRIVER)])
def test_an_owner_may_drive_and_a_driver_may_own(held: set[str], role: SystemRole) -> None:
    assert account_kind_conflict(held, role) is None


@pytest.mark.parametrize("role", [PASSENGER, DRIVER, OWNER])
def test_a_new_or_team_only_account_may_take_any(role: SystemRole) -> None:
    assert account_kind_conflict(set(), role) is None
    assert account_kind_conflict({"admin"}, role) is None


@pytest.mark.parametrize("team", [SystemRole.ADMIN, SystemRole.STAFF, SystemRole.SUPER_ADMIN])
def test_team_roles_join_any_account(team: SystemRole) -> None:
    for held in ({"passenger"}, {"driver"}, {"driver", "fleet_owner"}):
        assert account_kind_conflict(held, team) is None
