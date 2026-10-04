"""``/admin/reports/{report}``: the six reports SRS section 17 lists, as JSON
or CSV (the dashboard renders PDF and XLSX itself). Mounted under
``/admin`` after the main admin router, whose ``/reports/overview`` is a
different thing and matches first. Needs ``reports:view``.
"""

from __future__ import annotations

import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, Query, Response

from app.api.common_dependencies import DbSession
from app.api.v1.admin_analytics import City, DateFrom, DateTo
from app.api.v1.analytics_views import period_response
from app.api.v1.listing import CSV_RESPONSE, ExportFormat, FormatQuery, table_csv_response
from app.core.permissions import Permission, require_permissions
from app.repositories.admin_reports_repository import Granularity, Scope
from app.schemas.admin_reports import ReportColumnResponse, ReportResponse
from app.services.admin_analytics_service import Period
from app.services.admin_reports_service import AdminReportsService, ReportName

router = APIRouter()

_BREAKDOWNS = {"peak_hours", "route_popularity"}


@router.get(
    "/reports/{report}",
    response_model=ReportResponse,
    responses=CSV_RESPONSE,
    dependencies=[Depends(require_permissions(Permission.REPORTS_VIEW))],
)
async def get_report(
    report: ReportName,
    db: DbSession,
    date_from: DateFrom = None,
    date_to: DateTo = None,
    city: City = None,
    route_id: Annotated[uuid.UUID | None, Query(alias="route")] = None,
    fleet_id: Annotated[uuid.UUID | None, Query(alias="fleet")] = None,
    granularity: Annotated[
        Granularity, Query(description="Rows per day, week (from Monday) or month.")
    ] = "day",
    export: ExportFormat = FormatQuery,
) -> ReportResponse | Response:
    """One of the reports, over ``from``-``to`` (Ghana dates, up to a year),
    optionally for one city (where trips start), route or fleet:

    * ``daily_rides`` -- trips completed and cancelled, seats offered and
      booked, occupancy, passengers boarded;
    * ``revenue`` -- paid bookings, gross, refunds, net, platform fees,
      average fare;
    * ``peak_hours`` -- by hour of the day: trips, seats, boardings,
      bookings made, searches;
    * ``route_popularity`` -- by route, busiest first;
    * ``passenger_growth`` -- new, total, active and first-time passengers;
    * ``cancellation_rates`` -- cancellations by passengers and with their
      trip, expired bookings, cancelled trips, and the rates.

    The time series have a row per ``granularity``; the two breakdowns
    ignore it. ``?format=csv`` returns the rows."""
    period = Period.resolve(date_from, date_to)
    scope = Scope(city=city, route_id=route_id, fleet_id=fleet_id)
    built = await AdminReportsService(db).build(
        report, period, granularity=granularity, scope=scope
    )
    if export == "csv":
        name = f"report-{report}-{period.start}-{period.end}"
        return table_csv_response([c.key for c in built.columns], built.rows, name=name)
    return ReportResponse(
        report=built.name,
        title=built.title,
        period=period_response(period, city),
        granularity=None if report in _BREAKDOWNS else granularity,
        route_id=route_id,
        fleet_id=fleet_id,
        columns=[
            ReportColumnResponse(key=c.key, label=c.label, kind=c.kind) for c in built.columns
        ],
        rows=built.rows,
        totals=built.totals,
        notes=built.notes,
    )
