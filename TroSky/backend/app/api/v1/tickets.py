"""Passenger-facing ticket read endpoints. Issuance happens only as a side
effect of ``BookingService.confirm_booking`` (see that module) — there is
no "create ticket" route. Driver-facing validation lives in
``app.api.v1.driver_trips``."""

from __future__ import annotations

import uuid

from fastapi import APIRouter

from app.api.dependencies import CurrentPrincipal, TicketServiceDep
from app.core.permissions import Permission
from app.models.tickets import Ticket
from app.schemas.ticket import TicketResponse
from app.services.ticket_service import TicketService

router = APIRouter()


def _ticket_response(service: TicketService, ticket: Ticket) -> TicketResponse:
    return TicketResponse(
        id=ticket.id,
        ticket_reference=ticket.ticket_reference,
        booking_id=ticket.booking_id,
        booking_passenger_id=ticket.booking_passenger_id,
        trip_id=ticket.trip_id,
        status=ticket.status,
        issued_at=ticket.issued_at,
        expires_at=ticket.expires_at,
        validated_at=ticket.validated_at,
        qr_token=service.get_qr_token(ticket),
    )


@router.get("/{ticket_id}", response_model=TicketResponse)
async def get_ticket(
    ticket_id: uuid.UUID, principal: CurrentPrincipal, service: TicketServiceDep
) -> TicketResponse:
    is_privileged = principal.has_permission(Permission.BOOKINGS_VIEW_ANY)
    ticket = await service.get_ticket(
        ticket_id, requesting_user_id=principal.user_id, is_privileged=is_privileged
    )
    return _ticket_response(service, ticket)
