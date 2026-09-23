"""Enable required PostgreSQL extensions (pgcrypto, postgis, citext).

Revision ID: 20260804_0001
Revises:
Create Date: 2026-08-04 00:00:00
"""

from __future__ import annotations

from collections.abc import Sequence

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "20260804_0001"
down_revision: str | None = None
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # pgcrypto: gen_random_uuid() for UUID primary key defaults.
    op.execute("CREATE EXTENSION IF NOT EXISTS pgcrypto")
    # postgis: geography/geometry types for stops, routes, and GPS positions.
    op.execute("CREATE EXTENSION IF NOT EXISTS postgis")
    # citext: case-insensitive text, used for normalized email storage.
    op.execute("CREATE EXTENSION IF NOT EXISTS citext")


def downgrade() -> None:
    op.execute("DROP EXTENSION IF EXISTS citext")
    op.execute("DROP EXTENSION IF EXISTS postgis")
    op.execute("DROP EXTENSION IF EXISTS pgcrypto")
