"""The pure parts of the demo seed (D1) and the GPS simulator (D2)."""

from __future__ import annotations

from datetime import UTC, date, datetime

import pytest
from scripts.seed_demo_data import ROUTES, STOPS, _layout, departures, vehicle_slot
from scripts.simulate_gps import main, path_length_km, point_along

# Madina 5.6687,-0.1664 -> Legon 5.6510,-0.1830 -> Circle 5.5713,-0.2051
PATH = [(5.6687, -0.1664), (5.6510, -0.1830), (5.5713, -0.2051)]


class TestTimetable:
    def test_every_half_hour_from_half_five_to_nine(self) -> None:
        day = departures(date(2026, 10, 2))

        assert day[0] == datetime(2026, 10, 2, 5, 30, tzinfo=UTC)
        assert day[-1] == datetime(2026, 10, 2, 21, 0, tzinfo=UTC)
        assert len(day) == 32

    def test_a_routes_two_vehicles_alternate(self) -> None:
        day = departures(date(2026, 10, 2))

        assert [vehicle_slot(d) for d in day[:4]] == [0, 1, 0, 1]

    def test_routes_only_use_known_stops(self) -> None:
        known = {code for code, *_ in STOPS}
        assert all(set(route.stops) <= known for route in ROUTES)
        assert len({route.name for route in ROUTES}) == len(ROUTES)

    @pytest.mark.parametrize("seats", [15, 20, 30])
    def test_seat_layouts_fit_the_vehicle(self, seats: int) -> None:
        layout = _layout(seats)

        assert len(layout.seats) == seats
        assert len({s.seat_number for s in layout.seats}) == seats
        assert all(s.row_number <= layout.rows for s in layout.seats)
        assert all(s.column_number <= layout.columns for s in layout.seats)


class TestSimulatorPath:
    def test_starts_and_ends_on_the_stops(self) -> None:
        start, _ = point_along(PATH, 0)
        end, _ = point_along(PATH, path_length_km(PATH) + 5)

        assert start == pytest.approx(PATH[0])
        assert end == pytest.approx(PATH[-1])

    def test_heads_south_west_towards_circle(self) -> None:
        _, heading = point_along(PATH, 1.0)

        assert 180 < heading < 270

    def test_halfway_along_the_first_leg(self) -> None:
        first_leg = path_length_km(PATH[:2])

        (latitude, longitude), _ = point_along(PATH, first_leg / 2)

        assert latitude == pytest.approx((PATH[0][0] + PATH[1][0]) / 2, abs=1e-6)
        assert longitude == pytest.approx((PATH[0][1] + PATH[1][1]) / 2, abs=1e-6)

    @pytest.mark.parametrize("args", [["--interval", "1"], ["--speed", "60", "--speedup", "3"]])
    def test_refuses_settings_the_backend_would_reject(self, args: list[str]) -> None:
        with pytest.raises(SystemExit):
            main(args)
