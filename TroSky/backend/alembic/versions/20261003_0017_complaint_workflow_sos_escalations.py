"""Complaint workflow and SOS escalations.

The admin dashboard's step 4:

* ``complaints`` gains ``priority`` (each has its own resolution time),
  ``assigned_to`` / ``assigned_at``, and ``first_response_at``.
* ``complaint_notes``: the support team's internal notes and its messages
  to the passenger.
* ``sos_escalations``: who the operations team contacted about an SOS
  alert (police, ambulance, the fleet owner...) and when.

Existing complaints get a priority from their category (safety ones are
high), and the ones already decided count their decision as the first
response.

Revision ID: 20261003_0017
Revises: 20261003_0016
Create Date: 2026-10-03 00:00:00
"""

from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "20261003_0017"
down_revision: str | None = "20261003_0016"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

_PRIORITY = postgresql.ENUM("low", "medium", "high", "urgent", name="complaint_priority")
_NOTE_KIND = postgresql.ENUM("internal", "message", name="complaint_note_kind")
_CONTACT_TYPE = postgresql.ENUM(
    "police",
    "ambulance",
    "fire_service",
    "fleet_owner",
    "emergency_contact",
    "other",
    name="escalation_contact_type",
)


def _timestamps() -> list[sa.Column[object]]:
    return [
        sa.Column("id", sa.Uuid(), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column(
            "created_at",
            sa.TIMESTAMP(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.TIMESTAMP(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
    ]


def upgrade() -> None:
    bind = op.get_bind()
    _PRIORITY.create(bind, checkfirst=True)
    _NOTE_KIND.create(bind, checkfirst=True)
    _CONTACT_TYPE.create(bind, checkfirst=True)

    op.add_column(
        "complaints",
        sa.Column(
            "priority",
            postgresql.ENUM(name="complaint_priority", create_type=False),
            server_default="medium",
            nullable=False,
        ),
    )
    op.add_column("complaints", sa.Column("assigned_to", sa.Uuid(), nullable=True))
    op.add_column(
        "complaints", sa.Column("assigned_at", sa.TIMESTAMP(timezone=True), nullable=True)
    )
    op.add_column(
        "complaints", sa.Column("first_response_at", sa.TIMESTAMP(timezone=True), nullable=True)
    )
    op.create_foreign_key(
        "fk_complaints_assigned_to_users",
        "complaints",
        "users",
        ["assigned_to"],
        ["id"],
        ondelete="SET NULL",
    )
    op.create_index("ix_complaints_assigned_to", "complaints", ["assigned_to"])
    op.create_index("ix_complaints_created_at", "complaints", ["created_at"])
    op.execute("UPDATE complaints SET priority = 'high' WHERE category = 'safety'")
    op.execute(
        "UPDATE complaints SET first_response_at = resolved_at WHERE resolved_at IS NOT NULL"
    )

    op.create_table(
        "complaint_notes",
        *_timestamps(),
        sa.Column("complaint_id", sa.Uuid(), nullable=False),
        sa.Column("author_id", sa.Uuid(), nullable=True),
        sa.Column(
            "kind", postgresql.ENUM(name="complaint_note_kind", create_type=False), nullable=False
        ),
        sa.Column("body", sa.String(2000), nullable=False),
        sa.PrimaryKeyConstraint("id", name="pk_complaint_notes"),
        sa.ForeignKeyConstraint(
            ["complaint_id"],
            ["complaints.id"],
            name="fk_complaint_notes_complaint_id_complaints",
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["author_id"],
            ["users.id"],
            name="fk_complaint_notes_author_id_users",
            ondelete="SET NULL",
        ),
    )
    op.create_index(
        "ix_complaint_notes_complaint_id", "complaint_notes", ["complaint_id", "created_at"]
    )

    op.create_table(
        "sos_escalations",
        *_timestamps(),
        sa.Column("sos_alert_id", sa.Uuid(), nullable=False),
        sa.Column(
            "contact_type",
            postgresql.ENUM(name="escalation_contact_type", create_type=False),
            nullable=False,
        ),
        sa.Column("contact_name", sa.String(100), nullable=True),
        sa.Column("phone_number", sa.String(20), nullable=True),
        sa.Column("contacted_at", sa.TIMESTAMP(timezone=True), nullable=False),
        sa.Column("notes", sa.String(1000), nullable=True),
        sa.Column("logged_by", sa.Uuid(), nullable=True),
        sa.PrimaryKeyConstraint("id", name="pk_sos_escalations"),
        sa.ForeignKeyConstraint(
            ["sos_alert_id"],
            ["sos_alerts.id"],
            name="fk_sos_escalations_sos_alert_id_sos_alerts",
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["logged_by"],
            ["users.id"],
            name="fk_sos_escalations_logged_by_users",
            ondelete="SET NULL",
        ),
    )
    op.create_index(
        "ix_sos_escalations_sos_alert_id", "sos_escalations", ["sos_alert_id", "contacted_at"]
    )


def downgrade() -> None:
    op.drop_index("ix_sos_escalations_sos_alert_id", table_name="sos_escalations")
    op.drop_table("sos_escalations")
    op.drop_index("ix_complaint_notes_complaint_id", table_name="complaint_notes")
    op.drop_table("complaint_notes")
    op.drop_index("ix_complaints_created_at", table_name="complaints")
    op.drop_index("ix_complaints_assigned_to", table_name="complaints")
    op.drop_constraint("fk_complaints_assigned_to_users", "complaints", type_="foreignkey")
    op.drop_column("complaints", "first_response_at")
    op.drop_column("complaints", "assigned_at")
    op.drop_column("complaints", "assigned_to")
    op.drop_column("complaints", "priority")
    bind = op.get_bind()
    _CONTACT_TYPE.drop(bind, checkfirst=True)
    _NOTE_KIND.drop(bind, checkfirst=True)
    _PRIORITY.drop(bind, checkfirst=True)
