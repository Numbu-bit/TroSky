"""Database access for tickets."""

from __future__ import annotations

import secrets
import string
import uuid
from datetime import UTC, datetime

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.tickets import Ticket, TicketStatus

_REFERENCE_ALPHABET = string.ascii_uppercase + string.digits


class TicketRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    def generate_ticket_reference(self) -> str:
        suffix = "".join(secrets.choice(_REFERENCE_ALPHABET) for _ in range(8))
        return f"TKT-{suffix}"

    async def create_ticket(
        self,
        *,
        booking_id: uuid.UUID,
        booking_passenger_id: uuid.UUID,
        trip_id: uuid.UUID,
        expires_at: datetime,
    ) -> Ticket:
        ticket = Ticket(
            ticket_reference=self.generate_ticket_reference(),
            booking_id=booking_id,
            booking_passenger_id=booking_passenger_id,
            trip_id=trip_id,
            expires_at=expires_at,
        )
        self._session.add(ticket)
        await self._session.flush()
        return ticket

    async def get_by_id(self, ticket_id: uuid.UUID) -> Ticket | None:
        result = await self._session.execute(select(Ticket).where(Ticket.id == ticket_id))
        return result.scalar_one_or_none()

    async def get_for_update(self, ticket_id: uuid.UUID) -> Ticket | None:
        result = await self._session.execute(
            select(Ticket).where(Ticket.id == ticket_id).with_for_update()
        )
        return result.scalar_one_or_none()

    async def list_for_booking(self, booking_id: uuid.UUID) -> list[Ticket]:
        result = await self._session.execute(select(Ticket).where(Ticket.booking_id == booking_id))
        return list(result.scalars().all())

    async def list_for_trip(self, trip_id: uuid.UUID) -> list[Ticket]:
        result = await self._session.execute(select(Ticket).where(Ticket.trip_id == trip_id))
        return list(result.scalars().all())

    async def set_status(
        self,
        ticket: Ticket,
        *,
        new_status: TicketStatus,
        validated_by: uuid.UUID | None = None,
        revoked_reason: str | None = None,
    ) -> None:
        ticket.status = new_status
        now = datetime.now(UTC)
        if new_status == TicketStatus.VALIDATED:
            ticket.validated_at = now
            ticket.validated_by = validated_by
        elif new_status == TicketStatus.REVOKED:
            ticket.revoked_at = now
            ticket.revoked_reason = revoked_reason
        await self._session.flush()

    async def revoke_tickets_for_booking(self, booking_id: uuid.UUID, *, reason: str) -> int:
        """Revokes every still-``ISSUED`` ticket for a booking (e.g. it was
        cancelled after tickets had already been issued). Already-validated
        or already-revoked tickets are left untouched — a passenger who has
        already boarded keeps their boarding history intact."""
        tickets = await self.list_for_booking(booking_id)
        revoked_count = 0
        for ticket in tickets:
            if ticket.status == TicketStatus.ISSUED:
                await self.set_status(
                    ticket, new_status=TicketStatus.REVOKED, revoked_reason=reason
                )
                revoked_count += 1
        return revoked_count
