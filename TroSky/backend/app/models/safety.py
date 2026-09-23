"""Safety domain models: driver/passenger-reported incidents and SOS
distress alerts. Deliberately kept together — both feed the same
ops-review workflow shape (report → acknowledge/review → resolve) even
though SOS is materially more urgent (see ``app.services.safety_service``
for the notification-fan-out difference)."""

from __future__ import annotations

import uuid
from datetime import datetime
from enum import StrEnum
from typing import Any

from geoalchemy2 import Geography
from sqlalchemy import Enum as PgEnum
from sqlalchemy import ForeignKey, Index
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.types import TIMESTAMP, String

from app.models.base import UUIDAuditBase, enum_values


class IncidentType(StrEnum):
    ACCIDENT = "accident"
    BREAKDOWN = "breakdown"
    DELAY = "delay"
    SAFETY_CONCERN = "safety_concern"
    OTHER = "other"


class IncidentSeverity(StrEnum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"


class IncidentStatus(StrEnum):
    REPORTED = "reported"
    IN_REVIEW = "in_review"
    RESOLVED = "resolved"
    CLOSED = "closed"


class SosAlertStatus(StrEnum):
    ACTIVE = "active"
    ACKNOWLEDGED = "acknowledged"
    RESOLVED = "resolved"
    FALSE_ALARM = "false_alarm"


class Incident(UUIDAuditBase):
    __tablename__ = "incidents"

    trip_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("trips.id", ondelete="CASCADE"), nullable=False
    )
    reported_by: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    incident_type: Mapped[IncidentType] = mapped_column(
        PgEnum(IncidentType, name="incident_type", native_enum=True, values_callable=enum_values),
        nullable=False,
    )
    severity: Mapped[IncidentSeverity] = mapped_column(
        PgEnum(
            IncidentSeverity,
            name="incident_severity",
            native_enum=True,
            values_callable=enum_values,
        ),
        nullable=False,
    )
    description: Mapped[str] = mapped_column(String(2000), nullable=False)
    location: Mapped[Any | None] = mapped_column(
        Geography(geometry_type="POINT", srid=4326, spatial_index=False), nullable=True
    )
    status: Mapped[IncidentStatus] = mapped_column(
        PgEnum(
            IncidentStatus, name="incident_status", native_enum=True, values_callable=enum_values
        ),
        nullable=False,
        default=IncidentStatus.REPORTED,
    )
    resolved_by: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    resolved_at: Mapped[datetime | None] = mapped_column(TIMESTAMP(timezone=True), nullable=True)
    resolution_notes: Mapped[str | None] = mapped_column(String(1000), nullable=True)

    __table_args__ = (
        Index("ix_incidents_trip_id", "trip_id"),
        Index("ix_incidents_status", "status"),
    )


class SosAlert(UUIDAuditBase):
    __tablename__ = "sos_alerts"

    trip_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("trips.id", ondelete="CASCADE"), nullable=False
    )
    triggered_by: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    location: Mapped[Any | None] = mapped_column(
        Geography(geometry_type="POINT", srid=4326, spatial_index=False), nullable=True
    )
    status: Mapped[SosAlertStatus] = mapped_column(
        PgEnum(
            SosAlertStatus, name="sos_alert_status", native_enum=True, values_callable=enum_values
        ),
        nullable=False,
        default=SosAlertStatus.ACTIVE,
    )
    acknowledged_by: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    acknowledged_at: Mapped[datetime | None] = mapped_column(
        TIMESTAMP(timezone=True), nullable=True
    )
    resolved_by: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    resolved_at: Mapped[datetime | None] = mapped_column(TIMESTAMP(timezone=True), nullable=True)
    resolution_notes: Mapped[str | None] = mapped_column(String(1000), nullable=True)

    __table_args__ = (
        Index("ix_sos_alerts_trip_id", "trip_id"),
        Index("ix_sos_alerts_status", "status"),
    )
