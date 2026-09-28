"""Database access for incidents and SOS alerts."""

from __future__ import annotations

import uuid
from datetime import UTC, datetime

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.safety import (
    Incident,
    IncidentSeverity,
    IncidentStatus,
    IncidentType,
    SosAlert,
    SosAlertStatus,
)
from app.utilities.geo import latlng_to_wkt


class IncidentRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def create(
        self,
        *,
        trip_id: uuid.UUID,
        reported_by: uuid.UUID,
        incident_type: IncidentType,
        severity: IncidentSeverity,
        description: str,
        latitude: float | None,
        longitude: float | None,
    ) -> Incident:
        incident = Incident(
            trip_id=trip_id,
            reported_by=reported_by,
            incident_type=incident_type,
            severity=severity,
            description=description,
            location=latlng_to_wkt(latitude, longitude)
            if latitude is not None and longitude is not None
            else None,
        )
        self._session.add(incident)
        await self._session.flush()
        return incident

    async def get_by_id(self, incident_id: uuid.UUID) -> Incident | None:
        result = await self._session.execute(select(Incident).where(Incident.id == incident_id))
        return result.scalar_one_or_none()

    async def get_for_update(self, incident_id: uuid.UUID) -> Incident | None:
        result = await self._session.execute(
            select(Incident).where(Incident.id == incident_id).with_for_update()
        )
        return result.scalar_one_or_none()

    async def list_all(
        self, *, status: IncidentStatus | None, limit: int, offset: int
    ) -> tuple[list[Incident], int]:
        stmt = select(Incident)
        if status is not None:
            stmt = stmt.where(Incident.status == status)
        count_result = await self._session.execute(
            select(func.count()).select_from(stmt.subquery())
        )
        total = count_result.scalar_one()
        result = await self._session.execute(
            stmt.order_by(Incident.created_at.desc()).limit(limit).offset(offset)
        )
        return list(result.scalars().all()), total

    async def set_status(
        self,
        incident: Incident,
        *,
        new_status: IncidentStatus,
        resolved_by: uuid.UUID | None = None,
        resolution_notes: str | None = None,
    ) -> None:
        incident.status = new_status
        if resolved_by is not None:
            incident.resolved_by = resolved_by
            incident.resolved_at = datetime.now(UTC)
            incident.resolution_notes = resolution_notes
        await self._session.flush()


class SosAlertRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def create(
        self,
        *,
        trip_id: uuid.UUID,
        triggered_by: uuid.UUID,
        latitude: float | None,
        longitude: float | None,
    ) -> SosAlert:
        alert = SosAlert(
            trip_id=trip_id,
            triggered_by=triggered_by,
            location=latlng_to_wkt(latitude, longitude)
            if latitude is not None and longitude is not None
            else None,
        )
        self._session.add(alert)
        await self._session.flush()
        return alert

    async def get_by_id(self, alert_id: uuid.UUID) -> SosAlert | None:
        result = await self._session.execute(select(SosAlert).where(SosAlert.id == alert_id))
        return result.scalar_one_or_none()

    async def get_for_update(self, alert_id: uuid.UUID) -> SosAlert | None:
        result = await self._session.execute(
            select(SosAlert).where(SosAlert.id == alert_id).with_for_update()
        )
        return result.scalar_one_or_none()

    async def list_all(
        self, *, status: SosAlertStatus | None, limit: int, offset: int
    ) -> tuple[list[SosAlert], int]:
        stmt = select(SosAlert)
        if status is not None:
            stmt = stmt.where(SosAlert.status == status)
        count_result = await self._session.execute(
            select(func.count()).select_from(stmt.subquery())
        )
        total = count_result.scalar_one()
        result = await self._session.execute(
            stmt.order_by(SosAlert.created_at.desc()).limit(limit).offset(offset)
        )
        return list(result.scalars().all()), total

    async def acknowledge(self, alert: SosAlert, *, acknowledged_by: uuid.UUID) -> None:
        alert.status = SosAlertStatus.ACKNOWLEDGED
        alert.acknowledged_by = acknowledged_by
        alert.acknowledged_at = datetime.now(UTC)
        await self._session.flush()

    async def resolve(
        self,
        alert: SosAlert,
        *,
        resolved_by: uuid.UUID,
        resolution_notes: str | None,
        status: SosAlertStatus,
    ) -> None:
        alert.status = status
        alert.resolved_by = resolved_by
        alert.resolved_at = datetime.now(UTC)
        alert.resolution_notes = resolution_notes
        await self._session.flush()
