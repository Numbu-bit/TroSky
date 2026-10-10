"""Fraud detection.

The admin dashboard's step 6:

* ``fraud_rules``: admins' changes to the rules' thresholds, time windows,
  severities and on/off switches (rules without a row run on defaults).
* ``fraud_flags`` and ``fraud_flag_events``: what the rules found, and each
  finding's timeline.
* ``blocked_devices``: phones no one may sign in from.
* ``ticket_scan_attempts``: tickets refused at boarding because they had
  been used already or were for another trip.
* ``wallets.frozen_at`` / ``frozen_reason`` / ``frozen_by``: a wallet frozen
  while fraud is looked into.

Additive only.

Revision ID: 20261003_0018
Revises: 20261003_0017
Create Date: 2026-10-03 00:00:00
"""

from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "20261003_0018"
down_revision: str | None = "20261003_0017"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

_SEVERITY = postgresql.ENUM("low", "medium", "high", "critical", name="fraud_severity")
_STATUS = postgresql.ENUM(
    "open", "investigating", "confirmed", "false_positive", name="fraud_flag_status"
)
_SCAN_OUTCOME = postgresql.ENUM("already_used", "wrong_trip", name="ticket_scan_outcome")


def _base_columns() -> list[sa.Column[object]]:
    return [
        sa.Column("id", sa.Uuid(), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column(
            "created_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False
        ),
        sa.Column(
            "updated_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False
        ),
    ]


def _user_fk(table: str, column: str) -> sa.ForeignKeyConstraint:
    return sa.ForeignKeyConstraint(
        [column], ["users.id"], name=f"fk_{table}_{column}_users", ondelete="SET NULL"
    )


def upgrade() -> None:
    bind = op.get_bind()
    _SEVERITY.create(bind, checkfirst=True)
    _STATUS.create(bind, checkfirst=True)
    _SCAN_OUTCOME.create(bind, checkfirst=True)

    op.create_table(
        "fraud_rules",
        sa.Column("key", sa.String(60), primary_key=True),
        sa.Column("enabled", sa.Boolean(), nullable=False),
        sa.Column("threshold", sa.Numeric(14, 4), nullable=False),
        sa.Column("window_minutes", sa.Integer(), nullable=False),
        sa.Column(
            "severity", postgresql.ENUM(name="fraud_severity", create_type=False), nullable=False
        ),
        sa.Column("updated_by", sa.Uuid(), nullable=True),
        sa.Column(
            "updated_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False
        ),
        sa.PrimaryKeyConstraint("key", name="pk_fraud_rules"),
        sa.CheckConstraint("threshold >= 0", name="threshold_non_negative"),
        sa.CheckConstraint("window_minutes > 0", name="window_minutes_positive"),
        _user_fk("fraud_rules", "updated_by"),
    )

    op.create_table(
        "fraud_flags",
        *_base_columns(),
        sa.Column("rule", sa.String(60), nullable=False),
        sa.Column("fingerprint", sa.String(200), nullable=False),
        sa.Column(
            "severity", postgresql.ENUM(name="fraud_severity", create_type=False), nullable=False
        ),
        sa.Column("risk_score", sa.Integer(), nullable=False),
        sa.Column("entity_type", sa.String(30), nullable=False),
        sa.Column("entity_id", sa.String(100), nullable=False),
        sa.Column("subject_user_id", sa.Uuid(), nullable=True),
        sa.Column("summary", sa.String(500), nullable=False),
        sa.Column("amount_at_risk", sa.Numeric(12, 2), nullable=True),
        sa.Column("observed", sa.Numeric(14, 4), nullable=False),
        sa.Column("evidence", postgresql.JSONB(), nullable=False),
        sa.Column(
            "status", postgresql.ENUM(name="fraud_flag_status", create_type=False), nullable=False
        ),
        sa.Column("assigned_to", sa.Uuid(), nullable=True),
        sa.Column("reviewed_by", sa.Uuid(), nullable=True),
        sa.Column("reviewed_at", sa.TIMESTAMP(timezone=True), nullable=True),
        sa.Column("review_reason", sa.String(1000), nullable=True),
        sa.Column("first_detected_at", sa.TIMESTAMP(timezone=True), nullable=False),
        sa.Column("last_detected_at", sa.TIMESTAMP(timezone=True), nullable=False),
        sa.Column("occurrences", sa.Integer(), nullable=False),
        sa.PrimaryKeyConstraint("id", name="pk_fraud_flags"),
        sa.UniqueConstraint("fingerprint", name="uq_fraud_flags_fingerprint"),
        sa.CheckConstraint("risk_score BETWEEN 0 AND 100", name="risk_score_range"),
        _user_fk("fraud_flags", "subject_user_id"),
        _user_fk("fraud_flags", "assigned_to"),
        _user_fk("fraud_flags", "reviewed_by"),
    )
    op.create_index("ix_fraud_flags_status", "fraud_flags", ["status"])
    op.create_index("ix_fraud_flags_rule", "fraud_flags", ["rule"])
    op.create_index("ix_fraud_flags_subject_user_id", "fraud_flags", ["subject_user_id"])
    op.create_index("ix_fraud_flags_first_detected_at", "fraud_flags", ["first_detected_at"])

    op.create_table(
        "fraud_flag_events",
        *_base_columns(),
        sa.Column("flag_id", sa.Uuid(), nullable=False),
        sa.Column("kind", sa.String(30), nullable=False),
        sa.Column("actor_id", sa.Uuid(), nullable=True),
        sa.Column("details", postgresql.JSONB(), nullable=False),
        sa.PrimaryKeyConstraint("id", name="pk_fraud_flag_events"),
        sa.ForeignKeyConstraint(
            ["flag_id"],
            ["fraud_flags.id"],
            name="fk_fraud_flag_events_flag_id_fraud_flags",
            ondelete="CASCADE",
        ),
        _user_fk("fraud_flag_events", "actor_id"),
    )
    op.create_index(
        "ix_fraud_flag_events_flag_id", "fraud_flag_events", ["flag_id", "created_at"]
    )

    op.create_table(
        "blocked_devices",
        *_base_columns(),
        sa.Column("device_id", sa.String(255), nullable=False),
        sa.Column("reason", sa.String(500), nullable=False),
        sa.Column("blocked_by", sa.Uuid(), nullable=True),
        sa.Column("flag_id", sa.Uuid(), nullable=True),
        sa.PrimaryKeyConstraint("id", name="pk_blocked_devices"),
        sa.UniqueConstraint("device_id", name="uq_blocked_devices_device_id"),
        _user_fk("blocked_devices", "blocked_by"),
        sa.ForeignKeyConstraint(
            ["flag_id"],
            ["fraud_flags.id"],
            name="fk_blocked_devices_flag_id_fraud_flags",
            ondelete="SET NULL",
        ),
    )

    op.create_table(
        "ticket_scan_attempts",
        *_base_columns(),
        sa.Column("ticket_id", sa.Uuid(), nullable=False),
        sa.Column("trip_id", sa.Uuid(), nullable=False),
        sa.Column("scanned_by", sa.Uuid(), nullable=True),
        sa.Column(
            "outcome",
            postgresql.ENUM(name="ticket_scan_outcome", create_type=False),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("id", name="pk_ticket_scan_attempts"),
        sa.ForeignKeyConstraint(
            ["ticket_id"],
            ["tickets.id"],
            name="fk_ticket_scan_attempts_ticket_id_tickets",
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["trip_id"],
            ["trips.id"],
            name="fk_ticket_scan_attempts_trip_id_trips",
            ondelete="CASCADE",
        ),
        _user_fk("ticket_scan_attempts", "scanned_by"),
    )
    op.create_index(
        "ix_ticket_scan_attempts_ticket_id", "ticket_scan_attempts", ["ticket_id", "created_at"]
    )

    op.add_column("wallets", sa.Column("frozen_at", sa.TIMESTAMP(timezone=True), nullable=True))
    op.add_column("wallets", sa.Column("frozen_reason", sa.String(500), nullable=True))
    op.add_column("wallets", sa.Column("frozen_by", sa.Uuid(), nullable=True))
    op.create_foreign_key(
        "fk_wallets_frozen_by_users",
        "wallets",
        "users",
        ["frozen_by"],
        ["id"],
        ondelete="SET NULL",
    )


def downgrade() -> None:
    op.drop_constraint("fk_wallets_frozen_by_users", "wallets", type_="foreignkey")
    op.drop_column("wallets", "frozen_by")
    op.drop_column("wallets", "frozen_reason")
    op.drop_column("wallets", "frozen_at")
    op.drop_index("ix_ticket_scan_attempts_ticket_id", table_name="ticket_scan_attempts")
    op.drop_table("ticket_scan_attempts")
    op.drop_table("blocked_devices")
    op.drop_index("ix_fraud_flag_events_flag_id", table_name="fraud_flag_events")
    op.drop_table("fraud_flag_events")
    op.drop_index("ix_fraud_flags_first_detected_at", table_name="fraud_flags")
    op.drop_index("ix_fraud_flags_subject_user_id", table_name="fraud_flags")
    op.drop_index("ix_fraud_flags_rule", table_name="fraud_flags")
    op.drop_index("ix_fraud_flags_status", table_name="fraud_flags")
    op.drop_table("fraud_flags")
    op.drop_table("fraud_rules")
    bind = op.get_bind()
    _SCAN_OUTCOME.drop(bind, checkfirst=True)
    _STATUS.drop(bind, checkfirst=True)
    _SEVERITY.drop(bind, checkfirst=True)
