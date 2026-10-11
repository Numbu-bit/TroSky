"""Daily figures for admin analytics, for many figures in one round trip.

Each figure is a ``(name, day, value)`` select over the window asked for;
they are joined with UNION ALL and run as one query, so a dashboard of ten
figures costs one round trip to the database rather than ten.

Days are Ghana days (``Africa/Accra``, which is UTC+0 all year).
"""

from __future__ import annotations

from collections import defaultdict
from collections.abc import Sequence
from dataclasses import dataclass, field
from datetime import date, datetime
from decimal import Decimal
from typing import Any

from sqlalchemy import ColumnElement, Select, String, cast, func, literal, union_all
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import aliased

from app.models.routes import Route, Stop
from app.models.trips import Trip

TIMEZONE = "Africa/Accra"


def ghana_day(column: Any) -> Any:
    """The Ghana calendar day of a timestamp column."""
    return func.date(func.timezone(TIMEZONE, column))


@dataclass(frozen=True)
class DailyFigure:
    """One figure: a select whose FROM/joins are already set, the timestamp
    that dates each row, what to add up, and how (if at all) the row reaches
    a trip -- which is what ties it to a city."""

    name: str
    base: Select[Any]
    timestamp: Any
    value: Any
    trip_id: Any | None = None
    # For rows tied to a place but no trip (searches): the stop whose city
    # counts.
    stop_id: Any | None = None
    conditions: Sequence[ColumnElement[bool]] = field(default_factory=tuple)
    # Split the figure by this column: one figure per value, named
    # ``"<name>:<value>"`` (payments by method, sign-ups by role).
    group: Any | None = None


class AdminAnalyticsRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def daily(
        self,
        figures: Sequence[DailyFigure],
        *,
        start: datetime,
        end: datetime,
        city: str | None,
    ) -> dict[str, dict[date, Decimal]]:
        """``{figure: {day: value}}`` for rows dated in ``[start, end)``.

        With ``city``, only rows linked to a trip starting in that city
        count; figures with no trip link are then left out entirely (their
        absence, not a zero, says the filter does not apply).
        """
        selects = []
        for figure in figures:
            if city is not None and figure.trip_id is None and figure.stop_id is None:
                continue
            day = ghana_day(figure.timestamp).label("day")
            name: Any = literal(figure.name)
            if figure.group is not None:
                name = func.concat(figure.name, ":", cast(figure.group, String))
            stmt = figure.base.with_only_columns(
                name.label("figure"), day, figure.value.label("value")
            ).where(figure.timestamp >= start, figure.timestamp < end, *figure.conditions)
            if city is not None and figure.trip_id is None:
                place = aliased(Stop)
                stmt = stmt.join(place, place.id == figure.stop_id).where(
                    func.lower(place.city) == city.strip().lower()
                )
            elif city is not None:
                # Aliased: the figure may itself be about trips.
                trip, route, origin = aliased(Trip), aliased(Route), aliased(Stop)
                stmt = (
                    stmt.join(trip, trip.id == figure.trip_id)
                    .join(route, route.id == trip.route_id)
                    .join(origin, origin.id == route.origin_stop_id)
                    .where(func.lower(origin.city) == city.strip().lower())
                )
            selects.append(
                stmt.group_by(day, figure.group) if figure.group is not None else stmt.group_by(day)
            )
        out: dict[str, dict[date, Decimal]] = defaultdict(dict)
        if not selects:
            return out
        rows = await self._session.execute(union_all(*selects))
        for name, day, value in rows:
            out[name][day] = Decimal(str(value or 0))
        for figure in figures:
            tied_to_a_city = figure.trip_id is not None or figure.stop_id is not None
            if figure.group is None and (city is None or tied_to_a_city):
                out.setdefault(figure.name, {})
        return out
