"""Driver domain models: driver profiles, verification documents, approval
decisions, status history, and (non-trip) vehicle assignments.

Trip-specific driver assignments (``trip_driver_assignments``) are a
separate concept introduced in Phase 4 alongside trips; ``driver_assignments``
here represents a fleet owner authorizing a driver to operate a specific
vehicle at all (a prerequisite for that driver ever being assigned to a trip
on that vehicle).
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


class ApprovalStatus(StrEnum):
    """Shared status vocabulary for driver and vehicle verification."""

    PENDING = "pending"
    UNDER_REVIEW = "under_review"
    APPROVED = "approved"
    REJECTED = "rejected"
    SUSPENDED = "suspended"
    EXPIRED = "expired"


class DocumentType(StrEnum):
    DRIVER_LICENSE = "driver_license"
    PROFILE_PHOTO = "profile_photo"
    GHANA_CARD = "ghana_card"
    POLICE_REPORT = "police_report"
    VEHICLE_INSURANCE = "vehicle_insurance"
    VEHICLE_REGISTRATION = "vehicle_registration"
    ROADWORTHINESS_CERTIFICATE = "roadworthiness_certificate"
    OTHER = "other"


class DocumentStatus(StrEnum):
    PENDING = "pending"
    UNDER_REVIEW = "under_review"
    APPROVED = "approved"
    REJECTED = "rejected"
    EXPIRED = "expired"


class ApprovalDecision(StrEnum):
    APPROVED = "approved"
    REJECTED = "rejected"


class Driver(UUIDAuditBase):
    """A driver's verification/operational profile. One per user with the
    ``driver`` role."""

    __tablename__ = "drivers"

    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    license_number: Mapped[str] = mapped_column(String(50), nullable=False)
    license_expiry: Mapped[date] = mapped_column(Date, nullable=False)
    license_class: Mapped[str | None] = mapped_column(String(20), nullable=True)
    years_of_experience: Mapped[int | None] = mapped_column(Integer, nullable=True)
    status: Mapped[ApprovalStatus] = mapped_column(
        PgEnum(
            ApprovalStatus, name="approval_status", native_enum=True, values_callable=enum_values
        ),
        nullable=False,
        default=ApprovalStatus.PENDING,
    )

    __table_args__ = (
        UniqueConstraint("user_id", name="uq_drivers_user_id"),
        UniqueConstraint("license_number", name="uq_drivers_license_number"),
        CheckConstraint(
            "years_of_experience IS NULL OR years_of_experience >= 0",
            name="years_of_experience_non_negative",
        ),
        Index("ix_drivers_status", "status"),
    )


class DriverDocument(UUIDAuditBase):
    __tablename__ = "driver_documents"

    driver_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("drivers.id", ondelete="CASCADE"), nullable=False
    )
    document_type: Mapped[DocumentType] = mapped_column(
        PgEnum(DocumentType, name="document_type", native_enum=True, values_callable=enum_values),
        nullable=False,
    )
    storage_key: Mapped[str] = mapped_column(String(500), nullable=False)
    original_filename: Mapped[str] = mapped_column(String(255), nullable=False)
    mime_type: Mapped[str] = mapped_column(String(100), nullable=False)
    file_size_bytes: Mapped[int] = mapped_column(Integer, nullable=False)
    status: Mapped[DocumentStatus] = mapped_column(
        PgEnum(
            DocumentStatus, name="document_status", native_enum=True, values_callable=enum_values
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
        Index("ix_driver_documents_driver_id", "driver_id"),
    )


class DriverApproval(UUIDAuditBase):
    """One row per formal approve/reject decision on a driver."""

    __tablename__ = "driver_approvals"

    driver_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("drivers.id", ondelete="CASCADE"), nullable=False
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
        ),
        nullable=False,
    )
    notes: Mapped[str | None] = mapped_column(String(1000), nullable=True)
    rejection_reason: Mapped[str | None] = mapped_column(String(500), nullable=True)
    decided_at: Mapped[datetime] = mapped_column(
        TIMESTAMP(timezone=True), nullable=False, server_default="now()"
    )

    __table_args__ = (Index("ix_driver_approvals_driver_id", "driver_id"),)


class DriverStatusHistory(UUIDAuditBase):
    """Append-only audit trail of every driver status transition."""

    __tablename__ = "driver_status_history"

    driver_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("drivers.id", ondelete="CASCADE"), nullable=False
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

    __table_args__ = (Index("ix_driver_status_history_driver_id", "driver_id"),)


class DriverAssignment(UUIDAuditBase):
    """A fleet owner authorizing a driver to operate a specific vehicle.
    Prerequisite for (but distinct from) a trip-specific assignment."""

    __tablename__ = "driver_assignments"

    driver_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("drivers.id", ondelete="CASCADE"), nullable=False
    )
    vehicle_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("vehicles.id", ondelete="CASCADE"), nullable=False
    )
    fleet_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("fleets.id", ondelete="CASCADE"), nullable=False
    )
    assigned_by: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    assigned_at: Mapped[datetime] = mapped_column(
        TIMESTAMP(timezone=True), nullable=False, server_default="now()"
    )
    unassigned_at: Mapped[datetime | None] = mapped_column(TIMESTAMP(timezone=True), nullable=True)

    __table_args__ = (
        Index("ix_driver_assignments_driver_id", "driver_id"),
        Index("ix_driver_assignments_vehicle_id", "vehicle_id"),
        Index(
            "ix_driver_assignments_active_vehicle",
            "vehicle_id",
            "is_active",
        ),
    )
