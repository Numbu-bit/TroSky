"""Trips change status on their own (see ``app.services.trip_autopilot``).

* ``trip_event_type`` gains ``boarding_started``: recorded when a trip goes
  from scheduled to boarding, on its first ticket scan or when its vehicle
  reaches the first stop shortly before departure.

Revision ID: 20261008_0021
Revises: 20261003_0020
Create Date: 2026-10-08 00:00:00
"""

from __future__ import annotations

from collections.abc import Sequence

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "20261008_0021"
down_revision: str | None = "20261003_0020"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # PostgreSQL 12+ allows ADD VALUE inside the migration's transaction, as
    # long as nothing here uses the new value.
    op.execute("ALTER TYPE trip_event_type ADD VALUE IF NOT EXISTS 'boarding_started'")


def downgrade() -> None:
    # The value stays: Postgres cannot drop an enum value. Rows using it
    # must be changed first if it ever has to go.
    pass
