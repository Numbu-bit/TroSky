"""Permissions granted to one person.

``user_permissions``: how a member of the admin team with the new ``staff``
role gets exactly the access their job needs. The role itself, and the new
``admins:manage`` permission, are reference data (``seed_reference_data``).
Additive only.

Revision ID: 20261003_0019
Revises: 20261003_0018
Create Date: 2026-10-03 00:00:00
"""

from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "20261003_0019"
down_revision: str | None = "20261003_0018"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "user_permissions",
        sa.Column("id", sa.Uuid(), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column(
            "created_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False
        ),
        sa.Column(
            "updated_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False
        ),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("permission_id", sa.Uuid(), nullable=False),
        sa.Column("granted_by", sa.Uuid(), nullable=True),
        sa.PrimaryKeyConstraint("id", name="pk_user_permissions"),
        sa.UniqueConstraint(
            "user_id", "permission_id", name="uq_user_permissions_user_permission"
        ),
        sa.ForeignKeyConstraint(
            ["user_id"], ["users.id"], name="fk_user_permissions_user_id_users", ondelete="CASCADE"
        ),
        sa.ForeignKeyConstraint(
            ["permission_id"],
            ["permissions.id"],
            name="fk_user_permissions_permission_id_permissions",
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["granted_by"],
            ["users.id"],
            name="fk_user_permissions_granted_by_users",
            ondelete="SET NULL",
        ),
    )


def downgrade() -> None:
    op.drop_table("user_permissions")
