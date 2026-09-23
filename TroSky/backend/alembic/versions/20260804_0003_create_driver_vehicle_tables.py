"""Create driver, fleet-owner, fleet, vehicle, verification-document, and
seat-layout tables.

Revision ID: 20260804_0003
Revises: 20260804_0002
Create Date: 2026-08-04 00:20:00
"""

from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "20260804_0003"
down_revision: str | None = "20260804_0002"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

approval_status_enum = sa.Enum(
    "pending", "under_review", "approved", "rejected", "suspended", "expired",
    name="approval_status",
)
document_type_enum = sa.Enum(
    "driver_license", "profile_photo", "ghana_card", "police_report",
    "vehicle_insurance", "vehicle_registration", "roadworthiness_certificate", "other",
    name="document_type",
)
document_status_enum = sa.Enum(
    "pending", "under_review", "approved", "rejected", "expired", name="document_status"
)
approval_decision_enum = sa.Enum("approved", "rejected", name="approval_decision")
vehicle_type_enum = sa.Enum("bus", "minibus", "shuttle", "sedan", "other", name="vehicle_type")
seat_type_enum = sa.Enum("standard", "vip", "window", "aisle", name="seat_type")


def upgrade() -> None:
    # Enum types are created automatically (checkfirst) the first time each
    # is used as a column type below — no separate explicit CREATE TYPE step.
    op.create_table(
        "drivers",
        sa.Column("id", sa.Uuid(), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("license_number", sa.String(50), nullable=False),
        sa.Column("license_expiry", sa.Date(), nullable=False),
        sa.Column("license_class", sa.String(20), nullable=True),
        sa.Column("years_of_experience", sa.Integer(), nullable=True),
        sa.Column("status", approval_status_enum, nullable=False, server_default="pending"),
        sa.PrimaryKeyConstraint("id", name="pk_drivers"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], name="fk_drivers_user_id_users", ondelete="CASCADE"),
        sa.UniqueConstraint("user_id", name="uq_drivers_user_id"),
        sa.UniqueConstraint("license_number", name="uq_drivers_license_number"),
        sa.CheckConstraint("years_of_experience IS NULL OR years_of_experience >= 0", name="years_of_experience_non_negative"),
    )
    op.create_index("ix_drivers_status", "drivers", ["status"])

    op.create_table(
        "fleet_owners",
        sa.Column("id", sa.Uuid(), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("business_name", sa.String(200), nullable=False),
        sa.Column("business_registration_number", sa.String(50), nullable=True),
        sa.Column("status", approval_status_enum, nullable=False, server_default="pending"),
        sa.PrimaryKeyConstraint("id", name="pk_fleet_owners"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], name="fk_fleet_owners_user_id_users", ondelete="CASCADE"),
        sa.UniqueConstraint("user_id", name="uq_fleet_owners_user_id"),
        sa.UniqueConstraint("business_registration_number", name="uq_fleet_owners_business_registration_number"),
    )

    op.create_table(
        "fleets",
        sa.Column("id", sa.Uuid(), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("fleet_owner_id", sa.Uuid(), nullable=False),
        sa.Column("name", sa.String(200), nullable=False),
        sa.Column("description", sa.String(1000), nullable=True),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.PrimaryKeyConstraint("id", name="pk_fleets"),
        sa.ForeignKeyConstraint(["fleet_owner_id"], ["fleet_owners.id"], name="fk_fleets_fleet_owner_id_fleet_owners", ondelete="CASCADE"),
        sa.UniqueConstraint("fleet_owner_id", "name", name="uq_fleets_owner_name"),
    )
    op.create_index("ix_fleets_fleet_owner_id", "fleets", ["fleet_owner_id"])

    op.create_table(
        "vehicles",
        sa.Column("id", sa.Uuid(), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("fleet_id", sa.Uuid(), nullable=False),
        sa.Column("registration_number", sa.String(20), nullable=False),
        sa.Column("vehicle_type", vehicle_type_enum, nullable=False),
        sa.Column("make", sa.String(100), nullable=True),
        sa.Column("model", sa.String(100), nullable=True),
        sa.Column("year", sa.Integer(), nullable=True),
        sa.Column("capacity", sa.Integer(), nullable=False),
        sa.Column("status", approval_status_enum, nullable=False, server_default="pending"),
        sa.PrimaryKeyConstraint("id", name="pk_vehicles"),
        sa.ForeignKeyConstraint(["fleet_id"], ["fleets.id"], name="fk_vehicles_fleet_id_fleets", ondelete="CASCADE"),
        sa.UniqueConstraint("registration_number", name="uq_vehicles_registration_number"),
        sa.CheckConstraint("capacity > 0", name="capacity_positive"),
    )
    op.create_index("ix_vehicles_fleet_id", "vehicles", ["fleet_id"])
    op.create_index("ix_vehicles_status", "vehicles", ["status"])

    op.create_table(
        "driver_documents",
        sa.Column("id", sa.Uuid(), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("driver_id", sa.Uuid(), nullable=False),
        sa.Column("document_type", document_type_enum, nullable=False),
        sa.Column("storage_key", sa.String(500), nullable=False),
        sa.Column("original_filename", sa.String(255), nullable=False),
        sa.Column("mime_type", sa.String(100), nullable=False),
        sa.Column("file_size_bytes", sa.Integer(), nullable=False),
        sa.Column("status", document_status_enum, nullable=False, server_default="pending"),
        sa.Column("expiry_date", sa.Date(), nullable=True),
        sa.Column("reviewed_by", sa.Uuid(), nullable=True),
        sa.Column("reviewed_at", sa.TIMESTAMP(timezone=True), nullable=True),
        sa.Column("rejection_reason", sa.String(500), nullable=True),
        sa.Column("notes", sa.String(1000), nullable=True),
        sa.PrimaryKeyConstraint("id", name="pk_driver_documents"),
        sa.ForeignKeyConstraint(["driver_id"], ["drivers.id"], name="fk_driver_documents_driver_id_drivers", ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["reviewed_by"], ["users.id"], name="fk_driver_documents_reviewed_by_users", ondelete="SET NULL"),
        sa.CheckConstraint("file_size_bytes > 0", name="file_size_bytes_positive"),
    )
    op.create_index("ix_driver_documents_driver_id", "driver_documents", ["driver_id"])

    op.create_table(
        "driver_approvals",
        sa.Column("id", sa.Uuid(), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("driver_id", sa.Uuid(), nullable=False),
        sa.Column("reviewer_id", sa.Uuid(), nullable=True),
        sa.Column("decision", approval_decision_enum, nullable=False),
        sa.Column("notes", sa.String(1000), nullable=True),
        sa.Column("rejection_reason", sa.String(500), nullable=True),
        sa.Column("decided_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.PrimaryKeyConstraint("id", name="pk_driver_approvals"),
        sa.ForeignKeyConstraint(["driver_id"], ["drivers.id"], name="fk_driver_approvals_driver_id_drivers", ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["reviewer_id"], ["users.id"], name="fk_driver_approvals_reviewer_id_users", ondelete="SET NULL"),
    )
    op.create_index("ix_driver_approvals_driver_id", "driver_approvals", ["driver_id"])

    op.create_table(
        "driver_status_history",
        sa.Column("id", sa.Uuid(), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("driver_id", sa.Uuid(), nullable=False),
        sa.Column("from_status", approval_status_enum, nullable=True),
        sa.Column("to_status", approval_status_enum, nullable=False),
        sa.Column("changed_by", sa.Uuid(), nullable=True),
        sa.Column("reason", sa.String(500), nullable=True),
        sa.Column("changed_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.PrimaryKeyConstraint("id", name="pk_driver_status_history"),
        sa.ForeignKeyConstraint(["driver_id"], ["drivers.id"], name="fk_driver_status_history_driver_id_drivers", ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["changed_by"], ["users.id"], name="fk_driver_status_history_changed_by_users", ondelete="SET NULL"),
    )
    op.create_index("ix_driver_status_history_driver_id", "driver_status_history", ["driver_id"])

    op.create_table(
        "driver_assignments",
        sa.Column("id", sa.Uuid(), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("driver_id", sa.Uuid(), nullable=False),
        sa.Column("vehicle_id", sa.Uuid(), nullable=False),
        sa.Column("fleet_id", sa.Uuid(), nullable=False),
        sa.Column("assigned_by", sa.Uuid(), nullable=True),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("assigned_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("unassigned_at", sa.TIMESTAMP(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint("id", name="pk_driver_assignments"),
        sa.ForeignKeyConstraint(["driver_id"], ["drivers.id"], name="fk_driver_assignments_driver_id_drivers", ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["vehicle_id"], ["vehicles.id"], name="fk_driver_assignments_vehicle_id_vehicles", ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["fleet_id"], ["fleets.id"], name="fk_driver_assignments_fleet_id_fleets", ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["assigned_by"], ["users.id"], name="fk_driver_assignments_assigned_by_users", ondelete="SET NULL"),
    )
    op.create_index("ix_driver_assignments_driver_id", "driver_assignments", ["driver_id"])
    op.create_index("ix_driver_assignments_vehicle_id", "driver_assignments", ["vehicle_id"])
    op.create_index("ix_driver_assignments_active_vehicle", "driver_assignments", ["vehicle_id", "is_active"])

    op.create_table(
        "vehicle_documents",
        sa.Column("id", sa.Uuid(), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("vehicle_id", sa.Uuid(), nullable=False),
        sa.Column("document_type", document_type_enum, nullable=False),
        sa.Column("storage_key", sa.String(500), nullable=False),
        sa.Column("original_filename", sa.String(255), nullable=False),
        sa.Column("mime_type", sa.String(100), nullable=False),
        sa.Column("file_size_bytes", sa.Integer(), nullable=False),
        sa.Column("status", document_status_enum, nullable=False, server_default="pending"),
        sa.Column("expiry_date", sa.Date(), nullable=True),
        sa.Column("reviewed_by", sa.Uuid(), nullable=True),
        sa.Column("reviewed_at", sa.TIMESTAMP(timezone=True), nullable=True),
        sa.Column("rejection_reason", sa.String(500), nullable=True),
        sa.Column("notes", sa.String(1000), nullable=True),
        sa.PrimaryKeyConstraint("id", name="pk_vehicle_documents"),
        sa.ForeignKeyConstraint(["vehicle_id"], ["vehicles.id"], name="fk_vehicle_documents_vehicle_id_vehicles", ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["reviewed_by"], ["users.id"], name="fk_vehicle_documents_reviewed_by_users", ondelete="SET NULL"),
        sa.CheckConstraint("file_size_bytes > 0", name="file_size_bytes_positive"),
    )
    op.create_index("ix_vehicle_documents_vehicle_id", "vehicle_documents", ["vehicle_id"])

    op.create_table(
        "vehicle_approvals",
        sa.Column("id", sa.Uuid(), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("vehicle_id", sa.Uuid(), nullable=False),
        sa.Column("reviewer_id", sa.Uuid(), nullable=True),
        sa.Column("decision", approval_decision_enum, nullable=False),
        sa.Column("notes", sa.String(1000), nullable=True),
        sa.Column("rejection_reason", sa.String(500), nullable=True),
        sa.Column("decided_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.PrimaryKeyConstraint("id", name="pk_vehicle_approvals"),
        sa.ForeignKeyConstraint(["vehicle_id"], ["vehicles.id"], name="fk_vehicle_approvals_vehicle_id_vehicles", ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["reviewer_id"], ["users.id"], name="fk_vehicle_approvals_reviewer_id_users", ondelete="SET NULL"),
    )
    op.create_index("ix_vehicle_approvals_vehicle_id", "vehicle_approvals", ["vehicle_id"])

    op.create_table(
        "vehicle_status_history",
        sa.Column("id", sa.Uuid(), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("vehicle_id", sa.Uuid(), nullable=False),
        sa.Column("from_status", approval_status_enum, nullable=True),
        sa.Column("to_status", approval_status_enum, nullable=False),
        sa.Column("changed_by", sa.Uuid(), nullable=True),
        sa.Column("reason", sa.String(500), nullable=True),
        sa.Column("changed_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.PrimaryKeyConstraint("id", name="pk_vehicle_status_history"),
        sa.ForeignKeyConstraint(["vehicle_id"], ["vehicles.id"], name="fk_vehicle_status_history_vehicle_id_vehicles", ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["changed_by"], ["users.id"], name="fk_vehicle_status_history_changed_by_users", ondelete="SET NULL"),
    )
    op.create_index("ix_vehicle_status_history_vehicle_id", "vehicle_status_history", ["vehicle_id"])

    op.create_table(
        "vehicle_seat_layouts",
        sa.Column("id", sa.Uuid(), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("vehicle_id", sa.Uuid(), nullable=False),
        sa.Column("name", sa.String(100), nullable=True),
        sa.Column("rows", sa.Integer(), nullable=False),
        sa.Column("columns", sa.Integer(), nullable=False),
        sa.Column("total_seats", sa.Integer(), nullable=False),
        sa.PrimaryKeyConstraint("id", name="pk_vehicle_seat_layouts"),
        sa.ForeignKeyConstraint(["vehicle_id"], ["vehicles.id"], name="fk_vehicle_seat_layouts_vehicle_id_vehicles", ondelete="CASCADE"),
        sa.UniqueConstraint("vehicle_id", name="uq_vehicle_seat_layouts_vehicle_id"),
        sa.CheckConstraint("rows > 0", name="rows_positive"),
        sa.CheckConstraint("columns > 0", name="columns_positive"),
        sa.CheckConstraint("total_seats > 0", name="total_seats_positive"),
    )

    op.create_table(
        "vehicle_seats",
        sa.Column("id", sa.Uuid(), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("layout_id", sa.Uuid(), nullable=False),
        sa.Column("seat_number", sa.String(10), nullable=False),
        sa.Column("row_number", sa.Integer(), nullable=False),
        sa.Column("column_number", sa.Integer(), nullable=False),
        sa.Column("seat_type", seat_type_enum, nullable=False, server_default="standard"),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.PrimaryKeyConstraint("id", name="pk_vehicle_seats"),
        sa.ForeignKeyConstraint(["layout_id"], ["vehicle_seat_layouts.id"], name="fk_vehicle_seats_layout_id_vehicle_seat_layouts", ondelete="CASCADE"),
        sa.UniqueConstraint("layout_id", "seat_number", name="uq_vehicle_seats_layout_seat_number"),
        sa.CheckConstraint("row_number > 0", name="row_number_positive"),
        sa.CheckConstraint("column_number > 0", name="column_number_positive"),
    )
    op.create_index("ix_vehicle_seats_layout_id", "vehicle_seats", ["layout_id"])


def downgrade() -> None:
    op.drop_table("vehicle_seats")
    op.drop_table("vehicle_seat_layouts")
    op.drop_table("vehicle_status_history")
    op.drop_table("vehicle_approvals")
    op.drop_table("vehicle_documents")
    op.drop_table("driver_assignments")
    op.drop_table("driver_status_history")
    op.drop_table("driver_approvals")
    op.drop_table("driver_documents")
    op.drop_table("vehicles")
    op.drop_table("fleets")
    op.drop_table("fleet_owners")
    op.drop_table("drivers")

    bind = op.get_bind()
    seat_type_enum.drop(bind, checkfirst=True)
    vehicle_type_enum.drop(bind, checkfirst=True)
    approval_decision_enum.drop(bind, checkfirst=True)
    document_status_enum.drop(bind, checkfirst=True)
    document_type_enum.drop(bind, checkfirst=True)
    approval_status_enum.drop(bind, checkfirst=True)
