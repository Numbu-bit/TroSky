"""User growth read models: activity, activation, retention and where users
travel.

"Active" means did something only a person would: signed in (a new session)
or made a booking. The backend keeps no page-view history, so this is the
activity it can count for past days.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime, timedelta
from typing import Any

from sqlalchemy import Date, cast, distinct, func, literal, select, union_all
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import aliased

from app.models.bookings import Booking
from app.models.identity import User, UserSession
from app.models.routes import Route, Stop
from app.models.trips import Trip
from app.repositories.admin_analytics_repository import TIMEZONE, ghana_day


@dataclass(frozen=True, slots=True)
class Cohort:
    week: date  # the Monday of the week they signed up
    size: int
    # Share still active in each later week: [week 1, week 2, ...].
    retained: list[int]


def _activity() -> Any:
    return union_all(
        select(UserSession.user_id.label("user_id"), UserSession.created_at.label("at")),
        select(Booking.passenger_id.label("user_id"), Booking.created_at.label("at")),
    ).subquery("activity")


def _week(column: Any) -> Any:
    return cast(func.date_trunc("week", func.timezone(TIMEZONE, column)), Date)


class AdminGrowthRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def users_before(self, moment: datetime) -> int:
        return int(
            await self._session.scalar(
                select(func.count(User.id)).where(
                    User.created_at < moment, User.deleted_at.is_(None)
                )
            )
            or 0
        )

    async def daily_active(self, since: datetime, until: datetime) -> dict[date, int]:
        activity = _activity()
        day = ghana_day(activity.c.at)
        rows = await self._session.execute(
            select(day, func.count(distinct(activity.c.user_id)))
            .where(activity.c.at >= since, activity.c.at < until)
            .group_by(day)
        )
        return {row[0]: int(row[1]) for row in rows}

    async def active_in(self, windows: list[tuple[datetime, datetime]]) -> list[int]:
        """Distinct active users in each ``[start, end)`` window, one query."""
        activity = _activity()
        columns = [
            func.count(distinct(activity.c.user_id)).filter(
                activity.c.at >= start, activity.c.at < end
            )
            for start, end in windows
        ]
        row = (await self._session.execute(select(*columns))).one()
        return [int(value) for value in row]

    async def activation(
        self, since: datetime, until: datetime, *, within: timedelta, paid_statuses: Any
    ) -> tuple[int, int]:
        """``(signed up, booked and paid within `within` of signing up)``
        for accounts created in ``[since, until)``."""
        first_paid = (
            select(func.min(Booking.created_at))
            .where(Booking.passenger_id == User.id, Booking.status.in_(paid_statuses))
            .correlate(User)
            .scalar_subquery()
        )
        row = (
            await self._session.execute(
                select(
                    func.count(User.id),
                    func.count(User.id).filter(first_paid <= User.created_at + within),
                ).where(
                    User.created_at >= since,
                    User.created_at < until,
                    User.deleted_at.is_(None),
                )
            )
        ).one()
        return int(row[0]), int(row[1])

    async def retention(self, since: datetime, until: datetime) -> list[Cohort]:
        """Weekly cohorts of accounts created in the window, and how many of
        each were active in every week after the one they joined, up to the
        window's end."""
        cohort_week = _week(User.created_at)
        cohorts = (
            select(User.id.label("user_id"), cohort_week.label("week"))
            .where(User.created_at >= since, User.created_at < until, User.deleted_at.is_(None))
            .subquery("cohorts")
        )
        sizes = {
            row[0]: int(row[1])
            for row in await self._session.execute(
                select(cohorts.c.week, func.count()).group_by(cohorts.c.week)
            )
        }
        activity = _activity()
        active_week = _week(activity.c.at).label("active_week")
        weeks = (
            select(activity.c.user_id, active_week)
            .where(activity.c.at >= since, activity.c.at < until)
            .distinct()
            .subquery("active_weeks")
        )
        offset = ((weeks.c.active_week - cohorts.c.week) / 7).label("offset")
        retained: dict[date, dict[int, int]] = {week: {} for week in sizes}
        rows = await self._session.execute(
            select(cohorts.c.week, offset, func.count(distinct(weeks.c.user_id)))
            .join(weeks, weeks.c.user_id == cohorts.c.user_id)
            .where(weeks.c.active_week > cohorts.c.week)
            .group_by(cohorts.c.week, offset)
        )
        for week, after, count in rows:
            retained[week][int(after)] = int(count)
        last_week = (until - timedelta(days=1)).date()
        last_monday = last_week - timedelta(days=last_week.weekday())
        out = []
        for week in sorted(sizes):
            span = (last_monday - week).days // 7
            out.append(
                Cohort(
                    week=week,
                    size=sizes[week],
                    retained=[retained[week].get(n, 0) for n in range(1, span + 1)],
                )
            )
        return out

    async def travellers_by_city(
        self, since: datetime, until: datetime, *, paid_statuses: Any, limit: int
    ) -> list[tuple[str, int]]:
        """Distinct passengers with a paid booking in the window, by the city
        their trip started in."""
        origin = aliased(Stop)
        city = func.coalesce(origin.city, literal("Unknown"))
        rows = await self._session.execute(
            select(city, func.count(distinct(Booking.passenger_id)))
            .select_from(Booking)
            .join(Trip, Trip.id == Booking.trip_id)
            .join(Route, Route.id == Trip.route_id)
            .join(origin, origin.id == Route.origin_stop_id)
            .where(
                Booking.created_at >= since,
                Booking.created_at < until,
                Booking.status.in_(paid_statuses),
            )
            .group_by(city)
            .order_by(func.count(distinct(Booking.passenger_id)).desc())
            .limit(limit)
        )
        return [(row[0], int(row[1])) for row in rows]
