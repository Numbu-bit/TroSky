"""A deleted account's phone number and email are free for a new sign-up.

* ``uq_users_phone_number`` and ``uq_users_email`` become unique indexes on
  accounts that are not deleted (``deleted_at IS NULL``). A deleted account
  keeps its row and its history; only the number and email stop being
  taken. The names stay, so a clash is reported as before
  (``UserRepository.create``).

Revision ID: 20261013_0022
Revises: 20261008_0021
Create Date: 2026-10-13 00:00:00
"""

from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "20261013_0022"
down_revision: str | None = "20261008_0021"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

_NOT_DELETED = sa.text("deleted_at IS NULL")


def upgrade() -> None:
    for name, column in (("uq_users_phone_number", "phone_number"), ("uq_users_email", "email")):
        op.drop_constraint(name, "users", type_="unique")
        op.create_index(name, "users", [column], unique=True, postgresql_where=_NOT_DELETED)


def downgrade() -> None:
    # Fails while a deleted account and a newer one share a number or an
    # email: which of them gives it up is for a person to decide.
    for name, column in (("uq_users_phone_number", "phone_number"), ("uq_users_email", "email")):
        op.drop_index(name, table_name="users")
        op.create_unique_constraint(name, "users", [column])
