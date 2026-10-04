"""Responses for admin analytics: payments, revenue, user growth, the
conversion funnel and driver performance."""

from __future__ import annotations

import uuid
from datetime import date, datetime
from decimal import Decimal
from typing import Literal

from pydantic import Field

from app.models.payments import PaymentPurpose, PaymentStatus
from app.providers.payments.base import PaymentChannel
from app.schemas.analytics import CountFigure, CountPoint, MoneyFigure, PeriodResponse
from app.schemas.common import ApiModel


class Compared(ApiModel):
    """A single value against the previous period."""

    value: Decimal | None
    previous: Decimal | None


# ----------------------------------------------------------------- payments
class PaymentBookingRef(ApiModel):
    id: uuid.UUID
    reference: str


class PayerRef(ApiModel):
    id: uuid.UUID
    name: str | None
    phone_number: str


class AdminPaymentResponse(ApiModel):
    id: uuid.UUID
    reference: str = Field(..., description="TroSky's own reference.")
    provider_reference: str | None
    purpose: PaymentPurpose
    method: PaymentChannel
    status: PaymentStatus
    amount: Decimal
    platform_fee: Decimal | None = Field(..., description="TroSky's fee within it (bookings).")
    refunded_amount: Decimal
    currency: str
    failure_reason: str | None
    booking: PaymentBookingRef | None
    payer: PayerRef
    route_name: str | None
    created_at: datetime
    completed_at: datetime | None


# ------------------------------------------------------------------ revenue
class MethodFigure(MoneyFigure):
    method: str


class RevenueSliceResponse(ApiModel):
    key: str = Field(..., description="Route or fleet id, or the hour (0-23).")
    label: str | None
    amount: Decimal
    payments: int


class PendingWithdrawals(ApiModel):
    amount: Decimal
    count: int


class RevenueResponse(ApiModel):
    period: PeriodResponse
    gross: MoneyFigure = Field(..., description="Collected for bookings, by payment date.")
    refunds: MoneyFigure = Field(..., description="Refunds paid out, by payout date.")
    net: MoneyFigure = Field(..., description="gross - refunds.")
    platform_fees: MoneyFigure = Field(..., description="TroSky's fees within gross.")
    paid_bookings: CountFigure
    average_fare: Compared = Field(..., description="gross / paid bookings.")
    failed_payment_rate: Compared = Field(
        ..., description="Failed booking payments / all attempts started in the period (0-1)."
    )
    by_method: list[MethodFigure]
    by_route: list[RevenueSliceResponse] = Field(..., description="Top 20, this period.")
    by_fleet: list[RevenueSliceResponse] = Field(..., description="Top 20, this period.")
    by_hour: list[RevenueSliceResponse] = Field(..., description="Ghana time, this period.")
    pending_withdrawals: PendingWithdrawals = Field(..., description="Now, not per period.")


# -------------------------------------------------------------- user growth
class RoleFigure(CountFigure):
    role: str


class ActivationResponse(ApiModel):
    signed_up: int
    activated: int = Field(..., description="Made a paid booking within 7 days of signing up.")
    rate: Decimal | None
    previous_signed_up: int
    previous_activated: int
    previous_rate: Decimal | None


class CohortResponse(ApiModel):
    week: date = Field(..., description="Monday of the week they signed up.")
    size: int
    retained: list[int] = Field(..., description="Active in week 1, 2, ... after joining.")
    retention_rates: list[Decimal]


class CityUsers(ApiModel):
    city: str
    users: int


class UsersResponse(ApiModel):
    """ "Active" = signed in or made a booking that day."""

    period: PeriodResponse
    new_users: CountFigure
    signups_by_role: list[RoleFigure]
    cumulative_users: list[CountPoint]
    daily_active: list[CountPoint]
    average_daily_active: Compared
    weekly_active: Compared = Field(..., description="In the 7 days to the period's end.")
    monthly_active: Compared = Field(..., description="In the 30 days to the period's end.")
    activation: ActivationResponse
    cohorts: list[CohortResponse]
    travellers_by_city: list[CityUsers] = Field(
        ..., description="Passengers with a paid booking, by the city their trip started in."
    )


class FunnelStage(ApiModel):
    stage: str
    value: int
    previous: int
    change_percent: Decimal | None
    conversion: Decimal | None = Field(
        ..., description="Share of the stage before (0-1); null for the first."
    )
    previous_conversion: Decimal | None


class FunnelResponse(ApiModel):
    """Searches, then bookings made in the period: reserved (any), paid, and
    boarded (a ticket scanned). Searches are counted from 3 Oct 2026, when
    they started being recorded."""

    period: PeriodResponse
    stages: list[FunnelStage]


# ------------------------------------------------------- driver performance
class ScoreBreakdown(ApiModel):
    """Each part of the score, 0-100; null when there is no data yet."""

    rating: Decimal | None
    on_time: Decimal | None
    reliability: Decimal | None
    complaints: Decimal | None
    qr_scanning: Decimal | None


class AtRiskReason(ApiModel):
    code: str
    message: str


class DriverPerformanceResponse(ApiModel):
    driver_id: uuid.UUID
    full_name: str | None
    trips_assigned: int
    trips_completed: int
    trips_cancelled: int
    average_rating: Decimal | None
    rating_count: int
    on_time_rate: Decimal | None = Field(
        ..., description="Completed trips that left within 5 minutes of schedule (0-1)."
    )
    cancellation_rate: Decimal | None
    complaints: int
    complaints_per_100_trips: Decimal | None
    tickets_issued: int
    tickets_scanned: int
    qr_scan_rate: Decimal | None = Field(..., description="Tickets scanned / issued (0-1).")
    score: Decimal | None = Field(..., description="0-100, weighted; see score_breakdown.")
    score_breakdown: ScoreBreakdown
    at_risk: bool
    at_risk_reasons: list[AtRiskReason]


class DailyPerformance(ApiModel):
    date: date
    trips_completed: int
    on_time_rate: Decimal | None
    average_rating: Decimal | None


class RatingCount(ApiModel):
    score: int
    count: int


class ReviewResponse(ApiModel):
    rating_id: uuid.UUID
    trip_id: uuid.UUID
    score: int
    comment: str | None
    created_at: datetime


class DriverEarnings(ApiModel):
    today: Decimal
    this_week: Decimal = Field(..., description="Since Monday.")
    this_month: Decimal
    currency: str
    pending_withdrawals: Decimal


class DriverPerformanceDetailResponse(DriverPerformanceResponse):
    period: PeriodResponse
    daily: list[DailyPerformance]
    rating_distribution: list[RatingCount]
    recent_reviews: list[ReviewResponse]
    earnings: DriverEarnings


# ----------------------------------------------------------------- demand
DemandType = Literal["searches", "unmet", "bookings"]
DayName = Literal["mon", "tue", "wed", "thu", "fri", "sat", "sun"]


class DemandCell(ApiModel):
    latitude: Decimal = Field(..., description="The grid point the cell is around.")
    longitude: Decimal
    weight: int


class DemandStop(ApiModel):
    stop_id: uuid.UUID
    name: str
    city: str | None
    weight: int


class DemandPair(ApiModel):
    origin_stop_id: uuid.UUID
    origin_name: str
    destination_stop_id: uuid.UUID
    destination_name: str
    weight: int


class DemandDay(ApiModel):
    day: DayName
    hours: list[int] = Field(..., description="24 values: 00:00-00:59 to 23:00-23:59, Ghana time.")


class SupplyGapResponse(ApiModel):
    stop_id: uuid.UUID
    name: str
    city: str | None
    searches: int = Field(..., description="Searches with this pickup stop.")
    unmet: int = Field(..., description="Of those, how many found no bus with a free seat.")
    unmet_share: Decimal


class DemandResponse(ApiModel):
    period: PeriodResponse
    type: DemandType
    days: list[DayName] | None
    hour_from: int | None
    hour_to: int | None
    total: int = Field(..., description="Searches, or seats booked, over the period.")
    previous_total: int = Field(..., description="The same number of days just before.")
    change_percent: Decimal | None
    cell_degrees: Decimal = Field(..., description="Each cell's side: about 550 m.")
    cells: list[DemandCell] = Field(..., description="Heaviest first.")
    withheld: int = Field(
        ...,
        description="Searches in cells with too few to show without singling anyone out.",
    )
    top_origins: list[DemandStop]
    top_pairs: list[DemandPair]
    by_day_and_hour: list[DemandDay] = Field(..., description="Monday first.")
    supply_gaps: list[SupplyGapResponse] = Field(
        ..., description="Pickup stops where searches most often found nothing to book."
    )
