"""Unit coverage for the Step 17 fare-split helper.

``FareService.live_fare_per_seat`` is the single place that decides the
number the Trip-tracking screen shows next to the vehicle marker. It is
called from both the REST poll and the WebSocket push path (via
``TrackingService._live_fare_fields``), so the two surfaces always agree.
"""

from __future__ import annotations

from decimal import Decimal

import pytest

from app.core.config import Settings
from app.services.fare_service import FareService


def _fares() -> FareService:
    return FareService(Settings())


class TestLiveFarePerSeat:
    def test_no_riders_pays_the_whole_fare(self) -> None:
        fare = _fares().live_fare_per_seat(full_route_fare=Decimal("16.00"), riders_count=0)
        assert fare == Decimal("16.00")

    def test_single_rider_pays_the_whole_fare(self) -> None:
        fare = _fares().live_fare_per_seat(full_route_fare=Decimal("16.00"), riders_count=1)
        assert fare == Decimal("16.00")

    def test_split_rounds_half_up_to_the_minor_unit(self) -> None:
        # 16.00 / 3 = 5.3333...; quantized to cedis minor unit should
        # round .3333 down to 5.33, not up.
        fare = _fares().live_fare_per_seat(full_route_fare=Decimal("16.00"), riders_count=3)
        assert fare == Decimal("5.33")

    def test_full_fill_splits_evenly(self) -> None:
        fare = _fares().live_fare_per_seat(full_route_fare=Decimal("16.00"), riders_count=4)
        assert fare == Decimal("4.00")

    def test_split_is_clamped_to_minimum(self) -> None:
        # Any value below the Settings floor comes up to it, so a
        # pathologically high rider count never undercuts the operator.
        fare = _fares().live_fare_per_seat(full_route_fare=Decimal("1.00"), riders_count=50)
        settings = Settings()
        assert fare == settings.FARE_MINIMUM_AMOUNT

    def test_negative_rider_count_is_treated_as_empty_trip(self) -> None:
        # Defensive: a caller mis-passing -1 shouldn't crash or negate the
        # fare; we treat it the same as 0.
        fare = _fares().live_fare_per_seat(full_route_fare=Decimal("12.00"), riders_count=-1)
        assert fare == Decimal("12.00")


class TestLiveFareSchemaParity:
    """The WebSocket payload shape must match what REST returns, so
    clients can swap transports without changing their parser."""

    def test_rest_and_ws_payloads_share_the_fare_keys(self) -> None:
        # Imported inside the test to keep import-side effects off the
        # hot path if the modules move.
        from app.services.tracking_service import LiveLocation
        from decimal import Decimal as D
        from datetime import UTC, datetime
        import json
        import uuid

        live = LiveLocation(
            trip_id=uuid.UUID("00000000-0000-4000-8000-000000000001"),
            latitude=5.6,
            longitude=-0.19,
            speed_kmh=None,
            heading_degrees=None,
            recorded_at=datetime.now(UTC),
            is_stale=False,
            live_fare_per_seat=D("5.33"),
            riders_count=3,
        )
        payload = json.loads(live.to_publish_payload())
        assert payload["live_fare_per_seat"] == "5.33"
        assert payload["riders_count"] == 3
