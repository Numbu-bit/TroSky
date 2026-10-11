"""Shared behaviour for admin list endpoints: sorting and CSV export.

``?sort=field`` sorts ascending, ``?sort=-field`` descending, among the
fields each endpoint allows. ``?format=csv`` returns every row matching the
filters (up to ``CSV_EXPORT_MAX_ROWS``) as a spreadsheet-ready file instead
of one JSON page; nested fields become dotted columns (``driver.name``).
"""

from __future__ import annotations

import csv
import io
import json
from collections.abc import Collection, Mapping, Sequence
from datetime import UTC, datetime
from typing import Any, Literal

from fastapi import Query, Response
from pydantic import BaseModel

from app.api.common_dependencies import PaginationParams
from app.core.exceptions import ValidationAppError

ExportFormat = Literal["json", "csv"]
CSV_EXPORT_MAX_ROWS = 10_000

FormatQuery = Query(
    default="json",
    alias="format",
    description="csv: every matching row (up to 10,000) as a CSV file, ignoring limit/offset.",
)
CSV_RESPONSE: dict[int | str, dict[str, Any]] = {
    200: {"content": {"text/csv": {}}, "description": "JSON page, or CSV with format=csv."}
}


def export_window(pagination: PaginationParams, export: ExportFormat) -> tuple[int, int]:
    """``(limit, offset)``: the page asked for, or every row (up to the cap)
    for a CSV export."""
    if export == "csv":
        return CSV_EXPORT_MAX_ROWS, 0
    return pagination.limit, pagination.offset


def parse_sort(raw: str | None, allowed: Collection[str], *, default: str) -> tuple[str, bool]:
    """``(field, descending)`` from ``?sort=``; 422 for a field not allowed."""
    value = (raw or default).strip()
    descending = value.startswith("-")
    field = value.lstrip("-+")
    if field not in allowed:
        raise ValidationAppError(
            f"Cannot sort by '{field}'.",
            details={"param": "sort", "allowed": sorted(allowed)},
        )
    return field, descending


def _flatten(value: Any, prefix: str, out: dict[str, Any]) -> None:
    if isinstance(value, dict):
        for key, inner in value.items():
            _flatten(inner, f"{prefix}.{key}" if prefix else key, out)
    elif isinstance(value, list):
        scalars = all(not isinstance(item, dict | list) for item in value)
        out[prefix] = "; ".join(str(item) for item in value) if scalars else json.dumps(value)
    else:
        out[prefix] = value


def csv_response(rows: Sequence[BaseModel], *, name: str) -> Response:
    """Rows as a downloadable CSV, columns in the schema's field order."""
    flat: list[dict[str, Any]] = []
    for row in rows:
        record: dict[str, Any] = {}
        _flatten(row.model_dump(mode="json"), "", record)
        flat.append(record)
    columns: list[str] = []
    for record in flat:
        columns.extend(key for key in record if key not in columns)
    # A nested object that is empty in some rows (a vehicle with no driver)
    # shows up as a bare column next to its dotted ones; keep the dotted ones.
    columns = [c for c in columns if not any(o.startswith(f"{c}.") for o in columns)]
    buffer = io.StringIO()
    writer = csv.DictWriter(buffer, fieldnames=columns, extrasaction="ignore")
    writer.writeheader()
    writer.writerows(flat)
    return _attachment(buffer.getvalue(), name)


def table_csv_response(
    columns: Sequence[str], rows: Sequence[Mapping[str, Any]], *, name: str
) -> Response:
    """A table as a downloadable CSV, its columns in the order given; an
    absent value is an empty cell."""
    buffer = io.StringIO()
    writer = csv.writer(buffer)
    writer.writerow(columns)
    for row in rows:
        writer.writerow(["" if row.get(column) is None else row[column] for column in columns])
    return _attachment(buffer.getvalue(), name)


def _attachment(content: str, name: str) -> Response:
    stamp = datetime.now(UTC).strftime("%Y%m%d-%H%M")
    return Response(
        content=content,
        media_type="text/csv; charset=utf-8",
        headers={"Content-Disposition": f'attachment; filename="{name}-{stamp}.csv"'},
    )
