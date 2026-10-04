"""Trip domain models: the trip itself, its driver/vehicle assignments,
status history, and domain event log.

A trip is a scheduled or active run of a route (see ``app.models.routes``).
The trip lifecycle is governed by an explicit state machine — see
``app.services.trip_service.TRIP_TRANSITIONS``.
"""

from __future__ import annotations

import uuid
from datetime import datetime
from decimal import Decimal
from enum import StrEnum

from sqlalchemy import CheckConstraint, ForeignKey, Index
from sqlalchemy import Enum as PgEnum
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.types import TIMESTAMP, Boolean, Numeric, String

from app.models.base import UUIDAuditBase, enum_values


class TripStatus(StrEnum):
    SCHEDULED = "scheduled"
    BOARDING = "boarding"
    IN_PROGRESS = "in_progress"
    PAUSED = "paused"
    COMPLETED = "completed"
    CANCELLED = "cancelled"


class AssignmentResponse(StrEnum):
    """The assigned driver's answer to a trip (an admin may give it for them)."""

    PENDING = "pending"
    ACCEPTED = "accepted"
    DECLINED = "declined"


class TripEventType(StrEnum):
    TRIP_SCHEDULED = "trip_scheduled"
    TRIP_STARTED = "trip_started"
    TRIP_PAUSED = "trip_paused"
    TRIP_RESUMED = "trip_resumed"
    TRIP_COMPLETED = "trip_completed"
    TRIP_CANCELLED = "trip_cancelled"
    STOP_REACHED = "stop_reached"
    DELAY_REPORTED = "delay_reported"
    OTHER = "other"


class Trip(UUIDAuditBase):
    __tablename__ = "trips"

    route_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("routes.id", ondelete="RESTRICT"), nullable=False
    )
    route_schedule_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("route_schedules.id", ondelete="SET NULL"), nullable=True
    )
    scheduled_departure_at: Mapped[datetime] = mapped_column(
        TIMESTAMP(timezone=True), nullable=False
    )
    scheduled_arrival_at: Mapped[datetime | None] = mapped_column(
        TIMESTAMP(timezone=True), nullable=True
    )
    actual_departure_at: Mapped[datetime | None] = mapped_column(
        TIMESTAMP(timezone=True), nullable=True
    )
    actual_arrival_at: Mapped[datetime | None] = mapped_column(
        TIMESTAMP(timezone=True), nullable=True
    )
    status: Mapped[TripStatus] = mapped_column(
        PgEnum(TripStatus, name="trip_status", native_enum=True, values_callable=enum_values),
        nullable=False,
        default=TripStatus.SCHEDULED,
    )
    fare_amount: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)
    created_by: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    version: Mapped[int] = mapped_column(nullable=False, default=1, server_default="1")

    __table_args__ = (
        CheckConstraint("fare_amount >= 0", name="fare_amount_non_negative"),
        Index("ix_trips_route_id", "route_id"),
        Index("ix_trips_status", "status"),
        Index("ix_trips_scheduled_departure_at", "scheduled_departure_at"),
    )

    __mapper_args__ = {"version_id_col": version}  # noqa: RUF012 - SQLAlchemy special attribute


class TripDriverAssignment(UUIDAuditBase):
    __tablename__ = "trip_driver_assignments"

    trip_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("trips.id", ondelete="CASCADE"), nullable=False
    )
    driver_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("drivers.id", ondelete="RESTRICT"), nullable=False
    )
    assigned_by: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    assigned_at: Mapped[datetime] = mapped_column(
        TIMESTAMP(timezone=True), nullable=False, server_default="now()"
    )
    unassigned_at: Mapped[datetime | None] = mapped_column(TIMESTAMP(timezone=True), nullable=True)
    response: Mapped[AssignmentResponse] = mapped_column(
        PgEnum(
            AssignmentResponse,
            name="assignment_response",
            native_enum=True,
            values_callable=enum_values,
        ),
        nullable=False,
        default=AssignmentResponse.PENDING,
        server_default="pending",
    )
    responded_at: Mapped[datetime | None] = mapped_column(TIMESTAMP(timezone=True), nullable=True)
    responded_by: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    response_reason: Mapped[str | None] = mapped_column(String(500), nullable=True)

    __table_args__ = (
        Index("ix_trip_driver_assignments_trip_id", "trip_id"),
        Index("ix_trip_driver_assignments_driver_id", "driver_id"),
        Index(
            "uq_trip_driver_assignments_active_trip",
            "trip_id",
            unique=True,
            postgresql_where=is_active.is_(True),
        ),
    )


class TripVehicleAssignment(UUIDAuditBase):
    __tablename__ = "trip_vehicle_assignments"

    trip_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("trips.id", ondelete="CASCADE"), nullable=False
    )
    vehicle_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("vehicles.id", ondelete="RESTRICT"), nullable=False
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
        Index("ix_trip_vehicle_assignments_trip_id", "trip_id"),
        Index("ix_trip_vehicle_assignments_vehicle_id", "vehicle_id"),
        Index(
            "uq_trip_vehicle_assignments_active_trip",
            "trip_id",
            unique=True,
            postgresql_where=is_active.is_(True),
        ),
    )


class TripStatusHistory(UUIDAuditBase):
    __tablename__ = "trip_status_history"

    trip_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("trips.id", ondelete="CASCADE"), nullable=False
    )
    from_status: Mapped[TripStatus | None] = mapped_column(
        PgEnum(
            TripStatus,
            name="trip_status",
            native_enum=True,
            values_callable=enum_values,
            create_type=False,
        ),
        nullable=True,
    )
    to_status: Mapped[TripStatus] = mapped_column(
        PgEnum(
            TripStatus,
            name="trip_status",
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
    latitude: Mapped[Decimal | None] = mapped_column(Numeric(9, 6), nullable=True)
    longitude: Mapped[Decimal | None] = mapped_column(Numeric(9, 6), nullable=True)
    changed_at: Mapped[datetime] = mapped_column(
        TIMESTAMP(timezone=True), nullable=False, server_default="now()"
    )

    __table_args__ = (Index("ix_trip_status_history_trip_id", "trip_id"),)


class TripEvent(UUIDAuditBase):
    """A generic domain-event log for a trip (started, delayed, stop
    reached, etc). Downstream consumers (notifications, analytics — later
    phases) subscribe to these rather than to raw status transitions."""

    __tablename__ = "trip_events"

    trip_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("trips.id", ondelete="CASCADE"), nullable=False
    )
    event_type: Mapped[TripEventType] = mapped_column(
        PgEnum(
            TripEventType, name="trip_event_type", native_enum=True, values_callable=enum_values
        ),
        nullable=False,
    )
    payload: Mapped[dict[str, object] | None] = mapped_column(JSONB, nullable=True)
    occurred_at: Mapped[datetime] = mapped_column(
        TIMESTAMP(timezone=True), nullable=False, server_default="now()"
    )

    __table_args__ = (
        Index("ix_trip_events_trip_id", "trip_id"),
        Index("ix_trip_events_event_type", "event_type"),
    )
