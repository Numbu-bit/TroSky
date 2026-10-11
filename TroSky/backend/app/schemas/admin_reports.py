"""Responses for ``/admin/reports/{report}``: a table to render or export."""

from __future__ import annotations

import uuid
from typing import Any

from pydantic import Field

from app.repositories.admin_reports_repository import Granularity
from app.schemas.analytics import PeriodResponse
from app.schemas.common import ApiModel
from app.services.admin_reports_service import ColumnKind, ReportName


class ReportColumnResponse(ApiModel):
    key: str
    label: str
    kind: ColumnKind = Field(
        ..., description="period, hour, text, count, money (GHS, 2 places) or ratio (0-1)."
    )


class ReportResponse(ApiModel):
    report: ReportName
    title: str
    period: PeriodResponse
    granularity: Granularity | None = Field(
        ..., description="Null for the breakdowns (peak hours, route popularity)."
    )
    route_id: uuid.UUID | None
    fleet_id: uuid.UUID | None
    columns: list[ReportColumnResponse] = Field(..., description="In display order.")
    rows: list[dict[str, Any]] = Field(
        ..., description="One per column key. Null: the figure does not apply to the filters."
    )
    totals: dict[str, Any] = Field(..., description="Over every row; ratios recomputed.")
    notes: list[str]
