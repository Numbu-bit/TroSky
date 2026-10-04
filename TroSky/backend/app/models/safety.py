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
    PASSENGER_ISSUE = "passenger_issue"
    ROAD_HAZARD = "road_hazard"
    OTHER = "other"


class IncidentSeverity(StrEnum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"


# What an incident is filed as when the reporter does not choose: drivers
# reporting from the road should not have to triage. Ops can still change
# their view of it while reviewing.
DEFAULT_SEVERITY: dict[IncidentType, IncidentSeverity] = {
    IncidentType.ACCIDENT: IncidentSeverity.HIGH,
    IncidentType.SAFETY_CONCERN: IncidentSeverity.HIGH,
    IncidentType.BREAKDOWN: IncidentSeverity.MEDIUM,
    IncidentType.PASSENGER_ISSUE: IncidentSeverity.MEDIUM,
    IncidentType.ROAD_HAZARD: IncidentSeverity.MEDIUM,
    IncidentType.DELAY: IncidentSeverity.LOW,
    IncidentType.OTHER: IncidentSeverity.LOW,
}


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


class EscalationContactType(StrEnum):
    POLICE = "police"
    AMBULANCE = "ambulance"
    FIRE_SERVICE = "fire_service"
    FLEET_OWNER = "fleet_owner"
    EMERGENCY_CONTACT = "emergency_contact"  # one the passenger saved
    OTHER = "other"


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
    # One photo of the scene, in the private bucket; served as a signed URL.
    photo_storage_key: Mapped[str | None] = mapped_column(String(500), nullable=True)
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

    # NULL for an alert raised outside any trip (the Home screen's SOS button).
    trip_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("trips.id", ondelete="CASCADE"), nullable=True
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


class SosEscalation(UUIDAuditBase):
    """Who the operations team contacted about an SOS alert, and when."""

    __tablename__ = "sos_escalations"

    sos_alert_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("sos_alerts.id", ondelete="CASCADE"), nullable=False
    )
    contact_type: Mapped[EscalationContactType] = mapped_column(
        PgEnum(
            EscalationContactType,
            name="escalation_contact_type",
            native_enum=True,
            values_callable=enum_values,
        ),
        nullable=False,
    )
    contact_name: Mapped[str | None] = mapped_column(String(100), nullable=True)
    phone_number: Mapped[str | None] = mapped_column(String(20), nullable=True)
    contacted_at: Mapped[datetime] = mapped_column(TIMESTAMP(timezone=True), nullable=False)
    notes: Mapped[str | None] = mapped_column(String(1000), nullable=True)
    logged_by: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )

    __table_args__ = (Index("ix_sos_escalations_sos_alert_id", "sos_alert_id", "contacted_at"),)
