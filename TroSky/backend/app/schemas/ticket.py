"""Request/response schemas for tickets."""

from __future__ import annotations

import uuid
from datetime import datetime

from pydantic import Field

from app.models.tickets import TicketStatus
from app.schemas.common import ApiModel, RequestModel


class TicketResponse(ApiModel):
    id: uuid.UUID
    ticket_reference: str
    booking_id: uuid.UUID
    booking_passenger_id: uuid.UUID
    trip_id: uuid.UUID
    status: TicketStatus
    issued_at: datetime
    expires_at: datetime
    validated_at: datetime | None
    qr_token: str


class ValidateTicketRequest(RequestModel):
    qr_token: str = Field(..., min_length=1, max_length=512)
