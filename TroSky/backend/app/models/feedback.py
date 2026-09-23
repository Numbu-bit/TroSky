"""Feedback domain models: post-trip ratings and complaints."""

from __future__ import annotations

import uuid
from datetime import datetime
from enum import StrEnum

from sqlalchemy import CheckConstraint, ForeignKey, Index, UniqueConstraint
from sqlalchemy import Enum as PgEnum
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.types import TIMESTAMP, Integer, String

from app.models.base import UUIDAuditBase, enum_values


class ComplaintCategory(StrEnum):
    DRIVER_CONDUCT = "driver_conduct"
    VEHICLE_CONDITION = "vehicle_condition"
    SAFETY = "safety"
    PAYMENT = "payment"
    OTHER = "other"


class ComplaintStatus(StrEnum):
    OPEN = "open"
    IN_REVIEW = "in_review"
    RESOLVED = "resolved"
    DISMISSED = "dismissed"


class Rating(UUIDAuditBase):
    """One rating per booking — a passenger rates the trip they took."""

    __tablename__ = "ratings"

    booking_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("bookings.id", ondelete="RESTRICT"), nullable=False
    )
    trip_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("trips.id", ondelete="RESTRICT"), nullable=False
    )
    passenger_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    driver_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("drivers.id", ondelete="SET NULL"), nullable=True
    )
    score: Mapped[int] = mapped_column(Integer, nullable=False)
    comment: Mapped[str | None] = mapped_column(String(1000), nullable=True)

    __table_args__ = (
        UniqueConstraint("booking_id", name="uq_ratings_booking_id"),
        CheckConstraint("score >= 1 AND score <= 5", name="score_between_1_and_5"),
        Index("ix_ratings_driver_id", "driver_id"),
        Index("ix_ratings_trip_id", "trip_id"),
    )


class Complaint(UUIDAuditBase):
    __tablename__ = "complaints"

    filed_by: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    booking_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("bookings.id", ondelete="SET NULL"), nullable=True
    )
    trip_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("trips.id", ondelete="SET NULL"), nullable=True
    )
    category: Mapped[ComplaintCategory] = mapped_column(
        PgEnum(
            ComplaintCategory,
            name="complaint_category",
            native_enum=True,
            values_callable=enum_values,
        ),
        nullable=False,
    )
    subject: Mapped[str] = mapped_column(String(200), nullable=False)
    description: Mapped[str] = mapped_column(String(2000), nullable=False)
    status: Mapped[ComplaintStatus] = mapped_column(
        PgEnum(
            ComplaintStatus, name="complaint_status", native_enum=True, values_callable=enum_values
        ),
        nullable=False,
        default=ComplaintStatus.OPEN,
    )
    resolved_by: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    resolved_at: Mapped[datetime | None] = mapped_column(TIMESTAMP(timezone=True), nullable=True)
    resolution_notes: Mapped[str | None] = mapped_column(String(1000), nullable=True)

    __table_args__ = (
        Index("ix_complaints_filed_by", "filed_by"),
        Index("ix_complaints_status", "status"),
    )
