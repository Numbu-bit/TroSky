"""The admin directory (section 2 of the admin requests): every vehicle,
driver and fleet with live status, expiries and figures."""

from __future__ import annotations

import uuid
from datetime import UTC, date, datetime, timedelta
from decimal import Decimal

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.drivers import ApprovalStatus, DocumentStatus, DocumentType
from app.models.vehicles import VehicleDocument
from app.repositories.admin_directory_repository import (
    AdminDirectoryRepository,
    DriverFilters,
    VehicleFilters,
)
from app.services.trip_service import TripService
from tests.integration.scenarios import TripScenario, book, build_trip_scenario, fleet_service

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]


async def _scenario(session: AsyncSession, make_user, *, hours: float = 1) -> TripScenario:
    return await build_trip_scenario(
        session, make_user, departure=datetime.now(UTC) + timedelta(hours=hours)
    )


async def _vehicles(session: AsyncSession, **filters):
    rows, total = await AdminDirectoryRepository(session).list_vehicles(
        VehicleFilters(**filters), sort="registration_number", descending=False, limit=50, offset=0
    )
    return rows, total


async def _drivers(session: AsyncSession, **filters):
    rows, _ = await AdminDirectoryRepository(session).list_drivers(
        DriverFilters(**filters), sort="full_name", descending=False, limit=50, offset=0
    )
    return rows


def _document(vehicle_id: uuid.UUID, kind: DocumentType, expiry: date, status: DocumentStatus):
    return VehicleDocument(
        vehicle_id=vehicle_id,
        document_type=kind,
        storage_key=f"test/{uuid.uuid4()}",
        original_filename="scan.pdf",
        mime_type="application/pdf",
        file_size_bytes=100,
        status=status,
        expiry_date=expiry,
    )


class TestVehicles:
    async def test_live_status_follows_the_trip(self, db_session: AsyncSession, make_user) -> None:
        scenario = await _scenario(db_session, make_user)

        [idle], _ = await _vehicles(db_session, vehicle_id=scenario.vehicle_id)
        await TripService(db_session).start_trip(scenario.trip_id, scenario.driver_user_id)
        [moving], _ = await _vehicles(db_session, vehicle_id=scenario.vehicle_id)
        on_trip, _ = await _vehicles(
            db_session, fleet_id=scenario.fleet_id, live_statuses=["on_trip"]
        )

        assert idle.live_status == "idle"  # a trip still to run today
        assert moving.live_status == "on_trip"
        assert moving.current_trip_id == scenario.trip_id
        assert [row.vehicle_id for row in on_trip] == [scenario.vehicle_id]

    async def test_a_vehicle_with_nothing_today_is_offline(
        self, db_session: AsyncSession, make_user
    ) -> None:
        scenario = await _scenario(db_session, make_user, hours=48)

        [row], _ = await _vehicles(db_session, vehicle_id=scenario.vehicle_id)

        assert row.live_status == "offline"

    async def test_expiry_comes_from_approved_documents_only(
        self, db_session: AsyncSession, make_user
    ) -> None:
        scenario = await _scenario(db_session, make_user)
        soon = datetime.now(UTC).date() + timedelta(days=10)
        db_session.add_all(
            [
                _document(
                    scenario.vehicle_id,
                    DocumentType.VEHICLE_INSURANCE,
                    soon,
                    DocumentStatus.APPROVED,
                ),
                _document(
                    scenario.vehicle_id,
                    DocumentType.ROADWORTHINESS_CERTIFICATE,
                    soon,
                    DocumentStatus.REJECTED,
                ),
            ]
        )
        await db_session.flush()

        [row], _ = await _vehicles(db_session, vehicle_id=scenario.vehicle_id)
        within_30, _ = await _vehicles(
            db_session, fleet_id=scenario.fleet_id, expiring_within_days=30
        )
        within_5, _ = await _vehicles(
            db_session, fleet_id=scenario.fleet_id, expiring_within_days=5
        )

        assert row.insurance_expiry == soon
        assert row.roadworthy_expiry is None
        assert [r.vehicle_id for r in within_30] == [scenario.vehicle_id]
        assert within_5 == []

    async def test_driver_fleet_and_plate_search(self, db_session: AsyncSession, make_user) -> None:
        scenario = await _scenario(db_session, make_user)
        await fleet_service(db_session).assign_driver(
            scenario.owner_user_id, scenario.vehicle_id, scenario.driver_id
        )

        found, total = await _vehicles(db_session, query=scenario.registration_number[-4:].lower())
        rejected_only, _ = await _vehicles(
            db_session, fleet_id=scenario.fleet_id, statuses=[ApprovalStatus.REJECTED]
        )

        assert total >= 1
        row = next(r for r in found if r.vehicle_id == scenario.vehicle_id)
        assert row.driver_id == scenario.driver_id
        assert row.driver_name == "Test User"
        assert row.fleet_id == scenario.fleet_id
        assert rejected_only == []

    async def test_activity_counts_only_completed_bookings(
        self, db_session: AsyncSession, make_user
    ) -> None:
        scenario = await _scenario(db_session, make_user, hours=-1)
        paid = await book(db_session, (await make_user()).id, scenario, seat=0)
        trips = TripService(db_session)
        await trips.start_trip(scenario.trip_id, scenario.driver_user_id)
        await trips.end_trip(scenario.trip_id, scenario.driver_user_id)

        trips_run, completed, revenue = await AdminDirectoryRepository(db_session).vehicle_activity(
            scenario.vehicle_id, since=datetime.now(UTC) - timedelta(days=30)
        )

        assert (trips_run, completed) == (1, 1)
        assert revenue == paid.fare_amount


class TestDrivers:
    async def test_rating_vehicle_and_live_status(
        self, db_session: AsyncSession, make_user
    ) -> None:
        scenario = await _scenario(db_session, make_user)
        await fleet_service(db_session).assign_driver(
            scenario.owner_user_id, scenario.vehicle_id, scenario.driver_id
        )

        [row] = await _drivers(db_session, driver_id=scenario.driver_id)
        in_fleet = await _drivers(db_session, fleet_id=scenario.fleet_id)

        assert row.vehicle_id == scenario.vehicle_id
        assert row.fleet_id == scenario.fleet_id
        assert row.live_status == "idle"
        assert (row.average_rating, row.rating_count) == (None, 0)
        assert [r.driver_id for r in in_fleet] == [scenario.driver_id]

    async def test_licence_expiry_filter(self, db_session: AsyncSession, make_user) -> None:
        scenario = await _scenario(db_session, make_user)  # licence valid for a year

        soon = await _drivers(db_session, driver_id=scenario.driver_id, expiring_within_days=30)
        later = await _drivers(db_session, driver_id=scenario.driver_id, expiring_within_days=400)

        assert soon == []
        assert len(later) == 1


class TestFleets:
    async def test_size_activity_and_revenue(self, db_session: AsyncSession, make_user) -> None:
        scenario = await _scenario(db_session, make_user, hours=-1)
        paid = await book(db_session, (await make_user()).id, scenario, seat=0)
        trips = TripService(db_session)
        await trips.start_trip(scenario.trip_id, scenario.driver_user_id)

        [running], _ = await AdminDirectoryRepository(db_session).list_fleets(
            owner_statuses=None,
            query=None,
            sort="fleet_name",
            descending=False,
            limit=1,
            offset=0,
            fleet_id=scenario.fleet_id,
        )
        await trips.end_trip(scenario.trip_id, scenario.driver_user_id)
        [done], _ = await AdminDirectoryRepository(db_session).list_fleets(
            owner_statuses=None,
            query=None,
            sort="fleet_name",
            descending=False,
            limit=1,
            offset=0,
            fleet_id=scenario.fleet_id,
        )

        assert (running.vehicle_count, running.approved_vehicles, running.active_now) == (1, 1, 1)
        assert running.revenue_30d == Decimal("0")  # nothing completed yet
        assert done.active_now == 0
        assert done.revenue_30d == paid.fare_amount
        assert done.utilization_7d == Decimal("1.00")

    async def test_one_fleets_figures_do_not_leak_into_another(
        self, db_session: AsyncSession, make_user
    ) -> None:
        busy = await _scenario(db_session, make_user, hours=-1)
        quiet = await _scenario(db_session, make_user)
        await book(db_session, (await make_user()).id, busy, seat=0)
        trips = TripService(db_session)
        await trips.start_trip(busy.trip_id, busy.driver_user_id)
        await trips.end_trip(busy.trip_id, busy.driver_user_id)

        [row], _ = await AdminDirectoryRepository(db_session).list_fleets(
            owner_statuses=None,
            query=None,
            sort="fleet_name",
            descending=False,
            limit=1,
            offset=0,
            fleet_id=quiet.fleet_id,
        )

        assert row.revenue_30d == Decimal("0")
        assert row.vehicles_used_7d == 0
