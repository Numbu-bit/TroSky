"""Passenger accounts and work accounts are separate.

An account is either a passenger's (books and rides) or a work account (a
driver, a fleet owner, or both); see ``app.services.role_service``. Until now
a driver or fleet owner usually kept the passenger role their account was
created with. This takes it away: their bookings so far stay as they are,
and to book again they sign up for a passenger account with a different
phone number and email.

Revision ID: 20261020_0023
Revises: 20261013_0022
Create Date: 2026-10-20 00:00:00
"""

from __future__ import annotations

from collections.abc import Sequence

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "20261020_0023"
down_revision: str | None = "20261013_0022"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.execute(
        """
        DELETE FROM user_roles AS held
        USING roles AS passenger
        WHERE held.role_id = passenger.id
          AND passenger.slug = 'passenger'
          AND EXISTS (
              SELECT 1
              FROM user_roles AS other
              JOIN roles AS work ON work.id = other.role_id
              WHERE other.user_id = held.user_id
                AND work.slug IN ('driver', 'fleet_owner')
          )
        """
    )


def downgrade() -> None:
    # Which accounts had the passenger role is not kept, so it cannot be
    # given back exactly. Nothing to undo in the schema.
    pass
