"""Shared builders for analytics responses: periods and figures."""

from __future__ import annotations

from decimal import Decimal

from app.schemas.analytics import CountFigure, CountPoint, MoneyFigure, MoneyPoint, PeriodResponse
from app.services.admin_analytics_service import Figure, Period

_CENTS = Decimal("0.01")


def period_response(period: Period, city: str | None) -> PeriodResponse:
    previous = period.previous
    return PeriodResponse(
        from_date=period.start,
        to_date=period.end,
        previous_from_date=previous.start,
        previous_to_date=previous.end,
        days=period.days,
        city=city,
    )


def count_figure(figure: Figure) -> CountFigure:
    return CountFigure(
        value=int(figure.value),
        previous=int(figure.previous),
        change_percent=figure.change_percent,
        series=[CountPoint(date=day, value=int(value)) for day, value in figure.series],
    )


def money_figure(figure: Figure) -> MoneyFigure:
    return MoneyFigure(
        value=figure.value.quantize(_CENTS),
        previous=figure.previous.quantize(_CENTS),
        change_percent=figure.change_percent,
        series=[MoneyPoint(date=day, value=value.quantize(_CENTS)) for day, value in figure.series],
    )
