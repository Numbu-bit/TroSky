"""Money read models for the admin dashboard: every payment, and revenue
broken down by route, fleet and hour of the day."""

from __future__ import annotations

import uuid
from collections.abc import Collection
from dataclasses import dataclass
from datetime import datetime
from decimal import Decimal
from typing import Any, Literal

from sqlalchemy import ColumnElement, Select, and_, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import aliased

from app.models.bookings import Booking
from app.models.identity import User, UserProfile
from app.models.payments import (
    Payment,
    PaymentPurpose,
    PaymentStatus,
    WithdrawalRequest,
    WithdrawalStatus,
)
from app.models.routes import Route, Stop
from app.models.trips import Trip, TripVehicleAssignment
from app.models.vehicles import Fleet, Vehicle
from app.providers.payments.base import PaymentChannel
from app.repositories.admin_analytics_repository import TIMEZONE

COLLECTED = (PaymentStatus.SUCCESSFUL, PaymentStatus.PARTIALLY_REFUNDED, PaymentStatus.REFUNDED)
Breakdown = Literal["route", "fleet", "hour"]


@dataclass(frozen=True, slots=True)
class PaymentRow:
    payment_id: uuid.UUID
    internal_reference: str
    provider_reference: str | None
    purpose: PaymentPurpose
    channel: PaymentChannel
    status: PaymentStatus
    amount: Decimal
    refunded_amount: Decimal
    platform_fee: Decimal | None
    currency: str
    failure_reason: str | None
    booking_id: uuid.UUID | None
    booking_reference: str | None
    user_id: uuid.UUID
    passenger_name: str | None
    passenger_phone: str
    route_name: str | None
    created_at: datetime
    completed_at: datetime | None


@dataclass(frozen=True, slots=True)
class PaymentFilters:
    since: datetime | None = None
    until: datetime | None = None
    channels: Collection[PaymentChannel] | None = None
    statuses: Collection[PaymentStatus] | None = None
    purposes: Collection[PaymentPurpose] | None = None
    city: str | None = None
    route_id: uuid.UUID | None = None
    fleet_id: uuid.UUID | None = None
    query: str | None = None


@dataclass(frozen=True, slots=True)
class RevenueSlice:
    key: str
    label: str | None
    amount: Decimal
    payments: int


def _trip_scope(
    stmt: Select[Any], *, city: str | None, route_id: uuid.UUID | None, fleet_id: uuid.UUID | None
) -> Select[Any]:
    """Narrow a statement that already joins ``Booking`` to the trips of a
    city, route or fleet."""
    if city is not None:
        origin = aliased(Stop)
        city_trip, city_route = aliased(Trip), aliased(Route)
        stmt = (
            stmt.join(city_trip, city_trip.id == Booking.trip_id)
            .join(city_route, city_route.id == city_trip.route_id)
            .join(origin, origin.id == city_route.origin_stop_id)
            .where(func.lower(origin.city) == city.strip().lower())
        )
    if route_id is not None:
        route_trip = aliased(Trip)
        stmt = stmt.join(route_trip, route_trip.id == Booking.trip_id).where(
            route_trip.route_id == route_id
        )
    if fleet_id is not None:
        assignment, vehicle = aliased(TripVehicleAssignment), aliased(Vehicle)
        stmt = (
            stmt.join(
                assignment,
                and_(assignment.trip_id == Booking.trip_id, assignment.is_active.is_(True)),
            )
            .join(vehicle, vehicle.id == assignment.vehicle_id)
            .where(vehicle.fleet_id == fleet_id)
        )
    return stmt


class AdminFinanceRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def list_payments(
        self,
        filters: PaymentFilters,
        *,
        sort: str,
        descending: bool,
        limit: int,
        offset: int,
    ) -> tuple[list[PaymentRow], int]:
        trip_route = aliased(Route)
        listed = (
            select(
                Payment.id.label("payment_id"),
                Payment.internal_reference,
                Payment.provider_reference,
                Payment.purpose,
                Payment.channel,
                Payment.status,
                Payment.amount,
                Payment.refunded_amount,
                Booking.platform_fee,
                Payment.currency,
                Payment.failure_reason,
                Booking.id.label("booking_id"),
                Booking.booking_reference,
                Payment.user_id,
                UserProfile.full_name.label("passenger_name"),
                User.phone_number.label("passenger_phone"),
                trip_route.name.label("route_name"),
                Payment.created_at,
                Payment.completed_at,
            )
            .select_from(Payment)
            .join(User, User.id == Payment.user_id)
            .outerjoin(UserProfile, UserProfile.user_id == Payment.user_id)
            .outerjoin(Booking, Booking.id == Payment.booking_id)
            .outerjoin(Trip, Trip.id == Booking.trip_id)
            .outerjoin(trip_route, trip_route.id == Trip.route_id)
        )
        listed = _trip_scope(
            listed, city=filters.city, route_id=filters.route_id, fleet_id=filters.fleet_id
        )
        conditions: list[ColumnElement[bool]] = []
        if filters.since is not None:
            conditions.append(Payment.created_at >= filters.since)
        if filters.until is not None:
            conditions.append(Payment.created_at < filters.until)
        if filters.channels:
            conditions.append(Payment.channel.in_(list(filters.channels)))
        if filters.statuses:
            conditions.append(Payment.status.in_(list(filters.statuses)))
        if filters.purposes:
            conditions.append(Payment.purpose.in_(list(filters.purposes)))
        if filters.query:
            needle = f"%{filters.query.strip()}%"
            conditions.append(
                or_(
                    Payment.internal_reference.ilike(needle),
                    Payment.provider_reference.ilike(needle),
                    Booking.booking_reference.ilike(needle),
                    User.phone_number.ilike(needle),
                )
            )
        page = listed.where(*conditions).subquery("payment_rows")
        total = int(
            (await self._session.execute(select(func.count()).select_from(page))).scalar_one()
        )
        column = page.c[sort]
        order = column.desc().nulls_last() if descending else column.asc().nulls_last()
        result = await self._session.execute(
            select(page).order_by(order, page.c.payment_id).limit(limit).offset(offset)
        )
        return [PaymentRow(**row) for row in result.mappings().all()], total

    async def revenue_breakdown(
        self, by: Breakdown, *, since: datetime, until: datetime, city: str | None, limit: int
    ) -> list[RevenueSlice]:
        """Money collected for bookings in ``[since, until)`` by route, fleet
        or Ghana hour of the day, largest first (hours in order)."""
        amount = func.coalesce(func.sum(Payment.amount), 0).label("amount")
        count = func.count(Payment.id).label("payments")
        base = (
            select(Payment.id)
            .select_from(Payment)
            .join(Booking, Booking.id == Payment.booking_id)
            .where(
                Payment.purpose == PaymentPurpose.BOOKING_PAYMENT,
                Payment.status.in_(COLLECTED),
                Payment.completed_at >= since,
                Payment.completed_at < until,
            )
        )
        base = _trip_scope(base, city=city, route_id=None, fleet_id=None)
        stmt: Select[Any]
        if by == "route":
            stmt = (
                base.join(Trip, Trip.id == Booking.trip_id)
                .join(Route, Route.id == Trip.route_id)
                .with_only_columns(Route.id.label("key"), Route.name.label("label"), amount, count)
                .group_by(Route.id, Route.name)
                .order_by(amount.desc())
                .limit(limit)
            )
        elif by == "fleet":
            stmt = (
                base.join(
                    TripVehicleAssignment,
                    and_(
                        TripVehicleAssignment.trip_id == Booking.trip_id,
                        TripVehicleAssignment.is_active.is_(True),
                    ),
                )
                .join(Vehicle, Vehicle.id == TripVehicleAssignment.vehicle_id)
                .join(Fleet, Fleet.id == Vehicle.fleet_id)
                .with_only_columns(Fleet.id.label("key"), Fleet.name.label("label"), amount, count)
                .group_by(Fleet.id, Fleet.name)
                .order_by(amount.desc())
                .limit(limit)
            )
        else:
            hour = func.extract("hour", func.timezone(TIMEZONE, Payment.completed_at))
            stmt = (
                base.with_only_columns(hour.label("key"), amount, count)
                .group_by(hour)
                .order_by(hour)
            )
        rows = (await self._session.execute(stmt)).mappings().all()
        return [
            RevenueSlice(
                key=str(int(row["key"])) if by == "hour" else str(row["key"]),
                label=row.get("label"),
                amount=Decimal(str(row["amount"])),
                payments=int(row["payments"]),
            )
            for row in rows
        ]

    async def pending_withdrawals(self) -> tuple[Decimal, int]:
        """Withdrawals requested or approved but not paid out yet."""
        row = (
            await self._session.execute(
                select(
                    func.coalesce(func.sum(WithdrawalRequest.amount), 0),
                    func.count(WithdrawalRequest.id),
                ).where(
                    WithdrawalRequest.status.in_(
                        [WithdrawalStatus.PENDING, WithdrawalStatus.APPROVED]
                    )
                )
            )
        ).one()
        return Decimal(str(row[0])).quantize(Decimal("0.01")), int(row[1])
