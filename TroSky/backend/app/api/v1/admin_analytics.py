"""Admin analytics: every payment, revenue, user growth, the conversion
funnel and driver performance. Mounted under ``/admin``.

Every report takes ``from``/``to`` (inclusive Ghana dates; default the last
30 days) and compares it with the same number of days just before.
"""

from __future__ import annotations

import uuid
from datetime import UTC, date, datetime, time, timedelta
from decimal import Decimal
from typing import Annotated

from fastapi import APIRouter, Depends, Query, Response

from app.api.common_dependencies import DbSession, Pagination
from app.api.v1.analytics_views import count_figure, money_figure, period_response
from app.api.v1.listing import (
    CSV_RESPONSE,
    ExportFormat,
    FormatQuery,
    csv_response,
    export_window,
    parse_sort,
)
from app.core.config import get_settings
from app.core.exceptions import ValidationAppError
from app.core.permissions import Permission, require_permissions
from app.models.analytics import SEARCH_GRID_DEGREES
from app.models.payments import PaymentPurpose, PaymentStatus
from app.providers.payments.base import PaymentChannel
from app.repositories.admin_finance_repository import (
    AdminFinanceRepository,
    PaymentFilters,
    PaymentRow,
)
from app.schemas.admin_analytics import (
    ActivationResponse,
    AdminPaymentResponse,
    AtRiskReason,
    CityUsers,
    CohortResponse,
    Compared,
    DailyPerformance,
    DayName,
    DemandCell,
    DemandDay,
    DemandPair,
    DemandResponse,
    DemandStop,
    DemandType,
    DriverEarnings,
    DriverPerformanceDetailResponse,
    DriverPerformanceResponse,
    FunnelResponse,
    FunnelStage,
    MethodFigure,
    PayerRef,
    PaymentBookingRef,
    PendingWithdrawals,
    RatingCount,
    RevenueResponse,
    RevenueSliceResponse,
    ReviewResponse,
    RoleFigure,
    ScoreBreakdown,
    SupplyGapResponse,
    UsersResponse,
)
from app.schemas.analytics import CountPoint
from app.schemas.common import PaginatedResponse
from app.services.admin_analytics_service import (
    AT_RISK_RULES,
    FUNNEL_STAGES,
    AdminAnalyticsService,
    DriverPerformance,
    Period,
)
from app.utilities.query_params import parse_enum_list

router = APIRouter()

_REPORTS = require_permissions(Permission.REPORTS_VIEW)
_MONEY = require_permissions(
    Permission.PAYMENTS_REVIEW, Permission.REFUNDS_APPROVE, Permission.REPORTS_VIEW
)
_DRIVERS = require_permissions(Permission.REPORTS_VIEW, Permission.DRIVERS_APPROVE)

DateFrom = Annotated[
    date | None, Query(alias="from", description="Inclusive. Default: 29 days before 'to'.")
]
DateTo = Annotated[date | None, Query(alias="to", description="Inclusive. Default: today.")]
City = Annotated[str | None, Query(max_length=100, description="Where trips start.")]


def get_analytics(db: DbSession) -> AdminAnalyticsService:
    return AdminAnalyticsService(db)


Analytics = Annotated[AdminAnalyticsService, Depends(get_analytics)]


def _rate(part: int, whole: int) -> Decimal | None:
    return (Decimal(part) / whole).quantize(Decimal("0.0001")) if whole else None


# ----------------------------------------------------------------- payments
def _payment_response(row: PaymentRow) -> AdminPaymentResponse:
    return AdminPaymentResponse(
        id=row.payment_id,
        reference=row.internal_reference,
        provider_reference=row.provider_reference,
        purpose=row.purpose,
        method=row.channel,
        status=row.status,
        amount=row.amount,
        platform_fee=row.platform_fee,
        refunded_amount=row.refunded_amount,
        currency=row.currency,
        failure_reason=row.failure_reason,
        booking=(
            PaymentBookingRef(id=row.booking_id, reference=row.booking_reference)
            if row.booking_id and row.booking_reference
            else None
        ),
        payer=PayerRef(id=row.user_id, name=row.passenger_name, phone_number=row.passenger_phone),
        route_name=row.route_name,
        created_at=row.created_at,
        completed_at=row.completed_at,
    )


_PAYMENT_SORTS = ("created_at", "completed_at", "amount", "status")


@router.get(
    "/payments",
    response_model=PaginatedResponse[AdminPaymentResponse],
    responses=CSV_RESPONSE,
    dependencies=[Depends(_MONEY)],
)
async def list_payments(
    db: DbSession,
    pagination: Pagination,
    date_from: DateFrom = None,
    date_to: DateTo = None,
    method: Annotated[str | None, Query(description="Payment channels, comma-separated.")] = None,
    status: Annotated[str | None, Query(description="Statuses, comma-separated.")] = None,
    purpose: Annotated[
        str | None, Query(description="booking_payment and/or wallet_topup.")
    ] = None,
    city: City = None,
    route_id: uuid.UUID | None = None,
    fleet_id: uuid.UUID | None = None,
    q: Annotated[
        str | None, Query(max_length=60, description="Payment or booking reference, or phone.")
    ] = None,
    sort: Annotated[str | None, Query(description=f"One of {', '.join(_PAYMENT_SORTS)}.")] = None,
    export: ExportFormat = FormatQuery,
) -> PaginatedResponse[AdminPaymentResponse] | Response:
    """Every payment, newest first: bookings and wallet top-ups, whatever
    their status. ``from``/``to`` filter on when the payment was started."""
    field, descending = parse_sort(sort, _PAYMENT_SORTS, default="-created_at")
    limit, offset = export_window(pagination, export)
    rows, total = await AdminFinanceRepository(db).list_payments(
        PaymentFilters(
            since=datetime.combine(date_from, time.min, tzinfo=UTC) if date_from else None,
            until=(
                datetime.combine(date_to + timedelta(days=1), time.min, tzinfo=UTC)
                if date_to
                else None
            ),
            channels=parse_enum_list(method, PaymentChannel, param="method"),
            statuses=parse_enum_list(status, PaymentStatus, param="status"),
            purposes=parse_enum_list(purpose, PaymentPurpose, param="purpose"),
            city=city,
            route_id=route_id,
            fleet_id=fleet_id,
            query=q,
        ),
        sort=field,
        descending=descending,
        limit=limit,
        offset=offset,
    )
    items = [_payment_response(row) for row in rows]
    if export == "csv":
        return csv_response(items, name="payments")
    return PaginatedResponse(
        items=items, total=total, limit=pagination.limit, offset=pagination.offset
    )


# ------------------------------------------------------------------ revenue
@router.get("/analytics/revenue", response_model=RevenueResponse, dependencies=[Depends(_MONEY)])
async def get_revenue(
    analytics: Analytics, date_from: DateFrom = None, date_to: DateTo = None, city: City = None
) -> RevenueResponse:
    """Money in and out over the period, against the period before: gross
    booking payments, refunds, net, TroSky's fees, average fare, failed
    payments; by payment method per day, and by route, fleet and hour."""
    period = Period.resolve(date_from, date_to)
    report = await analytics.revenue(period, city)
    return RevenueResponse(
        period=period_response(period, city),
        gross=money_figure(report.gross),
        refunds=money_figure(report.refunds),
        net=money_figure(report.net),
        platform_fees=money_figure(report.platform_fees),
        paid_bookings=count_figure(report.paid_bookings),
        average_fare=Compared(
            value=report.average_fare.value, previous=report.average_fare.previous
        ),
        failed_payment_rate=Compared(
            value=report.failed_payment_rate.value, previous=report.failed_payment_rate.previous
        ),
        by_method=[
            MethodFigure(method=method, **money_figure(figure).model_dump())
            for method, figure in sorted(report.by_method.items())
        ],
        by_route=[RevenueSliceResponse.model_validate(s) for s in report.by_route],
        by_fleet=[RevenueSliceResponse.model_validate(s) for s in report.by_fleet],
        by_hour=[RevenueSliceResponse.model_validate(s) for s in report.by_hour],
        pending_withdrawals=PendingWithdrawals(
            amount=report.pending_withdrawals, count=report.pending_withdrawals_count
        ),
    )


# -------------------------------------------------------------- user growth
@router.get("/analytics/users", response_model=UsersResponse, dependencies=[Depends(_REPORTS)])
async def get_user_growth(
    analytics: Analytics, date_from: DateFrom = None, date_to: DateTo = None
) -> UsersResponse:
    """Sign-ups by role, users over time, daily/weekly/monthly active
    users, activation within 7 days, weekly retention cohorts, and where
    passengers travel. Users have no city, so there is no city filter."""
    period = Period.resolve(date_from, date_to)
    report = await analytics.users(period)
    activation = report.activation
    return UsersResponse(
        period=period_response(period, None),
        new_users=count_figure(report.new_users),
        signups_by_role=[
            RoleFigure(role=role, **count_figure(figure).model_dump())
            for role, figure in sorted(report.signups_by_role.items())
        ],
        cumulative_users=[CountPoint(date=d, value=v) for d, v in report.cumulative_users],
        daily_active=[CountPoint(date=d, value=v) for d, v in report.daily_active],
        average_daily_active=Compared(
            value=report.average_daily_active, previous=report.previous_average_daily_active
        ),
        weekly_active=Compared(
            value=Decimal(report.weekly_active), previous=Decimal(report.previous_weekly_active)
        ),
        monthly_active=Compared(
            value=Decimal(report.monthly_active), previous=Decimal(report.previous_monthly_active)
        ),
        activation=ActivationResponse(
            signed_up=activation.signed_up,
            activated=activation.activated,
            rate=activation.rate,
            previous_signed_up=activation.previous_signed_up,
            previous_activated=activation.previous_activated,
            previous_rate=activation.previous_rate,
        ),
        cohorts=[
            CohortResponse(
                week=cohort.week,
                size=cohort.size,
                retained=cohort.retained,
                retention_rates=[_rate(n, cohort.size) or Decimal("0") for n in cohort.retained],
            )
            for cohort in report.cohorts
        ],
        travellers_by_city=[CityUsers(city=c, users=n) for c, n in report.travellers_by_city],
    )


@router.get("/analytics/funnel", response_model=FunnelResponse, dependencies=[Depends(_REPORTS)])
async def get_funnel(
    analytics: Analytics, date_from: DateFrom = None, date_to: DateTo = None, city: City = None
) -> FunnelResponse:
    """Searches -> seats reserved -> paid -> boarded (ticket scanned), with
    the share of each stage that reached the next."""
    period = Period.resolve(date_from, date_to)
    figures = await analytics.funnel(period, city)
    stages = []
    for index, stage in enumerate(FUNNEL_STAGES):
        figure = figures[stage]
        before = figures[FUNNEL_STAGES[index - 1]] if index else None
        stages.append(
            FunnelStage(
                stage=stage,
                value=int(figure.value),
                previous=int(figure.previous),
                change_percent=figure.change_percent,
                conversion=_rate(int(figure.value), int(before.value)) if before else None,
                previous_conversion=(
                    _rate(int(figure.previous), int(before.previous)) if before else None
                ),
            )
        )
    return FunnelResponse(period=period_response(period, city), stages=stages)


# ------------------------------------------------------- driver performance
def _performance_response(
    performance: DriverPerformance, full_name: str | None
) -> DriverPerformanceResponse:
    counts = performance.counts
    return DriverPerformanceResponse(
        driver_id=counts.driver_id,
        full_name=full_name,
        trips_assigned=counts.trips_assigned,
        trips_completed=counts.trips_completed,
        trips_cancelled=counts.trips_cancelled,
        average_rating=performance.average_rating,
        rating_count=counts.ratings,
        on_time_rate=performance.on_time_rate,
        cancellation_rate=performance.cancellation_rate,
        complaints=counts.complaints,
        complaints_per_100_trips=performance.complaints_per_100_trips,
        tickets_issued=counts.tickets_issued,
        tickets_scanned=counts.tickets_scanned,
        qr_scan_rate=performance.qr_scan_rate,
        score=performance.score,
        score_breakdown=ScoreBreakdown(**performance.breakdown),
        at_risk=performance.at_risk,
        at_risk_reasons=[
            AtRiskReason(code=code, message=AT_RISK_RULES[code])
            for code in performance.at_risk_reasons
        ],
    )


_PERFORMANCE_SORTS = (
    "score",
    "average_rating",
    "trips_completed",
    "on_time_rate",
    "cancellation_rate",
    "complaints_per_100_trips",
    "qr_scan_rate",
    "full_name",
)


@router.get(
    "/drivers/performance",
    response_model=PaginatedResponse[DriverPerformanceResponse],
    responses=CSV_RESPONSE,
    dependencies=[Depends(_DRIVERS)],
)
async def list_driver_performance(
    analytics: Analytics,
    pagination: Pagination,
    date_from: DateFrom = None,
    date_to: DateTo = None,
    city: City = None,
    fleet_id: uuid.UUID | None = None,
    at_risk: Annotated[bool | None, Query(description="Only drivers flagged at risk.")] = None,
    min_trips: Annotated[int, Query(ge=0, description="Completed trips at least.")] = 0,
    sort: Annotated[
        str | None, Query(description=f"One of {', '.join(_PERFORMANCE_SORTS)}.")
    ] = None,
    export: ExportFormat = FormatQuery,
) -> PaginatedResponse[DriverPerformanceResponse] | Response:
    """Every driver with a trip in the period: rating, on-time starts,
    cancellations, complaints, QR scanning, a 0-100 score with its parts,
    and whether they are at risk (and why). Worst score first by default."""
    field, descending = parse_sort(sort, _PERFORMANCE_SORTS, default="score")
    period = Period.resolve(date_from, date_to)
    scored = await analytics.driver_performance(period, city=city, fleet_id=fleet_id)
    items = [
        _performance_response(performance, name)
        for performance, name in scored
        if performance.counts.trips_completed >= min_trips
        and (at_risk is None or performance.at_risk == at_risk)
    ]
    present = [i for i in items if getattr(i, field) is not None]
    missing = [i for i in items if getattr(i, field) is None]
    present.sort(key=lambda item: getattr(item, field), reverse=descending)
    ordered = present + missing
    if export == "csv":
        return csv_response(ordered, name="driver-performance")
    limit, offset = export_window(pagination, export)
    return PaginatedResponse(
        items=ordered[offset : offset + limit], total=len(ordered), limit=limit, offset=offset
    )


@router.get(
    "/drivers/{driver_id}/performance",
    response_model=DriverPerformanceDetailResponse,
    dependencies=[Depends(_DRIVERS)],
)
async def get_driver_performance(
    driver_id: uuid.UUID,
    analytics: Analytics,
    date_from: DateFrom = None,
    date_to: DateTo = None,
) -> DriverPerformanceDetailResponse:
    """One driver over the period: the same figures, a daily trend, the
    spread of their ratings, recent reviews, and earnings today, this week
    and this month with withdrawals still to be paid."""
    period = Period.resolve(date_from, date_to)
    detail = await analytics.driver_performance_detail(driver_id, period)
    return DriverPerformanceDetailResponse(
        **_performance_response(detail.performance, detail.full_name).model_dump(),
        period=period_response(period, None),
        daily=[
            DailyPerformance(
                date=day.day,
                trips_completed=day.trips_completed,
                on_time_rate=_rate(day.on_time, day.trips_completed),
                average_rating=day.rating_average,
            )
            for day in detail.daily
        ],
        rating_distribution=[
            RatingCount(score=score, count=detail.rating_distribution.get(score, 0))
            for score in range(1, 6)
        ],
        recent_reviews=[ReviewResponse.model_validate(review) for review in detail.recent_reviews],
        earnings=DriverEarnings(
            today=detail.earned_today,
            this_week=detail.earned_this_week,
            this_month=detail.earned_this_month,
            currency=get_settings().PAYMENTS_DEFAULT_CURRENCY,
            pending_withdrawals=detail.pending_withdrawals,
        ),
    )


# ------------------------------------------------------------------- demand
_DAY_NAMES: tuple[DayName, ...] = ("mon", "tue", "wed", "thu", "fri", "sat", "sun")


def _days(raw: str | None) -> list[DayName] | None:
    if raw is None or not raw.strip():
        return None
    wanted = [part.strip().lower() for part in raw.split(",") if part.strip()]
    unknown = sorted(set(wanted) - set(_DAY_NAMES))
    if unknown:
        raise ValidationAppError(
            f"Unknown days: {', '.join(unknown)}.",
            details={"param": "days", "allowed": list(_DAY_NAMES)},
        )
    return [day for day in _DAY_NAMES if day in wanted]


@router.get("/analytics/demand", response_model=DemandResponse, dependencies=[Depends(_REPORTS)])
async def get_demand(
    analytics: Analytics,
    kind: Annotated[
        DemandType,
        Query(
            alias="type",
            description="searches, unmet (searches that found no bus with a free seat), "
            "or bookings (seats).",
        ),
    ] = "searches",
    date_from: DateFrom = None,
    date_to: DateTo = None,
    city: City = None,
    days: Annotated[
        str | None, Query(description="Days of the week, e.g. 'mon,tue,wed,thu,fri'.")
    ] = None,
    hour_from: Annotated[int | None, Query(ge=0, le=23, description="Ghana time.")] = None,
    hour_to: Annotated[
        int | None,
        Query(ge=0, le=23, description="Inclusive; before hour_from wraps past midnight."),
    ] = None,
) -> DemandResponse:
    """Heat-map data for demand: totals per ~550 m grid cell (never anyone's
    position: a GPS search keeps only its cell, and cells with fewer than 3
    searches are withheld), the busiest pickup stops and journeys, the week
    hour by hour, and the pickup stops where searches most often found no bus
    with a free seat. Filter by city (where the pickup stop is), days of the
    week and hours of the day."""
    period = Period.resolve(date_from, date_to)
    chosen_days = _days(days)
    report = await analytics.demand(
        period,
        kind,
        city=city,
        days=[_DAY_NAMES.index(day) + 1 for day in chosen_days] if chosen_days else None,
        hour_from=hour_from,
        hour_to=hour_to,
    )
    change = (
        (Decimal(report.total - report.previous_total) / report.previous_total * 100).quantize(
            Decimal("0.1")
        )
        if report.previous_total
        else None
    )
    return DemandResponse(
        period=period_response(period, city),
        type=kind,
        days=chosen_days,
        hour_from=hour_from,
        hour_to=hour_to,
        total=report.total,
        previous_total=report.previous_total,
        change_percent=change,
        cell_degrees=SEARCH_GRID_DEGREES,
        cells=[
            DemandCell(latitude=cell.latitude, longitude=cell.longitude, weight=cell.weight)
            for cell in report.cells
        ],
        withheld=report.withheld,
        top_origins=[
            DemandStop(stop_id=stop.stop_id, name=stop.name, city=stop.city, weight=stop.weight)
            for stop in report.top_origins
        ],
        top_pairs=[
            DemandPair(
                origin_stop_id=pair.origin_stop_id,
                origin_name=pair.origin_name,
                destination_stop_id=pair.destination_stop_id,
                destination_name=pair.destination_name,
                weight=pair.weight,
            )
            for pair in report.top_pairs
        ],
        by_day_and_hour=[
            DemandDay(
                day=name,
                hours=[report.by_day_and_hour.get((number, hour), 0) for hour in range(24)],
            )
            for number, name in enumerate(_DAY_NAMES, start=1)
        ],
        supply_gaps=[
            SupplyGapResponse(
                stop_id=gap.stop_id,
                name=gap.name,
                city=gap.city,
                searches=gap.searches,
                unmet=gap.unmet,
                unmet_share=(Decimal(gap.unmet) / gap.searches).quantize(Decimal("0.0001")),
            )
            for gap in report.supply_gaps
        ],
    )
