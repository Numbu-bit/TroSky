"""Drivers accept trips and bookings; seats free up when passengers get off.

* ``trip_driver_assignments`` gets the driver's answer (``response``):
  pending, accepted or declined, with who gave it (the driver, or an admin
  for them), when and why. Assignments made before this are taken as
  accepted.
* ``booking_status`` gains ``awaiting_acceptance``: a new booking waits for
  the driver or an admin before it can be paid for.
* ``booking_offers``: each trip a booking was put to and what came of it. A
  booking nobody answers in time is moved to another trip.
* ``booking_passengers`` records when, where and how a passenger got off;
  ``reservation_status`` gains ``completed`` for the seat they left, which
  is then free for the rest of the route.
* ``driver_actions``: what drivers did, for the operations team.

Revision ID: 20261003_0020
Revises: 20261003_0019
Create Date: 2026-10-03 00:00:00
"""

from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "20261003_0020"
down_revision: str | None = "20261003_0019"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

_RESPONSE = postgresql.ENUM("pending", "accepted", "declined", name="assignment_response")
_OFFER = postgresql.ENUM(
    "pending", "accepted", "declined", "expired", "withdrawn", name="offer_status"
)
_ALIGHTED_HOW = postgresql.ENUM("driver", "admin", "arrival", name="alighted_how")
_ACTION_KIND = postgresql.ENUM(
    "trip_accepted",
    "trip_declined",
    "trip_started",
    "trip_paused",
    "trip_resumed",
    "trip_ended",
    "booking_accepted",
    "booking_declined",
    "booking_unanswered",
    "ticket_scanned",
    "passenger_alighted",
    name="driver_action_kind",
)
_ACTED_AS = postgresql.ENUM("driver", "admin", "system", name="acted_as")


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


def _fk(table: str, column: str, target: str, ondelete: str) -> sa.ForeignKeyConstraint:
    return sa.ForeignKeyConstraint(
        [column], [f"{target}.id"], name=f"fk_{table}_{column}_{target}", ondelete=ondelete
    )


def upgrade() -> None:
    bind = op.get_bind()
    for enum in (_RESPONSE, _OFFER, _ALIGHTED_HOW, _ACTION_KIND, _ACTED_AS):
        enum.create(bind, checkfirst=True)
    # PostgreSQL 12+ allows ADD VALUE inside the migration's transaction, as
    # long as nothing here uses the new value.
    op.execute("ALTER TYPE booking_status ADD VALUE IF NOT EXISTS 'awaiting_acceptance'")
    op.execute("ALTER TYPE reservation_status ADD VALUE IF NOT EXISTS 'completed'")

    op.add_column(
        "trip_driver_assignments",
        sa.Column(
            "response",
            postgresql.ENUM(name="assignment_response", create_type=False),
            nullable=False,
            server_default="accepted",
        ),
    )
    # Existing assignments count as accepted; new ones start pending.
    op.alter_column("trip_driver_assignments", "response", server_default="pending")
    op.add_column(
        "trip_driver_assignments",
        sa.Column("responded_at", sa.TIMESTAMP(timezone=True), nullable=True),
    )
    op.add_column("trip_driver_assignments", sa.Column("responded_by", sa.Uuid(), nullable=True))
    op.add_column(
        "trip_driver_assignments", sa.Column("response_reason", sa.String(500), nullable=True)
    )
    op.create_foreign_key(
        "fk_trip_driver_assignments_responded_by_users",
        "trip_driver_assignments",
        "users",
        ["responded_by"],
        ["id"],
        ondelete="SET NULL",
    )

    op.add_column(
        "booking_passengers", sa.Column("alighted_at", sa.TIMESTAMP(timezone=True), nullable=True)
    )
    op.add_column("booking_passengers", sa.Column("alighted_stop_id", sa.Uuid(), nullable=True))
    op.add_column(
        "booking_passengers",
        sa.Column(
            "alighted_how", postgresql.ENUM(name="alighted_how", create_type=False), nullable=True
        ),
    )
    op.add_column("booking_passengers", sa.Column("alighted_by", sa.Uuid(), nullable=True))
    op.create_foreign_key(
        "fk_booking_passengers_alighted_stop_id_stops",
        "booking_passengers",
        "stops",
        ["alighted_stop_id"],
        ["id"],
        ondelete="SET NULL",
    )
    op.create_foreign_key(
        "fk_booking_passengers_alighted_by_users",
        "booking_passengers",
        "users",
        ["alighted_by"],
        ["id"],
        ondelete="SET NULL",
    )

    op.create_table(
        "booking_offers",
        *_base_columns(),
        sa.Column("booking_id", sa.Uuid(), nullable=False),
        sa.Column("trip_id", sa.Uuid(), nullable=False),
        sa.Column("driver_id", sa.Uuid(), nullable=True),
        sa.Column(
            "status", postgresql.ENUM(name="offer_status", create_type=False), nullable=False
        ),
        sa.Column("expires_at", sa.TIMESTAMP(timezone=True), nullable=False),
        sa.Column("decided_at", sa.TIMESTAMP(timezone=True), nullable=True),
        sa.Column("decided_by", sa.Uuid(), nullable=True),
        sa.Column("reason", sa.String(500), nullable=True),
        sa.PrimaryKeyConstraint("id", name="pk_booking_offers"),
        _fk("booking_offers", "booking_id", "bookings", "CASCADE"),
        _fk("booking_offers", "trip_id", "trips", "CASCADE"),
        _fk("booking_offers", "driver_id", "drivers", "SET NULL"),
        _fk("booking_offers", "decided_by", "users", "SET NULL"),
    )
    op.create_index("ix_booking_offers_booking_id", "booking_offers", ["booking_id"])
    op.create_index("ix_booking_offers_trip_id_status", "booking_offers", ["trip_id", "status"])
    op.create_index(
        "ix_booking_offers_status_expires_at", "booking_offers", ["status", "expires_at"]
    )
    op.create_index(
        "uq_booking_offers_pending_booking",
        "booking_offers",
        ["booking_id"],
        unique=True,
        postgresql_where=sa.text("status = 'pending'"),
    )

    op.create_table(
        "driver_actions",
        *_base_columns(),
        sa.Column("driver_id", sa.Uuid(), nullable=True),
        sa.Column("trip_id", sa.Uuid(), nullable=False),
        sa.Column("booking_id", sa.Uuid(), nullable=True),
        sa.Column(
            "kind", postgresql.ENUM(name="driver_action_kind", create_type=False), nullable=False
        ),
        sa.Column(
            "acted_as", postgresql.ENUM(name="acted_as", create_type=False), nullable=False
        ),
        sa.Column("actor_id", sa.Uuid(), nullable=True),
        sa.Column("reason", sa.String(500), nullable=True),
        sa.Column("details", postgresql.JSONB(), nullable=True),
        sa.PrimaryKeyConstraint("id", name="pk_driver_actions"),
        _fk("driver_actions", "driver_id", "drivers", "SET NULL"),
        _fk("driver_actions", "trip_id", "trips", "CASCADE"),
        _fk("driver_actions", "booking_id", "bookings", "CASCADE"),
        _fk("driver_actions", "actor_id", "users", "SET NULL"),
    )
    op.create_index(
        "ix_driver_actions_driver_id_created_at", "driver_actions", ["driver_id", "created_at"]
    )
    op.create_index("ix_driver_actions_trip_id", "driver_actions", ["trip_id"])
    op.create_index("ix_driver_actions_created_at", "driver_actions", ["created_at"])


def downgrade() -> None:
    op.drop_index("ix_driver_actions_created_at", table_name="driver_actions")
    op.drop_index("ix_driver_actions_trip_id", table_name="driver_actions")
    op.drop_index("ix_driver_actions_driver_id_created_at", table_name="driver_actions")
    op.drop_table("driver_actions")
    op.drop_index("uq_booking_offers_pending_booking", table_name="booking_offers")
    op.drop_index("ix_booking_offers_status_expires_at", table_name="booking_offers")
    op.drop_index("ix_booking_offers_trip_id_status", table_name="booking_offers")
    op.drop_index("ix_booking_offers_booking_id", table_name="booking_offers")
    op.drop_table("booking_offers")
    op.drop_constraint(
        "fk_booking_passengers_alighted_by_users", "booking_passengers", type_="foreignkey"
    )
    op.drop_constraint(
        "fk_booking_passengers_alighted_stop_id_stops", "booking_passengers", type_="foreignkey"
    )
    for column in ("alighted_by", "alighted_how", "alighted_stop_id", "alighted_at"):
        op.drop_column("booking_passengers", column)
    op.drop_constraint(
        "fk_trip_driver_assignments_responded_by_users",
        "trip_driver_assignments",
        type_="foreignkey",
    )
    for column in ("response_reason", "responded_by", "responded_at", "response"):
        op.drop_column("trip_driver_assignments", column)
    # The values added to booking_status and reservation_status stay: Postgres
    # cannot drop an enum value. Rows using them must be changed first.
    bind = op.get_bind()
    for enum in (_ACTED_AS, _ACTION_KIND, _ALIGHTED_HOW, _OFFER, _RESPONSE):
        enum.drop(bind, checkfirst=True)
