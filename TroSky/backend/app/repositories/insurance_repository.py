"""What the insurance rule reads: confirmed dates, past warnings, who to tell."""

from __future__ import annotations

import uuid
from collections.abc import Collection
from datetime import date

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.drivers import (
    ApprovalStatus,
    DocumentStatus,
    DocumentType,
    DriverAssignment,
    DriverDocument,
    DriverStatusHistory,
)
from app.models.identity import UserProfile
from app.models.notifications import Notification
from app.models.vehicles import Fleet, FleetOwner, VehicleDocument


class InsuranceRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def latest_expiries(
        self, driver_ids: Collection[uuid.UUID] | None = None
    ) -> dict[uuid.UUID, date]:
        """Each driver's latest confirmed insurance date, from their own
        documents and those of the vehicles they are assigned to. A driver
        with no confirmed date isn't listed."""
        own = (
            select(DriverDocument.driver_id, func.max(DriverDocument.expiry_date))
            .where(
                DriverDocument.document_type == DocumentType.VEHICLE_INSURANCE,
                DriverDocument.status == DocumentStatus.APPROVED,
                DriverDocument.expiry_date.is_not(None),
            )
            .group_by(DriverDocument.driver_id)
        )
        assigned = (
            select(DriverAssignment.driver_id, func.max(VehicleDocument.expiry_date))
            .join(VehicleDocument, VehicleDocument.vehicle_id == DriverAssignment.vehicle_id)
            .where(
                DriverAssignment.is_active.is_(True),
                VehicleDocument.document_type == DocumentType.VEHICLE_INSURANCE,
                VehicleDocument.status == DocumentStatus.APPROVED,
                VehicleDocument.expiry_date.is_not(None),
            )
            .group_by(DriverAssignment.driver_id)
        )
        if driver_ids is not None:
            own = own.where(DriverDocument.driver_id.in_(driver_ids))
            assigned = assigned.where(DriverAssignment.driver_id.in_(driver_ids))
        latest: dict[uuid.UUID, date] = {}
        for query in (own, assigned):
            for driver_id, expiry in (await self._session.execute(query)).all():
                latest[driver_id] = max(expiry, latest.get(driver_id, expiry))
        return latest

    async def drivers_of_vehicle(self, vehicle_id: uuid.UUID) -> list[uuid.UUID]:
        result = await self._session.execute(
            select(DriverAssignment.driver_id).where(
                DriverAssignment.vehicle_id == vehicle_id,
                DriverAssignment.is_active.is_(True),
            )
        )
        return list(result.scalars().all())

    async def fleet_owners_of_driver(self, driver_id: uuid.UUID) -> list[uuid.UUID]:
        """The accounts of the fleet owners whose vehicles this driver drives."""
        result = await self._session.execute(
            select(FleetOwner.user_id)
            .join(Fleet, Fleet.fleet_owner_id == FleetOwner.id)
            .join(DriverAssignment, DriverAssignment.fleet_id == Fleet.id)
            .where(DriverAssignment.driver_id == driver_id, DriverAssignment.is_active.is_(True))
            .distinct()
        )
        return list(result.scalars().all())

    async def full_name(self, user_id: uuid.UUID) -> str | None:
        name: str | None = await self._session.scalar(
            select(UserProfile.full_name).where(UserProfile.user_id == user_id)
        )
        return name

    async def last_suspension_reason(self, driver_id: uuid.UUID) -> str | None:
        return await self._session.scalar(
            select(DriverStatusHistory.reason)
            .where(
                DriverStatusHistory.driver_id == driver_id,
                DriverStatusHistory.to_status == ApprovalStatus.SUSPENDED,
            )
            .order_by(DriverStatusHistory.changed_at.desc())
            .limit(1)
        )

    async def warning_days_sent(
        self, user_id: uuid.UUID, *, action: str, expiry: date
    ) -> list[int]:
        """Which days' warnings this person has had about this expiry date."""
        result = await self._session.execute(
            select(Notification.data).where(
                Notification.user_id == user_id,
                Notification.data.contains({"action": action, "expiry_date": expiry.isoformat()}),
            )
        )
        return [int(data["day"]) for data in result.scalars().all()]
