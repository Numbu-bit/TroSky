"""Ticket issuance and QR validation.

Issuance is idempotent (``issue_tickets_for_booking`` is a no-op if tickets
already exist for the booking) because it's called from
``BookingService.confirm_booking``, which is itself idempotent and may be
invoked more than once for the same booking (a retried webhook, a
reconciliation poll racing a webhook that already landed).

Validation never trusts the QR code's contents on their own — a
syntactically valid, correctly-signed token only proves the token wasn't
forged; the ticket's *current* status is what actually decides whether
boarding is allowed, checked under a row lock so two conductors scanning
the same physical ticket at once can't both admit the same passenger.
"""

from __future__ import annotations

import uuid
from datetime import UTC, datetime, timedelta

from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings, get_settings
from app.core.database import keep_writes_on_failure
from app.core.exceptions import InvalidStateTransitionError, NotFoundError, TicketValidationError
from app.core.logging import get_logger
from app.models.bookings import Booking
from app.models.fraud import TicketScanAttempt, TicketScanOutcome
from app.models.tickets import Ticket, TicketStatus
from app.repositories.booking_repository import BookingRepository
from app.repositories.ticket_repository import TicketRepository
from app.repositories.trip_repository import TripRepository
from app.utilities.ticket_qr import decode_qr_token, encode_qr_token

logger = get_logger(__name__)

# How long past scheduled departure a ticket remains presentable if the
# trip has no explicit scheduled arrival time to anchor expiry to instead.
_DEFAULT_TICKET_VALIDITY = timedelta(hours=6)


class TicketService:
    def __init__(self, session: AsyncSession, settings: Settings | None = None) -> None:
        self._session = session
        self._settings = settings or get_settings()
        self._tickets = TicketRepository(session)
        self._bookings = BookingRepository(session)
        self._trips = TripRepository(session)

    async def issue_tickets_for_booking(self, booking: Booking) -> list[Ticket]:
        existing = await self._tickets.list_for_booking(booking.id)
        if existing:
            return existing  # idempotent

        trip = await self._trips.get_by_id(booking.trip_id)
        if trip is None:
            raise NotFoundError("Trip not found.")
        expires_at = trip.scheduled_arrival_at or (
            trip.scheduled_departure_at + _DEFAULT_TICKET_VALIDITY
        )

        passengers = await self._bookings.list_passengers(booking.id)
        tickets = [
            await self._tickets.create_ticket(
                booking_id=booking.id,
                booking_passenger_id=passenger.id,
                trip_id=trip.id,
                expires_at=expires_at,
            )
            for passenger in passengers
        ]
        logger.info("tickets_issued", booking_id=str(booking.id), count=len(tickets))
        return tickets

    def get_qr_token(self, ticket: Ticket) -> str:
        return encode_qr_token(
            ticket.id, ticket.expires_at, self._settings.TICKET_QR_SIGNING_SECRET.get_secret_value()
        )

    async def validate_qr(
        self, token: str, *, trip_id: uuid.UUID, validated_by: uuid.UUID
    ) -> Ticket:
        decoded = decode_qr_token(token, self._settings.TICKET_QR_SIGNING_SECRET.get_secret_value())
        if decoded is None:
            raise TicketValidationError("Invalid or tampered ticket code.")
        ticket_id, token_expires_at = decoded

        ticket = await self._tickets.get_for_update(ticket_id)
        if ticket is None:
            raise TicketValidationError("Ticket not found.")
        # Compared in whole seconds: that's all the token carries, while the
        # column keeps microseconds.
        if int(ticket.expires_at.timestamp()) != int(token_expires_at.timestamp()):
            # The persisted expiry no longer matches what this token was
            # signed against — the only way that happens is a stale token
            # from before some (currently nonexistent) re-issuance flow.
            raise TicketValidationError("This ticket code is stale.")
        if ticket.trip_id != trip_id:
            await self._keep_refusal(ticket, trip_id, validated_by, TicketScanOutcome.WRONG_TRIP)
            raise TicketValidationError("This ticket is not for this trip.")

        if ticket.status == TicketStatus.VALIDATED:
            await self._keep_refusal(ticket, trip_id, validated_by, TicketScanOutcome.ALREADY_USED)
            raise InvalidStateTransitionError("This ticket has already been used to board.")
        if ticket.status == TicketStatus.REVOKED:
            raise InvalidStateTransitionError("This ticket has been revoked.")
        if ticket.status == TicketStatus.EXPIRED or datetime.now(UTC) > ticket.expires_at:
            if ticket.status != TicketStatus.EXPIRED:
                await self._tickets.set_status(ticket, new_status=TicketStatus.EXPIRED)
            raise TicketValidationError("This ticket has expired.")

        await self._tickets.set_status(
            ticket, new_status=TicketStatus.VALIDATED, validated_by=validated_by
        )
        logger.info("ticket_validated", ticket_id=str(ticket.id), trip_id=str(trip_id))
        return ticket

    async def _keep_refusal(
        self,
        ticket: Ticket,
        trip_id: uuid.UUID,
        scanned_by: uuid.UUID,
        outcome: TicketScanOutcome,
    ) -> None:
        """Record a ticket shown again after boarding, or on another trip,
        for the fraud rules -- and keep the record although the scan fails."""
        try:
            async with self._session.begin_nested():
                self._session.add(
                    TicketScanAttempt(
                        ticket_id=ticket.id, trip_id=trip_id, scanned_by=scanned_by, outcome=outcome
                    )
                )
                await self._session.flush()
        except IntegrityError:  # not a trip at all: nothing to keep
            return
        keep_writes_on_failure(self._session)

    async def get_ticket(
        self, ticket_id: uuid.UUID, *, requesting_user_id: uuid.UUID, is_privileged: bool = False
    ) -> Ticket:
        ticket = await self._tickets.get_by_id(ticket_id)
        if ticket is None:
            raise NotFoundError("Ticket not found.")
        if not is_privileged:
            booking = await self._bookings.get_by_id(ticket.booking_id)
            if booking is None or booking.passenger_id != requesting_user_id:
                raise NotFoundError("Ticket not found.")
        return ticket

    async def list_tickets_for_booking(
        self,
        booking_id: uuid.UUID,
        *,
        requesting_user_id: uuid.UUID,
        is_privileged: bool = False,
    ) -> list[Ticket]:
        booking = await self._bookings.get_by_id(booking_id)
        if booking is None:
            raise NotFoundError("Booking not found.")
        if not is_privileged and booking.passenger_id != requesting_user_id:
            raise NotFoundError("Booking not found.")
        return await self._tickets.list_for_booking(booking_id)

    async def revoke_tickets_for_booking(self, booking_id: uuid.UUID, *, reason: str) -> int:
        return await self._tickets.revoke_tickets_for_booking(booking_id, reason=reason)
