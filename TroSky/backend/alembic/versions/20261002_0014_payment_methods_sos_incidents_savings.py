"""Saved payment methods, SOS outside a trip, incident photos and types, and
what each booking saved.

For the second round of frontend requests:

* ``payment_methods`` (G28) -- mobile money numbers a user saved, one of
  them the default.
* ``sos_alerts.trip_id`` becomes nullable (G19): the Home screen's SOS
  button works with no trip.
* ``incident_type`` gains ``passenger_issue`` and ``road_hazard``, and
  ``incidents.photo_storage_key`` holds one photo (G32).
* ``bookings.solo_fare_amount`` (G25): the unshared price at booking time,
  so trip history can say how much sharing saved.

Additive apart from the nullable ``trip_id``; existing rows need no
backfill (a NULL ``solo_fare_amount`` reads as "no saving").

Revision ID: 20261002_0014
Revises: 20260930_0013
Create Date: 2026-10-02 00:00:00
"""

from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "20261002_0014"
down_revision: str | None = "20260930_0013"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

_NEW_INCIDENT_TYPES = ("passenger_issue", "road_hazard")
_OLD_INCIDENT_TYPES = ("accident", "breakdown", "delay", "safety_concern", "other")


def upgrade() -> None:
    op.create_table(
        "payment_methods",
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
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column(
            "channel",
            postgresql.ENUM(name="payment_channel", create_type=False),
            nullable=False,
        ),
        sa.Column("phone_number", sa.String(20), nullable=False),
        sa.Column("label", sa.String(60), nullable=True),
        sa.Column("is_default", sa.Boolean(), server_default=sa.text("false"), nullable=False),
        sa.PrimaryKeyConstraint("id", name="pk_payment_methods"),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name="fk_payment_methods_user_id_users",
            ondelete="CASCADE",
        ),
        # Also serves "this user's methods" lookups, via its leading column.
        sa.UniqueConstraint(
            "user_id", "channel", "phone_number", name="uq_payment_methods_user_number"
        ),
    )
    op.create_index(
        "uq_payment_methods_one_default",
        "payment_methods",
        ["user_id"],
        unique=True,
        postgresql_where=sa.text("is_default"),
    )

    op.alter_column("sos_alerts", "trip_id", existing_type=sa.Uuid(), nullable=True)

    # PostgreSQL 12+ allows ADD VALUE inside the migration's transaction, as
    # long as nothing in that same transaction uses the new value.
    for value in _NEW_INCIDENT_TYPES:
        op.execute(f"ALTER TYPE incident_type ADD VALUE IF NOT EXISTS '{value}'")
    op.add_column("incidents", sa.Column("photo_storage_key", sa.String(500), nullable=True))

    op.add_column("bookings", sa.Column("solo_fare_amount", sa.Numeric(12, 2), nullable=True))
    op.create_check_constraint(
        "solo_fare_amount_non_negative", "bookings", "solo_fare_amount >= 0"
    )


def downgrade() -> None:
    op.drop_constraint("solo_fare_amount_non_negative", "bookings", type_="check")
    op.drop_column("bookings", "solo_fare_amount")

    op.drop_column("incidents", "photo_storage_key")
    # PostgreSQL cannot drop an enum value, so the type is rebuilt without
    # them; incidents filed under a new type become "other".
    new_types = ", ".join(f"'{value}'" for value in _NEW_INCIDENT_TYPES)
    op.execute(f"UPDATE incidents SET incident_type = 'other' WHERE incident_type IN ({new_types})")
    op.execute("ALTER TYPE incident_type RENAME TO incident_type_old")
    old_types = ", ".join(f"'{value}'" for value in _OLD_INCIDENT_TYPES)
    op.execute(f"CREATE TYPE incident_type AS ENUM ({old_types})")
    op.execute(
        "ALTER TABLE incidents ALTER COLUMN incident_type TYPE incident_type "
        "USING incident_type::text::incident_type"
    )
    op.execute("DROP TYPE incident_type_old")

    # Alerts raised outside a trip have nothing to hang off once trip_id is
    # required again.
    op.execute("DELETE FROM sos_alerts WHERE trip_id IS NULL")
    op.alter_column("sos_alerts", "trip_id", existing_type=sa.Uuid(), nullable=False)

    op.drop_index("uq_payment_methods_one_default", table_name="payment_methods")
    op.drop_table("payment_methods")
