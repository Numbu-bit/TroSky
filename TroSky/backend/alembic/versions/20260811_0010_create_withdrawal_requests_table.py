"""Add trip_earning/withdrawal wallet-reference-type values and create the
withdrawal_requests table.

Revision ID: 20260811_0010
Revises: 20260811_0009
Create Date: 2026-08-11 00:00:00
"""

from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import ENUM as PostgresEnum

# revision identifiers, used by Alembic.
revision: str = "20260811_0010"
down_revision: str | None = "20260811_0009"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

withdrawal_status_enum = sa.Enum(
    "pending", "approved", "rejected", "completed", "failed", name="withdrawal_status"
)
# References the `payment_channel` type created in 20260809_0006 —
# `create_type=False` so this migration doesn't try to (re-)create it.
payment_channel_enum = PostgresEnum(
    "mtn_momo",
    "telecel_cash",
    "airteltigo_money",
    "card",
    "wallet",
    name="payment_channel",
    create_type=False,
)


def upgrade() -> None:
    # New values for the existing `wallet_reference_type` enum. Must not be
    # used by any DML in this same migration/transaction — Postgres only
    # makes a newly-added enum value visible to transactions that start
    # after this one commits.
    op.execute("ALTER TYPE wallet_reference_type ADD VALUE IF NOT EXISTS 'trip_earning'")
    op.execute("ALTER TYPE wallet_reference_type ADD VALUE IF NOT EXISTS 'withdrawal'")

    op.create_table(
        "withdrawal_requests",
        sa.Column("id", sa.Uuid(), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("amount", sa.Numeric(12, 2), nullable=False),
        sa.Column("channel", payment_channel_enum, nullable=False),
        sa.Column("destination_phone_number", sa.String(20), nullable=False),
        sa.Column("status", withdrawal_status_enum, nullable=False, server_default="pending"),
        sa.Column("reviewed_by", sa.Uuid(), nullable=True),
        sa.Column("reviewed_at", sa.TIMESTAMP(timezone=True), nullable=True),
        sa.Column("decision_notes", sa.String(1000), nullable=True),
        sa.Column("provider_reference", sa.String(100), nullable=True),
        sa.Column("failure_reason", sa.String(500), nullable=True),
        sa.Column("version", sa.Integer(), nullable=False, server_default="1"),
        sa.PrimaryKeyConstraint("id", name="pk_withdrawal_requests"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], name="fk_withdrawal_requests_user_id_users", ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(["reviewed_by"], ["users.id"], name="fk_withdrawal_requests_reviewed_by_users", ondelete="SET NULL"),
        sa.CheckConstraint("amount > 0", name="amount_positive"),
    )
    op.create_index("ix_withdrawal_requests_user_id", "withdrawal_requests", ["user_id"])
    op.create_index("ix_withdrawal_requests_status", "withdrawal_requests", ["status"])


def downgrade() -> None:
    op.drop_table("withdrawal_requests")

    bind = op.get_bind()
    withdrawal_status_enum.drop(bind, checkfirst=True)

    # Postgres has no `ALTER TYPE ... DROP VALUE` — removing an enum value
    # cleanly requires rebuilding the type (create new, migrate columns,
    # drop old, rename). Not attempted here: this migration's downgrade
    # leaves `trip_earning`/`withdrawal` as harmless unused enum labels
    # rather than risk a destructive type-rebuild in a downgrade path.
