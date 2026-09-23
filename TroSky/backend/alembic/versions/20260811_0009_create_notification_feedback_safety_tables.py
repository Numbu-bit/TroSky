"""Create notification, rating, complaint, incident, and sos_alert tables.

Revision ID: 20260811_0009
Revises: 20260811_0008
Create Date: 2026-08-11 00:00:00
"""

from __future__ import annotations

from collections.abc import Sequence

import geoalchemy2
import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import JSONB

# revision identifiers, used by Alembic.
revision: str = "20260811_0009"
down_revision: str | None = "20260811_0008"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

notification_category_enum = sa.Enum(
    "transactional", "safety", "promotional", name="notification_category"
)
complaint_category_enum = sa.Enum(
    "driver_conduct", "vehicle_condition", "safety", "payment", "other",
    name="complaint_category",
)
complaint_status_enum = sa.Enum(
    "open", "in_review", "resolved", "dismissed", name="complaint_status"
)
incident_type_enum = sa.Enum(
    "accident", "breakdown", "delay", "safety_concern", "other", name="incident_type"
)
incident_severity_enum = sa.Enum("low", "medium", "high", "critical", name="incident_severity")
incident_status_enum = sa.Enum(
    "reported", "in_review", "resolved", "closed", name="incident_status"
)
sos_alert_status_enum = sa.Enum(
    "active", "acknowledged", "resolved", "false_alarm", name="sos_alert_status"
)


def upgrade() -> None:
    op.create_table(
        "notifications",
        sa.Column("id", sa.Uuid(), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("category", notification_category_enum, nullable=False),
        sa.Column("title", sa.String(200), nullable=False),
        sa.Column("body", sa.String(1000), nullable=False),
        sa.Column("data", JSONB(), nullable=False),
        sa.Column("channel_results", JSONB(), nullable=False),
        sa.Column("is_read", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("read_at", sa.TIMESTAMP(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint("id", name="pk_notifications"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], name="fk_notifications_user_id_users", ondelete="CASCADE"),
    )
    op.create_index("ix_notifications_user_id_created_at", "notifications", ["user_id", "created_at"])
    op.create_index("ix_notifications_user_id_is_read", "notifications", ["user_id", "is_read"])

    op.create_table(
        "ratings",
        sa.Column("id", sa.Uuid(), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("booking_id", sa.Uuid(), nullable=False),
        sa.Column("trip_id", sa.Uuid(), nullable=False),
        sa.Column("passenger_id", sa.Uuid(), nullable=False),
        sa.Column("driver_id", sa.Uuid(), nullable=True),
        sa.Column("score", sa.Integer(), nullable=False),
        sa.Column("comment", sa.String(1000), nullable=True),
        sa.PrimaryKeyConstraint("id", name="pk_ratings"),
        sa.ForeignKeyConstraint(["booking_id"], ["bookings.id"], name="fk_ratings_booking_id_bookings", ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(["trip_id"], ["trips.id"], name="fk_ratings_trip_id_trips", ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(["passenger_id"], ["users.id"], name="fk_ratings_passenger_id_users", ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["driver_id"], ["drivers.id"], name="fk_ratings_driver_id_drivers", ondelete="SET NULL"),
        sa.UniqueConstraint("booking_id", name="uq_ratings_booking_id"),
        sa.CheckConstraint("score >= 1 AND score <= 5", name="score_between_1_and_5"),
    )
    op.create_index("ix_ratings_driver_id", "ratings", ["driver_id"])
    op.create_index("ix_ratings_trip_id", "ratings", ["trip_id"])

    op.create_table(
        "complaints",
        sa.Column("id", sa.Uuid(), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("filed_by", sa.Uuid(), nullable=False),
        sa.Column("booking_id", sa.Uuid(), nullable=True),
        sa.Column("trip_id", sa.Uuid(), nullable=True),
        sa.Column("category", complaint_category_enum, nullable=False),
        sa.Column("subject", sa.String(200), nullable=False),
        sa.Column("description", sa.String(2000), nullable=False),
        sa.Column("status", complaint_status_enum, nullable=False, server_default="open"),
        sa.Column("resolved_by", sa.Uuid(), nullable=True),
        sa.Column("resolved_at", sa.TIMESTAMP(timezone=True), nullable=True),
        sa.Column("resolution_notes", sa.String(1000), nullable=True),
        sa.PrimaryKeyConstraint("id", name="pk_complaints"),
        sa.ForeignKeyConstraint(["filed_by"], ["users.id"], name="fk_complaints_filed_by_users", ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["booking_id"], ["bookings.id"], name="fk_complaints_booking_id_bookings", ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["trip_id"], ["trips.id"], name="fk_complaints_trip_id_trips", ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["resolved_by"], ["users.id"], name="fk_complaints_resolved_by_users", ondelete="SET NULL"),
    )
    op.create_index("ix_complaints_filed_by", "complaints", ["filed_by"])
    op.create_index("ix_complaints_status", "complaints", ["status"])

    op.create_table(
        "incidents",
        sa.Column("id", sa.Uuid(), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("trip_id", sa.Uuid(), nullable=False),
        sa.Column("reported_by", sa.Uuid(), nullable=False),
        sa.Column("incident_type", incident_type_enum, nullable=False),
        sa.Column("severity", incident_severity_enum, nullable=False),
        sa.Column("description", sa.String(2000), nullable=False),
        sa.Column(
            "location",
            geoalchemy2.types.Geography(geometry_type="POINT", srid=4326, spatial_index=False),
            nullable=True,
        ),
        sa.Column("status", incident_status_enum, nullable=False, server_default="reported"),
        sa.Column("resolved_by", sa.Uuid(), nullable=True),
        sa.Column("resolved_at", sa.TIMESTAMP(timezone=True), nullable=True),
        sa.Column("resolution_notes", sa.String(1000), nullable=True),
        sa.PrimaryKeyConstraint("id", name="pk_incidents"),
        sa.ForeignKeyConstraint(["trip_id"], ["trips.id"], name="fk_incidents_trip_id_trips", ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["reported_by"], ["users.id"], name="fk_incidents_reported_by_users", ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["resolved_by"], ["users.id"], name="fk_incidents_resolved_by_users", ondelete="SET NULL"),
    )
    op.create_index("ix_incidents_trip_id", "incidents", ["trip_id"])
    op.create_index("ix_incidents_status", "incidents", ["status"])

    op.create_table(
        "sos_alerts",
        sa.Column("id", sa.Uuid(), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("trip_id", sa.Uuid(), nullable=False),
        sa.Column("triggered_by", sa.Uuid(), nullable=False),
        sa.Column(
            "location",
            geoalchemy2.types.Geography(geometry_type="POINT", srid=4326, spatial_index=False),
            nullable=True,
        ),
        sa.Column("status", sos_alert_status_enum, nullable=False, server_default="active"),
        sa.Column("acknowledged_by", sa.Uuid(), nullable=True),
        sa.Column("acknowledged_at", sa.TIMESTAMP(timezone=True), nullable=True),
        sa.Column("resolved_by", sa.Uuid(), nullable=True),
        sa.Column("resolved_at", sa.TIMESTAMP(timezone=True), nullable=True),
        sa.Column("resolution_notes", sa.String(1000), nullable=True),
        sa.PrimaryKeyConstraint("id", name="pk_sos_alerts"),
        sa.ForeignKeyConstraint(["trip_id"], ["trips.id"], name="fk_sos_alerts_trip_id_trips", ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["triggered_by"], ["users.id"], name="fk_sos_alerts_triggered_by_users", ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["acknowledged_by"], ["users.id"], name="fk_sos_alerts_acknowledged_by_users", ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["resolved_by"], ["users.id"], name="fk_sos_alerts_resolved_by_users", ondelete="SET NULL"),
    )
    op.create_index("ix_sos_alerts_trip_id", "sos_alerts", ["trip_id"])
    op.create_index("ix_sos_alerts_status", "sos_alerts", ["status"])


def downgrade() -> None:
    op.drop_table("sos_alerts")
    op.drop_table("incidents")
    op.drop_table("complaints")
    op.drop_table("ratings")
    op.drop_table("notifications")

    bind = op.get_bind()
    sos_alert_status_enum.drop(bind, checkfirst=True)
    incident_status_enum.drop(bind, checkfirst=True)
    incident_severity_enum.drop(bind, checkfirst=True)
    incident_type_enum.drop(bind, checkfirst=True)
    complaint_status_enum.drop(bind, checkfirst=True)
    complaint_category_enum.drop(bind, checkfirst=True)
    notification_category_enum.drop(bind, checkfirst=True)
