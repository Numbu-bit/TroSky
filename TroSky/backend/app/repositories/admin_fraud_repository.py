"""Fraud flags for the admin dashboard: the filtered list, the records a
flag links to, and the figures behind ``/admin/fraud/stats``."""

from __future__ import annotations

import uuid
from collections.abc import Collection
from dataclasses import dataclass
from datetime import datetime
from typing import Any

from sqlalchemy import ColumnElement, Select, func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import aliased

from app.models.bookings import Booking
from app.models.fraud import (
    BlockedDevice,
    FraudFlag,
    FraudFlagEvent,
    FraudFlagStatus,
    FraudSeverity,
)
from app.models.identity import User, UserProfile
from app.models.payments import Payment, Wallet
from app.models.routes import Route
from app.models.trips import Trip


@dataclass(frozen=True, slots=True)
class FlagFilters:
    statuses: list[FraudFlagStatus] | None = None
    rules: list[str] | None = None
    severities: list[FraudSeverity] | None = None
    min_risk: int | None = None
    assigned_to: uuid.UUID | None = None
    unassigned: bool = False
    subject_user_id: uuid.UUID | None = None
    since: datetime | None = None
    until: datetime | None = None


@dataclass(frozen=True, slots=True)
class FlagRow:
    flag: FraudFlag
    subject_name: str | None
    assignee_name: str | None


SORTS = frozenset({"risk_score", "first_detected_at", "last_detected_at", "amount_at_risk"})


class AdminFraudRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    def _rows(self) -> Select[Any]:
        subject, assignee = aliased(UserProfile), aliased(UserProfile)
        return (
            select(FraudFlag, subject.full_name, assignee.full_name)
            .outerjoin(subject, subject.user_id == FraudFlag.subject_user_id)
            .outerjoin(assignee, assignee.user_id == FraudFlag.assigned_to)
        )

    async def list_flags(
        self, filters: FlagFilters, *, sort: str, descending: bool, limit: int, offset: int
    ) -> tuple[list[FlagRow], int]:
        conditions: list[ColumnElement[bool]] = []
        if filters.statuses:
            conditions.append(FraudFlag.status.in_(filters.statuses))
        if filters.rules:
            conditions.append(FraudFlag.rule.in_(filters.rules))
        if filters.severities:
            conditions.append(FraudFlag.severity.in_(filters.severities))
        if filters.min_risk is not None:
            conditions.append(FraudFlag.risk_score >= filters.min_risk)
        if filters.assigned_to is not None:
            conditions.append(FraudFlag.assigned_to == filters.assigned_to)
        if filters.unassigned:
            conditions.append(FraudFlag.assigned_to.is_(None))
        if filters.subject_user_id is not None:
            conditions.append(FraudFlag.subject_user_id == filters.subject_user_id)
        if filters.since is not None:
            conditions.append(FraudFlag.first_detected_at >= filters.since)
        if filters.until is not None:
            conditions.append(FraudFlag.first_detected_at < filters.until)
        total = int(
            await self._session.scalar(select(func.count(FraudFlag.id)).where(*conditions)) or 0
        )
        column = getattr(FraudFlag, sort)
        ordered = column.desc().nulls_last() if descending else column.asc().nulls_last()
        rows = await self._session.execute(
            self._rows()
            .where(*conditions)
            .order_by(ordered, FraudFlag.first_detected_at.desc(), FraudFlag.id)
            .limit(limit)
            .offset(offset)
        )
        return [FlagRow(*row) for row in rows.all()], total

    async def get(self, flag_id: uuid.UUID) -> FlagRow | None:
        row = (await self._session.execute(self._rows().where(FraudFlag.id == flag_id))).first()
        return FlagRow(*row) if row is not None else None

    async def timeline(self, flag_id: uuid.UUID) -> list[tuple[FraudFlagEvent, str | None]]:
        rows = await self._session.execute(
            select(FraudFlagEvent, UserProfile.full_name)
            .outerjoin(UserProfile, UserProfile.user_id == FraudFlagEvent.actor_id)
            .where(FraudFlagEvent.flag_id == flag_id)
            .order_by(FraudFlagEvent.created_at, FraudFlagEvent.id)
        )
        return list(rows.tuples().all())

    async def device_blocked(self, device_id: str) -> bool:
        found = await self._session.scalar(
            select(BlockedDevice.id).where(BlockedDevice.device_id == device_id)
        )
        return found is not None

    # ------------------------------------------------- what a flag links to
    async def users(self, ids: Collection[uuid.UUID]) -> list[tuple[Any, ...]]:
        if not ids:
            return []
        rows = await self._session.execute(
            select(
                User.id,
                UserProfile.full_name,
                User.phone_number,
                User.is_suspended,
                Wallet.frozen_at.is_not(None),
            )
            .outerjoin(UserProfile, UserProfile.user_id == User.id)
            .outerjoin(Wallet, Wallet.user_id == User.id)
            .where(User.id.in_(ids))
        )
        return [tuple(row) for row in rows.all()]

    async def trips(self, ids: Collection[uuid.UUID]) -> list[tuple[Any, ...]]:
        if not ids:
            return []
        rows = await self._session.execute(
            select(Trip.id, Route.name, Trip.scheduled_departure_at, Trip.status)
            .join(Route, Route.id == Trip.route_id)
            .where(Trip.id.in_(ids))
        )
        return [tuple(row) for row in rows.all()]

    async def bookings(self, ids: Collection[uuid.UUID]) -> list[tuple[Any, ...]]:
        if not ids:
            return []
        rows = await self._session.execute(
            select(
                Booking.id, Booking.booking_reference, Booking.status, Booking.fare_amount
            ).where(Booking.id.in_(ids))
        )
        return [tuple(row) for row in rows.all()]

    async def payments(self, ids: Collection[uuid.UUID]) -> list[tuple[Any, ...]]:
        if not ids:
            return []
        rows = await self._session.execute(
            select(
                Payment.id,
                Payment.internal_reference,
                Payment.amount,
                Payment.status,
                Payment.channel,
            ).where(Payment.id.in_(ids))
        )
        return [tuple(row) for row in rows.all()]

    # ------------------------------------------------------------- figures
    async def detected_by_rule(
        self, since: datetime, until: datetime
    ) -> list[tuple[str, int, int, int]]:
        """``(rule, detected, confirmed, false positives)`` for flags first
        raised in ``[since, until)``."""
        rows = await self._session.execute(
            select(
                FraudFlag.rule,
                func.count(),
                func.count().filter(FraudFlag.status == FraudFlagStatus.CONFIRMED),
                func.count().filter(FraudFlag.status == FraudFlagStatus.FALSE_POSITIVE),
            )
            .where(FraudFlag.first_detected_at >= since, FraudFlag.first_detected_at < until)
            .group_by(FraudFlag.rule)
        )
        return [(rule, int(n), int(yes), int(no)) for rule, n, yes, no in rows.all()]

    async def reviewed(self, since: datetime, until: datetime) -> tuple[int, int]:
        """Flags confirmed, and judged false positives, in ``[since, until)``."""
        row = (
            await self._session.execute(
                select(
                    func.count().filter(FraudFlag.status == FraudFlagStatus.CONFIRMED),
                    func.count().filter(FraudFlag.status == FraudFlagStatus.FALSE_POSITIVE),
                ).where(FraudFlag.reviewed_at >= since, FraudFlag.reviewed_at < until)
            )
        ).one()
        return int(row[0]), int(row[1])
