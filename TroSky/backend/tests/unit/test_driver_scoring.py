"""Driver performance scoring and the search heat-map grid."""

from __future__ import annotations

import uuid
from decimal import Decimal

import pytest

from app.repositories.admin_performance_repository import DriverCounts
from app.services.admin_analytics_service import score_driver
from app.services.trip_search_service import _grid_cell


def _counts(**values: int) -> DriverCounts:
    return DriverCounts(uuid.uuid4(), **values)


class TestScore:
    def test_a_driver_with_nothing_finished_has_no_score(self) -> None:
        upcoming_only = score_driver(_counts(trips_assigned=6))

        assert upcoming_only.score is None
        assert upcoming_only.cancellation_rate is None
        assert upcoming_only.at_risk is False

    def test_a_perfect_record(self) -> None:
        perfect = score_driver(
            _counts(
                trips_assigned=10,
                trips_completed=10,
                on_time=10,
                ratings=10,
                rating_total=50,
                tickets_issued=20,
                tickets_scanned=20,
            )
        )

        assert perfect.score == Decimal("100.0")
        assert perfect.breakdown["rating"] == Decimal("100.0")

    def test_missing_parts_are_left_out_not_counted_as_zero(self) -> None:
        # No ratings and no tickets yet: scored on the other three parts only.
        unrated = score_driver(_counts(trips_assigned=4, trips_completed=4, on_time=2))

        assert unrated.breakdown["rating"] is None
        assert unrated.breakdown["qr_scanning"] is None
        # (.25 x 0.5 on time + .15 reliability + .15 complaints) / .55
        assert unrated.score == Decimal("77.3")

    def test_weights(self) -> None:
        one_star = score_driver(_counts(trips_completed=1, on_time=1, ratings=1, rating_total=1))

        # (.35 x 0 rating + .25 + .15 + .15) / .90 -- no tickets, so no QR part
        assert one_star.score == Decimal("61.1")


class TestAtRisk:
    @pytest.mark.parametrize(
        ("values", "reason"),
        [
            ({"ratings": 5, "rating_total": 15, "trips_completed": 5, "on_time": 5}, "low_rating"),
            ({"trips_completed": 5, "on_time": 3}, "late_starts"),
            ({"trips_completed": 4, "on_time": 4, "trips_cancelled": 1}, "cancellations"),
            ({"trips_completed": 5, "on_time": 5, "complaints": 1}, "complaints"),
            (
                {"trips_completed": 5, "on_time": 5, "tickets_issued": 10, "tickets_scanned": 7},
                "qr_not_scanned",
            ),
        ],
    )
    def test_each_rule(self, values: dict[str, int], reason: str) -> None:
        assert score_driver(_counts(**values)).at_risk_reasons == [reason]

    def test_too_little_data_flags_nothing(self) -> None:
        # One bad trip is not a pattern.
        shaky = score_driver(
            _counts(
                trips_completed=1,
                on_time=0,
                trips_cancelled=1,
                ratings=1,
                rating_total=1,
                complaints=1,
                tickets_issued=2,
                tickets_scanned=0,
            )
        )

        assert shaky.at_risk_reasons == []
        assert shaky.score is not None


class TestSearchGrid:
    @pytest.mark.parametrize(
        ("coordinate", "cell"),
        [
            (5.6037, Decimal("5.605")),
            (5.6024, Decimal("5.600")),
            (-0.1870, Decimal("-0.185")),
            (-0.1874, Decimal("-0.185")),
            (None, None),
        ],
    )
    def test_rounds_to_the_nearest_550m_cell(self, coordinate, cell) -> None:
        assert _grid_cell(coordinate) == cell
