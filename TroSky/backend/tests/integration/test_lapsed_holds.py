"""A seat hold that has run out frees its seat at once: the seat map, search
and fares treat it as free, and booking the seat resolves the old hold,
without waiting for the background sweep (which may be asleep on a small
server).

Uses the Madina -> Legon -> Circle scenario, 4 seats.
"""

from __future__ import annotations

import uuid
from datetime import UTC, datetime, timedelta

import pytest
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.exceptions import SeatNotAvailableError
from app.core.redis import get_redis_client
from app.models.bookings import (
    Booking,
    BookingOffer,
    BookingStatus,
    ReservationStatus,
    SeatReservation,
)
from app.repositories.booking_repository import BookingRepository
from app.repositories.trip_view_repository import TripViewRepository
from app.schemas.booking import BookingCreateRequest, PassengerInput
from app.services.booking_service import BookingService
from tests.integration.scenarios import TripScenario, build_trip_scenario

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]


async def _scenario(session: AsyncSession, make_user) -> TripScenario:
    return await build_trip_scenario(
        session, make_user, departure=datetime.now(UTC) + timedelta(hours=3)
    )


async def _hold(
    service: BookingService, make_user, scenario: TripScenario, seat: int = 0
) -> Booking:
    return await service.create_booking(
        (await make_user()).id,
        BookingCreateRequest(
            trip_id=scenario.trip_id,
            passengers=[PassengerInput(seat_id=scenario.seat_ids[seat], full_name="Ama Owusu")],
        ),
        idempotency_key=None,
    )


async def _lapse(session: AsyncSession, booking: Booking) -> None:
    """Its hold ran out a minute ago, and no sweep has been round."""
    past = datetime.now(UTC) - timedelta(minutes=1)
    booking.expires_at = past
    for model in (SeatReservation, BookingOffer):
        await session.execute(
            update(model).where(model.booking_id == booking.id).values(expires_at=past)
        )
    await session.flush()


async def _reservation(session: AsyncSession, booking: Booking) -> SeatReservation:
    return (
        await session.execute(
            select(SeatReservation).where(SeatReservation.booking_id == booking.id)
        )
    ).scalar_one()


class TestTheSeatShowsFree:
    async def test_on_the_seat_map_and_in_search(self, db_session: AsyncSession, make_user) -> None:
        scenario = await _scenario(db_session, make_user)
        held = await _hold(BookingService(db_session), make_user, scenario)
        bookings, views = BookingRepository(db_session), TripViewRepository(db_session)
        seat = scenario.seat_ids[0]

        assert seat in await bookings.list_active_seat_ids_for_trip(scenario.trip_id)
        assert (await views.summaries_by_ids([scenario.trip_id]))[scenario.trip_id].seats_taken == 1

        await _lapse(db_session, held)

        assert seat not in await bookings.list_active_seat_ids_for_trip(scenario.trip_id)
        assert (await views.summaries_by_ids([scenario.trip_id]))[scenario.trip_id].seats_taken == 0
        # Not yet marked expired: the sweep has not been round.
        assert (await _reservation(db_session, held)).status == ReservationStatus.HELD

    async def test_and_its_passenger_no_longer_shares_the_fare(
        self, db_session: AsyncSession, make_user
    ) -> None:
        scenario = await _scenario(db_session, make_user)
        held = await _hold(BookingService(db_session), make_user, scenario)
        bookings = BookingRepository(db_session)

        assert (
            len((await bookings.occupying_seats_for_trips([scenario.trip_id]))[scenario.trip_id])
            == 1
        )
        await _lapse(db_session, held)
        assert (await bookings.occupying_seats_for_trips([scenario.trip_id]))[
            scenario.trip_id
        ] == []


class TestBookingTheSeat:
    async def test_expires_the_lapsed_unpaid_booking(
        self, db_session: AsyncSession, make_user
    ) -> None:
        scenario = await _scenario(db_session, make_user)
        service = BookingService(db_session)
        held = await _hold(service, make_user, scenario)
        await _lapse(db_session, held)

        mine = await _hold(service, make_user, scenario)

        assert mine.trip_id == scenario.trip_id
        await db_session.refresh(held)
        assert held.status == BookingStatus.EXPIRED
        assert (await _reservation(db_session, held)).status == ReservationStatus.EXPIRED
        assert (await _reservation(db_session, mine)).status == ReservationStatus.HELD

    async def test_is_still_refused_while_the_hold_runs(
        self, db_session: AsyncSession, make_user
    ) -> None:
        scenario = await _scenario(db_session, make_user)
        service = BookingService(db_session)
        await _hold(service, make_user, scenario)

        with pytest.raises(SeatNotAvailableError):
            await _hold(service, make_user, scenario)

    async def test_a_seat_left_in_the_redis_hint_is_not_refused(
        self, db_session: AsyncSession, make_user, require_redis: None
    ) -> None:
        scenario = await _scenario(db_session, make_user)
        service = BookingService(db_session, get_redis_client())
        held = await _hold(service, make_user, scenario)
        await _lapse(db_session, held)
        # The hint set outlives the hold (another booking pushed its expiry).
        held_key = f"trip:{scenario.trip_id}:held_seats"
        assert await get_redis_client().sismember(held_key, str(scenario.seat_ids[0]))

        mine = await _hold(service, make_user, scenario)

        assert mine.status == BookingStatus.PENDING

    async def test_moves_on_a_booking_its_driver_never_answered(
        self, db_session: AsyncSession, make_user
    ) -> None:
        scenario = await _scenario(db_session, make_user)
        accepting = get_settings().model_copy(update={"BOOKING_ACCEPTANCE_REQUIRED": True})
        service = BookingService(db_session, settings=accepting)
        waiting = await _hold(service, make_user, scenario)
        assert waiting.status == BookingStatus.AWAITING_ACCEPTANCE
        await _lapse(db_session, waiting)

        mine = await _hold(service, make_user, scenario)

        assert mine.status == BookingStatus.AWAITING_ACCEPTANCE
        await db_session.refresh(waiting)
        # No other vehicle on the route to move it to: it ends, uncharged.
        assert waiting.status == BookingStatus.EXPIRED
        offer = (
            await db_session.execute(
                select(BookingOffer).where(BookingOffer.booking_id == waiting.id)
            )
        ).scalar_one()
        assert offer.status.value == "expired"


async def test_a_trip_without_lapsed_holds_is_unchanged(
    db_session: AsyncSession, make_user
) -> None:
    scenario = await _scenario(db_session, make_user)
    lapsed = await BookingRepository(db_session).bookings_with_lapsed_holds(
        scenario.trip_id, [scenario.seat_ids[0], uuid.uuid4()]
    )
    assert lapsed == []
