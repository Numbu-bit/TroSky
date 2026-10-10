"""Integration tests for BookingService: seat-hold creation, idempotency,
cancellation policy, confirmation, expiration — and the concurrency
guarantee itself (two simultaneous attempts on the same seat, only one
succeeds), against a real Postgres."""

from __future__ import annotations

import asyncio
import uuid
from datetime import UTC, datetime, timedelta
from decimal import Decimal

import pytest
from sqlalchemy import delete as sa_delete
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_session_factory
from app.core.exceptions import (
    ConflictError,
    IdempotencyConflictError,
    InvalidStateTransitionError,
    SeatNotAvailableError,
)
from app.models.bookings import (
    Booking,
    BookingPassenger,
    BookingStatus,
    BookingStatusHistory,
    ReservationStatus,
    SeatReservation,
)
from app.models.routes import Route, Stop
from app.models.vehicles import VehicleType
from app.providers.storage.malware_scan import NoOpMalwareScanner
from app.providers.storage.sandbox import SandboxStorageProvider
from app.schemas.booking import BookingCreateRequest, PassengerInput
from app.schemas.fleet import (
    FleetCreateRequest,
    FleetOwnerRegisterRequest,
    SeatInput,
    SeatLayoutRequest,
    VehicleCreateRequest,
)
from app.services.booking_service import BookingService
from app.services.fleet_service import FleetService
from app.services.trip_service import TripService
from app.utilities.geo import latlng_to_wkt

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]


async def _make_bookable_trip(
    session: AsyncSession, *, seat_count: int = 4, make_user
) -> tuple[uuid.UUID, list[uuid.UUID], Decimal]:
    """Creates a route/trip/vehicle/seat-layout and returns
    (trip_id, seat_ids, fare_amount) inside the caller's own session."""
    origin = Stop(name=f"O-{uuid.uuid4().hex[:6]}", location=latlng_to_wkt(5.6, -0.2))
    destination = Stop(name=f"D-{uuid.uuid4().hex[:6]}", location=latlng_to_wkt(6.7, -1.6))
    session.add_all([origin, destination])
    await session.flush()

    route = Route(
        name=f"R-{uuid.uuid4().hex[:8]}",
        origin_stop_id=origin.id,
        destination_stop_id=destination.id,
    )
    session.add(route)
    await session.flush()

    fleet_service = FleetService(session, SandboxStorageProvider(), NoOpMalwareScanner())
    owner_user_id = (await make_user()).id
    await fleet_service.register(owner_user_id, FleetOwnerRegisterRequest(business_name="XY Co"))
    fleet = await fleet_service.create_fleet(owner_user_id, FleetCreateRequest(name="Fleet F"))
    vehicle = await fleet_service.create_vehicle(
        owner_user_id,
        fleet.id,
        VehicleCreateRequest(
            registration_number=f"GR-{uuid.uuid4().hex[:6].upper()}",
            vehicle_type=VehicleType.BUS,
            capacity=seat_count,
        ),
    )
    seats = [
        SeatInput(seat_number=f"S{i}", row_number=1, column_number=i + 1) for i in range(seat_count)
    ]
    layout, seat_rows = await fleet_service.set_seat_layout(
        owner_user_id, vehicle.id, SeatLayoutRequest(rows=1, columns=seat_count, seats=seats)
    )
    # Trips only accept approved vehicles, so the helper has to walk the
    # same admin review step a real fleet owner would.
    await fleet_service.approve_vehicle(vehicle.id, reviewer_id=(await make_user()).id, notes=None)

    trip_service = TripService(session)
    fare = Decimal("20.00")
    trip = await trip_service.create_trip(
        route_id=route.id,
        route_schedule_id=None,
        scheduled_departure_at=datetime.now(UTC) + timedelta(hours=2),
        scheduled_arrival_at=None,
        fare_amount=fare,
        created_by=None,
    )
    await trip_service.assign_vehicle(trip.id, vehicle.id, assigned_by=None)

    return trip.id, [s.id for s in seat_rows], fare


class TestCreateBooking:
    async def test_create_booking_holds_seats(self, db_session: AsyncSession, make_user) -> None:
        trip_id, seat_ids, fare = await _make_bookable_trip(db_session, make_user=make_user)
        service = BookingService(db_session)
        request = BookingCreateRequest(
            trip_id=trip_id,
            passengers=[PassengerInput(seat_id=seat_ids[0], full_name="Ama Mensah")],
        )
        booking = await service.create_booking(
            (await make_user()).id, request, idempotency_key=None
        )

        assert booking.status == BookingStatus.PENDING
        # The passenger pays the operator's fare plus TroSky's booking fee;
        # the three stored amounts must always reconcile.
        assert booking.fare_amount == fare
        assert booking.total_amount == booking.fare_amount + booking.platform_fee
        assert booking.expires_at is not None

        taken = await service._bookings.list_active_seat_ids_for_trip(trip_id)
        assert seat_ids[0] in taken

    async def test_create_booking_rejects_seat_not_on_vehicle(
        self, db_session: AsyncSession, make_user
    ) -> None:
        trip_id, _, _ = await _make_bookable_trip(db_session, make_user=make_user)
        service = BookingService(db_session)
        request = BookingCreateRequest(
            trip_id=trip_id,
            passengers=[PassengerInput(seat_id=uuid.uuid4(), full_name="Ama Mensah")],
        )
        with pytest.raises(Exception):  # noqa: B017, PT011 - NotFoundError
            await service.create_booking((await make_user()).id, request, idempotency_key=None)

    async def test_create_booking_on_non_bookable_trip_rejected(
        self, db_session: AsyncSession, make_user
    ) -> None:
        trip_id, seat_ids, _ = await _make_bookable_trip(db_session, make_user=make_user)
        trip_service = TripService(db_session)
        await trip_service.cancel_trip(trip_id, cancelled_by=None, reason="test")

        service = BookingService(db_session)
        request = BookingCreateRequest(
            trip_id=trip_id,
            passengers=[PassengerInput(seat_id=seat_ids[0], full_name="Ama Mensah")],
        )
        with pytest.raises(ConflictError):
            await service.create_booking((await make_user()).id, request, idempotency_key=None)

    async def test_idempotent_replay_returns_same_booking(
        self, db_session: AsyncSession, make_user
    ) -> None:
        trip_id, seat_ids, _ = await _make_bookable_trip(db_session, make_user=make_user)
        service = BookingService(db_session)
        key = uuid.uuid4()
        request = BookingCreateRequest(
            trip_id=trip_id,
            passengers=[PassengerInput(seat_id=seat_ids[0], full_name="Ama Mensah")],
        )
        passenger_id = (await make_user()).id
        first = await service.create_booking(passenger_id, request, idempotency_key=key)
        second = await service.create_booking(passenger_id, request, idempotency_key=key)
        assert first.id == second.id

    async def test_idempotency_conflict_on_different_payload(
        self, db_session: AsyncSession, make_user
    ) -> None:
        trip_id, seat_ids, _ = await _make_bookable_trip(db_session, make_user=make_user)
        service = BookingService(db_session)
        key = uuid.uuid4()
        passenger_id = (await make_user()).id
        first_request = BookingCreateRequest(
            trip_id=trip_id,
            passengers=[PassengerInput(seat_id=seat_ids[0], full_name="Ama Mensah")],
        )
        await service.create_booking(passenger_id, first_request, idempotency_key=key)

        second_request = BookingCreateRequest(
            trip_id=trip_id,
            passengers=[PassengerInput(seat_id=seat_ids[1], full_name="Ama Mensah")],
        )
        with pytest.raises(IdempotencyConflictError):
            await service.create_booking(passenger_id, second_request, idempotency_key=key)


class TestCancellation:
    async def test_cancel_before_trip_start_auto_approved(
        self, db_session: AsyncSession, make_user
    ) -> None:
        trip_id, seat_ids, _ = await _make_bookable_trip(db_session, make_user=make_user)
        service = BookingService(db_session)
        request = BookingCreateRequest(
            trip_id=trip_id,
            passengers=[PassengerInput(seat_id=seat_ids[0], full_name="Ama Mensah")],
        )
        passenger_id = (await make_user()).id
        booking = await service.create_booking(passenger_id, request, idempotency_key=None)

        cancelled = await service.cancel_booking(
            booking.id, requesting_user_id=passenger_id, reason="Change of plans"
        )
        assert cancelled.status == BookingStatus.CANCELLED

        taken = await service._bookings.list_active_seat_ids_for_trip(trip_id)
        assert seat_ids[0] not in taken

    async def test_cannot_cancel_twice(self, db_session: AsyncSession, make_user) -> None:
        trip_id, seat_ids, _ = await _make_bookable_trip(db_session, make_user=make_user)
        service = BookingService(db_session)
        request = BookingCreateRequest(
            trip_id=trip_id,
            passengers=[PassengerInput(seat_id=seat_ids[0], full_name="Ama Mensah")],
        )
        passenger_id = (await make_user()).id
        booking = await service.create_booking(passenger_id, request, idempotency_key=None)
        await service.cancel_booking(booking.id, requesting_user_id=passenger_id, reason=None)

        with pytest.raises(InvalidStateTransitionError):
            await service.cancel_booking(booking.id, requesting_user_id=passenger_id, reason=None)

    async def test_other_passenger_cannot_cancel(self, db_session: AsyncSession, make_user) -> None:
        trip_id, seat_ids, _ = await _make_bookable_trip(db_session, make_user=make_user)
        service = BookingService(db_session)
        request = BookingCreateRequest(
            trip_id=trip_id,
            passengers=[PassengerInput(seat_id=seat_ids[0], full_name="Ama Mensah")],
        )
        owner_id = (await make_user()).id
        booking = await service.create_booking(owner_id, request, idempotency_key=None)

        with pytest.raises(Exception):  # noqa: B017, PT011 - NotFoundError
            await service.cancel_booking(
                booking.id, requesting_user_id=(await make_user()).id, reason=None
            )


class TestConfirmationAndExpiry:
    async def test_confirm_booking_confirms_reservations(
        self, db_session: AsyncSession, make_user
    ) -> None:
        trip_id, seat_ids, _ = await _make_bookable_trip(db_session, make_user=make_user)
        service = BookingService(db_session)
        request = BookingCreateRequest(
            trip_id=trip_id,
            passengers=[PassengerInput(seat_id=seat_ids[0], full_name="Ama Mensah")],
        )
        booking = await service.create_booking(
            (await make_user()).id, request, idempotency_key=None
        )

        confirmed = await service.confirm_booking(booking.id)
        assert confirmed.status == BookingStatus.CONFIRMED

        reservations = await service._bookings.list_reservations_for_booking(booking.id)
        assert all(r.status == ReservationStatus.CONFIRMED for r in reservations)

    async def test_confirm_is_idempotent(self, db_session: AsyncSession, make_user) -> None:
        trip_id, seat_ids, _ = await _make_bookable_trip(db_session, make_user=make_user)
        service = BookingService(db_session)
        request = BookingCreateRequest(
            trip_id=trip_id,
            passengers=[PassengerInput(seat_id=seat_ids[0], full_name="Ama Mensah")],
        )
        booking = await service.create_booking(
            (await make_user()).id, request, idempotency_key=None
        )
        await service.confirm_booking(booking.id)
        twice = await service.confirm_booking(booking.id)
        assert twice.status == BookingStatus.CONFIRMED

    async def test_expire_stale_bookings_releases_seats(
        self, db_session: AsyncSession, make_user
    ) -> None:
        trip_id, seat_ids, _ = await _make_bookable_trip(db_session, make_user=make_user)
        service = BookingService(db_session)
        request = BookingCreateRequest(
            trip_id=trip_id,
            passengers=[PassengerInput(seat_id=seat_ids[0], full_name="Ama Mensah")],
        )
        booking = await service.create_booking(
            (await make_user()).id, request, idempotency_key=None
        )

        # Force it into the past so the sweep picks it up.
        stored = await service._bookings.get_by_id(booking.id)
        assert stored is not None
        stored.expires_at = datetime.now(UTC) - timedelta(seconds=1)
        await db_session.flush()

        # The sweep also expires any unpaid booking earlier tests committed
        # and left to lapse, so this one is checked by itself below.
        expired_count = await service.expire_stale_bookings()
        assert expired_count >= 1

        refreshed = await service._bookings.get_by_id(booking.id)
        assert refreshed is not None
        assert refreshed.status == BookingStatus.EXPIRED

        taken = await service._bookings.list_active_seat_ids_for_trip(trip_id)
        assert seat_ids[0] not in taken


class TestConcurrentSeatReservation:
    async def test_only_one_of_two_concurrent_attempts_succeeds(
        self, committed_user, committed_make_user
    ) -> None:
        """The critical correctness test: two independent database sessions
        (simulating two concurrent API requests) racing for the same single
        seat. Exactly one must win — enforced by the partial unique index,
        not by application-level locking.

        This test needs two genuinely independent, separately-committing
        connections to observe real cross-session contention, so it can't
        use the SAVEPOINT-isolated ``db_session`` fixture like the rest of
        this module; it depends on ``require_postgres`` directly instead so
        it skips (rather than fails with a raw connection error) when no
        real Postgres is reachable, consistent with every other
        Postgres-dependent test.
        """
        session_factory = get_session_factory()
        async with session_factory() as setup_session, setup_session.begin():
            trip_id, seat_ids, _ = await _make_bookable_trip(
                setup_session, seat_count=1, make_user=committed_make_user
            )
        seat_id = seat_ids[0]

        async def attempt() -> Booking:
            async with session_factory() as session:
                service = BookingService(session)
                request = BookingCreateRequest(
                    trip_id=trip_id,
                    passengers=[PassengerInput(seat_id=seat_id, full_name="Racer")],
                )
                try:
                    booking = await service.create_booking(
                        committed_user.id, request, idempotency_key=None
                    )
                except Exception:
                    await session.rollback()
                    raise
                else:
                    await session.commit()
                    return booking

        results = await asyncio.gather(attempt(), attempt(), return_exceptions=True)

        successes = [r for r in results if isinstance(r, Booking)]
        failures = [r for r in results if isinstance(r, SeatNotAvailableError)]

        assert len(successes) == 1, f"Expected exactly one winner, got: {results}"
        assert len(failures) == 1, f"Expected exactly one SeatNotAvailableError, got: {results}"

        # This test commits, unlike the rest of the module, so it has to
        # clean up after itself. A left-behind pending booking eventually
        # ages past its hold and is then swept by whichever later run
        # exercises expire_stale_bookings, which counts across the table.
        async with session_factory() as cleanup, cleanup.begin():
            await cleanup.execute(
                sa_delete(SeatReservation).where(SeatReservation.trip_id == trip_id)
            )
            await cleanup.execute(
                sa_delete(BookingStatusHistory).where(
                    BookingStatusHistory.booking_id.in_(
                        select(Booking.id).where(Booking.trip_id == trip_id)
                    )
                )
            )
            await cleanup.execute(
                sa_delete(BookingPassenger).where(
                    BookingPassenger.booking_id.in_(
                        select(Booking.id).where(Booking.trip_id == trip_id)
                    )
                )
            )
            await cleanup.execute(sa_delete(Booking).where(Booking.trip_id == trip_id))
