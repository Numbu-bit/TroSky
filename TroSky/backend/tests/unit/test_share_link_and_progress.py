"""Share-link tokens (G24) and where a vehicle is along its route (G21)."""

from __future__ import annotations

import uuid
from datetime import UTC, datetime, timedelta
from decimal import Decimal

import pytest

from app.utilities.geo import progress_along_route_km, travel_minutes
from app.utilities.share_link import decode_share_token, encode_share_token

SECRET = "s" * 40


class TestShareToken:
    def test_round_trip(self) -> None:
        booking_id = uuid.uuid4()
        expires_at = datetime(2026, 10, 2, 18, 30, tzinfo=UTC)

        token = encode_share_token(booking_id, expires_at, SECRET)

        assert decode_share_token(token, SECRET) == (booking_id, expires_at)
        assert len(token) <= 60  # fits in a text message with room to spare

    def test_a_changed_character_is_rejected(self) -> None:
        token = encode_share_token(uuid.uuid4(), datetime.now(UTC), SECRET)
        tampered = token[:10] + ("A" if token[10] != "A" else "B") + token[11:]

        assert decode_share_token(tampered, SECRET) is None

    def test_a_token_from_another_secret_is_rejected(self) -> None:
        token = encode_share_token(uuid.uuid4(), datetime.now(UTC), "t" * 40)

        assert decode_share_token(token, SECRET) is None

    @pytest.mark.parametrize("junk", ["", "abc", "!!!!", "a" * 54, "a" * 200])
    def test_junk_is_rejected_without_raising(self, junk: str) -> None:
        assert decode_share_token(junk, SECRET) is None

    def test_a_later_expiry_cannot_be_forged(self) -> None:
        booking_id = uuid.uuid4()
        token = encode_share_token(booking_id, datetime.now(UTC), SECRET)
        longer = encode_share_token(booking_id, datetime.now(UTC) + timedelta(days=30), "x" * 40)

        # Same booking, new expiry, but not signed with our secret.
        assert decode_share_token(token[:32] + longer[32:], SECRET) is None


# Madina 0 km, Legon 10 km, Circle 20 km, due north of each other.
ROUTE = [(5.6, -1.0, 0.0), (5.7, -1.0, 10.0), (5.8, -1.0, 20.0)]


class TestProgressAlongRoute:
    @pytest.mark.parametrize(
        ("latitude", "expected_km"),
        [(5.6, 0.0), (5.65, 5.0), (5.7, 10.0), (5.75, 15.0), (5.8, 20.0)],
    )
    def test_on_the_route(self, latitude: float, expected_km: float) -> None:
        progress = progress_along_route_km(ROUTE, latitude, -1.0)

        assert progress == pytest.approx(expected_km, abs=0.01)

    def test_a_little_off_the_road_still_places_it(self) -> None:
        # ~550 m east of the line, level with the middle of the first leg.
        assert progress_along_route_km(ROUTE, 5.65, -0.995) == pytest.approx(5.0, abs=0.01)

    def test_before_the_start_and_beyond_the_end_are_clamped(self) -> None:
        assert progress_along_route_km(ROUTE, 5.5, -1.0) == pytest.approx(0.0)
        assert progress_along_route_km(ROUTE, 5.9, -1.0) == pytest.approx(20.0)

    def test_a_route_needs_two_points(self) -> None:
        assert progress_along_route_km(ROUTE[:1], 5.6, -1.0) is None


class TestTravelMinutes:
    def test_uses_the_vehicles_own_speed_when_moving(self) -> None:
        assert travel_minutes(5.0, Decimal("30"), fallback_kmh=Decimal("25")) == 10

    def test_falls_back_when_crawling_or_unknown(self) -> None:
        assert travel_minutes(5.0, Decimal("2"), fallback_kmh=Decimal("25")) == 12
        assert travel_minutes(5.0, None, fallback_kmh=Decimal("25")) == 12

    def test_rounds_up_and_never_goes_negative(self) -> None:
        assert travel_minutes(0.01, Decimal("30"), fallback_kmh=Decimal("25")) == 1
        assert travel_minutes(-3.0, Decimal("30"), fallback_kmh=Decimal("25")) == 0
