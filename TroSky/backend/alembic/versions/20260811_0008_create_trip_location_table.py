"""Create trip_locations table.

Revision ID: 20260811_0008
Revises: 20260811_0007
Create Date: 2026-08-11 00:00:00
"""

from __future__ import annotations

from collections.abc import Sequence

import geoalchemy2
import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "20260811_0008"
down_revision: str | None = "20260811_0007"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "trip_locations",
        sa.Column("id", sa.Uuid(), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("trip_id", sa.Uuid(), nullable=False),
        sa.Column(
            "location",
            geoalchemy2.types.Geography(geometry_type="POINT", srid=4326, spatial_index=False),
            nullable=False,
        ),
        sa.Column("speed_kmh", sa.Numeric(6, 2), nullable=True),
        sa.Column("heading_degrees", sa.Numeric(5, 2), nullable=True),
        sa.Column("accuracy_meters", sa.Numeric(8, 2), nullable=True),
        sa.Column("recorded_at", sa.TIMESTAMP(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint("id", name="pk_trip_locations"),
        sa.ForeignKeyConstraint(["trip_id"], ["trips.id"], name="fk_trip_locations_trip_id_trips", ondelete="CASCADE"),
        sa.CheckConstraint("speed_kmh IS NULL OR speed_kmh >= 0", name="speed_kmh_non_negative"),
    )
    op.create_index("ix_trip_locations_location", "trip_locations", ["location"], postgresql_using="gist")
    op.create_index(
        "ix_trip_locations_trip_id_recorded_at", "trip_locations", ["trip_id", "recorded_at"]
    )


def downgrade() -> None:
    op.drop_table("trip_locations")
