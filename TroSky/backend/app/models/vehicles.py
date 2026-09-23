"""Fleet ownership, fleets, vehicles, verification documents/approvals, and
seat layouts.

Reuses the ``ApprovalStatus`` / ``DocumentType`` / ``DocumentStatus`` /
``ApprovalDecision`` vocabulary from ``app.models.drivers`` — the same
Postgres enum types back both driver and vehicle/fleet-owner verification.
"""

from __future__ import annotations

import uuid
from datetime import date, datetime
from enum import StrEnum

from sqlalchemy import CheckConstraint, ForeignKey, Index, UniqueConstraint
from sqlalchemy import Enum as PgEnum
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.types import TIMESTAMP, Boolean, Date, Integer, String

from app.models.base import UUIDAuditBase, enum_values
from app.models.drivers import ApprovalDecision, ApprovalStatus, DocumentStatus, DocumentType


class VehicleType(StrEnum):
    BUS = "bus"
    MINIBUS = "minibus"
    SHUTTLE = "shuttle"
    SEDAN = "sedan"
    OTHER = "other"


class SeatType(StrEnum):
    STANDARD = "standard"
    VIP = "vip"
    WINDOW = "window"
    AISLE = "aisle"


class FleetOwner(UUIDAuditBase):
    """A fleet owner's verification/business profile. One per user with the
    ``fleet_owner`` role."""

    __tablename__ = "fleet_owners"

    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    business_name: Mapped[str] = mapped_column(String(200), nullable=False)
    business_registration_number: Mapped[str | None] = mapped_column(String(50), nullable=True)
    status: Mapped[ApprovalStatus] = mapped_column(
        PgEnum(
            ApprovalStatus,
            name="approval_status",
            native_enum=True,
            values_callable=enum_values,
            create_type=False,
        ),
        nullable=False,
        default=ApprovalStatus.PENDING,
    )

    __table_args__ = (
        UniqueConstraint("user_id", name="uq_fleet_owners_user_id"),
        UniqueConstraint(
            "business_registration_number", name="uq_fleet_owners_business_registration_number"
        ),
    )


class Fleet(UUIDAuditBase):
    __tablename__ = "fleets"

    fleet_owner_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("fleet_owners.id", ondelete="CASCADE"), nullable=False
    )
    name: Mapped[str] = mapped_column(String(200), nullable=False)
    description: Mapped[str | None] = mapped_column(String(1000), nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)

    __table_args__ = (
        UniqueConstraint("fleet_owner_id", "name", name="uq_fleets_owner_name"),
        Index("ix_fleets_fleet_owner_id", "fleet_owner_id"),
    )


class Vehicle(UUIDAuditBase):
    __tablename__ = "vehicles"

    fleet_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("fleets.id", ondelete="CASCADE"), nullable=False
    )
    registration_number: Mapped[str] = mapped_column(String(20), nullable=False)
    vehicle_type: Mapped[VehicleType] = mapped_column(
        PgEnum(VehicleType, name="vehicle_type", native_enum=True, values_callable=enum_values),
        nullable=False,
    )
    make: Mapped[str | None] = mapped_column(String(100), nullable=True)
    model: Mapped[str | None] = mapped_column(String(100), nullable=True)
    year: Mapped[int | None] = mapped_column(Integer, nullable=True)
    capacity: Mapped[int] = mapped_column(Integer, nullable=False)
    status: Mapped[ApprovalStatus] = mapped_column(
        PgEnum(
            ApprovalStatus,
            name="approval_status",
            native_enum=True,
            values_callable=enum_values,
            create_type=False,
        ),
        nullable=False,
        default=ApprovalStatus.PENDING,
    )

    __table_args__ = (
        UniqueConstraint("registration_number", name="uq_vehicles_registration_number"),
        CheckConstraint("capacity > 0", name="capacity_positive"),
        Index("ix_vehicles_fleet_id", "fleet_id"),
        Index("ix_vehicles_status", "status"),
    )


class VehicleDocument(UUIDAuditBase):
    __tablename__ = "vehicle_documents"

    vehicle_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("vehicles.id", ondelete="CASCADE"), nullable=False
    )
    document_type: Mapped[DocumentType] = mapped_column(
        PgEnum(
            DocumentType,
            name="document_type",
            native_enum=True,
            values_callable=enum_values,
            create_type=False,
        ),
        nullable=False,
    )
    storage_key: Mapped[str] = mapped_column(String(500), nullable=False)
    original_filename: Mapped[str] = mapped_column(String(255), nullable=False)
    mime_type: Mapped[str] = mapped_column(String(100), nullable=False)
    file_size_bytes: Mapped[int] = mapped_column(Integer, nullable=False)
    status: Mapped[DocumentStatus] = mapped_column(
        PgEnum(
            DocumentStatus,
            name="document_status",
            native_enum=True,
            values_callable=enum_values,
            create_type=False,
        ),
        nullable=False,
        default=DocumentStatus.PENDING,
    )
    expiry_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    reviewed_by: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    reviewed_at: Mapped[datetime | None] = mapped_column(TIMESTAMP(timezone=True), nullable=True)
    rejection_reason: Mapped[str | None] = mapped_column(String(500), nullable=True)
    notes: Mapped[str | None] = mapped_column(String(1000), nullable=True)

    __table_args__ = (
        CheckConstraint("file_size_bytes > 0", name="file_size_bytes_positive"),
        Index("ix_vehicle_documents_vehicle_id", "vehicle_id"),
    )


class VehicleApproval(UUIDAuditBase):
    __tablename__ = "vehicle_approvals"

    vehicle_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("vehicles.id", ondelete="CASCADE"), nullable=False
    )
    reviewer_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    decision: Mapped[ApprovalDecision] = mapped_column(
        PgEnum(
            ApprovalDecision,
            name="approval_decision",
            native_enum=True,
            values_callable=enum_values,
            create_type=False,
        ),
        nullable=False,
    )
    notes: Mapped[str | None] = mapped_column(String(1000), nullable=True)
    rejection_reason: Mapped[str | None] = mapped_column(String(500), nullable=True)
    decided_at: Mapped[datetime] = mapped_column(
        TIMESTAMP(timezone=True), nullable=False, server_default="now()"
    )

    __table_args__ = (Index("ix_vehicle_approvals_vehicle_id", "vehicle_id"),)


class VehicleStatusHistory(UUIDAuditBase):
    __tablename__ = "vehicle_status_history"

    vehicle_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("vehicles.id", ondelete="CASCADE"), nullable=False
    )
    from_status: Mapped[ApprovalStatus | None] = mapped_column(
        PgEnum(
            ApprovalStatus,
            name="approval_status",
            native_enum=True,
            values_callable=enum_values,
            create_type=False,
        ),
        nullable=True,
    )
    to_status: Mapped[ApprovalStatus] = mapped_column(
        PgEnum(
            ApprovalStatus,
            name="approval_status",
            native_enum=True,
            values_callable=enum_values,
            create_type=False,
        ),
        nullable=False,
    )
    changed_by: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    reason: Mapped[str | None] = mapped_column(String(500), nullable=True)
    changed_at: Mapped[datetime] = mapped_column(
        TIMESTAMP(timezone=True), nullable=False, server_default="now()"
    )

    __table_args__ = (Index("ix_vehicle_status_history_vehicle_id", "vehicle_id"),)


class VehicleSeatLayout(UUIDAuditBase):
    """The active seat map for a vehicle. One per vehicle for MVP —
    reconfiguring seats updates this row's children rather than versioning."""

    __tablename__ = "vehicle_seat_layouts"

    vehicle_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("vehicles.id", ondelete="CASCADE"), nullable=False
    )
    name: Mapped[str | None] = mapped_column(String(100), nullable=True)
    rows: Mapped[int] = mapped_column(Integer, nullable=False)
    columns: Mapped[int] = mapped_column(Integer, nullable=False)
    total_seats: Mapped[int] = mapped_column(Integer, nullable=False)

    __table_args__ = (
        UniqueConstraint("vehicle_id", name="uq_vehicle_seat_layouts_vehicle_id"),
        CheckConstraint("rows > 0", name="rows_positive"),
        CheckConstraint("columns > 0", name="columns_positive"),
        CheckConstraint("total_seats > 0", name="total_seats_positive"),
    )


class VehicleSeat(UUIDAuditBase):
    __tablename__ = "vehicle_seats"

    layout_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("vehicle_seat_layouts.id", ondelete="CASCADE"), nullable=False
    )
    seat_number: Mapped[str] = mapped_column(String(10), nullable=False)
    row_number: Mapped[int] = mapped_column(Integer, nullable=False)
    column_number: Mapped[int] = mapped_column(Integer, nullable=False)
    seat_type: Mapped[SeatType] = mapped_column(
        PgEnum(SeatType, name="seat_type", native_enum=True, values_callable=enum_values),
        nullable=False,
        default=SeatType.STANDARD,
    )
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)

    __table_args__ = (
        UniqueConstraint("layout_id", "seat_number", name="uq_vehicle_seats_layout_seat_number"),
        CheckConstraint("row_number > 0", name="row_number_positive"),
        CheckConstraint("column_number > 0", name="column_number_positive"),
        Index("ix_vehicle_seats_layout_id", "layout_id"),
    )
