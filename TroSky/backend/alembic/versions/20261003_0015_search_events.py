"""Search events, for the conversion funnel and demand heat maps.

One row per trip search: when, for which day, between which stops, roughly
where from (a ~550 m grid cell, never the exact position), and how many
trips it found and could book. Additive only.

Revision ID: 20261003_0015
Revises: 20261002_0014
Create Date: 2026-10-03 00:00:00
"""

from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "20261003_0015"
down_revision: str | None = "20261002_0014"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "search_events",
        sa.Column("id", sa.Uuid(), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column(
            "searched_at",
            sa.TIMESTAMP(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column("travel_date", sa.Date(), nullable=False),
        sa.Column("origin_stop_id", sa.Uuid(), nullable=True),
        sa.Column("destination_stop_id", sa.Uuid(), nullable=True),
        sa.Column("cell_latitude", sa.Numeric(8, 3), nullable=True),
        sa.Column("cell_longitude", sa.Numeric(8, 3), nullable=True),
        sa.Column("results_count", sa.Integer(), nullable=False),
        sa.Column("bookable_count", sa.Integer(), nullable=False),
        sa.Column("outcome", sa.String(40), nullable=False),
        sa.PrimaryKeyConstraint("id", name="pk_search_events"),
        sa.ForeignKeyConstraint(
            ["origin_stop_id"],
            ["stops.id"],
            name="fk_search_events_origin_stop_id_stops",
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["destination_stop_id"],
            ["stops.id"],
            name="fk_search_events_destination_stop_id_stops",
            ondelete="SET NULL",
        ),
    )
    op.create_index("ix_search_events_searched_at", "search_events", ["searched_at"])


def downgrade() -> None:
    op.drop_index("ix_search_events_searched_at", table_name="search_events")
    op.drop_table("search_events")
