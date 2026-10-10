"""Database access for the log of what drivers did on their trips."""

from __future__ import annotations

import uuid
from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Any

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.driver_actions import ActedAs, DriverAction, DriverActionKind
from app.models.drivers import Driver
from app.models.identity import UserProfile


@dataclass(frozen=True, slots=True)
class DriverActionRow:
    action: DriverAction
    driver_name: str | None
    actor_name: str | None


class DriverActionRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def record(
        self,
        *,
        kind: DriverActionKind,
        trip_id: uuid.UUID,
        driver_id: uuid.UUID | None,
        acted_as: ActedAs,
        actor_id: uuid.UUID | None,
        booking_id: uuid.UUID | None = None,
        reason: str | None = None,
        details: dict[str, Any] | None = None,
    ) -> DriverAction:
        action = DriverAction(
            # The moment it happened, not the transaction's start (``now()``):
            # one request can record several, and the log must keep their order.
            created_at=datetime.now(UTC),
            kind=kind,
            trip_id=trip_id,
            driver_id=driver_id,
            acted_as=acted_as,
            actor_id=actor_id,
            booking_id=booking_id,
            reason=reason,
            details=details,
        )
        self._session.add(action)
        await self._session.flush()
        return action

    async def search(
        self,
        *,
        driver_id: uuid.UUID | None,
        trip_id: uuid.UUID | None,
        booking_id: uuid.UUID | None,
        kinds: list[DriverActionKind] | None,
        acted_as: ActedAs | None,
        since: datetime | None,
        until: datetime | None,
        limit: int,
        offset: int,
    ) -> tuple[list[DriverActionRow], int]:
        """Newest first."""
        conditions: list[Any] = []
        if driver_id is not None:
            conditions.append(DriverAction.driver_id == driver_id)
        if trip_id is not None:
            conditions.append(DriverAction.trip_id == trip_id)
        if booking_id is not None:
            conditions.append(DriverAction.booking_id == booking_id)
        if kinds:
            conditions.append(DriverAction.kind.in_(kinds))
        if acted_as is not None:
            conditions.append(DriverAction.acted_as == acted_as)
        if since is not None:
            conditions.append(DriverAction.created_at >= since)
        if until is not None:
            conditions.append(DriverAction.created_at < until)

        total = (
            await self._session.execute(
                select(func.count()).select_from(DriverAction).where(*conditions)
            )
        ).scalar_one()
        driver_profile = select(UserProfile.full_name).join(
            Driver, Driver.user_id == UserProfile.user_id
        )
        rows = await self._session.execute(
            select(
                DriverAction,
                driver_profile.where(Driver.id == DriverAction.driver_id)
                .scalar_subquery()
                .label("driver_name"),
                select(UserProfile.full_name)
                .where(UserProfile.user_id == DriverAction.actor_id)
                .scalar_subquery()
                .label("actor_name"),
            )
            .where(*conditions)
            .order_by(DriverAction.created_at.desc(), DriverAction.id.desc())
            .limit(limit)
            .offset(offset)
        )
        return [
            DriverActionRow(action=action, driver_name=driver_name, actor_name=actor_name)
            for action, driver_name, actor_name in rows.all()
        ], total
