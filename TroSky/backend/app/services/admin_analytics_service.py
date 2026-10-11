"""Admin analytics: figures over a period, against the period before it.

Every analytics endpoint takes ``from``/``to`` (inclusive Ghana dates) and
an optional ``city``, and reports each figure as its total for the period,
the total for the same number of days just before, and a daily series.
"""

from __future__ import annotations

import uuid
from collections.abc import Collection, Mapping, Sequence
from dataclasses import dataclass, replace
from datetime import UTC, date, datetime, time, timedelta
from decimal import Decimal
from typing import Any, get_args

from sqlalchemy import exists, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.exceptions import NotFoundError, ValidationAppError
from app.models.analytics import SearchEvent
from app.models.bookings import Booking, BookingStatus
from app.models.drivers import Driver
from app.models.feedback import Complaint, ComplaintCategory
from app.models.identity import Role, User, UserRole
from app.models.payments import (
    Payment,
    PaymentPurpose,
    PaymentStatus,
    RefundRequest,
    RefundStatus,
)
from app.models.safety import SosAlert
from app.models.tickets import Ticket, TicketStatus
from app.models.trips import Trip, TripStatus
from app.repositories.admin_analytics_repository import AdminAnalyticsRepository, DailyFigure
from app.repositories.admin_complaints_repository import (
    AdminComplaintsRepository,
    OpenCount,
    complaint_figures,
)
from app.repositories.admin_demand_repository import (
    AdminDemandRepository,
    Cell,
    DemandFilters,
    DemandKind,
    PairDemand,
    StopDemand,
    SupplyGap,
)
from app.repositories.admin_directory_repository import AdminDirectoryRepository
from app.repositories.admin_finance_repository import (
    AdminFinanceRepository,
    Breakdown,
    RevenueSlice,
)
from app.repositories.admin_growth_repository import AdminGrowthRepository, Cohort
from app.repositories.admin_performance_repository import (
    AdminPerformanceRepository,
    DayCounts,
    DriverCounts,
    PeriodTrips,
    Review,
)
from app.repositories.wallet_repository import WalletRepository

DEFAULT_PERIOD_DAYS = 30
MAX_PERIOD_DAYS = 366
# Bookings that were paid for, whatever happened next.
PAID_BOOKING_STATUSES = (
    BookingStatus.CONFIRMED,
    BookingStatus.COMPLETED,
    BookingStatus.REFUND_PENDING,
    BookingStatus.REFUNDED,
)
COLLECTED_PAYMENT_STATUSES = (
    PaymentStatus.SUCCESSFUL,
    PaymentStatus.PARTIALLY_REFUNDED,
    PaymentStatus.REFUNDED,
)


@dataclass(frozen=True, slots=True)
class Period:
    """Inclusive Ghana dates. Africa/Accra is UTC+0 with no daylight saving,
    so a Ghana midnight is a UTC midnight."""

    start: date
    end: date

    @classmethod
    def resolve(cls, start: date | None, end: date | None) -> Period:
        today = datetime.now(UTC).date()
        end = end or today
        start = start or end - timedelta(days=DEFAULT_PERIOD_DAYS - 1)
        if start > end:
            raise ValidationAppError("'from' must not be after 'to'.", details={"param": "from"})
        if (end - start).days + 1 > MAX_PERIOD_DAYS:
            raise ValidationAppError(
                f"A period can be at most {MAX_PERIOD_DAYS} days.", details={"param": "from"}
            )
        return cls(start, end)

    @property
    def days(self) -> int:
        return (self.end - self.start).days + 1

    @property
    def previous(self) -> Period:
        end = self.start - timedelta(days=1)
        return Period(end - timedelta(days=self.days - 1), end)

    def dates(self) -> list[date]:
        return [self.start + timedelta(days=offset) for offset in range(self.days)]

    @property
    def since(self) -> datetime:
        return datetime.combine(self.start, time.min, tzinfo=UTC)

    @property
    def until(self) -> datetime:
        """The first moment after the period."""
        return datetime.combine(self.end + timedelta(days=1), time.min, tzinfo=UTC)


@dataclass(frozen=True, slots=True)
class Figure:
    value: Decimal
    previous: Decimal
    series: list[tuple[date, Decimal]]

    @property
    def change_percent(self) -> Decimal | None:
        if not self.previous:
            return None
        return ((self.value - self.previous) / self.previous * 100).quantize(Decimal("0.1"))


def figure_from(daily: dict[date, Decimal], period: Period) -> Figure:
    previous = period.previous
    return Figure(
        value=sum((daily.get(day, Decimal("0")) for day in period.dates()), Decimal("0")),
        previous=sum((daily.get(day, Decimal("0")) for day in previous.dates()), Decimal("0")),
        series=[(day, daily.get(day, Decimal("0"))) for day in period.dates()],
    )


def _new_role_holders(slug: str, name: str) -> DailyFigure:
    return DailyFigure(
        name=name,
        base=select(UserRole.user_id).select_from(UserRole).join(Role, Role.id == UserRole.role_id),
        timestamp=UserRole.assigned_at,
        value=func.count(UserRole.user_id),
        conditions=(Role.slug == slug,),
    )


OVERVIEW_FIGURES: Sequence[DailyFigure] = (
    DailyFigure(
        name="new_users",
        base=select(User.id).select_from(User),
        timestamp=User.created_at,
        value=func.count(User.id),
        conditions=(User.deleted_at.is_(None),),
    ),
    _new_role_holders("passenger", "new_passengers"),
    _new_role_holders("driver", "new_drivers"),
    DailyFigure(
        name="paid_bookings",
        base=select(Booking.id).select_from(Booking),
        timestamp=Booking.created_at,
        value=func.count(Booking.id),
        trip_id=Booking.trip_id,
        conditions=(Booking.status.in_(PAID_BOOKING_STATUSES),),
    ),
    DailyFigure(
        name="completed_trips",
        base=select(Trip.id).select_from(Trip),
        timestamp=Trip.scheduled_departure_at,
        value=func.count(Trip.id),
        trip_id=Trip.id,
        conditions=(Trip.status == TripStatus.COMPLETED,),
    ),
    DailyFigure(
        name="booking_payments",
        base=select(Payment.id)
        .select_from(Payment)
        .join(Booking, Booking.id == Payment.booking_id),
        timestamp=Payment.completed_at,
        value=func.coalesce(func.sum(Payment.amount), 0),
        trip_id=Booking.trip_id,
        conditions=(
            Payment.purpose == PaymentPurpose.BOOKING_PAYMENT,
            Payment.status.in_(COLLECTED_PAYMENT_STATUSES),
        ),
    ),
    DailyFigure(
        name="complaints",
        base=select(Complaint.id).select_from(Complaint),
        timestamp=Complaint.created_at,
        value=func.count(Complaint.id),
        trip_id=Complaint.trip_id,
    ),
    DailyFigure(
        name="sos_alerts",
        base=select(SosAlert.id).select_from(SosAlert),
        timestamp=SosAlert.created_at,
        value=func.count(SosAlert.id),
        trip_id=SosAlert.trip_id,
    ),
)


_COMPLETED_TRIPS = next(figure for figure in OVERVIEW_FIGURES if figure.name == "completed_trips")


class AdminAnalyticsService:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session
        self._repo = AdminAnalyticsRepository(session)
        self._finance = AdminFinanceRepository(session)

    async def revenue(self, period: Period, city: str | None) -> RevenueReport:
        return await _revenue_report(self._repo, self._finance, period, city)

    async def users(self, period: Period) -> UsersReport:
        return await _users_report(self._repo, AdminGrowthRepository(self._session), period)

    async def driver_performance(
        self, period: Period, *, city: str | None, fleet_id: uuid.UUID | None
    ) -> list[tuple[DriverPerformance, str | None]]:
        """Every driver with a trip in the period, scored."""
        return await _driver_performance(self._session, period, city=city, fleet_id=fleet_id)

    async def driver_performance_detail(
        self, driver_id: uuid.UUID, period: Period
    ) -> DriverPerformanceDetail:
        return await _driver_performance_detail(self._session, driver_id, period)

    async def funnel(self, period: Period, city: str | None) -> dict[str, Figure]:
        daily = await self._repo.daily(
            FUNNEL_FIGURES, start=period.previous.since, end=period.until, city=city
        )
        return {stage: figure_from(daily.get(stage, {}), period) for stage in FUNNEL_STAGES}

    async def complaints(
        self, period: Period, city: str | None, *, sla_hours: Mapping[str, int]
    ) -> ComplaintStats:
        """What is open now, and how complaints were handled over the
        period against the period before."""
        daily = await self._repo.daily(
            [*complaint_figures(), _COMPLETED_TRIPS],
            start=period.previous.since,
            end=period.until,
            city=city,
        )

        def figure(name: str) -> Figure:
            return figure_from(daily.get(name, {}), period)

        filed = figure("filed")
        per_thousand = Figure(filed.value * 1000, filed.previous * 1000, [])
        return ComplaintStats(
            open_now=await AdminComplaintsRepository(self._session).open_counts(
                sla_hours=sla_hours, now=datetime.now(UTC), city=city
            ),
            filed=filed,
            per_1000_trips=_ratio(per_thousand, figure("completed_trips"), places="0.01"),
            avg_first_response_hours=_ratio(
                figure("response_hours"), figure("responded"), places="0.1"
            ),
            avg_resolution_hours=_ratio(
                figure("resolution_hours"), figure("decided"), places="0.1"
            ),
            by_category={
                category: figure(f"by_category:{category.value}") for category in ComplaintCategory
            },
        )

    async def demand(
        self,
        period: Period,
        kind: DemandKind,
        *,
        city: str | None,
        days: Collection[int] | None,
        hour_from: int | None,
        hour_to: int | None,
    ) -> DemandReport:
        """Where and when people wanted to travel over the period: grid
        cells, the busiest pickup stops and journeys, the week by hour, and
        where searches found nothing to book."""
        demand = AdminDemandRepository(self._session)
        filters = DemandFilters(
            since=period.since,
            until=period.until,
            city=city,
            days=days,
            hour_from=hour_from,
            hour_to=hour_to,
        )
        before = replace(filters, since=period.previous.since, until=period.previous.until)
        cells, withheld = await demand.cells(kind, filters)
        return DemandReport(
            total=await demand.total(kind, filters),
            previous_total=await demand.total(kind, before),
            cells=cells,
            withheld=withheld,
            top_origins=await demand.top_origins(kind, filters),
            top_pairs=await demand.top_pairs(kind, filters),
            by_day_and_hour=await demand.by_day_and_hour(kind, filters),
            supply_gaps=await demand.supply_gaps(filters),
        )

    async def overview_figures(self, period: Period, city: str | None) -> dict[str, Figure]:
        """Each overview figure over ``period`` and the period before it;
        with ``city``, figures that cannot be tied to a city are left out."""
        daily = await self._repo.daily(
            OVERVIEW_FIGURES, start=period.previous.since, end=period.until, city=city
        )
        return {name: figure_from(values, period) for name, values in daily.items()}


# ------------------------------------------------------------------ revenue
def _collected_booking_payments(name: str, value: Any, *, group: Any = None) -> DailyFigure:
    return DailyFigure(
        name=name,
        base=select(Payment.id)
        .select_from(Payment)
        .join(Booking, Booking.id == Payment.booking_id),
        timestamp=Payment.completed_at,
        value=value,
        trip_id=Booking.trip_id,
        conditions=(
            Payment.purpose == PaymentPurpose.BOOKING_PAYMENT,
            Payment.status.in_(COLLECTED_PAYMENT_STATUSES),
        ),
        group=group,
    )


def _booking_payment_attempts(name: str, *conditions: Any) -> DailyFigure:
    return DailyFigure(
        name=name,
        base=select(Payment.id)
        .select_from(Payment)
        .join(Booking, Booking.id == Payment.booking_id),
        timestamp=Payment.created_at,
        value=func.count(Payment.id),
        trip_id=Booking.trip_id,
        conditions=(Payment.purpose == PaymentPurpose.BOOKING_PAYMENT, *conditions),
    )


REVENUE_FIGURES: Sequence[DailyFigure] = (
    _collected_booking_payments("gross", func.coalesce(func.sum(Payment.amount), 0)),
    _collected_booking_payments("platform_fees", func.coalesce(func.sum(Booking.platform_fee), 0)),
    _collected_booking_payments("paid_bookings", func.count(Payment.id)),
    _collected_booking_payments(
        "by_method", func.coalesce(func.sum(Payment.amount), 0), group=Payment.channel
    ),
    DailyFigure(
        name="refunds",
        base=select(RefundRequest.id)
        .select_from(RefundRequest)
        .join(Booking, Booking.id == RefundRequest.booking_id),
        timestamp=RefundRequest.reviewed_at,
        value=func.coalesce(func.sum(RefundRequest.amount), 0),
        trip_id=Booking.trip_id,
        conditions=(RefundRequest.status == RefundStatus.COMPLETED,),
    ),
    _booking_payment_attempts("payment_attempts"),
    _booking_payment_attempts("failed_payments", Payment.status == PaymentStatus.FAILED),
)


@dataclass(frozen=True, slots=True)
class Ratio:
    value: Decimal | None
    previous: Decimal | None


@dataclass(frozen=True, slots=True)
class DemandReport:
    total: int
    previous_total: int
    cells: list[Cell]
    withheld: int
    top_origins: list[StopDemand]
    top_pairs: list[PairDemand]
    by_day_and_hour: dict[tuple[int, int], int]
    supply_gaps: list[SupplyGap]


@dataclass(frozen=True, slots=True)
class ComplaintStats:
    open_now: list[OpenCount]
    filed: Figure
    per_1000_trips: Ratio
    avg_first_response_hours: Ratio
    avg_resolution_hours: Ratio
    by_category: dict[ComplaintCategory, Figure]


def _ratio(numerator: Figure, denominator: Figure, *, places: str = "0.0001") -> Ratio:
    def divide(top: Decimal, bottom: Decimal) -> Decimal | None:
        return (top / bottom).quantize(Decimal(places)) if bottom else None

    return Ratio(
        divide(numerator.value, denominator.value), divide(numerator.previous, denominator.previous)
    )


def _difference(left: Figure, right: Figure) -> Figure:
    return Figure(
        value=left.value - right.value,
        previous=left.previous - right.previous,
        series=[(day, a - b) for (day, a), (_, b) in zip(left.series, right.series, strict=True)],
    )


@dataclass(frozen=True, slots=True)
class RevenueReport:
    gross: Figure
    refunds: Figure
    net: Figure
    platform_fees: Figure
    paid_bookings: Figure
    average_fare: Ratio
    failed_payment_rate: Ratio
    by_method: dict[str, Figure]
    by_route: list[RevenueSlice]
    by_fleet: list[RevenueSlice]
    by_hour: list[RevenueSlice]
    pending_withdrawals: Decimal
    pending_withdrawals_count: int


async def _revenue_report(
    repo: AdminAnalyticsRepository,
    finance: AdminFinanceRepository,
    period: Period,
    city: str | None,
) -> RevenueReport:
    daily = await repo.daily(
        REVENUE_FIGURES, start=period.previous.since, end=period.until, city=city
    )

    def figure(name: str) -> Figure:
        return figure_from(daily.get(name, {}), period)

    gross, refunds = figure("gross"), figure("refunds")
    paid = figure("paid_bookings")
    pending, pending_count = await finance.pending_withdrawals()
    breakdowns: dict[Breakdown, list[RevenueSlice]] = {}
    for by in get_args(Breakdown):
        breakdowns[by] = await finance.revenue_breakdown(
            by, since=period.since, until=period.until, city=city, limit=20
        )
    return RevenueReport(
        gross=gross,
        refunds=refunds,
        net=_difference(gross, refunds),
        platform_fees=figure("platform_fees"),
        paid_bookings=paid,
        average_fare=_ratio(gross, paid, places="0.01"),
        failed_payment_rate=_ratio(figure("failed_payments"), figure("payment_attempts")),
        by_method={
            name.split(":", 1)[1]: figure_from(values, period)
            for name, values in daily.items()
            if name.startswith("by_method:")
        },
        by_route=breakdowns["route"],
        by_fleet=breakdowns["fleet"],
        by_hour=breakdowns["hour"],
        pending_withdrawals=pending,
        pending_withdrawals_count=pending_count,
    )


# -------------------------------------------------------------- user growth
SIGNUP_FIGURES: Sequence[DailyFigure] = (
    DailyFigure(
        name="new_users",
        base=select(User.id).select_from(User),
        timestamp=User.created_at,
        value=func.count(User.id),
        conditions=(User.deleted_at.is_(None),),
    ),
    DailyFigure(
        name="signups",
        base=select(UserRole.user_id).select_from(UserRole).join(Role, Role.id == UserRole.role_id),
        timestamp=UserRole.assigned_at,
        value=func.count(UserRole.user_id),
        group=Role.slug,
    ),
)
ACTIVATION_WINDOW = timedelta(days=7)


@dataclass(frozen=True, slots=True)
class Activation:
    signed_up: int
    activated: int
    previous_signed_up: int
    previous_activated: int

    @staticmethod
    def _rate(done: int, of: int) -> Decimal | None:
        return (Decimal(done) / of).quantize(Decimal("0.0001")) if of else None

    @property
    def rate(self) -> Decimal | None:
        return self._rate(self.activated, self.signed_up)

    @property
    def previous_rate(self) -> Decimal | None:
        return self._rate(self.previous_activated, self.previous_signed_up)


@dataclass(frozen=True, slots=True)
class UsersReport:
    new_users: Figure
    signups_by_role: dict[str, Figure]
    cumulative_users: list[tuple[date, int]]
    daily_active: list[tuple[date, int]]
    average_daily_active: Decimal
    previous_average_daily_active: Decimal
    weekly_active: int
    previous_weekly_active: int
    monthly_active: int
    previous_monthly_active: int
    activation: Activation
    cohorts: list[Cohort]
    travellers_by_city: list[tuple[str, int]]


def _day_start(day: date) -> datetime:
    return datetime.combine(day, time.min, tzinfo=UTC)


async def _users_report(
    repo: AdminAnalyticsRepository, growth: AdminGrowthRepository, period: Period
) -> UsersReport:
    previous = period.previous
    daily = await repo.daily(SIGNUP_FIGURES, start=previous.since, end=period.until, city=None)
    new_users = figure_from(daily.get("new_users", {}), period)
    running = await growth.users_before(period.since)
    cumulative = []
    for day, value in new_users.series:
        running += int(value)
        cumulative.append((day, running))

    active = await growth.daily_active(previous.since, period.until)

    def average(p: Period) -> Decimal:
        total = sum(active.get(day, 0) for day in p.dates())
        return (Decimal(total) / p.days).quantize(Decimal("0.1"))

    def window(end: date, days: int) -> tuple[datetime, datetime]:
        return _day_start(end - timedelta(days=days - 1)), _day_start(end + timedelta(days=1))

    wau, previous_wau, mau, previous_mau = await growth.active_in(
        [
            window(period.end, 7),
            window(previous.end, 7),
            window(period.end, 30),
            window(previous.end, 30),
        ]
    )
    signed_up, activated = await growth.activation(
        period.since, period.until, within=ACTIVATION_WINDOW, paid_statuses=PAID_BOOKING_STATUSES
    )
    previous_signed_up, previous_activated = await growth.activation(
        previous.since,
        previous.until,
        within=ACTIVATION_WINDOW,
        paid_statuses=PAID_BOOKING_STATUSES,
    )
    return UsersReport(
        new_users=new_users,
        signups_by_role={
            name.split(":", 1)[1]: figure_from(values, period)
            for name, values in daily.items()
            if name.startswith("signups:")
        },
        cumulative_users=cumulative,
        daily_active=[(day, active.get(day, 0)) for day in period.dates()],
        average_daily_active=average(period),
        previous_average_daily_active=average(previous),
        weekly_active=wau,
        previous_weekly_active=previous_wau,
        monthly_active=mau,
        previous_monthly_active=previous_mau,
        activation=Activation(signed_up, activated, previous_signed_up, previous_activated),
        cohorts=await growth.retention(period.since, period.until),
        travellers_by_city=await growth.travellers_by_city(
            period.since, period.until, paid_statuses=PAID_BOOKING_STATUSES, limit=20
        ),
    )


# ------------------------------------------------------------------ funnel
FUNNEL_STAGES = ("searches", "reserved", "paid", "boarded")
FUNNEL_FIGURES: Sequence[DailyFigure] = (
    DailyFigure(
        name="searches",
        base=select(SearchEvent.id).select_from(SearchEvent),
        timestamp=SearchEvent.searched_at,
        value=func.count(SearchEvent.id),
        stop_id=SearchEvent.origin_stop_id,
    ),
    DailyFigure(
        name="reserved",
        base=select(Booking.id).select_from(Booking),
        timestamp=Booking.created_at,
        value=func.count(Booking.id),
        trip_id=Booking.trip_id,
    ),
    DailyFigure(
        name="paid",
        base=select(Booking.id).select_from(Booking),
        timestamp=Booking.created_at,
        value=func.count(Booking.id),
        trip_id=Booking.trip_id,
        conditions=(Booking.status.in_(PAID_BOOKING_STATUSES),),
    ),
    DailyFigure(
        name="boarded",
        base=select(Booking.id).select_from(Booking),
        timestamp=Booking.created_at,
        value=func.count(Booking.id),
        trip_id=Booking.trip_id,
        conditions=(
            exists().where(
                Ticket.booking_id == Booking.id, Ticket.status == TicketStatus.VALIDATED
            ),
        ),
    ),
)


# ------------------------------------------------------- driver performance
ON_TIME_GRACE = timedelta(minutes=5)
SCORE_WEIGHTS = {
    "rating": Decimal("0.35"),
    "on_time": Decimal("0.25"),
    "reliability": Decimal("0.15"),
    "complaints": Decimal("0.15"),
    "qr_scanning": Decimal("0.10"),
}
# A rule only flags a driver once there is enough to go on.
AT_RISK_RULES = {
    "low_rating": "Average rating below 3.5 (5+ ratings).",
    "late_starts": "Fewer than 70% of trips started on time (5+ trips).",
    "cancellations": "More than 10% of finished trips were cancelled (5+ trips).",
    "complaints": "More than 5 complaints per 100 trips (5+ trips).",
    "qr_not_scanned": "Fewer than 80% of tickets scanned at boarding (10+ tickets).",
}


def _share(part: int, whole: int) -> Decimal | None:
    return (Decimal(part) / whole).quantize(Decimal("0.0001")) if whole else None


@dataclass(frozen=True, slots=True)
class DriverPerformance:
    counts: DriverCounts
    average_rating: Decimal | None
    on_time_rate: Decimal | None
    cancellation_rate: Decimal | None
    complaints_per_100_trips: Decimal | None
    qr_scan_rate: Decimal | None
    score: Decimal | None
    breakdown: dict[str, Decimal | None]
    at_risk_reasons: list[str]

    @property
    def at_risk(self) -> bool:
        return bool(self.at_risk_reasons)


def score_driver(counts: DriverCounts) -> DriverPerformance:
    """Rates, a 0-100 score and at-risk reasons from one driver's counts.

    Each part of the score is 0-1: rating (1 star = 0, 5 = 1), on-time
    starts, trips not cancelled, complaints (10+ per 100 trips = 0) and
    tickets scanned. A part with no data yet is left out and the other
    weights scaled up, so a new driver is not marked down for having no
    ratings.
    """
    average = (
        (Decimal(counts.rating_total) / counts.ratings).quantize(Decimal("0.01"))
        if counts.ratings
        else None
    )
    on_time = _share(counts.on_time, counts.trips_completed)
    # Only trips that are over (run or called off) say anything about
    # reliability; trips still to come do not.
    resolved = counts.trips_completed + counts.trips_cancelled
    cancellation = _share(counts.trips_cancelled, resolved)
    per_100 = (
        (Decimal(counts.complaints) * 100 / counts.trips_completed).quantize(Decimal("0.01"))
        if counts.trips_completed
        else None
    )
    scanning = _share(counts.tickets_scanned, counts.tickets_issued)
    components: dict[str, Decimal | None] = {
        "rating": (average - 1) / 4 if average is not None else None,
        "on_time": on_time,
        "reliability": 1 - cancellation if cancellation is not None else None,
        "complaints": max(Decimal("0"), 1 - per_100 / 10) if per_100 is not None else None,
        "qr_scanning": scanning,
    }
    present = {name: value for name, value in components.items() if value is not None}
    score = None
    if present:
        weight = sum((SCORE_WEIGHTS[name] for name in present), Decimal("0"))
        weighted = sum(
            (SCORE_WEIGHTS[name] * value for name, value in present.items()), Decimal("0")
        )
        score = (weighted / weight * 100).quantize(Decimal("0.1"))
    reasons = []
    if counts.ratings >= 5 and average is not None and average < Decimal("3.5"):
        reasons.append("low_rating")
    if counts.trips_completed >= 5 and on_time is not None and on_time < Decimal("0.7"):
        reasons.append("late_starts")
    if resolved >= 5 and cancellation is not None and cancellation > Decimal("0.1"):
        reasons.append("cancellations")
    if counts.trips_completed >= 5 and per_100 is not None and per_100 > 5:
        reasons.append("complaints")
    if counts.tickets_issued >= 10 and scanning is not None and scanning < Decimal("0.8"):
        reasons.append("qr_not_scanned")
    return DriverPerformance(
        counts=counts,
        average_rating=average,
        on_time_rate=on_time,
        cancellation_rate=cancellation,
        complaints_per_100_trips=per_100,
        qr_scan_rate=scanning,
        score=score,
        breakdown={
            name: (value * 100).quantize(Decimal("0.1")) if value is not None else None
            for name, value in components.items()
        },
        at_risk_reasons=reasons,
    )


@dataclass(frozen=True, slots=True)
class DriverPerformanceDetail:
    performance: DriverPerformance
    full_name: str | None
    daily: list[DayCounts]
    rating_distribution: dict[int, int]
    recent_reviews: list[Review]
    earned_today: Decimal
    earned_this_week: Decimal
    earned_this_month: Decimal
    pending_withdrawals: Decimal


async def _driver_performance(
    session: AsyncSession,
    period: Period,
    *,
    city: str | None,
    fleet_id: uuid.UUID | None,
) -> list[tuple[DriverPerformance, str | None]]:
    counts = await AdminPerformanceRepository(session).counts(
        PeriodTrips(period.since, period.until, city=city, fleet_id=fleet_id), grace=ON_TIME_GRACE
    )
    names = await AdminDirectoryRepository(session).driver_names(counts.keys())
    return [(score_driver(each), names.get(driver_id)) for driver_id, each in counts.items()]


async def _driver_performance_detail(
    session: AsyncSession, driver_id: uuid.UUID, period: Period
) -> DriverPerformanceDetail:
    driver = await session.get(Driver, driver_id)
    if driver is None:
        raise NotFoundError("Driver not found.")
    repo = AdminPerformanceRepository(session)
    scope = PeriodTrips(period.since, period.until, driver_ids=[driver_id])
    counts = (await repo.counts(scope, grace=ON_TIME_GRACE)).get(driver_id, DriverCounts(driver_id))
    names = await AdminDirectoryRepository(session).driver_names([driver_id])

    today = datetime.now(UTC).date()
    starts = [
        _day_start(today),
        _day_start(today - timedelta(days=today.weekday())),
        _day_start(today.replace(day=1)),
    ]
    minor = Decimal(1).scaleb(-get_settings().payments_default_currency_minor_unit)
    earned = [
        (Decimal(units) * minor).quantize(minor)
        for units in await repo.earnings_since(driver.user_id, starts)
    ]
    return DriverPerformanceDetail(
        performance=score_driver(counts),
        full_name=names.get(driver_id),
        daily=await repo.daily(driver_id, scope, grace=ON_TIME_GRACE),
        rating_distribution=await repo.rating_distribution(driver_id, scope),
        recent_reviews=await repo.recent_reviews(driver_id, limit=10),
        earned_today=earned[0],
        earned_this_week=earned[1],
        earned_this_month=earned[2],
        pending_withdrawals=(
            await WalletRepository(session).pending_withdrawals_total(driver.user_id)
        ).quantize(Decimal("0.01")),
    )
