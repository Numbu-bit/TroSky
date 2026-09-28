"""Integration tests for AnalyticsService: fleet summaries are tenant-
isolated to the requesting owner and reflect real trip/revenue/rating
data, and the platform overview's counts move as expected — against a
real Postgres."""

from __future__ import annotations

import uuid
from datetime import UTC, date, datetime, timedelta
from decimal import Decimal

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import NotFoundError
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
from app.services.analytics_service import AnalyticsService
from app.services.booking_service import BookingService
from app.services.driver_service import DriverService
from app.services.fleet_service import FleetService
from app.services.rating_service import RatingService
from app.services.trip_service import TripService
from tests.integration.test_trip_service import _make_route

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]


async def _make_fleet_with_completed_trip(
    session: AsyncSession, make_user
) -> tuple[uuid.UUID, uuid.UUID, uuid.UUID]:
    """Returns ``(fleet_owner_user_id, fleet_id, booking_id)`` for a fleet
    with one vehicle that completed one paid, rated trip."""
    fleet_service = FleetService(session, SandboxStorageProvider(), NoOpMalwareScanner())
    owner_user_id = (await make_user()).id
    await fleet_service.register(owner_user_id, FleetOwnerRegisterRequest(business_name="X Co"))
    fleet = await fleet_service.create_fleet(owner_user_id, FleetCreateRequest(name="Fleet A"))

    driver_service = DriverService(session, SandboxStorageProvider(), NoOpMalwareScanner())
    driver_user_id = (await make_user()).id
    driver = await driver_service.register(
        driver_user_id,
        DriverRegisterRequest(
            license_number=f"GHA-{uuid.uuid4().hex[:8]}",
            license_expiry=date.today() + timedelta(days=365),
        ),
    )
    await driver_service.approve(driver.id, reviewer_id=(await make_user()).id, notes=None)

    vehicle = await fleet_service.create_vehicle(
        owner_user_id,
        fleet.id,
        VehicleCreateRequest(
            registration_number=f"GR-{uuid.uuid4().hex[:6].upper()}",
            vehicle_type=VehicleType.BUS,
            capacity=1,
        ),
    )
    await fleet_service.approve_vehicle(vehicle.id, reviewer_id=(await make_user()).id, notes=None)
    _, seat_rows = await fleet_service.set_seat_layout(
        owner_user_id,
        vehicle.id,
        SeatLayoutRequest(
            rows=1, columns=1, seats=[SeatInput(seat_number="S1", row_number=1, column_number=1)]
        ),
    )

    route = await _make_route(session, make_user)
    trip_service = TripService(session)
    trip = await trip_service.create_trip(
        route_id=route.id,
        route_schedule_id=None,
        scheduled_departure_at=datetime.now(UTC) + timedelta(hours=1),
        scheduled_arrival_at=None,
        fare_amount=Decimal("30.00"),
        created_by=None,
    )
    await trip_service.assign_driver(trip.id, driver.id, assigned_by=None)
    await trip_service.assign_vehicle(trip.id, vehicle.id, assigned_by=None)

    booking_service = BookingService(session)
    passenger_id = (await make_user()).id
    booking = await booking_service.create_booking(
        passenger_id,
        BookingCreateRequest(
            trip_id=trip.id,
            passengers=[PassengerInput(seat_id=seat_rows[0].id, full_name="Pat Mensah")],
        ),
        idempotency_key=None,
    )
    await booking_service.confirm_booking(booking.id)
    await trip_service.start_trip(trip.id, driver_user_id)
    await trip_service.end_trip(trip.id, driver_user_id)
    await RatingService(session).rate_booking(
        booking.id, passenger_id=passenger_id, score=5, comment=None
    )

    return owner_user_id, fleet.id, booking.id


class TestFleetSummary:
    async def test_summary_reflects_completed_trip_revenue_and_rating(
        self, db_session: AsyncSession, make_user
    ) -> None:
        owner_user_id, fleet_id, _ = await _make_fleet_with_completed_trip(db_session, make_user)
        service = AnalyticsService(db_session)
        summary = await service.get_fleet_summary(owner_user_id, fleet_id)

        assert summary.vehicle_count == 1
        assert summary.total_trips == 1
        assert summary.completed_trips == 1
        assert summary.total_revenue == Decimal("30.00")
        assert summary.rating_count == 1
        assert summary.average_rating == Decimal("5.00")

    async def test_other_owner_cannot_see_fleet_summary(
        self, db_session: AsyncSession, make_user
    ) -> None:
        _, fleet_id, _ = await _make_fleet_with_completed_trip(db_session, make_user)
        service = AnalyticsService(db_session)
        with pytest.raises(NotFoundError):
            await service.get_fleet_summary(uuid.uuid4(), fleet_id)


class TestPlatformOverview:
    async def test_overview_counts_reflect_seeded_data(
        self, db_session: AsyncSession, make_user
    ) -> None:
        await _make_fleet_with_completed_trip(db_session, make_user)
        service = AnalyticsService(db_session)
        overview = await service.get_platform_overview()

        assert overview.total_bookings >= 1
        assert overview.completed_bookings >= 1
        assert overview.total_drivers >= 1
        assert overview.total_fleet_owners >= 1
