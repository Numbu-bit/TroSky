"""Integration tests for RatingService: a completed booking can be rated
exactly once, by its own passenger, and the driver's average reflects it —
against a real Postgres."""

from __future__ import annotations

import uuid
from datetime import UTC, datetime, timedelta
from decimal import Decimal

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ConflictError, NotFoundError
from app.repositories.vehicle_repository import SeatSpec, VehicleRepository
from app.schemas.booking import BookingCreateRequest, PassengerInput
from app.services.booking_service import BookingService
from app.services.rating_service import RatingService
from app.services.trip_service import TripService
from tests.integration.test_trip_service import _make_approved_driver_and_vehicle, _make_route

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]


async def _make_completed_booking(
    session: AsyncSession, *, passenger_id: uuid.UUID, make_user
) -> tuple[uuid.UUID, uuid.UUID]:
    """Returns ``(booking_id, driver_user_id)`` for a booking whose trip has
    fully run: driver assigned, booked+confirmed, started, and ended
    (bookings are only accepted while a trip is scheduled or boarding)."""
    route = await _make_route(session, make_user)
    driver_user_id, driver_id, vehicle_id = await _make_approved_driver_and_vehicle(
        session, make_user
    )
    trip_service = TripService(session)
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

    booking_service = BookingService(session)
    booking = await booking_service.create_booking(
        passenger_id,
        BookingCreateRequest(
            trip_id=trip.id,
            passengers=[
                PassengerInput(
                    seat_id=(await _first_seat(session, vehicle_id)), full_name="Pat Mensah"
                )
            ],
        ),
        idempotency_key=None,
    )
    await booking_service.confirm_booking(booking.id)
    await trip_service.start_trip(trip.id, driver_user_id)
    await trip_service.end_trip(trip.id, driver_user_id)
    return booking.id, driver_user_id


async def _first_seat(session: AsyncSession, vehicle_id: uuid.UUID) -> uuid.UUID:
    """The vehicle's first seat, giving it a one-seat layout if it has none."""
    vehicles = VehicleRepository(session)
    layout = await vehicles.get_seat_layout(vehicle_id)
    if layout is None:
        layout = await vehicles.replace_seat_layout(
            vehicle_id,
            name=None,
            rows=1,
            columns=1,
            seats=[SeatSpec(seat_number="S1", row_number=1, column_number=1)],
        )
    seats = await vehicles.list_seats(layout.id)
    return seats[0].id


class TestRateBooking:
    async def test_rating_a_completed_booking_succeeds(
        self, db_session: AsyncSession, make_user
    ) -> None:
        passenger_id = (await make_user()).id
        booking_id, driver_user_id = await _make_completed_booking(
            db_session, passenger_id=passenger_id, make_user=make_user
        )
        service = RatingService(db_session)
        rating = await service.rate_booking(
            booking_id, passenger_id=passenger_id, score=5, comment="Great trip"
        )
        assert rating.score == 5
        assert rating.driver_id is not None

    async def test_cannot_rate_twice(self, db_session: AsyncSession, make_user) -> None:
        passenger_id = (await make_user()).id
        booking_id, _ = await _make_completed_booking(
            db_session, passenger_id=passenger_id, make_user=make_user
        )
        service = RatingService(db_session)
        await service.rate_booking(booking_id, passenger_id=passenger_id, score=4, comment=None)
        with pytest.raises(ConflictError):
            await service.rate_booking(booking_id, passenger_id=passenger_id, score=2, comment=None)

    async def test_cannot_rate_someone_elses_booking(
        self, db_session: AsyncSession, make_user
    ) -> None:
        booking_id, _ = await _make_completed_booking(
            db_session, passenger_id=(await make_user()).id, make_user=make_user
        )
        service = RatingService(db_session)
        with pytest.raises(NotFoundError):
            await service.rate_booking(booking_id, passenger_id=uuid.uuid4(), score=3, comment=None)

    async def test_driver_average_reflects_new_ratings(
        self, db_session: AsyncSession, make_user
    ) -> None:
        passenger_id = (await make_user()).id
        booking_id, driver_user_id = await _make_completed_booking(
            db_session, passenger_id=passenger_id, make_user=make_user
        )
        service = RatingService(db_session)
        rating = await service.rate_booking(
            booking_id, passenger_id=passenger_id, score=4, comment=None
        )
        assert rating.driver_id is not None
        average, count = await service.get_driver_average_rating(rating.driver_id)
        assert count == 1
        assert average == Decimal("4.00")
