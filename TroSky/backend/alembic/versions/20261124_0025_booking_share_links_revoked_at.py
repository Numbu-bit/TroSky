"""bookings.share_links_revoked_at: the passenger stopped sharing their trip.

Live-trip links are signed tokens, not rows, so stopping them is a moment on
the booking: every link issued before it answers 410. Nullable, no default,
no backfill: no booking has stopped sharing yet.

Rollback: ``downgrade()`` drops the column; links already stopped would
open again until they expire.

Revision ID: 20261124_0025
Revises: 20261123_0024
Create Date: 2026-11-24 09:00:00
"""

from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "20261124_0025"
down_revision: str | None = "20261123_0024"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "bookings",
        sa.Column("share_links_revoked_at", sa.TIMESTAMP(timezone=True), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("bookings", "share_links_revoked_at")
