"""Driver performance over a period: the raw counts behind the scores.

Everything is measured over the trips a driver is assigned to whose
scheduled departure falls in the period, so a driver's numbers for a week
are about that week's trips.
"""

from __future__ import annotations

import uuid
from collections.abc import Collection
from dataclasses import dataclass, field
from datetime import date, datetime, timedelta
from decimal import Decimal
from typing import Any

from sqlalchemy import ColumnElement, and_, func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import aliased

from app.models.feedback import Complaint, Rating
from app.models.payments import Wallet, WalletReferenceType, WalletTransaction
from app.models.routes import Route, Stop
from app.models.tickets import Ticket, TicketStatus
from app.models.trips import Trip, TripDriverAssignment, TripStatus, TripVehicleAssignment
from app.models.vehicles import Vehicle
from app.repositories.admin_analytics_repository import ghana_day


@dataclass(slots=True)
class DriverCounts:
    driver_id: uuid.UUID
    trips_assigned: int = 0
    trips_completed: int = 0
    trips_cancelled: int = 0
    on_time: int = 0
    ratings: int = 0
    rating_total: int = 0
    complaints: int = 0
    tickets_issued: int = 0
    tickets_scanned: int = 0


@dataclass(frozen=True, slots=True)
class DayCounts:
    day: date
    trips_completed: int
    on_time: int
    rating_average: Decimal | None


@dataclass(frozen=True, slots=True)
class Review:
    rating_id: uuid.UUID
    trip_id: uuid.UUID
    score: int
    comment: str | None
    created_at: datetime


@dataclass(frozen=True, slots=True)
class PeriodTrips:
    """Which trips count: the driver's, departing in the window, optionally
    only in one city or one fleet's vehicles."""

    since: datetime
    until: datetime
    city: str | None = None
    fleet_id: uuid.UUID | None = None
    driver_ids: Collection[uuid.UUID] | None = field(default=None)


class AdminPerformanceRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    def _trips(self, scope: PeriodTrips) -> Any:
        """``(trip_id, driver_id, status, departs, departed)`` for the trips
        in scope."""
        stmt = (
            select(
                Trip.id.label("trip_id"),
                TripDriverAssignment.driver_id,
                Trip.status,
                Trip.scheduled_departure_at.label("departs"),
                Trip.actual_departure_at.label("departed"),
            )
            .join(
                TripDriverAssignment,
                and_(
                    TripDriverAssignment.trip_id == Trip.id,
                    TripDriverAssignment.is_active.is_(True),
                ),
            )
            .where(
                Trip.scheduled_departure_at >= scope.since,
                Trip.scheduled_departure_at < scope.until,
            )
        )
        if scope.driver_ids is not None:
            stmt = stmt.where(TripDriverAssignment.driver_id.in_(list(scope.driver_ids)))
        if scope.city is not None:
            origin = aliased(Stop)
            stmt = (
                stmt.join(Route, Route.id == Trip.route_id)
                .join(origin, origin.id == Route.origin_stop_id)
                .where(func.lower(origin.city) == scope.city.strip().lower())
            )
        if scope.fleet_id is not None:
            stmt = (
                stmt.join(
                    TripVehicleAssignment,
                    and_(
                        TripVehicleAssignment.trip_id == Trip.id,
                        TripVehicleAssignment.is_active.is_(True),
                    ),
                )
                .join(Vehicle, Vehicle.id == TripVehicleAssignment.vehicle_id)
                .where(Vehicle.fleet_id == scope.fleet_id)
            )
        return stmt.subquery("scope_trips")

    async def counts(
        self, scope: PeriodTrips, *, grace: timedelta
    ) -> dict[uuid.UUID, DriverCounts]:
        trips = self._trips(scope)
        completed = trips.c.status == TripStatus.COMPLETED
        on_time: ColumnElement[bool] = and_(
            completed, trips.c.departed.is_not(None), trips.c.departed <= trips.c.departs + grace
        )
        out: dict[uuid.UUID, DriverCounts] = {}
        for row in await self._session.execute(
            select(
                trips.c.driver_id,
                func.count(),
                func.count().filter(completed),
                func.count().filter(trips.c.status == TripStatus.CANCELLED),
                func.count().filter(on_time),
            ).group_by(trips.c.driver_id)
        ):
            out[row[0]] = DriverCounts(row[0], int(row[1]), int(row[2]), int(row[3]), int(row[4]))
        if not out:
            return out
        for driver_id, count, total in await self._session.execute(
            select(
                trips.c.driver_id, func.count(Rating.id), func.coalesce(func.sum(Rating.score), 0)
            )
            .join(Rating, Rating.trip_id == trips.c.trip_id)
            .where(Rating.driver_id == trips.c.driver_id)
            .group_by(trips.c.driver_id)
        ):
            out[driver_id].ratings, out[driver_id].rating_total = int(count), int(total)
        for driver_id, count in await self._session.execute(
            select(trips.c.driver_id, func.count(Complaint.id))
            .join(Complaint, Complaint.trip_id == trips.c.trip_id)
            .group_by(trips.c.driver_id)
        ):
            out[driver_id].complaints = int(count)
        for driver_id, issued, scanned in await self._session.execute(
            select(
                trips.c.driver_id,
                func.count(Ticket.id),
                func.count(Ticket.id).filter(Ticket.status == TicketStatus.VALIDATED),
            )
            .join(Ticket, Ticket.trip_id == trips.c.trip_id)
            .where(completed, Ticket.status != TicketStatus.REVOKED)
            .group_by(trips.c.driver_id)
        ):
            out[driver_id].tickets_issued, out[driver_id].tickets_scanned = (
                int(issued),
                int(scanned),
            )
        return out

    async def daily(
        self, driver_id: uuid.UUID, scope: PeriodTrips, *, grace: timedelta
    ) -> list[DayCounts]:
        trips = self._trips(PeriodTrips(scope.since, scope.until, driver_ids=[driver_id]))
        completed = trips.c.status == TripStatus.COMPLETED
        day = ghana_day(trips.c.departs)
        averages = {
            row[0]: Decimal(str(row[1])).quantize(Decimal("0.01"))
            for row in await self._session.execute(
                select(day, func.avg(Rating.score))
                .join(Rating, Rating.trip_id == trips.c.trip_id)
                .where(Rating.driver_id == driver_id)
                .group_by(day)
            )
        }
        rows = await self._session.execute(
            select(
                day,
                func.count().filter(completed),
                func.count().filter(
                    completed,
                    trips.c.departed.is_not(None),
                    trips.c.departed <= trips.c.departs + grace,
                ),
            )
            .group_by(day)
            .order_by(day)
        )
        return [DayCounts(row[0], int(row[1]), int(row[2]), averages.get(row[0])) for row in rows]

    async def rating_distribution(self, driver_id: uuid.UUID, scope: PeriodTrips) -> dict[int, int]:
        trips = self._trips(PeriodTrips(scope.since, scope.until, driver_ids=[driver_id]))
        rows = await self._session.execute(
            select(Rating.score, func.count())
            .join(trips, trips.c.trip_id == Rating.trip_id)
            .where(Rating.driver_id == driver_id)
            .group_by(Rating.score)
        )
        return {int(score): int(count) for score, count in rows}

    async def recent_reviews(self, driver_id: uuid.UUID, *, limit: int) -> list[Review]:
        rows = await self._session.execute(
            select(Rating.id, Rating.trip_id, Rating.score, Rating.comment, Rating.created_at)
            .where(Rating.driver_id == driver_id)
            .order_by(Rating.created_at.desc())
            .limit(limit)
        )
        return [Review(*row) for row in rows]

    async def earnings_since(self, user_id: uuid.UUID, moments: list[datetime]) -> list[int]:
        """Trip earnings credited to the driver's wallet since each moment, in
        minor units, one query."""
        row = (
            await self._session.execute(
                select(
                    *[
                        func.coalesce(
                            func.sum(WalletTransaction.amount_minor_units).filter(
                                WalletTransaction.created_at >= moment
                            ),
                            0,
                        )
                        for moment in moments
                    ]
                )
                .join(Wallet, Wallet.id == WalletTransaction.wallet_id)
                .where(
                    Wallet.user_id == user_id,
                    WalletTransaction.reference_type == WalletReferenceType.TRIP_EARNING,
                )
            )
        ).one()
        return [int(value) for value in row]
