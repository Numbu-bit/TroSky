"""Ticket domain model: one QR-boarding-pass row per booked seat.

A ticket's QR payload is never persisted — it is fully derivable from
``(id, expires_at)`` plus ``TICKET_QR_SIGNING_SECRET`` (see
``app.utilities.ticket_qr``), the same reasoning JWTs use for not storing
their own signature: recomputing it is cheap, storing it would just be a
second, driftable copy of the same fact, and rotating the signing secret
naturally (and correctly) invalidates every outstanding QR code at once.
"""

from __future__ import annotations

import uuid
from datetime import datetime
from enum import StrEnum

from sqlalchemy import Enum as PgEnum
from sqlalchemy import ForeignKey, Index, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.types import TIMESTAMP, String

from app.models.base import UUIDAuditBase, enum_values


class TicketStatus(StrEnum):
    ISSUED = "issued"
    VALIDATED = "validated"
    EXPIRED = "expired"
    REVOKED = "revoked"


class Ticket(UUIDAuditBase):
    __tablename__ = "tickets"

    ticket_reference: Mapped[str] = mapped_column(String(20), nullable=False)
    booking_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("bookings.id", ondelete="RESTRICT"), nullable=False
    )
    booking_passenger_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("booking_passengers.id", ondelete="RESTRICT"), nullable=False
    )
    trip_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("trips.id", ondelete="RESTRICT"), nullable=False
    )
    status: Mapped[TicketStatus] = mapped_column(
        PgEnum(TicketStatus, name="ticket_status", native_enum=True, values_callable=enum_values),
        nullable=False,
        default=TicketStatus.ISSUED,
    )
    issued_at: Mapped[datetime] = mapped_column(
        TIMESTAMP(timezone=True), nullable=False, server_default="now()"
    )
    expires_at: Mapped[datetime] = mapped_column(TIMESTAMP(timezone=True), nullable=False)
    validated_at: Mapped[datetime | None] = mapped_column(TIMESTAMP(timezone=True), nullable=True)
    validated_by: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    revoked_at: Mapped[datetime | None] = mapped_column(TIMESTAMP(timezone=True), nullable=True)
    revoked_reason: Mapped[str | None] = mapped_column(String(255), nullable=True)

    __table_args__ = (
        UniqueConstraint("ticket_reference", name="uq_tickets_ticket_reference"),
        UniqueConstraint("booking_passenger_id", name="uq_tickets_booking_passenger_id"),
        Index("ix_tickets_booking_id", "booking_id"),
        Index("ix_tickets_trip_id", "trip_id"),
        Index("ix_tickets_status", "status"),
    )
