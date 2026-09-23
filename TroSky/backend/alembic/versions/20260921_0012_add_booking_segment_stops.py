"""Record which part of the route a booking actually rides.

Distance-based fares (``app.services.fare_service``) price the segment a
passenger travels rather than the whole route, and sharing divides a
segment's cost between the passengers aboard for it. Both need to know
where each booking boards and alights, which nothing recorded before —
every booking was implicitly end to end.

Both columns are nullable: NULL means "the whole route", which is exactly
what existing bookings were, so no backfill can misstate history.

Revision ID: 20260921_0012
Revises: 20260921_0011
Create Date: 2026-09-21 00:00:00
"""

from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "20260921_0012"
down_revision: str | None = "20260921_0011"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column("bookings", sa.Column("origin_stop_id", sa.Uuid(), nullable=True))
    op.add_column("bookings", sa.Column("destination_stop_id", sa.Uuid(), nullable=True))
    op.create_foreign_key(
        "fk_bookings_origin_stop_id_stops",
        "bookings",
        "stops",
        ["origin_stop_id"],
        ["id"],
        ondelete="RESTRICT",
    )
    op.create_foreign_key(
        "fk_bookings_destination_stop_id_stops",
        "bookings",
        "stops",
        ["destination_stop_id"],
        ["id"],
        ondelete="RESTRICT",
    )
    # Occupancy is counted per trip and segment on every quote, so the
    # lookup is on the hot path for booking creation.
    op.create_index(
        "ix_bookings_trip_segment",
        "bookings",
        ["trip_id", "origin_stop_id", "destination_stop_id"],
    )


def downgrade() -> None:
    op.drop_index("ix_bookings_trip_segment", table_name="bookings")
    op.drop_constraint("fk_bookings_destination_stop_id_stops", "bookings", type_="foreignkey")
    op.drop_constraint("fk_bookings_origin_stop_id_stops", "bookings", type_="foreignkey")
    op.drop_column("bookings", "destination_stop_id")
    op.drop_column("bookings", "origin_stop_id")
