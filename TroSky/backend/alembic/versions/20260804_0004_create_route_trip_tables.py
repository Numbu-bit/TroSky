"""Create route, stop, schedule, and trip tables.

Revision ID: 20260804_0004
Revises: 20260804_0003
Create Date: 2026-08-08 00:00:00
"""

from __future__ import annotations

from collections.abc import Sequence

import geoalchemy2
import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import JSONB

# revision identifiers, used by Alembic.
revision: str = "20260804_0004"
down_revision: str | None = "20260804_0003"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

day_of_week_enum = sa.Enum(
    "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
    name="day_of_week",
)
trip_status_enum = sa.Enum(
    "scheduled", "boarding", "in_progress", "paused", "completed", "cancelled",
    name="trip_status",
)
trip_event_type_enum = sa.Enum(
    "trip_scheduled", "trip_started", "trip_paused", "trip_resumed", "trip_completed",
    "trip_cancelled", "stop_reached", "delay_reported", "other",
    name="trip_event_type",
)


def upgrade() -> None:
    op.create_table(
        "stops",
        sa.Column("id", sa.Uuid(), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("name", sa.String(200), nullable=False),
        sa.Column("code", sa.String(20), nullable=True),
        sa.Column("description", sa.String(500), nullable=True),
        sa.Column(
            "location",
            geoalchemy2.types.Geography(
                geometry_type="POINT",
                srid=4326,
                from_text="ST_GeogFromText",
                name="geography",
                spatial_index=False,
            ),
            nullable=False,
        ),
        sa.Column("address", sa.String(500), nullable=True),
        sa.Column("city", sa.String(100), nullable=True),
        sa.Column("region", sa.String(100), nullable=True),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.PrimaryKeyConstraint("id", name="pk_stops"),
        sa.UniqueConstraint("code", name="uq_stops_code"),
    )
    op.create_index("ix_stops_location", "stops", ["location"], postgresql_using="gist")
    op.create_index("ix_stops_city", "stops", ["city"])

    op.create_table(
        "routes",
        sa.Column("id", sa.Uuid(), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("name", sa.String(200), nullable=False),
        sa.Column("origin_stop_id", sa.Uuid(), nullable=False),
        sa.Column("destination_stop_id", sa.Uuid(), nullable=False),
        sa.Column("distance_km", sa.Numeric(8, 2), nullable=True),
        sa.Column("estimated_duration_minutes", sa.Integer(), nullable=True),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("created_by", sa.Uuid(), nullable=True),
        sa.PrimaryKeyConstraint("id", name="pk_routes"),
        sa.ForeignKeyConstraint(["origin_stop_id"], ["stops.id"], name="fk_routes_origin_stop_id_stops", ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(["destination_stop_id"], ["stops.id"], name="fk_routes_destination_stop_id_stops", ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(["created_by"], ["users.id"], name="fk_routes_created_by_users", ondelete="SET NULL"),
        sa.UniqueConstraint("name", name="uq_routes_name"),
        sa.CheckConstraint("origin_stop_id != destination_stop_id", name="origin_destination_distinct"),
    )
    op.create_index("ix_routes_origin_destination", "routes", ["origin_stop_id", "destination_stop_id"])

    op.create_table(
        "route_stops",
        sa.Column("id", sa.Uuid(), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("route_id", sa.Uuid(), nullable=False),
        sa.Column("stop_id", sa.Uuid(), nullable=False),
        sa.Column("sequence_number", sa.Integer(), nullable=False),
        sa.Column("distance_from_origin_km", sa.Numeric(8, 2), nullable=True),
        sa.Column("estimated_offset_minutes", sa.Integer(), nullable=True),
        sa.PrimaryKeyConstraint("id", name="pk_route_stops"),
        sa.ForeignKeyConstraint(["route_id"], ["routes.id"], name="fk_route_stops_route_id_routes", ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["stop_id"], ["stops.id"], name="fk_route_stops_stop_id_stops", ondelete="RESTRICT"),
        sa.UniqueConstraint("route_id", "sequence_number", name="uq_route_stops_route_sequence"),
        sa.UniqueConstraint("route_id", "stop_id", name="uq_route_stops_route_stop"),
        sa.CheckConstraint("sequence_number >= 0", name="sequence_number_non_negative"),
    )
    op.create_index("ix_route_stops_route_id", "route_stops", ["route_id"])

    op.create_table(
        "route_schedules",
        sa.Column("id", sa.Uuid(), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("route_id", sa.Uuid(), nullable=False),
        sa.Column("departure_time", sa.Time(), nullable=False),
        sa.Column("days_of_week", sa.ARRAY(day_of_week_enum), nullable=False),
        sa.Column("fare_amount", sa.Numeric(12, 2), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.PrimaryKeyConstraint("id", name="pk_route_schedules"),
        sa.ForeignKeyConstraint(["route_id"], ["routes.id"], name="fk_route_schedules_route_id_routes", ondelete="CASCADE"),
        sa.CheckConstraint("fare_amount >= 0", name="fare_amount_non_negative"),
    )
    op.create_index("ix_route_schedules_route_id", "route_schedules", ["route_id"])

    op.create_table(
        "trips",
        sa.Column("id", sa.Uuid(), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("route_id", sa.Uuid(), nullable=False),
        sa.Column("route_schedule_id", sa.Uuid(), nullable=True),
        sa.Column("scheduled_departure_at", sa.TIMESTAMP(timezone=True), nullable=False),
        sa.Column("scheduled_arrival_at", sa.TIMESTAMP(timezone=True), nullable=True),
        sa.Column("actual_departure_at", sa.TIMESTAMP(timezone=True), nullable=True),
        sa.Column("actual_arrival_at", sa.TIMESTAMP(timezone=True), nullable=True),
        sa.Column("status", trip_status_enum, nullable=False, server_default="scheduled"),
        sa.Column("fare_amount", sa.Numeric(12, 2), nullable=False),
        sa.Column("created_by", sa.Uuid(), nullable=True),
        sa.Column("version", sa.Integer(), nullable=False, server_default="1"),
        sa.PrimaryKeyConstraint("id", name="pk_trips"),
        sa.ForeignKeyConstraint(["route_id"], ["routes.id"], name="fk_trips_route_id_routes", ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(["route_schedule_id"], ["route_schedules.id"], name="fk_trips_route_schedule_id_route_schedules", ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["created_by"], ["users.id"], name="fk_trips_created_by_users", ondelete="SET NULL"),
        sa.CheckConstraint("fare_amount >= 0", name="fare_amount_non_negative"),
    )
    op.create_index("ix_trips_route_id", "trips", ["route_id"])
    op.create_index("ix_trips_status", "trips", ["status"])
    op.create_index("ix_trips_scheduled_departure_at", "trips", ["scheduled_departure_at"])

    op.create_table(
        "trip_driver_assignments",
        sa.Column("id", sa.Uuid(), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("trip_id", sa.Uuid(), nullable=False),
        sa.Column("driver_id", sa.Uuid(), nullable=False),
        sa.Column("assigned_by", sa.Uuid(), nullable=True),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("assigned_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("unassigned_at", sa.TIMESTAMP(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint("id", name="pk_trip_driver_assignments"),
        sa.ForeignKeyConstraint(["trip_id"], ["trips.id"], name="fk_trip_driver_assignments_trip_id_trips", ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["driver_id"], ["drivers.id"], name="fk_trip_driver_assignments_driver_id_drivers", ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(["assigned_by"], ["users.id"], name="fk_trip_driver_assignments_assigned_by_users", ondelete="SET NULL"),
    )
    op.create_index("ix_trip_driver_assignments_trip_id", "trip_driver_assignments", ["trip_id"])
    op.create_index("ix_trip_driver_assignments_driver_id", "trip_driver_assignments", ["driver_id"])
    op.create_index(
        "uq_trip_driver_assignments_active_trip",
        "trip_driver_assignments",
        ["trip_id"],
        unique=True,
        postgresql_where=sa.text("is_active = true"),
    )

    op.create_table(
        "trip_vehicle_assignments",
        sa.Column("id", sa.Uuid(), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("trip_id", sa.Uuid(), nullable=False),
        sa.Column("vehicle_id", sa.Uuid(), nullable=False),
        sa.Column("assigned_by", sa.Uuid(), nullable=True),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("assigned_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("unassigned_at", sa.TIMESTAMP(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint("id", name="pk_trip_vehicle_assignments"),
        sa.ForeignKeyConstraint(["trip_id"], ["trips.id"], name="fk_trip_vehicle_assignments_trip_id_trips", ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["vehicle_id"], ["vehicles.id"], name="fk_trip_vehicle_assignments_vehicle_id_vehicles", ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(["assigned_by"], ["users.id"], name="fk_trip_vehicle_assignments_assigned_by_users", ondelete="SET NULL"),
    )
    op.create_index("ix_trip_vehicle_assignments_trip_id", "trip_vehicle_assignments", ["trip_id"])
    op.create_index("ix_trip_vehicle_assignments_vehicle_id", "trip_vehicle_assignments", ["vehicle_id"])
    op.create_index(
        "uq_trip_vehicle_assignments_active_trip",
        "trip_vehicle_assignments",
        ["trip_id"],
        unique=True,
        postgresql_where=sa.text("is_active = true"),
    )

    op.create_table(
        "trip_status_history",
        sa.Column("id", sa.Uuid(), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("trip_id", sa.Uuid(), nullable=False),
        sa.Column("from_status", trip_status_enum, nullable=True),
        sa.Column("to_status", trip_status_enum, nullable=False),
        sa.Column("changed_by", sa.Uuid(), nullable=True),
        sa.Column("reason", sa.String(500), nullable=True),
        sa.Column("latitude", sa.Numeric(9, 6), nullable=True),
        sa.Column("longitude", sa.Numeric(9, 6), nullable=True),
        sa.Column("changed_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.PrimaryKeyConstraint("id", name="pk_trip_status_history"),
        sa.ForeignKeyConstraint(["trip_id"], ["trips.id"], name="fk_trip_status_history_trip_id_trips", ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["changed_by"], ["users.id"], name="fk_trip_status_history_changed_by_users", ondelete="SET NULL"),
    )
    op.create_index("ix_trip_status_history_trip_id", "trip_status_history", ["trip_id"])

    op.create_table(
        "trip_events",
        sa.Column("id", sa.Uuid(), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("trip_id", sa.Uuid(), nullable=False),
        sa.Column("event_type", trip_event_type_enum, nullable=False),
        sa.Column("payload", JSONB(), nullable=True),
        sa.Column("occurred_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.PrimaryKeyConstraint("id", name="pk_trip_events"),
        sa.ForeignKeyConstraint(["trip_id"], ["trips.id"], name="fk_trip_events_trip_id_trips", ondelete="CASCADE"),
    )
    op.create_index("ix_trip_events_trip_id", "trip_events", ["trip_id"])
    op.create_index("ix_trip_events_event_type", "trip_events", ["event_type"])


def downgrade() -> None:
    op.drop_table("trip_events")
    op.drop_table("trip_status_history")
    op.drop_table("trip_vehicle_assignments")
    op.drop_table("trip_driver_assignments")
    op.drop_table("trips")
    op.drop_table("route_schedules")
    op.drop_table("route_stops")
    op.drop_table("routes")
    op.drop_table("stops")

    bind = op.get_bind()
    trip_event_type_enum.drop(bind, checkfirst=True)
    trip_status_enum.drop(bind, checkfirst=True)
    day_of_week_enum.drop(bind, checkfirst=True)
