"""The admin dashboard's operational views: the alerts feed, global search,
SOS details and trip replay. Each shows only what the caller's permissions
cover."""

from __future__ import annotations

import uuid
from collections.abc import Awaitable, Callable
from dataclasses import dataclass, field
from datetime import UTC, date, datetime, time, timedelta
from decimal import Decimal
from itertools import pairwise
from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ForbiddenError, NotFoundError
from app.core.permissions import Permission, Principal
from app.models.feedback import ComplaintPriority
from app.models.fraud import FraudSeverity
from app.models.safety import SosAlert, SosEscalation
from app.models.trips import Trip
from app.repositories.admin_complaints_repository import (
    AdminComplaintsRepository,
    ComplaintFilters,
)
from app.repositories.admin_fraud_repository import AdminFraudRepository, FlagFilters
from app.repositories.admin_live_repository import AdminLiveRepository, Hit, Point
from app.repositories.safety_repository import SosAlertRepository
from app.repositories.trip_repository import TripRepository
from app.repositories.trip_view_repository import TripSummary, TripViewRepository
from app.schemas.admin_workflow import AlertSeverity, AlertType, SearchKind
from app.services.fraud_service import HIGH_RISK, OPEN_FLAGS
from app.services.system_settings_service import EscalationContact, admin_settings
from app.utilities.geo import haversine_distance_km, wkb_to_latlng

# Per alert type; the feed is for acting on, not for archaeology.
ALERT_LIMIT_PER_TYPE = 200
EXPIRY_WARNING_DAYS = 30
EXPIRY_SOON_DAYS = 7
_SEVERITY_ORDER = {"critical": 0, "high": 1, "medium": 2, "low": 3}
_COMPLAINT_SEVERITY: dict[ComplaintPriority, AlertSeverity] = {
    ComplaintPriority.URGENT: "high",
    ComplaintPriority.HIGH: "high",
    ComplaintPriority.MEDIUM: "medium",
    ComplaintPriority.LOW: "low",
}
TRACK_MAX_POINTS = 20_000


# The permissions behind each alert type and each kind of search result.
ALERT_PERMISSIONS = (
    Permission.SOS_REVIEW,
    Permission.COMPLAINTS_MANAGE,
    Permission.DRIVERS_APPROVE,
    Permission.VEHICLES_APPROVE,
    Permission.FRAUD_VIEW,
    Permission.FRAUD_MANAGE,
)
SEARCH_PERMISSIONS: dict[SearchKind, tuple[Permission, ...]] = {
    "users": (Permission.USERS_MANAGE, Permission.USERS_SUSPEND),
    "drivers": (Permission.DRIVERS_APPROVE, Permission.TRIPS_MONITOR_LIVE),
    "vehicles": (Permission.VEHICLES_APPROVE, Permission.TRIPS_MONITOR_LIVE),
    "trips": (Permission.TRIPS_MANAGE, Permission.TRIPS_MONITOR_LIVE),
    "bookings": (Permission.BOOKINGS_VIEW_ANY,),
    "payments": (Permission.PAYMENTS_REVIEW, Permission.REFUNDS_APPROVE),
}


@dataclass(frozen=True, slots=True)
class Alert:
    type: AlertType
    severity: AlertSeverity
    title: str
    entity_type: str
    entity_id: uuid.UUID
    since: datetime
    details: dict[str, Any] = field(default_factory=dict)


@dataclass(frozen=True, slots=True)
class SosTrip:
    summary: TripSummary
    driver_phone: str | None
    fleet_owner_name: str | None
    fleet_owner_phone: str | None
    last_position: Point | None


@dataclass(frozen=True, slots=True)
class SosDetail:
    alert: SosAlert
    latitude: float | None
    longitude: float | None
    triggered_by_name: str | None
    triggered_by_phone: str
    trip: SosTrip | None
    escalations: list[tuple[SosEscalation, str | None]]
    escalation_contacts: list[EscalationContact]


@dataclass(frozen=True, slots=True)
class TripTrack:
    trip: Trip
    points: list[Point]
    truncated: bool
    distance_km: Decimal
    max_speed_kmh: Decimal | None


def _document_name(document_type: str) -> str:
    return document_type.replace("_", " ").capitalize()


class AdminOpsService:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session
        self._live = AdminLiveRepository(session)

    # ------------------------------------------------------------- alerts
    async def alerts(
        self, principal: Principal, *, limit: int
    ) -> tuple[list[Alert], dict[str, int]]:
        """Everything waiting for someone, most severe first and then
        oldest: SOS nobody has picked up, complaints past their due time,
        documents expiring within 30 days (or expired), and approvals
        waiting longer than the approval target."""
        now = datetime.now(UTC)
        values = await admin_settings(self._session)
        alerts: list[Alert] = []
        counts: dict[str, int] = {}
        if principal.has_permission(Permission.SOS_REVIEW):
            active, counts["sos_active"] = await self._live.active_sos(limit=ALERT_LIMIT_PER_TYPE)
            alerts.extend(
                Alert(
                    type="sos_active",
                    severity="critical",
                    title=f"SOS from {sos.name or sos.phone}",
                    entity_type="sos_alert",
                    entity_id=sos.id,
                    since=sos.raised_at,
                    details={
                        "trip_id": sos.trip_id,
                        "triggered_by": sos.triggered_by,
                        "phone_number": sos.phone,
                    },
                )
                for sos in active
            )
        if principal.has_permission(Permission.COMPLAINTS_MANAGE):
            late, counts["complaint_overdue"] = await AdminComplaintsRepository(
                self._session
            ).list_complaints(
                ComplaintFilters(overdue=True),
                sla_hours=values.complaint_sla_hours,
                now=now,
                sort="due_at",
                descending=False,
                limit=ALERT_LIMIT_PER_TYPE,
                offset=0,
            )
            alerts.extend(
                Alert(
                    type="complaint_overdue",
                    severity=_COMPLAINT_SEVERITY[row.complaint.priority],
                    title=f"Complaint overdue: {row.complaint.subject}",
                    entity_type="complaint",
                    entity_id=row.complaint.id,
                    since=row.due_at,
                    details={
                        "priority": row.complaint.priority.value,
                        "category": row.complaint.category.value,
                        "status": row.complaint.status.value,
                        "assigned_to": row.complaint.assigned_to,
                        "assignee_name": row.assignee_name,
                    },
                )
                for row in late
            )
        drivers = principal.has_permission(Permission.DRIVERS_APPROVE)
        vehicles = principal.has_permission(Permission.VEHICLES_APPROVE)
        if drivers or vehicles:
            alerts.extend(await self._document_alerts(now.date(), drivers, vehicles, counts))
            alerts.extend(
                await self._approval_alerts(
                    now, values.approval_target_hours, drivers, vehicles, counts
                )
            )
        if principal.has_permission(Permission.FRAUD_VIEW, Permission.FRAUD_MANAGE):
            alerts.extend(await self._fraud_alerts(counts))
        alerts.sort(key=lambda alert: (_SEVERITY_ORDER[alert.severity], alert.since))
        return alerts[:limit], counts

    async def _fraud_alerts(self, counts: dict[str, int]) -> list[Alert]:
        """Fraud flags with a high risk score that are still open."""
        rows, counts["fraud_high_risk"] = await AdminFraudRepository(self._session).list_flags(
            FlagFilters(statuses=list(OPEN_FLAGS), min_risk=HIGH_RISK),
            sort="risk_score",
            descending=True,
            limit=ALERT_LIMIT_PER_TYPE,
            offset=0,
        )
        return [
            Alert(
                type="fraud_high_risk",
                severity="critical" if row.flag.severity == FraudSeverity.CRITICAL else "high",
                title=f"Possible fraud: {row.flag.summary}"[:200],
                entity_type="fraud_flag",
                entity_id=row.flag.id,
                since=row.flag.first_detected_at,
                details={
                    "rule": row.flag.rule,
                    "risk_score": row.flag.risk_score,
                    "amount_at_risk": row.flag.amount_at_risk,
                    "subject_user_id": row.flag.subject_user_id,
                    "status": row.flag.status.value,
                },
            )
            for row in rows
        ]

    async def _document_alerts(
        self, today: date, drivers: bool, vehicles: bool, counts: dict[str, int]
    ) -> list[Alert]:
        documents, counts["document_expiring"] = await self._live.expiring_documents(
            until=today + timedelta(days=EXPIRY_WARNING_DAYS),
            drivers=drivers,
            vehicles=vehicles,
            limit=ALERT_LIMIT_PER_TYPE,
        )
        alerts = []
        for document in documents:
            expired = document.expires_on < today
            severity: AlertSeverity
            if expired:
                severity, when = "high", f"expired on {document.expires_on:%d %b %Y}"
            else:
                soon = document.expires_on <= today + timedelta(days=EXPIRY_SOON_DAYS)
                severity = "medium" if soon else "low"
                when = f"expires on {document.expires_on:%d %b %Y}"
            alerts.append(
                Alert(
                    type="document_expiring",
                    severity=severity,
                    title=(
                        f"{_document_name(document.document_type)} for "
                        f"{document.owner_label} {when}"
                    ),
                    entity_type=document.owner_type,
                    entity_id=document.owner_id,
                    since=datetime.combine(document.expires_on, time.min, tzinfo=UTC),
                    details={
                        "document_type": document.document_type,
                        "expires_on": document.expires_on.isoformat(),
                        "expired": expired,
                    },
                )
            )
        return alerts

    async def _approval_alerts(
        self,
        now: datetime,
        target_hours: int,
        drivers: bool,
        vehicles: bool,
        counts: dict[str, int],
    ) -> list[Alert]:
        waiting, counts["approval_waiting"] = await self._live.waiting_approvals(
            waiting_before=now - timedelta(hours=target_hours),
            drivers=drivers,
            vehicles=vehicles,
            limit=ALERT_LIMIT_PER_TYPE,
        )
        return [
            Alert(
                type="approval_waiting",
                severity="medium",
                title=f"{item.kind.capitalize()} {item.label} waiting for approval",
                entity_type=item.kind,
                entity_id=item.id,
                since=item.waiting_since,
                details={
                    "status": item.status.value,
                    "waiting_hours": int((now - item.waiting_since).total_seconds() // 3600),
                    "target_hours": target_hours,
                },
            )
            for item in waiting
        ]

    # ------------------------------------------------------------- search
    async def search(
        self, principal: Principal, query: str, *, limit: int
    ) -> tuple[list[SearchKind], dict[SearchKind, list[Hit]]]:
        """Users, drivers, vehicles, trips, bookings and payments matching
        ``query`` -- each kind only for an admin who may see it."""
        searches: dict[SearchKind, Callable[..., Awaitable[list[Hit]]]] = {
            "users": self._live.search_users,
            "drivers": self._live.search_drivers,
            "vehicles": self._live.search_vehicles,
            "trips": self._live.search_trips,
            "bookings": self._live.search_bookings,
            "payments": self._live.search_payments,
        }
        searched: list[SearchKind] = [
            kind
            for kind, permissions in SEARCH_PERMISSIONS.items()
            if principal.has_permission(*permissions)
        ]
        if not searched:
            raise ForbiddenError("Searching needs a permission to see at least one kind of record.")
        results: dict[SearchKind, list[Hit]] = {kind: [] for kind in searches}
        for kind in searched:
            results[kind] = await searches[kind](query, limit=limit)
        return searched, results

    # ---------------------------------------------------------------- SOS
    async def sos_detail(self, alert_id: uuid.UUID) -> SosDetail:
        alert = await SosAlertRepository(self._session).get_by_id(alert_id)
        if alert is None:
            raise NotFoundError("SOS alert not found.")
        position = wkb_to_latlng(alert.location)
        person = await self._live.person(alert.triggered_by)
        name, phone = person if person is not None else (None, "")
        trip = None
        if alert.trip_id is not None:
            summary = (
                await TripViewRepository(self._session).summaries_by_ids([alert.trip_id])
            ).get(alert.trip_id)
            if summary is not None:
                driver = (
                    await self._live.person(summary.driver_user_id)
                    if summary.driver_user_id is not None
                    else None
                )
                owner = (
                    await self._live.fleet_owner(summary.fleet_id)
                    if summary.fleet_id is not None
                    else None
                )
                trip = SosTrip(
                    summary=summary,
                    driver_phone=driver[1] if driver else None,
                    fleet_owner_name=owner[0] if owner else None,
                    fleet_owner_phone=owner[1] if owner else None,
                    last_position=await self._live.last_point(alert.trip_id),
                )
        return SosDetail(
            alert=alert,
            latitude=position[0] if position else None,
            longitude=position[1] if position else None,
            triggered_by_name=name,
            triggered_by_phone=phone,
            trip=trip,
            escalations=await self._live.escalations(alert.id),
            escalation_contacts=(await admin_settings(self._session)).sos_escalation_contacts,
        )

    # -------------------------------------------------------------- track
    async def track(
        self,
        trip_id: uuid.UUID,
        *,
        since: datetime | None,
        until: datetime | None,
        limit: int = TRACK_MAX_POINTS,
    ) -> TripTrack:
        """A trip's recorded positions, oldest first, for replay. Positions
        are kept for ``GPS_RAW_RETENTION_DAYS``."""
        trip = await TripRepository(self._session).get_by_id(trip_id)
        if trip is None:
            raise NotFoundError("Trip not found.")
        points = await self._live.track(trip_id, since=since, until=until, limit=limit)
        truncated = len(points) > limit
        points = points[:limit]
        distance = sum(
            (
                haversine_distance_km(a.latitude, a.longitude, b.latitude, b.longitude)
                for a, b in pairwise(points)
            ),
            0.0,
        )
        speeds = [point.speed_kmh for point in points if point.speed_kmh is not None]
        return TripTrack(
            trip=trip,
            points=points,
            truncated=truncated,
            distance_km=Decimal(str(round(distance, 3))),
            max_speed_kmh=max(speeds) if speeds else None,
        )
