"""Favourite routes, uploaded avatars, and rating categories.

Three additions the mobile app needs (frontend requests G4, G5, G13):

* ``favourite_routes`` -- journeys a user pins to the Home screen, as a
  boarding and an alighting stop.
* ``user_profiles.avatar_storage_key`` -- where an uploaded profile photo
  sits in the private bucket. The API hands out a short-lived signed URL
  for it; ``avatar_url`` stays for a photo hosted elsewhere.
* ``ratings.safety`` / ``cleanliness`` / ``professionalism`` /
  ``timeliness`` -- optional 1-5 scores alongside the overall ``score``.

Everything is additive: no existing row changes, and every new column is
nullable, so no backfill is needed.

Revision ID: 20260930_0013
Revises: 20260921_0012
Create Date: 2026-09-30 00:00:00
"""

from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "20260930_0013"
down_revision: str | None = "20260921_0012"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

_RATING_CATEGORIES = ("safety", "cleanliness", "professionalism", "timeliness")


def upgrade() -> None:
    op.create_table(
        "favourite_routes",
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
        sa.Column("origin_stop_id", sa.Uuid(), nullable=False),
        sa.Column("destination_stop_id", sa.Uuid(), nullable=False),
        sa.Column("label", sa.String(60), nullable=True),
        sa.PrimaryKeyConstraint("id", name="pk_favourite_routes"),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name="fk_favourite_routes_user_id_users",
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["origin_stop_id"],
            ["stops.id"],
            name="fk_favourite_routes_origin_stop_id_stops",
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["destination_stop_id"],
            ["stops.id"],
            name="fk_favourite_routes_destination_stop_id_stops",
            ondelete="RESTRICT",
        ),
        # Also serves "this user's favourites" lookups, via its leading column.
        sa.UniqueConstraint(
            "user_id",
            "origin_stop_id",
            "destination_stop_id",
            name="uq_favourite_routes_user_journey",
        ),
        sa.CheckConstraint("origin_stop_id <> destination_stop_id", name="distinct_stops"),
    )

    op.add_column(
        "user_profiles", sa.Column("avatar_storage_key", sa.String(500), nullable=True)
    )

    for category in _RATING_CATEGORIES:
        op.add_column("ratings", sa.Column(category, sa.SmallInteger(), nullable=True))
        op.create_check_constraint(
            f"{category}_between_1_and_5", "ratings", f"{category} >= 1 AND {category} <= 5"
        )


def downgrade() -> None:
    for category in reversed(_RATING_CATEGORIES):
        op.drop_constraint(f"{category}_between_1_and_5", "ratings", type_="check")
        op.drop_column("ratings", category)

    op.drop_column("user_profiles", "avatar_storage_key")

    op.drop_table("favourite_routes")
