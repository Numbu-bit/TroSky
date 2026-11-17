"""Driver.phone_number + Driver.verification_status (Step 17 gap-fill).

* ``drivers.phone_number``: optional E.164 string (nullable so the back-fill
  path is a Driver KYC update, not a mandatory migration). Passenger-visible
  only when the caller has a confirmed booking on that driver's trip
  (enforced in the schema builder, not the column).
* ``drivers.verification_status``: NOT NULL, default ``unverified``.
  Separate from the existing ``drivers.status`` (``ApprovalStatus``, the
  driver-onboarding/admin-approval lifecycle). This one is the simple
  passenger-facing surface the Ticket / Trip-details screens render.

Rollback: ``downgrade()`` drops the two columns and the new enum type.
Both columns are additive (no data loss) and have no outbound FKs, so a
downgrade is safe against any released version that doesn't read them.

Revision ID: 20261116_0023
Revises: 20261013_0022
Create Date: 2026-11-16 23:30:00
"""

from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "20261116_0023"
down_revision: str | None = "20261013_0022"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


_VERIFICATION_VALUES = ("unverified", "pending", "verified", "rejected")


def upgrade() -> None:
    verification_status = sa.Enum(
        *_VERIFICATION_VALUES, name="verification_status", native_enum=True
    )
    verification_status.create(op.get_bind(), checkfirst=True)

    op.add_column(
        "drivers",
        sa.Column("phone_number", sa.String(length=32), nullable=True),
    )
    op.create_check_constraint(
        "phone_number_e164",
        "drivers",
        r"phone_number IS NULL OR phone_number ~ '^\+[1-9][0-9]{7,14}$'",
    )
    op.add_column(
        "drivers",
        sa.Column(
            "verification_status",
            verification_status,
            nullable=False,
            server_default="unverified",
        ),
    )
    # Index for passenger-visibility lookups by driver (future-proofing
    # the admin dashboard; also required for the `p95 < 150 ms` bar).
    op.create_index("ix_drivers_verification_status", "drivers", ["verification_status"])


def downgrade() -> None:
    op.drop_index("ix_drivers_verification_status", table_name="drivers")
    op.drop_column("drivers", "verification_status")
    op.drop_constraint("phone_number_e164", "drivers", type_="check")
    op.drop_column("drivers", "phone_number")
    sa.Enum(*_VERIFICATION_VALUES, name="verification_status").drop(op.get_bind(), checkfirst=True)
