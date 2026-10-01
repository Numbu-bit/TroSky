"""Frontend requests G2 (a driver's trips), G3 (the passenger manifest), G8
(the admin trip list) and G12 (bookings with their trip, upcoming/past) --
against a real Postgres."""

from __future__ import annotations

import uuid
from datetime import UTC, datetime, timedelta

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ForbiddenError, NotFoundError
from app.models.bookings import BookingStatus
from app.models.trips import TripStatus
from app.repositories.trip_repository import TripRepository
from app.services.booking_service import BookingService
from app.services.ticket_service import TicketService
from app.services.trip_service import TripService
from tests.integration.scenarios import (
    approved_driver,
    book,
    build_trip_scenario,
    driver_service,
)

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]

DEPARTURE = datetime(2031, 3, 17, 7, 15, tzinfo=UTC)


async def _board(session: AsyncSession, booking_id: uuid.UUID, scenario, passenger_id) -> None:
    """Scan the booking's ticket, as the driver's phone does at the door."""
    tickets = TicketService(session)
    [ticket] = await tickets.list_tickets_for_booking(booking_id, requesting_user_id=passenger_id)
    await tickets.validate_qr(
        tickets.get_qr_token(ticket),
        trip_id=scenario.trip_id,
        validated_by=scenario.driver_user_id,
    )


class TestDriverTrips:
    async def test_a_driver_sees_their_trip_with_route_vehicle_and_seats(
        self, db_session: AsyncSession, make_user
    ) -> None:
        s = await build_trip_scenario(db_session, make_user, departure=DEPARTURE)
        await book(db_session, (await make_user()).id, s, seat=0)  # paid
        await book(db_session, (await make_user()).id, s, seat=1, confirm=False)  # held

        trips, total = await driver_service(db_session).list_own_trips(
            s.driver_user_id, statuses=None, on_date=None, limit=20, offset=0
        )

        assert total == 1
        [trip] = trips
        assert trip.trip_id == s.trip_id
        assert trip.route_name == s.route_name
        assert (trip.origin_stop_name, trip.destination_stop_name) == (
            s.stop_names[0],
            s.stop_names[2],
        )
        assert trip.vehicle_registration_number == s.registration_number
        assert trip.status == TripStatus.SCHEDULED
        # Four seats; one paid (on the manifest), one more held for payment.
        assert (trip.seats_total, trip.seats_booked, trip.seats_taken) == (4, 1, 2)
        assert trip.boarded_count == 0

    async def test_filters_by_status_and_day(self, db_session: AsyncSession, make_user) -> None:
        s = await build_trip_scenario(db_session, make_user, departure=DEPARTURE)
        drivers = driver_service(db_session)

        async def count(**filters: object) -> int:
            _, total = await drivers.list_own_trips(s.driver_user_id, limit=20, offset=0, **filters)
            return total

        assert await count(statuses=[TripStatus.SCHEDULED], on_date=DEPARTURE.date()) == 1
        assert await count(statuses=[TripStatus.COMPLETED], on_date=None) == 0
        assert await count(statuses=None, on_date=DEPARTURE.date() + timedelta(days=1)) == 0

    async def test_a_driver_never_sees_another_drivers_trips(
        self, db_session: AsyncSession, make_user
    ) -> None:
        mine = await build_trip_scenario(db_session, make_user, departure=DEPARTURE)
        await build_trip_scenario(db_session, make_user, departure=DEPARTURE)

        trips, total = await driver_service(db_session).list_own_trips(
            mine.driver_user_id, statuses=None, on_date=None, limit=20, offset=0
        )
        assert total == 1
        assert [t.trip_id for t in trips] == [mine.trip_id]

    async def test_boarded_count_follows_ticket_scans(
        self, db_session: AsyncSession, make_user
    ) -> None:
        s = await build_trip_scenario(db_session, make_user, departure=DEPARTURE)
        passenger = await make_user()
        booking = await book(db_session, passenger.id, s, seat=0)
        await _board(db_session, booking.id, s, passenger.id)

        [trip], _ = await driver_service(db_session).list_own_trips(
            s.driver_user_id, statuses=None, on_date=None, limit=20, offset=0
        )
        assert trip.boarded_count == 1


class TestManifest:
    async def test_lists_ticket_holders_in_pickup_order_with_masked_phones(
        self, db_session: AsyncSession, make_user
    ) -> None:
        s = await build_trip_scenario(db_session, make_user, departure=DEPARTURE)
        # Booked first, but boards further along the route.
        from_legon = await book(
            db_session,
            (await make_user()).id,
            s,
            seat=1,
            origin=s.stop_ids[1],
            name="Kofi Mensah",
            phone="0244564567",
        )
        from_start = await book(db_session, (await make_user()).id, s, seat=0, name="Ama Owusu")
        await book(db_session, (await make_user()).id, s, seat=2, confirm=False)  # unpaid

        entries = await TripService(db_session).get_manifest(s.trip_id, s.driver_user_id)

        assert [e.passenger_full_name for e in entries] == ["Ama Owusu", "Kofi Mensah"]
        assert [e.pickup_stop_name for e in entries] == [s.stop_names[0], s.stop_names[1]]
        assert [e.booking_reference for e in entries] == [
            from_start.booking_reference,
            from_legon.booking_reference,
        ]
        assert [e.seat_label for e in entries] == ["A1", "A2"]
        # The passenger's own number when given, masked either way.
        assert entries[1].phone_number == "+23324•••4567"
        assert "•••" in entries[0].phone_number
        assert not any(e.boarded for e in entries)

    async def test_scanning_a_ticket_marks_the_passenger_boarded(
        self, db_session: AsyncSession, make_user
    ) -> None:
        s = await build_trip_scenario(db_session, make_user, departure=DEPARTURE)
        passenger = await make_user()
        booking = await book(db_session, passenger.id, s, seat=0)
        await _board(db_session, booking.id, s, passenger.id)

        [entry] = await TripService(db_session).get_manifest(s.trip_id, s.driver_user_id)
        assert entry.boarded is True
        assert entry.boarded_at is not None

    async def test_a_cancelled_booking_leaves_the_manifest(
        self, db_session: AsyncSession, make_user
    ) -> None:
        s = await build_trip_scenario(db_session, make_user, departure=DEPARTURE)
        passenger = await make_user()
        booking = await book(db_session, passenger.id, s, seat=0)
        await BookingService(db_session).cancel_booking(
            booking.id, requesting_user_id=passenger.id, reason="Plans changed"
        )
        assert await TripService(db_session).get_manifest(s.trip_id, s.driver_user_id) == []

    async def test_only_the_assigned_driver_may_see_it(
        self, db_session: AsyncSession, make_user
    ) -> None:
        s = await build_trip_scenario(db_session, make_user, departure=DEPARTURE)
        other_driver_user, _ = await approved_driver(db_session, make_user)
        trips = TripService(db_session)

        with pytest.raises(ForbiddenError):
            await trips.get_manifest(s.trip_id, other_driver_user.id)
        with pytest.raises(ForbiddenError):
            await trips.get_manifest(s.trip_id, (await make_user()).id)  # not a driver
        with pytest.raises(NotFoundError):
            await trips.get_manifest(uuid.uuid4(), s.driver_user_id)


class TestAdminTripList:
    async def test_filters_and_shows_driver_and_free_seats(
        self, db_session: AsyncSession, make_user
    ) -> None:
        s = await build_trip_scenario(db_session, make_user, departure=DEPARTURE)
        await book(db_session, (await make_user()).id, s, seat=0)
        await book(db_session, (await make_user()).id, s, seat=1, confirm=False)
        trips = TripService(db_session)

        found, total = await trips.list_trips(
            statuses=[TripStatus.SCHEDULED],
            on_date=DEPARTURE.date(),
            route_id=s.route_id,
            driver_id=s.driver_id,
            limit=10,
            offset=0,
        )
        assert total == 1
        [trip] = found
        assert trip.driver_id == s.driver_id
        assert trip.driver_name == "Test User"
        assert trip.available_seats == 2  # 4 seats: 1 paid, 1 held

        _, none = await trips.list_trips(
            statuses=None,
            on_date=None,
            route_id=uuid.uuid4(),
            driver_id=None,
            limit=10,
            offset=0,
        )
        assert none == 0


class TestBookingViews:
    async def test_a_booking_carries_its_trip_and_its_own_stops(
        self, db_session: AsyncSession, make_user
    ) -> None:
        s = await build_trip_scenario(db_session, make_user, departure=DEPARTURE)
        booking = await book(db_session, (await make_user()).id, s, seat=1, origin=s.stop_ids[1])

        [view] = await BookingService(db_session).describe([booking])

        assert view.trip is not None
        assert view.trip.route_name == s.route_name
        assert view.trip.scheduled_departure_at == DEPARTURE
        assert view.trip.vehicle_registration_number == s.registration_number
        assert (view.trip.origin_stop_name, view.trip.destination_stop_name) == (
            s.stop_names[0],
            s.stop_names[2],
        )
        # This passenger boards at Legon and rides to the end of the route.
        assert view.boarding_stop_name == s.stop_names[1]
        assert view.alighting_stop_name == s.stop_names[2]
        assert [p.full_name for p in view.passengers] == ["Ama Owusu"]

    async def test_upcoming_and_past_bookings_are_split_by_the_trip(
        self, db_session: AsyncSession, make_user
    ) -> None:
        passenger = await make_user()
        ahead = await build_trip_scenario(db_session, make_user, departure=DEPARTURE)
        behind = await build_trip_scenario(
            db_session, make_user, departure=datetime.now(UTC) + timedelta(hours=3)
        )
        ahead_booking = await book(db_session, passenger.id, ahead, seat=0)
        behind_booking = await book(db_session, passenger.id, behind, seat=0)
        behind_trip = await TripRepository(db_session).get_by_id(behind.trip_id)
        assert behind_trip is not None
        behind_trip.scheduled_departure_at = datetime.now(UTC) - timedelta(days=2)
        await db_session.flush()
        service = BookingService(db_session)

        async def ids(**filters: object) -> list[uuid.UUID]:
            bookings, total = await service.list_own_bookings(
                passenger.id, limit=10, offset=0, **filters
            )
            assert total == len(bookings)
            return [b.id for b in bookings]

        assert await ids(upcoming=True) == [ahead_booking.id]
        assert await ids(upcoming=False) == [behind_booking.id]
        assert set(await ids()) == {ahead_booking.id, behind_booking.id}
        assert await ids(statuses=[BookingStatus.PENDING]) == []

        # Under way counts as upcoming even after its departure time -- and
        # sorts first, departing soonest.
        behind_trip.status = TripStatus.IN_PROGRESS
        await db_session.flush()
        assert await ids(upcoming=True) == [behind_booking.id, ahead_booking.id]
        assert await ids(upcoming=False) == []
