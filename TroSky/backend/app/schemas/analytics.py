"""Response schemas for fleet analytics and the admin platform overview."""

from __future__ import annotations

from datetime import date
from decimal import Decimal

from pydantic import Field

from app.schemas.common import ApiModel


class FleetSummaryResponse(ApiModel):
    vehicle_count: int
    total_trips: int
    completed_trips: int
    total_revenue: Decimal
    average_rating: Decimal | None
    rating_count: int


class PeriodResponse(ApiModel):
    from_date: date
    to_date: date
    previous_from_date: date
    previous_to_date: date
    days: int
    city: str | None


class CountPoint(ApiModel):
    date: date
    value: int


class CountFigure(ApiModel):
    value: int
    previous: int = Field(..., description="The same number of days just before.")
    change_percent: Decimal | None = Field(
        ..., description="Against the previous period; null when that was zero."
    )
    series: list[CountPoint]


class MoneyPoint(ApiModel):
    date: date
    value: Decimal


class MoneyFigure(ApiModel):
    value: Decimal
    previous: Decimal
    change_percent: Decimal | None
    series: list[MoneyPoint]


class OverviewFiguresResponse(ApiModel):
    """Per period. With ``city``, figures that cannot be tied to a city
    (sign-ups) are null."""

    new_users: CountFigure | None
    new_passengers: CountFigure | None
    new_drivers: CountFigure | None
    paid_bookings: CountFigure | None = Field(
        ..., description="Bookings made in the period that were paid, whatever happened next."
    )
    completed_trips: CountFigure | None
    booking_payments: MoneyFigure | None = Field(
        ..., description="Money collected for bookings, by payment date, before refunds."
    )
    complaints: CountFigure | None
    sos_alerts: CountFigure | None


class PlatformOverviewResponse(ApiModel):
    """All-time totals and live counts (never filtered), plus ``figures``
    for the period and city asked for."""

    total_users: int
    total_passengers: int
    total_drivers: int
    total_fleet_owners: int
    total_bookings: int
    completed_bookings: int
    total_revenue: Decimal
    active_trips: int
    open_complaints: int
    active_sos_alerts: int
    period: PeriodResponse
    figures: OverviewFiguresResponse
