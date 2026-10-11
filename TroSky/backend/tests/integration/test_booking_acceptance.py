"""Drivers accept or decline trips and bookings; admins can answer for them;
a booking nobody takes moves to another vehicle going the same way; and a
passenger's seat frees up when they get off.

Built on the Madina -> Legon -> Circle scenario (stops ~10 km apart), with a
second (and sometimes third) trip on the same route for bookings to move to.
"""

from __future__ import annotations

import uuid
from datetime import UTC, datetime, timedelta
from decimal import Decimal

import pytest
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings, get_settings
from app.core.exceptions import (
    ConflictError,
    ForbiddenError,
    InvalidStateTransitionError,
    NotFoundError,
)
from app.models.bookings import (
    AlightedHow,
    Booking,
    BookingOffer,
    BookingStatus,
    OfferStatus,
    ReservationStatus,
    SeatReservation,
)
from app.models.driver_actions import ActedAs, DriverActionKind
from app.models.notifications import Notification
from app.models.routes import Stop
from app.models.trips import AssignmentResponse
from app.repositories.booking_repository import BookingRepository
from app.repositories.driver_action_repository import DriverActionRepository
from app.repositories.trip_repository import TripRepository
from app.schemas.booking import BookingCreateRequest, PassengerInput
from app.services.alighting_service import AlightingService
from app.services.booking_acceptance_service import BookingAcceptanceService
from app.services.booking_service import BookingService
from app.services.trip_service import TripService
from app.services.wallet_service import WalletService
from app.utilities.geo import wkb_to_latlng
from tests.integration.scenarios import (
    TripScenario,
    another_trip,
    approved_driver,
    book,
    build_trip_scenario,
)

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]

MADINA, LEGON, CIRCLE = 0, 1, 2


@pytest.fixture
def accepting() -> Settings:
    return get_settings().model_copy(update={"BOOKING_ACCEPTANCE_REQUIRED": True})


async def _scenario(session: AsyncSession, make_user, *, hours: float = 2) -> TripScenario:
    departure = datetime.now(UTC) + timedelta(hours=hours)
    return await build_trip_scenario(session, make_user, departure=departure)


async def _request(
    session: AsyncSession,
    make_user,
    scenario: TripScenario,
    settings: Settings,
    *,
    seats: tuple[int, ...] = (0,),
    origin: int = LEGON,
    destination: int = CIRCLE,
) -> Booking:
    passenger = await make_user()
    return await BookingService(session, settings=settings).create_booking(
        passenger.id,
        BookingCreateRequest(
            trip_id=scenario.trip_id,
            passengers=[
                PassengerInput(seat_id=scenario.seat_ids[seat], full_name=f"Rider {seat}")
                for seat in seats
            ],
            origin_stop_id=scenario.stop_ids[origin],
            destination_stop_id=scenario.stop_ids[destination],
        ),
        idempotency_key=None,
    )


async def _pending_offer(session: AsyncSession, booking_id: uuid.UUID) -> BookingOffer | None:
    return await session.scalar(
        select(BookingOffer).where(
            BookingOffer.booking_id == booking_id, BookingOffer.status == OfferStatus.PENDING
        )
    )


async def _active_seats(session: AsyncSession, trip_id: uuid.UUID) -> set[uuid.UUID]:
    return await BookingRepository(session).list_active_seat_ids_for_trip(trip_id)


async def _titles(session: AsyncSession, user_id: uuid.UUID) -> list[str]:
    rows = await session.scalars(
        select(Notification.title)
        .where(Notification.user_id == user_id)
        .order_by(Notification.created_at)
    )
    return list(rows)


async def _kinds(session: AsyncSession, **filters: object) -> list[tuple[str, str]]:
    rows, _ = await DriverActionRepository(session).search(
        driver_id=filters.get("driver_id"),  # type: ignore[arg-type]
        trip_id=filters.get("trip_id"),  # type: ignore[arg-type]
        booking_id=filters.get("booking_id"),  # type: ignore[arg-type]
        kinds=None,
        acted_as=None,
        since=None,
        until=None,
        limit=50,
        offset=0,
    )
    return [(row.action.kind.value, row.action.acted_as.value) for row in reversed(rows)]


def _service(session: AsyncSession, settings: Settings) -> BookingAcceptanceService:
    return BookingAcceptanceService(session, settings=settings)


async def _expire(session: AsyncSession, booking_id: uuid.UUID) -> None:
    offer = await _pending_offer(session, booking_id)
    assert offer is not None
    offer.expires_at = datetime.now(UTC) - timedelta(seconds=1)
    await session.flush()


class TestWaitingForTheDriver:
    async def test_a_new_booking_waits_for_the_driver_and_cannot_be_paid_for_yet(
        self, db_session: AsyncSession, make_user, accepting: Settings
    ) -> None:
        scenario = await _scenario(db_session, make_user)
        booking = await _request(db_session, make_user, scenario, accepting)

        assert booking.status == BookingStatus.AWAITING_ACCEPTANCE
        offer = await _pending_offer(db_session, booking.id)
        assert offer is not None
        assert offer.driver_id == scenario.driver_id
        assert booking.expires_at == offer.expires_at
        assert (
            timedelta(seconds=100) < offer.expires_at - datetime.now(UTC) <= timedelta(seconds=120)
        )
        assert await _active_seats(db_session, scenario.trip_id) == {scenario.seat_ids[0]}
        assert "New booking request" in await _titles(db_session, scenario.driver_user_id)

        requests, total = await _service(db_session, accepting).requests_for_driver(
            scenario.driver_user_id, trip_id=None, limit=10, offset=0
        )
        assert total == 1
        assert requests[0].booking_id == booking.id
        assert requests[0].seat_numbers == ["A1"]
        assert requests[0].origin_stop_name == scenario.stop_names[LEGON]
        assert requests[0].attempt == 1

        # The payment-success path refuses it: nobody has accepted it.
        with pytest.raises(InvalidStateTransitionError):
            await BookingService(db_session, settings=accepting).confirm_booking(booking.id)

    async def test_the_driver_accepts_and_the_passenger_may_pay(
        self, db_session: AsyncSession, make_user, accepting: Settings
    ) -> None:
        scenario = await _scenario(db_session, make_user)
        booking = await _request(db_session, make_user, scenario, accepting)

        accepted = await _service(db_session, accepting).accept(
            booking.id,
            actor_id=scenario.driver_user_id,
            as_admin=False,
            trip_id=scenario.trip_id,
        )

        assert accepted.status == BookingStatus.PENDING
        assert accepted.expires_at is not None
        assert accepted.expires_at - datetime.now(UTC) > timedelta(
            seconds=accepting.SEAT_RESERVATION_HOLD_SECONDS - 30
        )
        assert await _pending_offer(db_session, booking.id) is None
        assert "Booking accepted" in await _titles(db_session, booking.passenger_id)
        # Taking a passenger on the trip is taking the trip.
        assignment = await TripRepository(db_session).get_active_driver_assignment(scenario.trip_id)
        assert assignment is not None
        assert assignment.response == AssignmentResponse.ACCEPTED
        assert await _kinds(db_session, trip_id=scenario.trip_id) == [
            ("trip_accepted", "driver"),
            ("booking_accepted", "driver"),
        ]

        paid = await BookingService(db_session, settings=accepting).confirm_booking(booking.id)
        assert paid.status == BookingStatus.CONFIRMED

    async def test_accepting_twice_is_harmless(
        self, db_session: AsyncSession, make_user, accepting: Settings
    ) -> None:
        scenario = await _scenario(db_session, make_user)
        booking = await _request(db_session, make_user, scenario, accepting)
        service = _service(db_session, accepting)

        await service.accept(booking.id, actor_id=scenario.driver_user_id, as_admin=False)
        again = await service.accept(booking.id, actor_id=scenario.driver_user_id, as_admin=False)

        assert again.status == BookingStatus.PENDING

    async def test_only_the_trips_own_driver_may_answer(
        self, db_session: AsyncSession, make_user, accepting: Settings
    ) -> None:
        scenario = await _scenario(db_session, make_user)
        booking = await _request(db_session, make_user, scenario, accepting)
        stranger, _ = await approved_driver(db_session, make_user)
        service = _service(db_session, accepting)

        with pytest.raises(ForbiddenError):
            await service.accept(booking.id, actor_id=stranger.id, as_admin=False)
        with pytest.raises(ForbiddenError):
            await service.decline(booking.id, actor_id=stranger.id, as_admin=False, reason="No")
        with pytest.raises(NotFoundError):  # not a booking on that trip
            await service.accept(
                booking.id, actor_id=scenario.driver_user_id, as_admin=False, trip_id=uuid.uuid4()
            )
        assert (await db_session.get(Booking, booking.id)).status == (  # type: ignore[union-attr]
            BookingStatus.AWAITING_ACCEPTANCE
        )

    async def test_an_admin_may_accept_for_the_driver(
        self, db_session: AsyncSession, make_user, accepting: Settings
    ) -> None:
        scenario = await _scenario(db_session, make_user)
        booking = await _request(db_session, make_user, scenario, accepting)
        admin = await make_user()

        accepted = await _service(db_session, accepting).accept(
            booking.id, actor_id=admin.id, as_admin=True
        )

        assert accepted.status == BookingStatus.PENDING
        assert await _kinds(db_session, booking_id=booking.id) == [("booking_accepted", "admin")]
        # The admin took the booking, not the trip, for the driver.
        assignment = await TripRepository(db_session).get_active_driver_assignment(scenario.trip_id)
        assert assignment is not None
        assert assignment.response == AssignmentResponse.PENDING

    async def test_with_acceptance_off_a_booking_goes_straight_to_payment(
        self, db_session: AsyncSession, make_user
    ) -> None:
        scenario = await _scenario(db_session, make_user)
        booking = await _request(db_session, make_user, scenario, get_settings())

        assert booking.status == BookingStatus.PENDING
        assert await _pending_offer(db_session, booking.id) is None


class TestMovingToAnotherVehicle:
    async def test_a_declined_booking_moves_to_another_vehicle_going_the_same_way(
        self, db_session: AsyncSession, make_user, accepting: Settings
    ) -> None:
        first = await _scenario(db_session, make_user)
        second = await another_trip(
            db_session, make_user, first, departure=datetime.now(UTC) + timedelta(hours=2.5)
        )
        booking = await _request(db_session, make_user, first, accepting, seats=(0, 1))

        await _service(db_session, accepting).decline(
            booking.id, actor_id=first.driver_user_id, as_admin=False, reason="Full already"
        )

        moved = await db_session.get(Booking, booking.id)
        assert moved is not None
        assert moved.trip_id == second.trip_id
        assert moved.status == BookingStatus.AWAITING_ACCEPTANCE
        assert moved.origin_stop_id == first.stop_ids[LEGON]
        assert moved.destination_stop_id == first.stop_ids[CIRCLE]
        assert moved.fare_amount == booking.fare_amount  # the price as booked
        assert await _active_seats(db_session, first.trip_id) == set()
        assert await _active_seats(db_session, second.trip_id) == set(second.seat_ids[:2])
        offer = await _pending_offer(db_session, booking.id)
        assert offer is not None
        assert offer.trip_id == second.trip_id
        assert "Moved to another vehicle" in await _titles(db_session, booking.passenger_id)
        assert "New booking request" in await _titles(db_session, second.driver_user_id)

        requests, _ = await _service(db_session, accepting).requests_for_driver(
            second.driver_user_id, trip_id=None, limit=10, offset=0
        )
        assert [(r.booking_id, r.attempt) for r in requests] == [(booking.id, 2)]
        assert await _kinds(db_session, booking_id=booking.id) == [("booking_declined", "driver")]

    async def test_an_unanswered_booking_moves_when_its_time_is_up(
        self, db_session: AsyncSession, make_user, accepting: Settings
    ) -> None:
        first = await _scenario(db_session, make_user)
        second = await another_trip(
            db_session, make_user, first, departure=datetime.now(UTC) + timedelta(hours=1.5)
        )
        booking = await _request(db_session, make_user, first, accepting)
        await _expire(db_session, booking.id)

        # (The sweep also handles anything other tests left behind.)
        handled = await _service(db_session, accepting).expire_unanswered()

        assert handled >= 1
        moved = await db_session.get(Booking, booking.id)
        assert moved is not None
        assert moved.trip_id == second.trip_id
        assert await _kinds(db_session, booking_id=booking.id) == [("booking_unanswered", "system")]

    async def test_with_nowhere_to_go_it_ends_and_the_passenger_pays_nothing(
        self, db_session: AsyncSession, make_user, accepting: Settings
    ) -> None:
        scenario = await _scenario(db_session, make_user)
        booking = await _request(db_session, make_user, scenario, accepting)
        await _expire(db_session, booking.id)

        await _service(db_session, accepting).expire_unanswered()

        ended = await db_session.get(Booking, booking.id)
        assert ended is not None
        assert ended.status == BookingStatus.EXPIRED
        assert ended.trip_id == scenario.trip_id
        assert await _active_seats(db_session, scenario.trip_id) == set()
        assert "Booking not accepted" in await _titles(db_session, booking.passenger_id)

    async def test_a_vehicle_without_enough_free_seats_is_passed_over(
        self, db_session: AsyncSession, make_user, accepting: Settings
    ) -> None:
        first = await _scenario(db_session, make_user)
        await another_trip(
            db_session, make_user, first, departure=datetime.now(UTC) + timedelta(hours=2), seats=1
        )
        booking = await _request(db_session, make_user, first, accepting, seats=(0, 1))

        await _service(db_session, accepting).decline(
            booking.id, actor_id=first.driver_user_id, as_admin=False, reason="Engine trouble"
        )

        ended = await db_session.get(Booking, booking.id)
        assert ended is not None
        assert ended.status == BookingStatus.CANCELLED

    async def test_a_vehicle_leaving_much_later_is_not_offered(
        self, db_session: AsyncSession, make_user, accepting: Settings
    ) -> None:
        first = await _scenario(db_session, make_user)
        await another_trip(
            db_session, make_user, first, departure=datetime.now(UTC) + timedelta(hours=5)
        )
        booking = await _request(db_session, make_user, first, accepting)

        await _service(db_session, accepting).decline(
            booking.id, actor_id=first.driver_user_id, as_admin=False, reason="Not today"
        )

        ended = await db_session.get(Booking, booking.id)
        assert ended is not None
        assert ended.status == BookingStatus.CANCELLED

    async def test_a_booking_stops_moving_after_the_limit(
        self, db_session: AsyncSession, make_user, accepting: Settings
    ) -> None:
        settings = accepting.model_copy(update={"BOOKING_MAX_MOVES": 1})
        first = await _scenario(db_session, make_user)
        soon = datetime.now(UTC) + timedelta(hours=2)
        second = await another_trip(db_session, make_user, first, departure=soon)
        await another_trip(db_session, make_user, first, departure=soon + timedelta(minutes=5))
        booking = await _request(db_session, make_user, first, settings)
        service = _service(db_session, settings)

        await service.decline(
            booking.id, actor_id=first.driver_user_id, as_admin=False, reason="Full"
        )
        await service.decline(
            booking.id, actor_id=second.driver_user_id, as_admin=False, reason="Full too"
        )

        ended = await db_session.get(Booking, booking.id)
        assert ended is not None
        assert ended.status == BookingStatus.CANCELLED

    async def test_an_admin_can_turn_a_booking_down_without_moving_it(
        self, db_session: AsyncSession, make_user, accepting: Settings
    ) -> None:
        first = await _scenario(db_session, make_user)
        await another_trip(
            db_session, make_user, first, departure=datetime.now(UTC) + timedelta(hours=2)
        )
        booking = await _request(db_session, make_user, first, accepting)
        admin = await make_user()

        await _service(db_session, accepting).decline(
            booking.id, actor_id=admin.id, as_admin=True, reason="Suspected fraud", move=False
        )

        ended = await db_session.get(Booking, booking.id)
        assert ended is not None
        assert (ended.status, ended.trip_id) == (BookingStatus.CANCELLED, first.trip_id)
        assert await _kinds(db_session, booking_id=booking.id) == [("booking_declined", "admin")]

    async def test_an_admin_can_turn_down_an_accepted_unpaid_booking(
        self, db_session: AsyncSession, make_user, accepting: Settings
    ) -> None:
        scenario = await _scenario(db_session, make_user)
        booking = await _request(db_session, make_user, scenario, accepting)
        service = _service(db_session, accepting)
        await service.accept(booking.id, actor_id=scenario.driver_user_id, as_admin=False)

        with pytest.raises(InvalidStateTransitionError):  # the driver has had their say
            await service.decline(
                booking.id, actor_id=scenario.driver_user_id, as_admin=False, reason="Changed"
            )
        admin = await make_user()
        await service.decline(
            booking.id, actor_id=admin.id, as_admin=True, reason="Wrong pickup", move=False
        )

        ended = await db_session.get(Booking, booking.id)
        assert ended is not None
        assert ended.status == BookingStatus.CANCELLED

    async def test_an_admin_can_move_a_booking_to_a_trip_of_their_choice(
        self, db_session: AsyncSession, make_user, accepting: Settings
    ) -> None:
        first = await _scenario(db_session, make_user)
        chosen = await another_trip(
            db_session, make_user, first, departure=datetime.now(UTC) + timedelta(hours=6)
        )
        other_route = await _scenario(db_session, make_user)
        booking = await _request(db_session, make_user, first, accepting)
        admin = await make_user()
        service = _service(db_session, accepting)

        with pytest.raises(ConflictError):  # does not go from Legon to Circle
            await service.move_to(booking.id, other_route.trip_id, actor_id=admin.id)
        moved = await service.move_to(booking.id, chosen.trip_id, actor_id=admin.id)

        assert moved.trip_id == chosen.trip_id
        assert moved.status == BookingStatus.AWAITING_ACCEPTANCE
        offers = await db_session.scalars(
            select(BookingOffer.status)
            .where(BookingOffer.booking_id == booking.id)
            .order_by(BookingOffer.created_at)
        )
        assert list(offers) == [OfferStatus.WITHDRAWN, OfferStatus.PENDING]

    async def test_answered_or_cancelled_bookings_are_left_alone(
        self, db_session: AsyncSession, make_user, accepting: Settings
    ) -> None:
        scenario = await _scenario(db_session, make_user)
        accepted = await _request(db_session, make_user, scenario, accepting, seats=(0,))
        cancelled = await _request(db_session, make_user, scenario, accepting, seats=(1,))
        service = _service(db_session, accepting)
        await _expire(db_session, accepted.id)
        await _expire(db_session, cancelled.id)
        # Answered after the deadline, but before the sweep came round.
        await service.accept(accepted.id, actor_id=scenario.driver_user_id, as_admin=False)
        await BookingService(db_session, settings=accepting).cancel_booking(
            cancelled.id, requesting_user_id=cancelled.passenger_id, reason="Changed my mind"
        )

        await service.expire_unanswered()

        for booking, status in (
            (accepted, BookingStatus.PENDING),
            (cancelled, BookingStatus.CANCELLED),
        ):
            stored = await db_session.get(Booking, booking.id)
            assert stored is not None
            assert (stored.status, stored.trip_id) == (status, scenario.trip_id)
            assert await _pending_offer(db_session, booking.id) is None
        assert ("booking_unanswered", "system") not in await _kinds(
            db_session, trip_id=scenario.trip_id
        )


class TestTheDriversAnswerToATrip:
    async def test_a_new_trip_waits_for_the_drivers_answer_and_they_are_told(
        self, db_session: AsyncSession, make_user
    ) -> None:
        scenario = await _scenario(db_session, make_user)

        assignment = await TripRepository(db_session).get_active_driver_assignment(scenario.trip_id)
        assert assignment is not None
        assert assignment.response == AssignmentResponse.PENDING
        assert "New trip assigned" in await _titles(db_session, scenario.driver_user_id)

    async def test_the_driver_declines_and_the_trip_is_left_without_one(
        self, db_session: AsyncSession, make_user
    ) -> None:
        scenario = await _scenario(db_session, make_user)

        answer = await TripService(db_session).respond(
            scenario.trip_id,
            actor_id=scenario.driver_user_id,
            accept=False,
            reason="My car is at the mechanic",
            as_admin=False,
        )

        assert (answer.response, answer.is_active) == (AssignmentResponse.DECLINED, False)
        assert answer.response_reason == "My car is at the mechanic"
        assert (
            await TripRepository(db_session).get_active_driver_assignment(scenario.trip_id) is None
        )
        assert await _kinds(db_session, trip_id=scenario.trip_id) == [("trip_declined", "driver")]

    async def test_an_admin_answers_for_the_driver_who_is_told(
        self, db_session: AsyncSession, make_user
    ) -> None:
        scenario = await _scenario(db_session, make_user)
        admin = await make_user()

        await TripService(db_session).respond(
            scenario.trip_id, actor_id=admin.id, accept=True, reason=None, as_admin=True
        )

        assert "Trip accepted for you" in await _titles(db_session, scenario.driver_user_id)
        assert await _kinds(db_session, trip_id=scenario.trip_id) == [("trip_accepted", "admin")]

    async def test_starting_a_trip_accepts_it_and_it_cannot_then_be_declined(
        self, db_session: AsyncSession, make_user
    ) -> None:
        scenario = await _scenario(db_session, make_user, hours=0)
        trips = TripService(db_session)

        await trips.start_trip(scenario.trip_id, scenario.driver_user_id)

        assignment = await TripRepository(db_session).get_active_driver_assignment(scenario.trip_id)
        assert assignment is not None
        assert assignment.response == AssignmentResponse.ACCEPTED
        with pytest.raises(InvalidStateTransitionError):
            await trips.respond(
                scenario.trip_id,
                actor_id=scenario.driver_user_id,
                accept=False,
                reason="Too late",
                as_admin=False,
            )
        assert await _kinds(db_session, trip_id=scenario.trip_id) == [
            ("trip_accepted", "driver"),
            ("trip_started", "driver"),
        ]

    async def test_another_driver_cannot_answer(self, db_session: AsyncSession, make_user) -> None:
        scenario = await _scenario(db_session, make_user)
        stranger, _ = await approved_driver(db_session, make_user)

        with pytest.raises(ForbiddenError):
            await TripService(db_session).respond(
                scenario.trip_id, actor_id=stranger.id, accept=True, reason=None, as_admin=False
            )


class TestGettingOff:
    async def _riding(
        self, session: AsyncSession, make_user, *, destination: int = CIRCLE
    ) -> tuple[TripScenario, Booking]:
        scenario = await _scenario(session, make_user, hours=0)
        passenger = await make_user()
        booking = (
            await book(session, passenger.id, scenario, seat=0, origin=None, destination=None)
            if destination == CIRCLE
            else await book(
                session,
                passenger.id,
                scenario,
                seat=0,
                origin=scenario.stop_ids[MADINA],
                destination=scenario.stop_ids[destination],
            )
        )
        await TripService(session).start_trip(scenario.trip_id, scenario.driver_user_id)
        return scenario, booking

    async def test_the_driver_marks_a_passenger_off_early_and_the_seat_is_free_again(
        self, db_session: AsyncSession, make_user
    ) -> None:
        scenario, booking = await self._riding(db_session, make_user)
        [rider] = await BookingRepository(db_session).list_passengers(booking.id)

        passenger, ended = await AlightingService(db_session).mark_off(
            scenario.trip_id,
            rider.id,
            actor_id=scenario.driver_user_id,
            as_admin=False,
            stop_id=scenario.stop_ids[LEGON],
        )

        assert passenger.alighted_how == AlightedHow.DRIVER
        assert passenger.alighted_stop_id == scenario.stop_ids[LEGON]
        assert ended.status == BookingStatus.COMPLETED
        reservation = await db_session.scalar(
            select(SeatReservation).where(SeatReservation.booking_id == booking.id)
        )
        assert reservation is not None
        assert reservation.status == ReservationStatus.COMPLETED
        legon = (await db_session.get(Stop, scenario.stop_ids[LEGON])).name  # type: ignore[union-attr]
        assert f"You're at {legon}" in await _titles(db_session, booking.passenger_id)
        share = (
            booking.fare_amount * get_settings().DRIVER_EARNINGS_SHARE_PERCENT / Decimal(100)
        ).quantize(Decimal("0.01"))
        assert await WalletService(db_session).get_balance(scenario.driver_user_id) == share

        # Someone waiting at Legon can now have that seat to Circle.
        newcomer = await make_user()
        taken = await book(
            db_session,
            newcomer.id,
            scenario,
            seat=0,
            origin=scenario.stop_ids[LEGON],
            destination=scenario.stop_ids[CIRCLE],
        )
        assert taken.status == BookingStatus.CONFIRMED

        # Ending the trip does not pay the driver for that booking twice.
        await TripService(db_session).end_trip(scenario.trip_id, scenario.driver_user_id)
        assert await WalletService(db_session).get_balance(scenario.driver_user_id) == (
            share + (taken.fare_amount * get_settings().DRIVER_EARNINGS_SHARE_PERCENT / 100)
        ).quantize(Decimal("0.01"))

    async def test_reaching_their_stop_lets_the_passenger_off(
        self, db_session: AsyncSession, make_user
    ) -> None:
        scenario, booking = await self._riding(db_session, make_user, destination=LEGON)
        alighting = AlightingService(db_session)
        madina = await db_session.get(Stop, scenario.stop_ids[MADINA])
        legon = await db_session.get(Stop, scenario.stop_ids[LEGON])
        assert madina is not None
        assert legon is not None

        assert (
            await alighting.on_vehicle_moved(scenario.trip_id, *wkb_to_latlng(madina.location)) == 0
        )
        assert (
            await alighting.on_vehicle_moved(scenario.trip_id, *wkb_to_latlng(legon.location)) == 1
        )

        done = await db_session.get(Booking, booking.id)
        assert done is not None
        assert done.status == BookingStatus.COMPLETED
        [rider] = await BookingRepository(db_session).list_passengers(booking.id)
        assert rider.alighted_how == AlightedHow.ARRIVAL
        assert await _active_seats(db_session, scenario.trip_id) == set()
        assert ("passenger_alighted", "system") in await _kinds(
            db_session, trip_id=scenario.trip_id
        )

    async def test_only_a_paid_passenger_on_a_trip_on_the_road(
        self, db_session: AsyncSession, make_user
    ) -> None:
        scenario = await _scenario(db_session, make_user, hours=0)
        unpaid = await book(db_session, (await make_user()).id, scenario, seat=1, confirm=False)
        paid = await book(db_session, (await make_user()).id, scenario, seat=2)
        alighting = AlightingService(db_session)
        [unpaid_rider] = await BookingRepository(db_session).list_passengers(unpaid.id)
        [paid_rider] = await BookingRepository(db_session).list_passengers(paid.id)

        with pytest.raises(ConflictError) as not_started:
            await alighting.mark_off(
                scenario.trip_id, paid_rider.id, actor_id=scenario.driver_user_id, as_admin=False
            )
        assert not_started.value.code == "TRIP_NOT_ON_THE_ROAD"

        await TripService(db_session).start_trip(scenario.trip_id, scenario.driver_user_id)
        with pytest.raises(ConflictError) as not_paid:
            await alighting.mark_off(
                scenario.trip_id, unpaid_rider.id, actor_id=scenario.driver_user_id, as_admin=False
            )
        assert not_paid.value.code == "BOOKING_NOT_PAID"
        stranger, _ = await approved_driver(db_session, make_user)
        with pytest.raises(ForbiddenError):
            await alighting.mark_off(
                scenario.trip_id, paid_rider.id, actor_id=stranger.id, as_admin=False
            )

    async def test_at_the_end_of_the_trip_everyone_is_offered_a_way_on(
        self, db_session: AsyncSession, make_user
    ) -> None:
        scenario, booking = await self._riding(db_session, make_user)

        await TripService(db_session).end_trip(scenario.trip_id, scenario.driver_user_id)

        circle = (await db_session.get(Stop, scenario.stop_ids[CIRCLE])).name  # type: ignore[union-attr]
        assert f"You're at {circle}" in await _titles(db_session, booking.passenger_id)
        assert await _kinds(db_session, trip_id=scenario.trip_id) == [
            ("trip_accepted", "driver"),
            ("trip_started", "driver"),
            ("trip_ended", "driver"),
        ]


class TestTheLogOfDriverActions:
    async def test_filters_and_names(
        self, db_session: AsyncSession, make_user, accepting: Settings
    ) -> None:
        scenario = await _scenario(db_session, make_user)
        booking = await _request(db_session, make_user, scenario, accepting)
        admin = await make_user()
        await _service(db_session, accepting).accept(booking.id, actor_id=admin.id, as_admin=True)
        await TripService(db_session).respond(
            scenario.trip_id,
            actor_id=scenario.driver_user_id,
            accept=True,
            reason=None,
            as_admin=False,
        )

        rows, total = await DriverActionRepository(db_session).search(
            driver_id=scenario.driver_id,
            trip_id=None,
            booking_id=None,
            kinds=[DriverActionKind.BOOKING_ACCEPTED],
            acted_as=ActedAs.ADMIN,
            since=None,
            until=None,
            limit=10,
            offset=0,
        )

        assert total == 1
        assert rows[0].action.booking_id == booking.id
        assert rows[0].actor_name == admin.profile.full_name
        assert rows[0].driver_name is not None
