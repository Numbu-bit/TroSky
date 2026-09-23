"""Create booking, booking-passenger, seat-reservation, booking-status-
history, and cancellation-request tables.

Revision ID: 20260809_0005
Revises: 20260804_0004
Create Date: 2026-08-09 00:00:00
"""

from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "20260809_0005"
down_revision: str | None = "20260804_0004"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

booking_status_enum = sa.Enum(
    "pending", "payment_pending", "confirmed", "cancelled", "expired", "completed",
    "refund_pending", "refunded",
    name="booking_status",
)
reservation_status_enum = sa.Enum("held", "confirmed", "released", "expired", name="reservation_status")
cancellation_status_enum = sa.Enum("pending", "approved", "rejected", name="cancellation_status")


def upgrade() -> None:
    op.create_table(
        "bookings",
        sa.Column("id", sa.Uuid(), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("booking_reference", sa.String(20), nullable=False),
        sa.Column("passenger_id", sa.Uuid(), nullable=False),
        sa.Column("trip_id", sa.Uuid(), nullable=False),
        sa.Column("status", booking_status_enum, nullable=False, server_default="pending"),
        sa.Column("passenger_count", sa.Integer(), nullable=False),
        sa.Column("total_amount", sa.Numeric(12, 2), nullable=False),
        sa.Column("idempotency_key", sa.Uuid(), nullable=True),
        sa.Column("idempotency_request_hash", sa.String(64), nullable=True),
        sa.Column("expires_at", sa.TIMESTAMP(timezone=True), nullable=True),
        sa.Column("version", sa.Integer(), nullable=False, server_default="1"),
        sa.PrimaryKeyConstraint("id", name="pk_bookings"),
        sa.ForeignKeyConstraint(["passenger_id"], ["users.id"], name="fk_bookings_passenger_id_users", ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(["trip_id"], ["trips.id"], name="fk_bookings_trip_id_trips", ondelete="RESTRICT"),
        sa.UniqueConstraint("booking_reference", name="uq_bookings_booking_reference"),
        sa.UniqueConstraint("passenger_id", "idempotency_key", name="uq_bookings_passenger_idempotency_key"),
        sa.CheckConstraint("passenger_count > 0", name="passenger_count_positive"),
        sa.CheckConstraint("total_amount >= 0", name="total_amount_non_negative"),
    )
    op.create_index("ix_bookings_passenger_id", "bookings", ["passenger_id"])
    op.create_index("ix_bookings_trip_id", "bookings", ["trip_id"])
    op.create_index("ix_bookings_status", "bookings", ["status"])
    op.create_index("ix_bookings_status_expires_at", "bookings", ["status", "expires_at"])

    op.create_table(
        "booking_passengers",
        sa.Column("id", sa.Uuid(), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("booking_id", sa.Uuid(), nullable=False),
        sa.Column("seat_id", sa.Uuid(), nullable=False),
        sa.Column("full_name", sa.String(200), nullable=False),
        sa.Column("phone_number", sa.String(20), nullable=True),
        sa.PrimaryKeyConstraint("id", name="pk_booking_passengers"),
        sa.ForeignKeyConstraint(["booking_id"], ["bookings.id"], name="fk_booking_passengers_booking_id_bookings", ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["seat_id"], ["vehicle_seats.id"], name="fk_booking_passengers_seat_id_vehicle_seats", ondelete="RESTRICT"),
        sa.UniqueConstraint("booking_id", "seat_id", name="uq_booking_passengers_booking_seat"),
    )
    op.create_index("ix_booking_passengers_booking_id", "booking_passengers", ["booking_id"])

    op.create_table(
        "seat_reservations",
        sa.Column("id", sa.Uuid(), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("trip_id", sa.Uuid(), nullable=False),
        sa.Column("seat_id", sa.Uuid(), nullable=False),
        sa.Column("booking_id", sa.Uuid(), nullable=False),
        sa.Column("status", reservation_status_enum, nullable=False, server_default="held"),
        sa.Column("held_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("expires_at", sa.TIMESTAMP(timezone=True), nullable=True),
        sa.Column("confirmed_at", sa.TIMESTAMP(timezone=True), nullable=True),
        sa.Column("released_at", sa.TIMESTAMP(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint("id", name="pk_seat_reservations"),
        sa.ForeignKeyConstraint(["trip_id"], ["trips.id"], name="fk_seat_reservations_trip_id_trips", ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["seat_id"], ["vehicle_seats.id"], name="fk_seat_reservations_seat_id_vehicle_seats", ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(["booking_id"], ["bookings.id"], name="fk_seat_reservations_booking_id_bookings", ondelete="CASCADE"),
    )
    op.create_index("ix_seat_reservations_trip_id", "seat_reservations", ["trip_id"])
    op.create_index("ix_seat_reservations_booking_id", "seat_reservations", ["booking_id"])
    op.create_index("ix_seat_reservations_status_expires_at", "seat_reservations", ["status", "expires_at"])
    op.create_index(
        "uq_seat_reservations_active_trip_seat",
        "seat_reservations",
        ["trip_id", "seat_id"],
        unique=True,
        postgresql_where=sa.text("status IN ('held', 'confirmed')"),
    )

    op.create_table(
        "booking_status_history",
        sa.Column("id", sa.Uuid(), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("booking_id", sa.Uuid(), nullable=False),
        sa.Column("from_status", booking_status_enum, nullable=True),
        sa.Column("to_status", booking_status_enum, nullable=False),
        sa.Column("changed_by", sa.Uuid(), nullable=True),
        sa.Column("reason", sa.String(500), nullable=True),
        sa.Column("changed_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.PrimaryKeyConstraint("id", name="pk_booking_status_history"),
        sa.ForeignKeyConstraint(["booking_id"], ["bookings.id"], name="fk_booking_status_history_booking_id_bookings", ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["changed_by"], ["users.id"], name="fk_booking_status_history_changed_by_users", ondelete="SET NULL"),
    )
    op.create_index("ix_booking_status_history_booking_id", "booking_status_history", ["booking_id"])

    op.create_table(
        "cancellation_requests",
        sa.Column("id", sa.Uuid(), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("booking_id", sa.Uuid(), nullable=False),
        sa.Column("requested_by", sa.Uuid(), nullable=True),
        sa.Column("reason", sa.String(500), nullable=True),
        sa.Column("status", cancellation_status_enum, nullable=False, server_default="pending"),
        sa.Column("refund_eligible", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("decided_by", sa.Uuid(), nullable=True),
        sa.Column("decided_at", sa.TIMESTAMP(timezone=True), nullable=True),
        sa.Column("decision_notes", sa.String(1000), nullable=True),
        sa.PrimaryKeyConstraint("id", name="pk_cancellation_requests"),
        sa.ForeignKeyConstraint(["booking_id"], ["bookings.id"], name="fk_cancellation_requests_booking_id_bookings", ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["requested_by"], ["users.id"], name="fk_cancellation_requests_requested_by_users", ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["decided_by"], ["users.id"], name="fk_cancellation_requests_decided_by_users", ondelete="SET NULL"),
    )
    op.create_index("ix_cancellation_requests_booking_id", "cancellation_requests", ["booking_id"])


def downgrade() -> None:
    op.drop_table("cancellation_requests")
    op.drop_table("booking_status_history")
    op.drop_table("seat_reservations")
    op.drop_table("booking_passengers")
    op.drop_table("bookings")

    bind = op.get_bind()
    cancellation_status_enum.drop(bind, checkfirst=True)
    reservation_status_enum.drop(bind, checkfirst=True)
    booking_status_enum.drop(bind, checkfirst=True)
