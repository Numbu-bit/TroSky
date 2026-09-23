"""Create payment, payment-webhook-event, refund-request, wallet, and
wallet-transaction tables.

Revision ID: 20260809_0006
Revises: 20260809_0005
Create Date: 2026-08-09 00:00:00
"""

from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import JSONB

# revision identifiers, used by Alembic.
revision: str = "20260809_0006"
down_revision: str | None = "20260809_0005"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

payment_purpose_enum = sa.Enum("booking_payment", "wallet_topup", name="payment_purpose")
payment_channel_enum = sa.Enum(
    "mtn_momo", "telecel_cash", "airteltigo_money", "card", "wallet", name="payment_channel"
)
payment_status_enum = sa.Enum(
    "pending", "processing", "successful", "failed", "cancelled", "refunded",
    "partially_refunded",
    name="payment_status",
)
refund_status_enum = sa.Enum(
    "pending", "approved", "rejected", "completed", "failed", name="refund_status"
)
wallet_entry_type_enum = sa.Enum("credit", "debit", name="wallet_entry_type")
wallet_reference_type_enum = sa.Enum(
    "booking_payment", "wallet_topup", "refund", "admin_adjustment", name="wallet_reference_type"
)


def upgrade() -> None:
    op.create_table(
        "payments",
        sa.Column("id", sa.Uuid(), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("booking_id", sa.Uuid(), nullable=True),
        sa.Column("purpose", payment_purpose_enum, nullable=False),
        sa.Column("channel", payment_channel_enum, nullable=False),
        sa.Column("status", payment_status_enum, nullable=False, server_default="pending"),
        sa.Column("amount", sa.Numeric(12, 2), nullable=False),
        sa.Column("currency", sa.String(3), nullable=False, server_default="GHS"),
        sa.Column("refunded_amount", sa.Numeric(12, 2), nullable=False, server_default="0.00"),
        sa.Column("payer_phone_number", sa.String(20), nullable=True),
        sa.Column("internal_reference", sa.String(40), nullable=False),
        sa.Column("provider_reference", sa.String(100), nullable=True),
        sa.Column("idempotency_key", sa.Uuid(), nullable=True),
        sa.Column("idempotency_request_hash", sa.String(64), nullable=True),
        sa.Column("failure_reason", sa.String(500), nullable=True),
        sa.Column("initiated_at", sa.TIMESTAMP(timezone=True), nullable=True),
        sa.Column("completed_at", sa.TIMESTAMP(timezone=True), nullable=True),
        sa.Column("version", sa.Integer(), nullable=False, server_default="1"),
        sa.PrimaryKeyConstraint("id", name="pk_payments"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], name="fk_payments_user_id_users", ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(["booking_id"], ["bookings.id"], name="fk_payments_booking_id_bookings", ondelete="RESTRICT"),
        sa.UniqueConstraint("internal_reference", name="uq_payments_internal_reference"),
        sa.UniqueConstraint("user_id", "idempotency_key", name="uq_payments_user_idempotency_key"),
        sa.CheckConstraint("amount > 0", name="amount_positive"),
        sa.CheckConstraint("refunded_amount >= 0", name="refunded_amount_non_negative"),
    )
    op.create_index("ix_payments_user_id", "payments", ["user_id"])
    op.create_index("ix_payments_booking_id", "payments", ["booking_id"])
    op.create_index("ix_payments_status", "payments", ["status"])

    op.create_table(
        "payment_webhook_events",
        sa.Column("id", sa.Uuid(), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("channel", payment_channel_enum, nullable=False),
        sa.Column("provider_reference", sa.String(100), nullable=False),
        sa.Column("event_status", sa.String(20), nullable=False),
        sa.Column("signature_valid", sa.Boolean(), nullable=False),
        sa.Column("payment_id", sa.Uuid(), nullable=True),
        sa.Column("raw_payload", JSONB(), nullable=False),
        sa.Column("processed_at", sa.TIMESTAMP(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint("id", name="pk_payment_webhook_events"),
        sa.ForeignKeyConstraint(["payment_id"], ["payments.id"], name="fk_payment_webhook_events_payment_id_payments", ondelete="SET NULL"),
        sa.UniqueConstraint(
            "channel", "provider_reference", "event_status",
            name="uq_payment_webhook_events_channel_reference_status",
        ),
    )
    op.create_index("ix_payment_webhook_events_provider_reference", "payment_webhook_events", ["provider_reference"])
    op.create_index("ix_payment_webhook_events_payment_id", "payment_webhook_events", ["payment_id"])

    op.create_table(
        "refund_requests",
        sa.Column("id", sa.Uuid(), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("payment_id", sa.Uuid(), nullable=False),
        sa.Column("booking_id", sa.Uuid(), nullable=True),
        sa.Column("requested_by", sa.Uuid(), nullable=True),
        sa.Column("amount", sa.Numeric(12, 2), nullable=False),
        sa.Column("reason", sa.String(500), nullable=True),
        sa.Column("status", refund_status_enum, nullable=False, server_default="pending"),
        sa.Column("reviewed_by", sa.Uuid(), nullable=True),
        sa.Column("reviewed_at", sa.TIMESTAMP(timezone=True), nullable=True),
        sa.Column("decision_notes", sa.String(1000), nullable=True),
        sa.Column("provider_refund_reference", sa.String(100), nullable=True),
        sa.Column("failure_reason", sa.String(500), nullable=True),
        sa.Column("version", sa.Integer(), nullable=False, server_default="1"),
        sa.PrimaryKeyConstraint("id", name="pk_refund_requests"),
        sa.ForeignKeyConstraint(["payment_id"], ["payments.id"], name="fk_refund_requests_payment_id_payments", ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(["booking_id"], ["bookings.id"], name="fk_refund_requests_booking_id_bookings", ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(["requested_by"], ["users.id"], name="fk_refund_requests_requested_by_users", ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["reviewed_by"], ["users.id"], name="fk_refund_requests_reviewed_by_users", ondelete="SET NULL"),
        sa.CheckConstraint("amount > 0", name="amount_positive"),
    )
    op.create_index("ix_refund_requests_payment_id", "refund_requests", ["payment_id"])
    op.create_index("ix_refund_requests_booking_id", "refund_requests", ["booking_id"])
    op.create_index("ix_refund_requests_status", "refund_requests", ["status"])

    op.create_table(
        "wallets",
        sa.Column("id", sa.Uuid(), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("balance_minor_units", sa.BigInteger(), nullable=False, server_default="0"),
        sa.Column("currency", sa.String(3), nullable=False, server_default="GHS"),
        sa.Column("version", sa.Integer(), nullable=False, server_default="1"),
        sa.PrimaryKeyConstraint("id", name="pk_wallets"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], name="fk_wallets_user_id_users", ondelete="RESTRICT"),
        sa.UniqueConstraint("user_id", name="uq_wallets_user_id"),
        sa.CheckConstraint("balance_minor_units >= 0", name="balance_non_negative"),
    )

    op.create_table(
        "wallet_transactions",
        sa.Column("id", sa.Uuid(), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("wallet_id", sa.Uuid(), nullable=False),
        sa.Column("entry_type", wallet_entry_type_enum, nullable=False),
        sa.Column("amount_minor_units", sa.BigInteger(), nullable=False),
        sa.Column("balance_after_minor_units", sa.BigInteger(), nullable=False),
        sa.Column("reference_type", wallet_reference_type_enum, nullable=False),
        sa.Column("reference_id", sa.Uuid(), nullable=True),
        sa.Column("description", sa.String(255), nullable=False),
        sa.Column("idempotency_key", sa.String(64), nullable=True),
        sa.PrimaryKeyConstraint("id", name="pk_wallet_transactions"),
        sa.ForeignKeyConstraint(["wallet_id"], ["wallets.id"], name="fk_wallet_transactions_wallet_id_wallets", ondelete="RESTRICT"),
        sa.UniqueConstraint("wallet_id", "idempotency_key", name="uq_wallet_transactions_wallet_idempotency_key"),
        sa.CheckConstraint("amount_minor_units > 0", name="amount_minor_units_positive"),
        sa.CheckConstraint("balance_after_minor_units >= 0", name="balance_after_non_negative"),
    )
    op.create_index("ix_wallet_transactions_wallet_id", "wallet_transactions", ["wallet_id"])


def downgrade() -> None:
    op.drop_table("wallet_transactions")
    op.drop_table("wallets")
    op.drop_table("refund_requests")
    op.drop_table("payment_webhook_events")
    op.drop_table("payments")

    bind = op.get_bind()
    wallet_reference_type_enum.drop(bind, checkfirst=True)
    wallet_entry_type_enum.drop(bind, checkfirst=True)
    refund_status_enum.drop(bind, checkfirst=True)
    payment_status_enum.drop(bind, checkfirst=True)
    payment_channel_enum.drop(bind, checkfirst=True)
    payment_purpose_enum.drop(bind, checkfirst=True)
