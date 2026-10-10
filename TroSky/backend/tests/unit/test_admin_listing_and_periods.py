"""Admin list helpers (sorting, CSV) and analytics periods."""

from __future__ import annotations

import csv
import io
from datetime import UTC, date, datetime, timedelta
from decimal import Decimal

import pytest

from app.api.common_dependencies import PaginationParams
from app.api.v1.listing import CSV_EXPORT_MAX_ROWS, csv_response, export_window, parse_sort
from app.core.exceptions import ValidationAppError
from app.schemas.common import ApiModel
from app.services.admin_analytics_service import Figure, Period, figure_from


class TestSort:
    def test_ascending_descending_and_default(self) -> None:
        allowed = ("name", "created_at")

        assert parse_sort(None, allowed, default="name") == ("name", False)
        assert parse_sort("-created_at", allowed, default="name") == ("created_at", True)
        assert parse_sort("created_at", allowed, default="name") == ("created_at", False)

    def test_unknown_field_lists_the_allowed_ones(self) -> None:
        with pytest.raises(ValidationAppError) as rejected:
            parse_sort("price", ("name",), default="name")

        assert rejected.value.details["allowed"] == ["name"]


class _Inner(ApiModel):
    id: int
    name: str | None


class _Row(ApiModel):
    plate: str
    driver: _Inner | None
    tags: list[str]


class TestCsv:
    def test_nested_fields_become_dotted_columns(self) -> None:
        response = csv_response(
            [
                _Row(plate="GD-11-26", driver=_Inner(id=1, name="Kofi"), tags=["a", "b"]),
                _Row(plate="GD-12-26", driver=None, tags=[]),
            ],
            name="vehicles",
        )

        rows = list(csv.DictReader(io.StringIO(response.body.decode())))
        assert response.media_type.startswith("text/csv")
        assert 'filename="vehicles-' in response.headers["content-disposition"]
        assert rows[0] == {
            "plate": "GD-11-26",
            "driver.id": "1",
            "driver.name": "Kofi",
            "tags": "a; b",
        }
        assert rows[1]["driver.id"] == ""  # no driver: the column stays, empty

    def test_export_ignores_paging(self) -> None:
        page = PaginationParams(limit=20, offset=40)

        assert export_window(page, "json") == (20, 40)
        assert export_window(page, "csv") == (CSV_EXPORT_MAX_ROWS, 0)


class TestPeriod:
    def test_defaults_to_the_last_30_days(self) -> None:
        period = Period.resolve(None, None)

        assert period.end == datetime.now(UTC).date()
        assert period.days == 30

    def test_the_previous_period_is_as_long_and_just_before(self) -> None:
        period = Period.resolve(date(2026, 10, 1), date(2026, 10, 7))

        assert (period.previous.start, period.previous.end) == (
            date(2026, 9, 24),
            date(2026, 9, 30),
        )
        assert period.until - period.since == timedelta(days=7)

    @pytest.mark.parametrize(
        ("start", "end"),
        [(date(2026, 10, 5), date(2026, 10, 1)), (date(2025, 1, 1), date(2026, 10, 1))],
    )
    def test_backwards_or_too_long_is_rejected(self, start: date, end: date) -> None:
        with pytest.raises(ValidationAppError):
            Period.resolve(start, end)

    def test_figures_split_into_this_and_the_previous_period(self) -> None:
        period = Period.resolve(date(2026, 10, 2), date(2026, 10, 3))
        daily = {
            date(2026, 9, 30): Decimal("4"),  # previous period
            date(2026, 10, 1): Decimal("1"),  # previous period
            date(2026, 10, 3): Decimal("6"),
            date(2026, 10, 9): Decimal("100"),  # outside both
        }

        figure = figure_from(daily, period)

        assert (figure.value, figure.previous) == (Decimal("6"), Decimal("5"))
        assert figure.series == [
            (date(2026, 10, 2), Decimal("0")),
            (date(2026, 10, 3), Decimal("6")),
        ]
        assert figure.change_percent == Decimal("20.0")
        assert Figure(Decimal("3"), Decimal("0"), []).change_percent is None
