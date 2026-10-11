"""The reports SRS section 17 asks for, as tables the dashboard can render or
export (it makes PDF and XLSX itself; the API gives JSON or CSV).

Four are time series -- one row per day, week or month -- and two are
breakdowns: by hour of the day, and by route. Every figure is defined once,
and the time series reuse the dashboard analytics' own definitions where
they overlap, so the two never disagree.
"""

from __future__ import annotations

from collections.abc import Callable, Sequence
from dataclasses import dataclass, field
from datetime import date, timedelta
from decimal import Decimal
from typing import Any, Literal

from sqlalchemy import and_, distinct, func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import aliased

from app.models.bookings import Booking, BookingStatus
from app.models.tickets import Ticket, TicketStatus
from app.models.trips import Trip, TripStatus, TripVehicleAssignment
from app.models.vehicles import Vehicle
from app.repositories.admin_analytics_repository import DailyFigure
from app.repositories.admin_reports_repository import (
    PAID_BOOKINGS,
    AdminReportsRepository,
    Granularity,
    Scope,
)
from app.services.admin_analytics_service import OVERVIEW_FIGURES, REVENUE_FIGURES, Period

ReportName = Literal[
    "daily_rides",
    "revenue",
    "peak_hours",
    "route_popularity",
    "passenger_growth",
    "cancellation_rates",
]
ColumnKind = Literal["period", "hour", "text", "count", "money", "ratio"]

_CENTS = Decimal("0.01")
_RATIO = Decimal("0.0001")
CANCELLED_BOOKINGS = (BookingStatus.CANCELLED, BookingStatus.REFUND_PENDING, BookingStatus.REFUNDED)


@dataclass(frozen=True, slots=True)
class Column:
    key: str
    label: str
    kind: ColumnKind


@dataclass(frozen=True, slots=True)
class Report:
    name: ReportName
    title: str
    columns: list[Column]
    rows: list[dict[str, Any]]
    totals: dict[str, Any]
    notes: list[str] = field(default_factory=list)


def _named(figures: Sequence[DailyFigure], name: str) -> DailyFigure:
    return next(figure for figure in figures if figure.name == name)


def _trips(name: str, *conditions: Any) -> DailyFigure:
    return DailyFigure(
        name=name,
        base=select(Trip.id).select_from(Trip),
        timestamp=Trip.scheduled_departure_at,
        value=func.count(Trip.id),
        trip_id=Trip.id,
        conditions=conditions,
    )


def _bookings(name: str, value: Any, *conditions: Any, on_trips: bool = False) -> DailyFigure:
    """Bookings dated when they were made, or -- ``on_trips`` -- by their
    trip's departure."""
    base = select(Booking.id).select_from(Booking)
    if on_trips:
        base = base.join(Trip, Trip.id == Booking.trip_id)
    return DailyFigure(
        name=name,
        base=base,
        timestamp=Trip.scheduled_departure_at if on_trips else Booking.created_at,
        value=value,
        trip_id=Booking.trip_id,
        conditions=conditions,
    )


_COMPLETED = Trip.status == TripStatus.COMPLETED
_PAID = Booking.status.in_(PAID_BOOKINGS)
_SEATS = func.coalesce(func.sum(Booking.passenger_count), 0)


def _first_paid_booking() -> Any:
    """The time of the passenger's first paid booking."""
    earlier = aliased(Booking)
    return (
        select(func.min(earlier.created_at))
        .where(earlier.passenger_id == Booking.passenger_id, earlier.status.in_(PAID_BOOKINGS))
        .correlate(Booking)
        .scalar_subquery()
    )


DAILY_RIDES = (
    _trips("trips_completed", _COMPLETED),
    _trips("trips_cancelled", Trip.status == TripStatus.CANCELLED),
    DailyFigure(
        name="seats_offered",
        base=select(Trip.id)
        .select_from(Trip)
        .join(
            TripVehicleAssignment,
            and_(TripVehicleAssignment.trip_id == Trip.id, TripVehicleAssignment.is_active),
        )
        .join(Vehicle, Vehicle.id == TripVehicleAssignment.vehicle_id),
        timestamp=Trip.scheduled_departure_at,
        value=func.coalesce(func.sum(Vehicle.capacity), 0),
        trip_id=Trip.id,
        conditions=(_COMPLETED,),
    ),
    _bookings("seats_booked", _SEATS, _PAID, _COMPLETED, on_trips=True),
    DailyFigure(
        name="passengers_boarded",
        base=select(Ticket.id).select_from(Ticket).join(Trip, Trip.id == Ticket.trip_id),
        timestamp=Trip.scheduled_departure_at,
        value=func.count(Ticket.id),
        trip_id=Ticket.trip_id,
        conditions=(Ticket.status == TicketStatus.VALIDATED,),
    ),
)
REVENUE = tuple(
    _named(REVENUE_FIGURES, name) for name in ("paid_bookings", "gross", "refunds", "platform_fees")
)
PASSENGER_GROWTH = (
    _named(OVERVIEW_FIGURES, "new_passengers"),
    _bookings("active_passengers", func.count(distinct(Booking.passenger_id)), _PAID),
    _bookings(
        "first_time_bookers",
        func.count(distinct(Booking.passenger_id)),
        _PAID,
        Booking.created_at == _first_paid_booking(),
    ),
)
CANCELLATIONS = (
    _bookings("bookings_made", func.count(Booking.id)),
    _bookings(
        "cancelled_by_passengers",
        func.count(Booking.id),
        Booking.status.in_(CANCELLED_BOOKINGS),
        ~Booking.trip_id.in_(select(Trip.id).where(Trip.status == TripStatus.CANCELLED)),
    ),
    _bookings(
        "cancelled_with_trip",
        func.count(Booking.id),
        Booking.status.in_(CANCELLED_BOOKINGS),
        Booking.trip_id.in_(select(Trip.id).where(Trip.status == TripStatus.CANCELLED)),
    ),
    _bookings("expired_unpaid", func.count(Booking.id), Booking.status == BookingStatus.EXPIRED),
    _trips("trips_scheduled"),
    _trips("trips_cancelled", Trip.status == TripStatus.CANCELLED),
)


def _ratio(part: Any, whole: Any) -> Decimal | None:
    if part is None or not whole:
        return None
    return (Decimal(part) / Decimal(whole)).quantize(_RATIO)


def _money(value: Any) -> Decimal | None:
    return None if value is None else Decimal(value).quantize(_CENTS)


def truncate(day: date, granularity: Granularity) -> date:
    if granularity == "week":
        return day - timedelta(days=day.weekday())
    if granularity == "month":
        return day.replace(day=1)
    return day


def _next(day: date, granularity: Granularity) -> date:
    if granularity == "week":
        return day + timedelta(days=7)
    if granularity == "month":
        return (day.replace(day=28) + timedelta(days=4)).replace(day=1)
    return day + timedelta(days=1)


def buckets(period: Period, granularity: Granularity) -> list[date]:
    """Each day, week (from Monday) or month the period touches."""
    found, day = [], truncate(period.start, granularity)
    while day <= period.end:
        found.append(day)
        day = _next(day, granularity)
    return found


class AdminReportsService:
    def __init__(self, session: AsyncSession) -> None:
        self._reports = AdminReportsRepository(session)

    async def build(
        self, name: ReportName, period: Period, *, granularity: Granularity, scope: Scope
    ) -> Report:
        builders: dict[ReportName, Callable[..., Any]] = {
            "daily_rides": self._daily_rides,
            "revenue": self._revenue,
            "peak_hours": self._peak_hours,
            "route_popularity": self._route_popularity,
            "passenger_growth": self._passenger_growth,
            "cancellation_rates": self._cancellation_rates,
        }
        report: Report = await builders[name](period, granularity, scope)
        return report

    async def _series(
        self,
        figures: Sequence[DailyFigure],
        period: Period,
        granularity: Granularity,
        scope: Scope,
    ) -> tuple[list[date], dict[str, dict[date, Decimal] | None]]:
        found = await self._reports.series(
            figures, start=period.since, end=period.until, granularity=granularity, scope=scope
        )
        # A figure missing from the result does not apply to the scope.
        values: dict[str, dict[date, Decimal] | None] = {
            figure.name: found.get(figure.name) for figure in figures
        }
        return buckets(period, granularity), values

    @staticmethod
    def _at(values: dict[str, dict[date, Decimal] | None], name: str, when: date) -> int | None:
        series = values[name]
        return None if series is None else int(series.get(when, Decimal(0)))

    @staticmethod
    def _total(rows: list[dict[str, Any]], key: str) -> Any:
        present = [row[key] for row in rows if row[key] is not None]
        return sum(present) if present or not rows else None

    # ------------------------------------------------------------ the series
    async def _daily_rides(self, period: Period, granularity: Granularity, scope: Scope) -> Report:
        when, values = await self._series(DAILY_RIDES, period, granularity, scope)
        rows = []
        for day in when:
            row: dict[str, Any] = {"period": day}
            for figure in DAILY_RIDES:
                row[figure.name] = self._at(values, figure.name, day)
            row["occupancy"] = _ratio(row["seats_booked"], row["seats_offered"])
            rows.append(row)
        totals = {key: self._total(rows, key) for key in rows[0] if key != "period"}
        totals["occupancy"] = _ratio(totals["seats_booked"], totals["seats_offered"])
        return Report(
            name="daily_rides",
            title="Daily rides",
            columns=[
                Column("period", "Period", "period"),
                Column("trips_completed", "Trips completed", "count"),
                Column("trips_cancelled", "Trips cancelled", "count"),
                Column("seats_offered", "Seats offered", "count"),
                Column("seats_booked", "Seats booked", "count"),
                Column("occupancy", "Occupancy", "ratio"),
                Column("passengers_boarded", "Passengers boarded", "count"),
            ],
            rows=rows,
            totals=totals,
            notes=["Trips by their scheduled departure; seats on completed trips."],
        )

    async def _revenue(self, period: Period, granularity: Granularity, scope: Scope) -> Report:
        when, values = await self._series(REVENUE, period, granularity, scope)

        def money(name: str, day: date) -> Decimal | None:
            series = values[name]
            return None if series is None else _money(series.get(day, Decimal(0)))

        rows = []
        for day in when:
            gross, refunds = money("gross", day), money("refunds", day)
            paid = self._at(values, "paid_bookings", day)
            rows.append(
                {
                    "period": day,
                    "paid_bookings": paid,
                    "gross": gross,
                    "refunds": refunds,
                    "net": None if gross is None or refunds is None else gross - refunds,
                    "platform_fees": money("platform_fees", day),
                    "average_fare": _money(gross / paid) if gross is not None and paid else None,
                }
            )
        totals = {key: self._total(rows, key) for key in rows[0] if key != "period"}
        paid_total = totals["paid_bookings"]
        totals["average_fare"] = (
            _money(totals["gross"] / paid_total) if totals["gross"] and paid_total else None
        )
        return Report(
            name="revenue",
            title="Revenue",
            columns=[
                Column("period", "Period", "period"),
                Column("paid_bookings", "Paid bookings", "count"),
                Column("gross", "Gross (GHS)", "money"),
                Column("refunds", "Refunds (GHS)", "money"),
                Column("net", "Net (GHS)", "money"),
                Column("platform_fees", "Platform fees (GHS)", "money"),
                Column("average_fare", "Average fare (GHS)", "money"),
            ],
            rows=rows,
            totals=totals,
            notes=["Payments by when they were collected; refunds by when they were paid out."],
        )

    async def _passenger_growth(
        self, period: Period, granularity: Granularity, scope: Scope
    ) -> Report:
        when, values = await self._series(PASSENGER_GROWTH, period, granularity, scope)
        running: int | None = None
        if values["new_passengers"] is not None:
            running = await self._reports.count_before(
                _named(OVERVIEW_FIGURES, "new_passengers"), period.since
            )
        rows = []
        for day in when:
            new = self._at(values, "new_passengers", day)
            if running is not None and new is not None:
                running += new
            rows.append(
                {
                    "period": day,
                    "new_passengers": new,
                    "total_passengers": running,
                    "active_passengers": self._at(values, "active_passengers", day),
                    "first_time_bookers": self._at(values, "first_time_bookers", day),
                }
            )
        totals = {
            "new_passengers": self._total(rows, "new_passengers"),
            "total_passengers": running,
            "active_passengers": None,  # the same passenger is active in many periods
            "first_time_bookers": self._total(rows, "first_time_bookers"),
        }
        notes = ["Active: made a paid booking in the period."]
        if values["new_passengers"] is None:
            notes.append("Sign-ups have no city, route or fleet, so they are left out here.")
        return Report(
            name="passenger_growth",
            title="Passenger growth",
            columns=[
                Column("period", "Period", "period"),
                Column("new_passengers", "New passengers", "count"),
                Column("total_passengers", "Total passengers", "count"),
                Column("active_passengers", "Active passengers", "count"),
                Column("first_time_bookers", "First-time bookers", "count"),
            ],
            rows=rows,
            totals=totals,
            notes=notes,
        )

    async def _cancellation_rates(
        self, period: Period, granularity: Granularity, scope: Scope
    ) -> Report:
        when, values = await self._series(CANCELLATIONS, period, granularity, scope)
        rows = []
        for day in when:
            row: dict[str, Any] = {"period": day}
            for figure in CANCELLATIONS:
                row[figure.name] = self._at(values, figure.name, day)
            row["passenger_cancellation_rate"] = _ratio(
                row["cancelled_by_passengers"], row["bookings_made"]
            )
            row["trip_cancellation_rate"] = _ratio(row["trips_cancelled"], row["trips_scheduled"])
            rows.append(row)
        totals = {key: self._total(rows, key) for key in rows[0] if key != "period"}
        totals["passenger_cancellation_rate"] = _ratio(
            totals["cancelled_by_passengers"], totals["bookings_made"]
        )
        totals["trip_cancellation_rate"] = _ratio(
            totals["trips_cancelled"], totals["trips_scheduled"]
        )
        return Report(
            name="cancellation_rates",
            title="Cancellation rates",
            columns=[
                Column("period", "Period", "period"),
                Column("bookings_made", "Bookings made", "count"),
                Column("cancelled_by_passengers", "Cancelled by passengers", "count"),
                Column("cancelled_with_trip", "Cancelled with their trip", "count"),
                Column("expired_unpaid", "Expired unpaid", "count"),
                Column("passenger_cancellation_rate", "Passenger cancellation rate", "ratio"),
                Column("trips_scheduled", "Trips scheduled", "count"),
                Column("trips_cancelled", "Trips cancelled", "count"),
                Column("trip_cancellation_rate", "Trip cancellation rate", "ratio"),
            ],
            rows=rows,
            totals=totals,
            notes=["Bookings by when they were made; trips by their scheduled departure."],
        )

    # ----------------------------------------------------------- breakdowns
    async def _peak_hours(self, period: Period, granularity: Granularity, scope: Scope) -> Report:
        found = await self._reports.by_hour(start=period.since, end=period.until, scope=scope)
        keys = ("trips", "seats_booked", "passengers_boarded", "bookings_made", "searches")
        rows = [
            {
                "hour": f"{hour:02d}:00",
                **{key: (found[key].get(hour, 0) if key in found else None) for key in keys},
            }
            for hour in range(24)
        ]
        notes = [
            "Trips, seats and boardings by the hour of departure; bookings and searches by "
            "the hour they were made (Ghana time)."
        ]
        if "searches" not in found:
            notes.append("Searches have no route or fleet, so they are left out here.")
        return Report(
            name="peak_hours",
            title="Peak hours",
            columns=[
                Column("hour", "Hour", "hour"),
                Column("trips", "Trips departing", "count"),
                Column("seats_booked", "Seats booked", "count"),
                Column("passengers_boarded", "Passengers boarded", "count"),
                Column("bookings_made", "Bookings made", "count"),
                Column("searches", "Searches", "count"),
            ],
            rows=rows,
            totals={key: self._total(rows, key) for key in keys},
            notes=notes,
        )

    async def _route_popularity(
        self, period: Period, granularity: Granularity, scope: Scope
    ) -> Report:
        rows = await self._reports.by_route(start=period.since, end=period.until, scope=scope)
        for row in rows:
            row["occupancy"] = _ratio(row["seats_booked"], row["seats_offered"])
            row["fares"] = _money(row["fares"])
        rows.sort(key=lambda row: (-row["seats_booked"], row["route_name"]))
        counted = (
            "trips_completed",
            "trips_cancelled",
            "seats_offered",
            "seats_booked",
            "passengers_boarded",
            "bookings_cancelled",
        )
        totals: dict[str, Any] = {key: sum(row[key] for row in rows) for key in counted}
        totals["fares"] = _money(sum((row["fares"] for row in rows), Decimal(0)))
        totals["occupancy"] = _ratio(totals["seats_booked"], totals["seats_offered"])
        return Report(
            name="route_popularity",
            title="Route popularity",
            columns=[
                Column("route_id", "Route ID", "text"),
                Column("route_name", "Route", "text"),
                Column("origin", "From", "text"),
                Column("destination", "To", "text"),
                Column("trips_completed", "Trips completed", "count"),
                Column("trips_cancelled", "Trips cancelled", "count"),
                Column("seats_offered", "Seats offered", "count"),
                Column("seats_booked", "Seats booked", "count"),
                Column("occupancy", "Occupancy", "ratio"),
                Column("passengers_boarded", "Passengers boarded", "count"),
                Column("fares", "Fares (GHS)", "money"),
                Column("bookings_cancelled", "Bookings cancelled", "count"),
            ],
            rows=rows,
            totals=totals,
            notes=["Trips departing in the period, busiest route first."],
        )
