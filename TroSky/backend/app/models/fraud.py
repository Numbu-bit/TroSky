"""Fraud detection: the rules, the flags they raise, what was done about
each, and the evidence some rules need recorded as it happens.

* ``FraudRule`` -- an admin's changes to a rule's threshold, time window,
  severity or on/off switch. The rules themselves, and their defaults, are
  in ``app.services.fraud_rules``; a rule without a row runs on its
  defaults.
* ``FraudFlag`` -- something a rule found, for an admin to look into. Its
  ``fingerprint`` names the incident (this ticket, this user on this day),
  so running the detection again updates the flag rather than repeating it.
* ``FraudFlagEvent`` -- the flag's timeline: detected, detected again,
  assigned, its status changed, an action taken.
* ``BlockedDevice`` -- a phone no one may sign in from.
* ``TicketScanAttempt`` -- a ticket refused at boarding because it had been
  used already or was for another trip: kept for the ticket-reuse rule,
  although the scan itself failed.
"""

from __future__ import annotations

import uuid
from datetime import datetime
from decimal import Decimal
from enum import StrEnum
from typing import Any

from sqlalchemy import Boolean, CheckConstraint, ForeignKey, Index, UniqueConstraint
from sqlalchemy import Enum as PgEnum
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.types import TIMESTAMP, Integer, Numeric, String

from app.models.base import Base, UUIDAuditBase, enum_values


class FraudSeverity(StrEnum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"


class FraudFlagStatus(StrEnum):
    OPEN = "open"
    INVESTIGATING = "investigating"
    CONFIRMED = "confirmed"
    FALSE_POSITIVE = "false_positive"


class TicketScanOutcome(StrEnum):
    ALREADY_USED = "already_used"
    WRONG_TRIP = "wrong_trip"


def _severity_column() -> Any:
    return PgEnum(
        FraudSeverity, name="fraud_severity", native_enum=True, values_callable=enum_values
    )


class FraudRule(Base):
    __tablename__ = "fraud_rules"

    key: Mapped[str] = mapped_column(String(60), primary_key=True)
    enabled: Mapped[bool] = mapped_column(Boolean, nullable=False)
    threshold: Mapped[Decimal] = mapped_column(Numeric(14, 4), nullable=False)
    window_minutes: Mapped[int] = mapped_column(Integer, nullable=False)
    severity: Mapped[FraudSeverity] = mapped_column(_severity_column(), nullable=False)
    updated_by: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    updated_at: Mapped[datetime] = mapped_column(
        TIMESTAMP(timezone=True), nullable=False, server_default="now()"
    )

    __table_args__ = (
        CheckConstraint("threshold >= 0", name="threshold_non_negative"),
        CheckConstraint("window_minutes > 0", name="window_minutes_positive"),
    )


class FraudFlag(UUIDAuditBase):
    __tablename__ = "fraud_flags"

    rule: Mapped[str] = mapped_column(String(60), nullable=False)
    fingerprint: Mapped[str] = mapped_column(String(200), nullable=False)
    severity: Mapped[FraudSeverity] = mapped_column(_severity_column(), nullable=False)
    risk_score: Mapped[int] = mapped_column(Integer, nullable=False)
    # What the flag is about: a user, ticket, trip, driver, device or phone
    # number (the last two are not rows, hence a string id).
    entity_type: Mapped[str] = mapped_column(String(30), nullable=False)
    entity_id: Mapped[str] = mapped_column(String(100), nullable=False)
    # The account mainly concerned, when there is one: whom an action hits.
    subject_user_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    summary: Mapped[str] = mapped_column(String(500), nullable=False)
    amount_at_risk: Mapped[Decimal | None] = mapped_column(Numeric(12, 2), nullable=True)
    # The value the rule measured (failures, accounts, km...), to tell when
    # it has grown since the flag was raised.
    observed: Mapped[Decimal] = mapped_column(Numeric(14, 4), nullable=False)
    # The facts behind the flag, and the users, trips, bookings and
    # payments it links (``{"links": {"users": [...], ...}}``).
    evidence: Mapped[dict[str, Any]] = mapped_column(JSONB, nullable=False, default=dict)
    status: Mapped[FraudFlagStatus] = mapped_column(
        PgEnum(
            FraudFlagStatus,
            name="fraud_flag_status",
            native_enum=True,
            values_callable=enum_values,
        ),
        nullable=False,
        default=FraudFlagStatus.OPEN,
    )
    assigned_to: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    reviewed_by: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    reviewed_at: Mapped[datetime | None] = mapped_column(TIMESTAMP(timezone=True), nullable=True)
    review_reason: Mapped[str | None] = mapped_column(String(1000), nullable=True)
    first_detected_at: Mapped[datetime] = mapped_column(TIMESTAMP(timezone=True), nullable=False)
    last_detected_at: Mapped[datetime] = mapped_column(TIMESTAMP(timezone=True), nullable=False)
    occurrences: Mapped[int] = mapped_column(Integer, nullable=False, default=1)

    __table_args__ = (
        UniqueConstraint("fingerprint", name="uq_fraud_flags_fingerprint"),
        CheckConstraint("risk_score BETWEEN 0 AND 100", name="risk_score_range"),
        Index("ix_fraud_flags_status", "status"),
        Index("ix_fraud_flags_rule", "rule"),
        Index("ix_fraud_flags_subject_user_id", "subject_user_id"),
        Index("ix_fraud_flags_first_detected_at", "first_detected_at"),
    )


class FraudFlagEvent(UUIDAuditBase):
    __tablename__ = "fraud_flag_events"

    flag_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("fraud_flags.id", ondelete="CASCADE"), nullable=False
    )
    # detected, detected_again, assigned, status_changed, action
    kind: Mapped[str] = mapped_column(String(30), nullable=False)
    # None: the detection job.
    actor_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    details: Mapped[dict[str, Any]] = mapped_column(JSONB, nullable=False, default=dict)

    __table_args__ = (Index("ix_fraud_flag_events_flag_id", "flag_id", "created_at"),)


class BlockedDevice(UUIDAuditBase):
    __tablename__ = "blocked_devices"

    device_id: Mapped[str] = mapped_column(String(255), nullable=False)
    reason: Mapped[str] = mapped_column(String(500), nullable=False)
    blocked_by: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    flag_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("fraud_flags.id", ondelete="SET NULL"), nullable=True
    )

    __table_args__ = (UniqueConstraint("device_id", name="uq_blocked_devices_device_id"),)


class TicketScanAttempt(UUIDAuditBase):
    __tablename__ = "ticket_scan_attempts"

    ticket_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("tickets.id", ondelete="CASCADE"), nullable=False
    )
    # The trip the ticket was presented on.
    trip_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("trips.id", ondelete="CASCADE"), nullable=False
    )
    scanned_by: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    outcome: Mapped[TicketScanOutcome] = mapped_column(
        PgEnum(
            TicketScanOutcome,
            name="ticket_scan_outcome",
            native_enum=True,
            values_callable=enum_values,
        ),
        nullable=False,
    )

    __table_args__ = (Index("ix_ticket_scan_attempts_ticket_id", "ticket_id", "created_at"),)
