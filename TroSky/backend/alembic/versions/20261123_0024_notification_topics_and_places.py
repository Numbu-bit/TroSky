"""Notification topics, topic switches, favourite places, email change codes.

* ``notifications.topic`` (new enum ``notification_topic``): what each
  notification is about. Existing rows are filled from what they say:
  safety and promotional ones keep that meaning; insurance, document and
  support messages become ``account``; the rest ``booking_updates``.
* ``notification_preferences.booking_updates_enabled`` and
  ``payment_enabled``: topic switches, on by default. Promotions keep
  using ``promotional_opt_in``. Safety and account have no switch.
* ``favourite_places`` (new enum ``favourite_place_kind``): a user's home,
  work (one of each, by a partial unique index) and other places.
* ``otp_purpose`` gains ``email_change``.

Rollback: ``downgrade()`` drops the new table, columns and enum types. The
``email_change`` value stays in ``otp_purpose``: PostgreSQL cannot drop an
enum value, and an unused one is harmless.

Revision ID: 20261123_0024
Revises: 20261116_0023
Create Date: 2026-11-23 12:00:00
"""

from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "20261123_0024"
down_revision: str | None = "20261116_0023"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


_TOPICS = ("booking_updates", "payment", "promotions", "safety", "account")
_PLACE_KINDS = ("home", "work", "custom")


def upgrade() -> None:
    bind = op.get_bind()

    # -- notification topics ----------------------------------------------
    topic = sa.Enum(*_TOPICS, name="notification_topic", native_enum=True)
    topic.create(bind, checkfirst=True)
    op.add_column(
        "notifications",
        sa.Column("topic", topic, nullable=False, server_default="booking_updates"),
    )
    op.execute(
        """
        UPDATE notifications SET topic = CASE
            WHEN category = 'safety' THEN 'safety'
            WHEN category = 'promotional' THEN 'promotions'
            WHEN data ->> 'action' LIKE 'insurance%'
              OR data ->> 'type' IN ('documents_requested', 'complaint_message')
              THEN 'account'
            ELSE 'booking_updates'
        END::notification_topic
        """
    )
    op.alter_column("notifications", "topic", server_default=None)

    op.add_column(
        "notification_preferences",
        sa.Column(
            "booking_updates_enabled", sa.Boolean(), nullable=False, server_default=sa.true()
        ),
    )
    op.add_column(
        "notification_preferences",
        sa.Column("payment_enabled", sa.Boolean(), nullable=False, server_default=sa.true()),
    )

    # -- favourite places -------------------------------------------------
    kind = postgresql.ENUM(*_PLACE_KINDS, name="favourite_place_kind", create_type=False)
    sa.Enum(*_PLACE_KINDS, name="favourite_place_kind", native_enum=True).create(
        bind, checkfirst=True
    )
    op.create_table(
        "favourite_places",
        sa.Column("id", sa.Uuid(), nullable=False, server_default=sa.text("gen_random_uuid()")),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("kind", kind, nullable=False),
        sa.Column("label", sa.String(length=60), nullable=False),
        sa.Column("stop_id", sa.Uuid(), nullable=True),
        sa.Column("latitude", sa.Numeric(9, 6), nullable=False),
        sa.Column("longitude", sa.Numeric(9, 6), nullable=False),
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
        sa.PrimaryKeyConstraint("id", name="pk_favourite_places"),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name="fk_favourite_places_user_id_users",
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["stop_id"],
            ["stops.id"],
            name="fk_favourite_places_stop_id_stops",
            ondelete="SET NULL",
        ),
    )
    op.create_index("ix_favourite_places_user_id", "favourite_places", ["user_id"])
    op.create_index(
        "uq_favourite_places_user_home_work",
        "favourite_places",
        ["user_id", "kind"],
        unique=True,
        postgresql_where=sa.text("kind IN ('home', 'work')"),
    )

    # -- email change codes ------------------------------------------------
    # Added outside the transaction's use of the type: nothing below uses it.
    op.execute("ALTER TYPE otp_purpose ADD VALUE IF NOT EXISTS 'email_change'")


def downgrade() -> None:
    bind = op.get_bind()
    op.drop_index("uq_favourite_places_user_home_work", table_name="favourite_places")
    op.drop_index("ix_favourite_places_user_id", table_name="favourite_places")
    op.drop_table("favourite_places")
    sa.Enum(*_PLACE_KINDS, name="favourite_place_kind").drop(bind, checkfirst=True)

    op.drop_column("notification_preferences", "payment_enabled")
    op.drop_column("notification_preferences", "booking_updates_enabled")
    op.drop_column("notifications", "topic")
    sa.Enum(*_TOPICS, name="notification_topic").drop(bind, checkfirst=True)
