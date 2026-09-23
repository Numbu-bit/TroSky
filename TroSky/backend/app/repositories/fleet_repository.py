"""Database access for fleet owners and fleets."""

from __future__ import annotations

import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.drivers import ApprovalStatus
from app.models.vehicles import Fleet, FleetOwner


class FleetOwnerRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get_by_id(self, fleet_owner_id: uuid.UUID) -> FleetOwner | None:
        result = await self._session.execute(
            select(FleetOwner).where(FleetOwner.id == fleet_owner_id)
        )
        return result.scalar_one_or_none()

    async def get_by_user_id(self, user_id: uuid.UUID) -> FleetOwner | None:
        result = await self._session.execute(
            select(FleetOwner).where(FleetOwner.user_id == user_id)
        )
        return result.scalar_one_or_none()

    async def create(
        self, *, user_id: uuid.UUID, business_name: str, business_registration_number: str | None
    ) -> FleetOwner:
        owner = FleetOwner(
            user_id=user_id,
            business_name=business_name,
            business_registration_number=business_registration_number,
        )
        self._session.add(owner)
        await self._session.flush()
        return owner

    async def list_by_status(
        self, status: ApprovalStatus, *, limit: int, offset: int
    ) -> tuple[list[FleetOwner], int]:
        count_result = await self._session.execute(
            select(FleetOwner.id).where(FleetOwner.status == status)
        )
        total = len(count_result.scalars().all())
        result = await self._session.execute(
            select(FleetOwner)
            .where(FleetOwner.status == status)
            .order_by(FleetOwner.created_at)
            .limit(limit)
            .offset(offset)
        )
        return list(result.scalars().all()), total

    async def set_status(self, owner: FleetOwner, *, new_status: ApprovalStatus) -> None:
        owner.status = new_status
        await self._session.flush()


class FleetRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get_by_id(self, fleet_id: uuid.UUID) -> Fleet | None:
        result = await self._session.execute(select(Fleet).where(Fleet.id == fleet_id))
        return result.scalar_one_or_none()

    async def list_for_owner(self, fleet_owner_id: uuid.UUID) -> list[Fleet]:
        result = await self._session.execute(
            select(Fleet).where(Fleet.fleet_owner_id == fleet_owner_id).order_by(Fleet.created_at)
        )
        return list(result.scalars().all())

    async def create(
        self, *, fleet_owner_id: uuid.UUID, name: str, description: str | None
    ) -> Fleet:
        fleet = Fleet(fleet_owner_id=fleet_owner_id, name=name, description=description)
        self._session.add(fleet)
        await self._session.flush()
        return fleet

    async def update(self, fleet: Fleet, **fields: object) -> None:
        for key, value in fields.items():
            if value is not None:
                setattr(fleet, key, value)
        await self._session.flush()
