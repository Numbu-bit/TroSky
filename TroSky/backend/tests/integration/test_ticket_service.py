"""Integration tests for TicketService: issuance as a side effect of
booking confirmation (idempotent), QR validation (including rejection of a
tampered token, the wrong trip, and a repeat scan), and revocation when a
confirmed booking is subsequently cancelled — against a real Postgres."""

from __future__ import annotations

import uuid

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import InvalidStateTransitionError, TicketValidationError
from app.models.bookings import BookingStatus
from app.models.tickets import TicketStatus
from app.schemas.booking import BookingCreateRequest, PassengerInput
from app.services.booking_service import BookingService
from app.services.ticket_service import TicketService
from app.utilities.ticket_qr import encode_qr_token
from tests.integration.test_booking_service import _make_bookable_trip

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]


async def _make_confirmed_booking(
    session: AsyncSession, *, passenger_id: uuid.UUID, seat_count: int = 2, make_user
) -> tuple[uuid.UUID, uuid.UUID]:
    """Returns ``(booking_id, trip_id)`` for a booking confirmed directly
    (bypassing payment — that flow is Phase 6's own test suite; here we
    only care about what happens once a booking reaches CONFIRMED)."""
    trip_id, seat_ids, _ = await _make_bookable_trip(
        session, seat_count=seat_count, make_user=make_user
    )
    booking_service = BookingService(session)
    booking = await booking_service.create_booking(
        passenger_id,
        BookingCreateRequest(
            trip_id=trip_id,
            passengers=[
                PassengerInput(seat_id=seat_id, full_name=f"Passenger {i}")
                for i, seat_id in enumerate(seat_ids)
            ],
        ),
        idempotency_key=None,
    )
    await booking_service.confirm_booking(booking.id)
    return booking.id, trip_id


class TestTicketIssuance:
    async def test_confirming_a_booking_issues_one_ticket_per_passenger(
        self, db_session: AsyncSession, make_user
    ) -> None:
        booking_id, trip_id = await _make_confirmed_booking(
            db_session, passenger_id=(await make_user()).id, seat_count=3, make_user=make_user
        )
        ticket_service = TicketService(db_session)
        tickets = await ticket_service.list_tickets_for_booking(
            booking_id, requesting_user_id=uuid.uuid4(), is_privileged=True
        )
        assert len(tickets) == 3
        assert all(t.status == TicketStatus.ISSUED for t in tickets)
        assert all(t.trip_id == trip_id for t in tickets)

    async def test_confirming_twice_does_not_duplicate_tickets(
        self, db_session: AsyncSession, make_user
    ) -> None:
        passenger_id = (await make_user()).id
        booking_id, _ = await _make_confirmed_booking(
            db_session, passenger_id=passenger_id, make_user=make_user
        )
        booking_service = BookingService(db_session)
        await booking_service.confirm_booking(booking_id)  # idempotent re-confirm

        ticket_service = TicketService(db_session)
        tickets = await ticket_service.list_tickets_for_booking(
            booking_id, requesting_user_id=passenger_id
        )
        assert len(tickets) == 2  # seat_count default


class TestTicketValidation:
    async def test_valid_scan_marks_ticket_validated(
        self, db_session: AsyncSession, make_user
    ) -> None:
        passenger_id = (await make_user()).id
        booking_id, trip_id = await _make_confirmed_booking(
            db_session, passenger_id=passenger_id, seat_count=1, make_user=make_user
        )
        ticket_service = TicketService(db_session)
        [ticket] = await ticket_service.list_tickets_for_booking(
            booking_id, requesting_user_id=passenger_id
        )
        token = ticket_service.get_qr_token(ticket)

        driver_id = (await make_user()).id
        validated = await ticket_service.validate_qr(token, trip_id=trip_id, validated_by=driver_id)
        assert validated.status == TicketStatus.VALIDATED
        assert validated.validated_by == driver_id

    async def test_scanning_twice_is_rejected(self, db_session: AsyncSession, make_user) -> None:
        passenger_id = (await make_user()).id
        booking_id, trip_id = await _make_confirmed_booking(
            db_session, passenger_id=passenger_id, seat_count=1, make_user=make_user
        )
        ticket_service = TicketService(db_session)
        [ticket] = await ticket_service.list_tickets_for_booking(
            booking_id, requesting_user_id=passenger_id
        )
        token = ticket_service.get_qr_token(ticket)
        await ticket_service.validate_qr(token, trip_id=trip_id, validated_by=uuid.uuid4())

        with pytest.raises(InvalidStateTransitionError):
            await ticket_service.validate_qr(token, trip_id=trip_id, validated_by=uuid.uuid4())

    async def test_scanning_for_the_wrong_trip_is_rejected(
        self, db_session: AsyncSession, make_user
    ) -> None:
        passenger_id = (await make_user()).id
        booking_id, _real_trip_id = await _make_confirmed_booking(
            db_session, passenger_id=passenger_id, seat_count=1, make_user=make_user
        )
        ticket_service = TicketService(db_session)
        [ticket] = await ticket_service.list_tickets_for_booking(
            booking_id, requesting_user_id=passenger_id
        )
        token = ticket_service.get_qr_token(ticket)

        with pytest.raises(TicketValidationError):
            await ticket_service.validate_qr(token, trip_id=uuid.uuid4(), validated_by=uuid.uuid4())

    async def test_tampered_token_is_rejected(self, db_session: AsyncSession, make_user) -> None:
        passenger_id = (await make_user()).id
        booking_id, trip_id = await _make_confirmed_booking(
            db_session, passenger_id=passenger_id, seat_count=1, make_user=make_user
        )
        ticket_service = TicketService(db_session)
        [ticket] = await ticket_service.list_tickets_for_booking(
            booking_id, requesting_user_id=passenger_id
        )
        forged_token = encode_qr_token(ticket.id, ticket.expires_at, "wrong-secret")

        with pytest.raises(TicketValidationError):
            await ticket_service.validate_qr(
                forged_token, trip_id=trip_id, validated_by=uuid.uuid4()
            )


class TestTicketRevocation:
    async def test_cancelling_a_confirmed_booking_revokes_its_tickets(
        self, db_session: AsyncSession, make_user
    ) -> None:
        passenger_id = (await make_user()).id
        booking_id, _ = await _make_confirmed_booking(
            db_session, passenger_id=passenger_id, seat_count=2, make_user=make_user
        )
        booking_service = BookingService(db_session)
        booking = await booking_service.cancel_booking(
            booking_id, requesting_user_id=passenger_id, reason="Change of plans"
        )
        assert booking.status == BookingStatus.REFUND_PENDING

        ticket_service = TicketService(db_session)
        tickets = await ticket_service.list_tickets_for_booking(
            booking_id, requesting_user_id=passenger_id
        )
        assert all(t.status == TicketStatus.REVOKED for t in tickets)

    async def test_revocation_does_not_touch_an_already_validated_ticket(
        self, db_session: AsyncSession, make_user
    ) -> None:
        passenger_id = (await make_user()).id
        booking_id, trip_id = await _make_confirmed_booking(
            db_session, passenger_id=passenger_id, seat_count=2, make_user=make_user
        )
        ticket_service = TicketService(db_session)
        tickets = await ticket_service.list_tickets_for_booking(
            booking_id, requesting_user_id=passenger_id
        )
        boarded_ticket = tickets[0]
        token = ticket_service.get_qr_token(boarded_ticket)
        await ticket_service.validate_qr(token, trip_id=trip_id, validated_by=uuid.uuid4())

        booking_service = BookingService(db_session)
        await booking_service.cancel_booking(
            booking_id, requesting_user_id=passenger_id, reason=None
        )

        refreshed = await ticket_service.list_tickets_for_booking(
            booking_id, requesting_user_id=passenger_id
        )
        by_id = {t.id: t for t in refreshed}
        assert by_id[boarded_ticket.id].status == TicketStatus.VALIDATED  # untouched
        other_ticket = next(t for t in refreshed if t.id != boarded_ticket.id)
        assert other_ticket.status == TicketStatus.REVOKED
