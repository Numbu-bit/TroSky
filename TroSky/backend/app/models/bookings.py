"""Booking domain models: bookings, the passengers within a booking, seat
reservations (the concurrency-critical table), status history, and
cancellation requests.

Concurrency-safety design (see ``app.services.booking_service`` for the
full write-up): ``seat_reservations`` carries a **partial unique index** on
``(trip_id, seat_id)`` for rows whose status is ``held`` or ``confirmed`` —
the database itself rejects a second active reservation for the same seat
on the same trip, so overselling is impossible even under concurrent
requests, regardless of application-level locking. Redis is used only to
accelerate/short-circuit obviously-taken seats before hitting the
database — never as the source of truth.
"""

from __future__ import annotations

import uuid
from datetime import datetime
from decimal import Decimal
from enum import StrEnum

from sqlalchemy import CheckConstraint, ForeignKey, Index, UniqueConstraint
from sqlalchemy import Enum as PgEnum
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.types import TIMESTAMP, Integer, Numeric, String

from app.models.base import UUIDAuditBase, enum_values


class BookingStatus(StrEnum):
    PENDING = "pending"
    PAYMENT_PENDING = "payment_pending"
    CONFIRMED = "confirmed"
    CANCELLED = "cancelled"
    EXPIRED = "expired"
    COMPLETED = "completed"
    REFUND_PENDING = "refund_pending"
    REFUNDED = "refunded"


class ReservationStatus(StrEnum):
    HELD = "held"
    CONFIRMED = "confirmed"
    RELEASED = "released"
    EXPIRED = "expired"


class CancellationStatus(StrEnum):
    PENDING = "pending"
    APPROVED = "approved"
    REJECTED = "rejected"


class Booking(UUIDAuditBase):
    __tablename__ = "bookings"

    booking_reference: Mapped[str] = mapped_column(String(20), nullable=False)
    passenger_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="RESTRICT"), nullable=False
    )
    trip_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("trips.id", ondelete="RESTRICT"), nullable=False
    )
    status: Mapped[BookingStatus] = mapped_column(
        PgEnum(BookingStatus, name="booking_status", native_enum=True, values_callable=enum_values),
        nullable=False,
        default=BookingStatus.PENDING,
    )
    # Which part of the route this booking rides. NULL means end to end,
    # which is what every booking was before segment pricing existed.
    origin_stop_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("stops.id", ondelete="RESTRICT"), nullable=True
    )
    destination_stop_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("stops.id", ondelete="RESTRICT"), nullable=True
    )
    passenger_count: Mapped[int] = mapped_column(Integer, nullable=False)
    # fare_amount is the operator's share, platform_fee is TroSky's, and
    # total_amount is what the passenger actually pays (fare + fee). Kept as
    # three stored columns rather than deriving the split at read time so a
    # later change to the fee schedule never rewrites historical revenue.
    fare_amount: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False, server_default="0")
    platform_fee: Mapped[Decimal] = mapped_column(
        Numeric(12, 2), nullable=False, server_default="0"
    )
    total_amount: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)
    idempotency_key: Mapped[uuid.UUID | None] = mapped_column(nullable=True)
    idempotency_request_hash: Mapped[str | None] = mapped_column(String(64), nullable=True)
    expires_at: Mapped[datetime | None] = mapped_column(TIMESTAMP(timezone=True), nullable=True)
    version: Mapped[int] = mapped_column(nullable=False, default=1, server_default="1")

    __table_args__ = (
        UniqueConstraint("booking_reference", name="uq_bookings_booking_reference"),
        UniqueConstraint(
            "passenger_id", "idempotency_key", name="uq_bookings_passenger_idempotency_key"
        ),
        CheckConstraint("passenger_count > 0", name="passenger_count_positive"),
        CheckConstraint("total_amount >= 0", name="total_amount_non_negative"),
        CheckConstraint("fare_amount >= 0", name="fare_amount_non_negative"),
        CheckConstraint("platform_fee >= 0", name="platform_fee_non_negative"),
        Index("ix_bookings_passenger_id", "passenger_id"),
        Index("ix_bookings_trip_id", "trip_id"),
        Index("ix_bookings_trip_segment", "trip_id", "origin_stop_id", "destination_stop_id"),
        Index("ix_bookings_status", "status"),
        Index("ix_bookings_status_expires_at", "status", "expires_at"),
    )

    __mapper_args__ = {"version_id_col": version}  # noqa: RUF012 - SQLAlchemy special attribute


class BookingPassenger(UUIDAuditBase):
    """One traveler occupying one seat within a booking."""

    __tablename__ = "booking_passengers"

    booking_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("bookings.id", ondelete="CASCADE"), nullable=False
    )
    seat_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("vehicle_seats.id", ondelete="RESTRICT"), nullable=False
    )
    full_name: Mapped[str] = mapped_column(String(200), nullable=False)
    phone_number: Mapped[str | None] = mapped_column(String(20), nullable=True)

    __table_args__ = (
        UniqueConstraint("booking_id", "seat_id", name="uq_booking_passengers_booking_seat"),
        Index("ix_booking_passengers_booking_id", "booking_id"),
    )


class SeatReservation(UUIDAuditBase):
    """The concurrency-critical row: at most one *active* (held/confirmed)
    reservation may exist per (trip_id, seat_id) — enforced by a partial
    unique index, not application logic alone."""

    __tablename__ = "seat_reservations"

    trip_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("trips.id", ondelete="CASCADE"), nullable=False
    )
    seat_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("vehicle_seats.id", ondelete="RESTRICT"), nullable=False
    )
    booking_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("bookings.id", ondelete="CASCADE"), nullable=False
    )
    status: Mapped[ReservationStatus] = mapped_column(
        PgEnum(
            ReservationStatus,
            name="reservation_status",
            native_enum=True,
            values_callable=enum_values,
        ),
        nullable=False,
        default=ReservationStatus.HELD,
    )
    held_at: Mapped[datetime] = mapped_column(
        TIMESTAMP(timezone=True), nullable=False, server_default="now()"
    )
    expires_at: Mapped[datetime | None] = mapped_column(TIMESTAMP(timezone=True), nullable=True)
    confirmed_at: Mapped[datetime | None] = mapped_column(TIMESTAMP(timezone=True), nullable=True)
    released_at: Mapped[datetime | None] = mapped_column(TIMESTAMP(timezone=True), nullable=True)

    __table_args__ = (
        Index("ix_seat_reservations_trip_id", "trip_id"),
        Index("ix_seat_reservations_booking_id", "booking_id"),
        Index("ix_seat_reservations_status_expires_at", "status", "expires_at"),
        Index(
            "uq_seat_reservations_active_trip_seat",
            "trip_id",
            "seat_id",
            unique=True,
            postgresql_where=status.in_(["held", "confirmed"]),
        ),
    )


class BookingStatusHistory(UUIDAuditBase):
    __tablename__ = "booking_status_history"

    booking_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("bookings.id", ondelete="CASCADE"), nullable=False
    )
    from_status: Mapped[BookingStatus | None] = mapped_column(
        PgEnum(
            BookingStatus,
            name="booking_status",
            native_enum=True,
            values_callable=enum_values,
            create_type=False,
        ),
        nullable=True,
    )
    to_status: Mapped[BookingStatus] = mapped_column(
        PgEnum(
            BookingStatus,
            name="booking_status",
            native_enum=True,
            values_callable=enum_values,
            create_type=False,
        ),
        nullable=False,
    )
    changed_by: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    reason: Mapped[str | None] = mapped_column(String(500), nullable=True)
    changed_at: Mapped[datetime] = mapped_column(
        TIMESTAMP(timezone=True), nullable=False, server_default="now()"
    )

    __table_args__ = (Index("ix_booking_status_history_booking_id", "booking_id"),)


class CancellationRequest(UUIDAuditBase):
    __tablename__ = "cancellation_requests"

    booking_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("bookings.id", ondelete="CASCADE"), nullable=False
    )
    requested_by: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    reason: Mapped[str | None] = mapped_column(String(500), nullable=True)
    status: Mapped[CancellationStatus] = mapped_column(
        PgEnum(
            CancellationStatus,
            name="cancellation_status",
            native_enum=True,
            values_callable=enum_values,
        ),
        nullable=False,
        default=CancellationStatus.PENDING,
    )
    refund_eligible: Mapped[bool] = mapped_column(nullable=False, default=False)
    decided_by: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    decided_at: Mapped[datetime | None] = mapped_column(TIMESTAMP(timezone=True), nullable=True)
    decision_notes: Mapped[str | None] = mapped_column(String(1000), nullable=True)

    __table_args__ = (Index("ix_cancellation_requests_booking_id", "booking_id"),)
