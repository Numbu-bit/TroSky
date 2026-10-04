"""What drivers did on their trips, for the operations team to see: each
trip and booking accepted or declined, the trip started, paused, resumed and
ended, tickets scanned and passengers marked off. An admin acting for a
driver, and the system acting when nobody answered, are recorded the same
way with ``acted_as`` saying who it really was.
"""

from __future__ import annotations

import uuid
from enum import StrEnum
from typing import Any

from sqlalchemy import Enum as PgEnum
from sqlalchemy import ForeignKey, Index
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.types import String

from app.models.base import UUIDAuditBase, enum_values


class DriverActionKind(StrEnum):
    TRIP_ACCEPTED = "trip_accepted"
    TRIP_DECLINED = "trip_declined"
    TRIP_STARTED = "trip_started"
    TRIP_PAUSED = "trip_paused"
    TRIP_RESUMED = "trip_resumed"
    TRIP_ENDED = "trip_ended"
    BOOKING_ACCEPTED = "booking_accepted"
    BOOKING_DECLINED = "booking_declined"
    BOOKING_UNANSWERED = "booking_unanswered"
    TICKET_SCANNED = "ticket_scanned"
    PASSENGER_ALIGHTED = "passenger_alighted"


class ActedAs(StrEnum):
    DRIVER = "driver"
    ADMIN = "admin"
    SYSTEM = "system"


class DriverAction(UUIDAuditBase):
    __tablename__ = "driver_actions"

    # The driver whose trip it was (None: the trip had no driver then).
    driver_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("drivers.id", ondelete="SET NULL"), nullable=True
    )
    trip_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("trips.id", ondelete="CASCADE"), nullable=False
    )
    booking_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("bookings.id", ondelete="CASCADE"), nullable=True
    )
    kind: Mapped[DriverActionKind] = mapped_column(
        PgEnum(
            DriverActionKind,
            name="driver_action_kind",
            native_enum=True,
            values_callable=enum_values,
        ),
        nullable=False,
    )
    acted_as: Mapped[ActedAs] = mapped_column(
        PgEnum(ActedAs, name="acted_as", native_enum=True, values_callable=enum_values),
        nullable=False,
    )
    actor_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    reason: Mapped[str | None] = mapped_column(String(500), nullable=True)
    details: Mapped[dict[str, Any] | None] = mapped_column(JSONB, nullable=True)

    __table_args__ = (
        Index("ix_driver_actions_driver_id_created_at", "driver_id", "created_at"),
        Index("ix_driver_actions_trip_id", "trip_id"),
        Index("ix_driver_actions_created_at", "created_at"),
    )
