"""Create ticket table.

Revision ID: 20260811_0007
Revises: 20260809_0006
Create Date: 2026-08-11 00:00:00
"""

from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "20260811_0007"
down_revision: str | None = "20260809_0006"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

ticket_status_enum = sa.Enum("issued", "validated", "expired", "revoked", name="ticket_status")


def upgrade() -> None:
    op.create_table(
        "tickets",
        sa.Column("id", sa.Uuid(), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("ticket_reference", sa.String(20), nullable=False),
        sa.Column("booking_id", sa.Uuid(), nullable=False),
        sa.Column("booking_passenger_id", sa.Uuid(), nullable=False),
        sa.Column("trip_id", sa.Uuid(), nullable=False),
        sa.Column("status", ticket_status_enum, nullable=False, server_default="issued"),
        sa.Column("issued_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("expires_at", sa.TIMESTAMP(timezone=True), nullable=False),
        sa.Column("validated_at", sa.TIMESTAMP(timezone=True), nullable=True),
        sa.Column("validated_by", sa.Uuid(), nullable=True),
        sa.Column("revoked_at", sa.TIMESTAMP(timezone=True), nullable=True),
        sa.Column("revoked_reason", sa.String(255), nullable=True),
        sa.PrimaryKeyConstraint("id", name="pk_tickets"),
        sa.ForeignKeyConstraint(["booking_id"], ["bookings.id"], name="fk_tickets_booking_id_bookings", ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(
            ["booking_passenger_id"], ["booking_passengers.id"],
            name="fk_tickets_booking_passenger_id_booking_passengers", ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(["trip_id"], ["trips.id"], name="fk_tickets_trip_id_trips", ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(["validated_by"], ["users.id"], name="fk_tickets_validated_by_users", ondelete="SET NULL"),
        sa.UniqueConstraint("ticket_reference", name="uq_tickets_ticket_reference"),
        sa.UniqueConstraint("booking_passenger_id", name="uq_tickets_booking_passenger_id"),
    )
    op.create_index("ix_tickets_booking_id", "tickets", ["booking_id"])
    op.create_index("ix_tickets_trip_id", "tickets", ["trip_id"])
    op.create_index("ix_tickets_status", "tickets", ["status"])


def downgrade() -> None:
    op.drop_table("tickets")

    bind = op.get_bind()
    ticket_status_enum.drop(bind, checkfirst=True)
