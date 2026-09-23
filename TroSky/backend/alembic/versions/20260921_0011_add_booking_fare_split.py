"""Split a booking's money into the operator's fare and TroSky's platform fee.

``bookings.total_amount`` previously held a single figure, so the platform's
per-booking revenue (business plan section 4A) had nowhere to live. This adds
``fare_amount`` (the operator's share) and ``platform_fee`` (TroSky's),
leaving ``total_amount`` as what the passenger pays.

Existing rows are backfilled with fare_amount = total_amount and a zero fee:
those bookings were taken before the fee existed, so attributing revenue to
them retrospectively would overstate historical earnings.

Revision ID: 20260921_0011
Revises: 20260811_0010
Create Date: 2026-09-21 00:00:00
"""

from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "20260921_0011"
down_revision: str | None = "20260811_0010"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "bookings",
        sa.Column("fare_amount", sa.Numeric(12, 2), nullable=False, server_default="0"),
    )
    op.add_column(
        "bookings",
        sa.Column("platform_fee", sa.Numeric(12, 2), nullable=False, server_default="0"),
    )
    op.execute("UPDATE bookings SET fare_amount = total_amount WHERE fare_amount = 0")
    op.create_check_constraint("fare_amount_non_negative", "bookings", "fare_amount >= 0")
    op.create_check_constraint("platform_fee_non_negative", "bookings", "platform_fee >= 0")


def downgrade() -> None:
    op.drop_constraint("platform_fee_non_negative", "bookings", type_="check")
    op.drop_constraint("fare_amount_non_negative", "bookings", type_="check")
    op.drop_column("bookings", "platform_fee")
    op.drop_column("bookings", "fare_amount")
