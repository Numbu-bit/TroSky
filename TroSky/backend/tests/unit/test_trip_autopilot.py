"""What a vehicle's positions, and the clock, mean for its trip.

The route runs due north: Madina (5.6, -1.0), Legon (5.7, -1.0) and Circle
(5.8, -1.0), about 11 km apart. A thousandth of a degree is about 111 m.
"""

from __future__ import annotations

import uuid
from dataclasses import replace
from datetime import UTC, datetime, timedelta
from decimal import Decimal

import pytest
from pydantic import ValidationError

from app.core.config import Settings
from app.models.trips import TripStatus
from app.repositories.route_geometry import RouteGeometry, RoutePoint
from app.services.trip_autopilot import (
    Decision,
    Fix,
    Memory,
    Move,
    Rules,
    on_clock,
    on_position,
)

RULES = Rules(
    window=timedelta(minutes=30),
    at_stop_km=0.15,
    left_stop_km=0.3,
    still_km=0.05,
    pause_after=timedelta(minutes=20),
    arrival_after=timedelta(minutes=3),
    silence=timedelta(minutes=10),
)
DEPARTURE = datetime(2026, 10, 8, 7, 0, tzinfo=UTC)
MADINA, LEGON, CIRCLE = (5.6, -1.0), (5.7, -1.0), (5.8, -1.0)
BETWEEN = (5.65, -1.0)  # halfway to Legon, nowhere near a stop


def _route(*stops: tuple[float, float]) -> RouteGeometry:
    ids = [uuid.uuid4() for _ in stops]
    points = tuple(
        RoutePoint(
            stop_id=stop_id,
            name=f"Stop {index}",
            offset_km=Decimal(str(round(index * 11.1, 1))),
            offset_minutes=index * 20,
            latitude=latitude,
            longitude=longitude,
        )
        for index, (stop_id, (latitude, longitude)) in enumerate(zip(ids, stops, strict=True))
    )
    return RouteGeometry(
        route_id=uuid.uuid4(),
        route_name="Madina-Circle",
        origin_stop_id=ids[0],
        destination_stop_id=ids[-1],
        route_km=points[-1].offset_km,
        duration_minutes=40,
        points=points,
        fare_distances={point.stop_id: point.offset_km for point in points},
    )


ROUTE = _route(MADINA, LEGON, CIRCLE)


def _at(minutes: float) -> datetime:
    """Minutes after the departure time (negative: before it)."""
    return DEPARTURE + timedelta(minutes=minutes)


def _drive(
    status: TripStatus,
    *fixes: tuple[tuple[float, float], float],
    memory: Memory | None = None,
    route: RouteGeometry = ROUTE,
    accuracy_m: float | None = None,
) -> Decision:
    """Feed positions ``(point, minutes)`` in order, as a trip in ``status``
    the whole time; the last decision."""
    decision = Decision(None, None, memory or Memory())
    for point, minutes in fixes:
        fix = Fix(point, _at(minutes), accuracy_m / 1000 if accuracy_m else None)
        decision = on_position(status, DEPARTURE, route, decision.memory, fix, RULES)
    return decision


def _north(point: tuple[float, float], metres: float) -> tuple[float, float]:
    return point[0] + metres / 111_320, point[1]


def _east(point: tuple[float, float], metres: float) -> tuple[float, float]:
    return point[0], point[1] + metres / 111_320


class TestBoarding:
    def test_at_the_first_stop_shortly_before_departure(self) -> None:
        decision = _drive(TripStatus.SCHEDULED, (MADINA, -20))
        assert decision.move == Move.BOARD
        assert decision.reason == "Vehicle at the first stop"

    def test_not_while_still_far_off_in_time(self) -> None:
        decision = _drive(TripStatus.SCHEDULED, (MADINA, -45))
        assert decision.move is None
        assert decision.memory.been_at_first_stop  # leaving later still counts

    def test_a_boarding_trip_is_not_boarded_again(self) -> None:
        assert _drive(TripStatus.BOARDING, (MADINA, -10)).move is None


class TestDeparting:
    def test_leaving_the_first_stop_along_the_route_starts_the_trip(self) -> None:
        decision = _drive(TripStatus.BOARDING, (MADINA, -5), (_north(MADINA, 400), -1))
        assert decision.move == Move.START
        assert decision.reason == "Vehicle left the first stop"

    def test_from_scheduled_too(self) -> None:
        decision = _drive(TripStatus.SCHEDULED, (MADINA, -40), (_north(MADINA, 400), 1))
        assert decision.move == Move.START

    def test_pulling_away_less_than_the_leaving_distance_is_not_leaving(self) -> None:
        decision = _drive(TripStatus.BOARDING, (MADINA, -5), (_north(MADINA, 250), -4))
        assert decision.move is None

    def test_going_off_sideways_to_fill_up_is_not_leaving(self) -> None:
        decision = _drive(TripStatus.BOARDING, (MADINA, -5), (_east(MADINA, 500), -4))
        assert decision.move is None

    def test_first_heard_from_at_a_later_stop_after_departure_is_under_way(self) -> None:
        decision = _drive(TripStatus.SCHEDULED, (LEGON, 10))
        assert decision.move == Move.START
        assert decision.reason == "Vehicle on the route past its first stop"

    def test_but_before_departure_it_may_be_on_its_way_to_the_first_stop(self) -> None:
        assert _drive(TripStatus.SCHEDULED, (LEGON, -25)).move is None

    def test_a_route_without_measured_stops_goes_by_distance_alone(self) -> None:
        unmeasured = replace(
            ROUTE,
            points=tuple(
                RoutePoint(p.stop_id, p.name, None, None, p.latitude, p.longitude)
                for p in ROUTE.points
            ),
        )
        decision = _drive(
            TripStatus.BOARDING, (MADINA, -5), (_east(MADINA, 500), -4), route=unmeasured
        )
        assert decision.move == Move.START


class TestPausing:
    def test_standing_still_away_from_any_stop_pauses_the_trip(self) -> None:
        decision = _drive(TripStatus.IN_PROGRESS, (BETWEEN, 10), (BETWEEN, 20), (BETWEEN, 30))
        assert decision.move == Move.PAUSE
        assert decision.reason == "Not moved for 20 minutes"

    def test_not_a_minute_early(self) -> None:
        decision = _drive(TripStatus.IN_PROGRESS, (BETWEEN, 10), (BETWEEN, 29))
        assert decision.move is None

    def test_gps_wobble_is_still_standing(self) -> None:
        decision = _drive(
            TripStatus.IN_PROGRESS,
            (BETWEEN, 10),
            (_north(BETWEEN, 30), 18),
            (_east(BETWEEN, 40), 25),
            (BETWEEN, 31),
        )
        assert decision.move == Move.PAUSE

    def test_creeping_along_is_moving(self) -> None:
        decision = _drive(
            TripStatus.IN_PROGRESS,
            (BETWEEN, 10),
            (_north(BETWEEN, 60), 20),
            (_north(BETWEEN, 120), 31),
        )
        assert decision.move is None

    def test_waiting_at_a_stop_is_part_of_the_trip(self) -> None:
        decision = _drive(TripStatus.IN_PROGRESS, (LEGON, 10), (LEGON, 40))
        assert decision.move is None


class TestResuming:
    def test_moving_again_resumes_a_paused_trip(self) -> None:
        decision = _drive(TripStatus.PAUSED, (BETWEEN, 30), (_north(BETWEEN, 100), 32))
        assert decision.move == Move.RESUME
        assert decision.reason == "Vehicle moving again"

    def test_wobbling_on_the_spot_does_not(self) -> None:
        decision = _drive(TripStatus.PAUSED, (BETWEEN, 30), (_north(BETWEEN, 30), 32))
        assert decision.move is None

    def test_a_vague_position_must_move_further_than_its_error(self) -> None:
        decision = _drive(
            TripStatus.PAUSED, (BETWEEN, 30), (_north(BETWEEN, 100), 32), accuracy_m=200
        )
        assert decision.move is None


class TestArriving:
    def test_some_minutes_at_the_last_stop_completes_the_trip(self) -> None:
        decision = _drive(TripStatus.IN_PROGRESS, (CIRCLE, 40), (CIRCLE, 41), (CIRCLE, 43))
        assert decision.move == Move.COMPLETE
        assert decision.reason == "At the last stop for 3 minutes"

    def test_passing_close_by_is_not_arriving(self) -> None:
        decision = _drive(TripStatus.IN_PROGRESS, (CIRCLE, 40), (_north(CIRCLE, 500), 43))
        assert decision.move is None
        assert decision.memory.at_last_stop_since is None

    def test_a_round_trip_does_not_arrive_where_it_starts(self) -> None:
        loop = _route(MADINA, LEGON, MADINA)
        decision = _drive(TripStatus.IN_PROGRESS, (MADINA, 0), (MADINA, 5), route=loop)
        assert decision.move is None

    def test_but_does_once_it_has_been_round(self) -> None:
        loop = _route(MADINA, LEGON, MADINA)
        decision = _drive(
            TripStatus.IN_PROGRESS, (MADINA, 0), (LEGON, 20), (MADINA, 40), (MADINA, 44), route=loop
        )
        assert decision.move == Move.COMPLETE


class TestTheClock:
    def test_gone_quiet_at_the_last_stop_is_arrived(self) -> None:
        memory = _drive(TripStatus.IN_PROGRESS, (CIRCLE, 40)).memory
        assert on_clock(TripStatus.IN_PROGRESS, ROUTE, memory, _at(49), RULES).move is None
        decision = on_clock(TripStatus.IN_PROGRESS, ROUTE, memory, _at(50), RULES)
        assert decision.move == Move.COMPLETE
        assert decision.reason == "GPS went quiet at the last stop"

    def test_quiet_and_not_moved_on_the_road_is_paused(self) -> None:
        memory = _drive(TripStatus.IN_PROGRESS, (BETWEEN, 10)).memory
        assert on_clock(TripStatus.IN_PROGRESS, ROUTE, memory, _at(29), RULES).move is None
        assert on_clock(TripStatus.IN_PROGRESS, ROUTE, memory, _at(30), RULES).move == Move.PAUSE

    def test_nothing_without_a_position(self) -> None:
        assert on_clock(TripStatus.IN_PROGRESS, ROUTE, Memory(), _at(90), RULES).move is None

    def test_only_trips_on_the_road(self) -> None:
        memory = _drive(TripStatus.PAUSED, (BETWEEN, 10)).memory
        assert on_clock(TripStatus.PAUSED, ROUTE, memory, _at(90), RULES).move is None


class TestMemory:
    def test_a_late_position_changes_nothing(self) -> None:
        memory = _drive(TripStatus.IN_PROGRESS, (BETWEEN, 10)).memory
        decision = _drive(TripStatus.IN_PROGRESS, (CIRCLE, 5), memory=memory)
        assert decision.move is None
        assert decision.memory == memory

    def test_it_survives_being_stored(self) -> None:
        memory = _drive(TripStatus.BOARDING, (MADINA, -5), (CIRCLE, 40)).memory
        assert Memory.loads(memory.dumps()) == memory
        assert Memory.loads(None) == Memory()

    def test_fields_it_does_not_know_are_ignored(self) -> None:
        assert Memory.loads('{"seen_at": null, "from_a_later_version": 1}') == Memory()


def test_rules_come_from_the_settings() -> None:
    settings = _settings(TRIP_AT_STOP_METERS=200, TRIP_AUTO_PAUSE_MINUTES=25)
    rules = Rules.from_settings(settings)
    assert rules.at_stop_km == 0.2
    assert rules.pause_after == timedelta(minutes=25)


@pytest.mark.parametrize("cancel", [10, 15])
def test_trips_are_cancelled_only_after_the_alert(cancel: int) -> None:
    with pytest.raises(ValidationError, match="TRIP_NOT_STARTED_CANCEL_MINUTES"):
        _settings(TRIP_NOT_STARTED_ALERT_MINUTES=15, TRIP_NOT_STARTED_CANCEL_MINUTES=cancel)


def test_or_never() -> None:
    assert _settings(TRIP_NOT_STARTED_CANCEL_MINUTES=0).TRIP_NOT_STARTED_CANCEL_MINUTES == 0


def _settings(**values: object) -> Settings:
    return Settings.model_validate(
        {
            "SECRET_KEY": "x" * 32,
            "JWT_SECRET_KEY": "y" * 32,
            "PAYMENTS_WEBHOOK_SIGNING_SECRET": "z" * 32,
            "TICKET_QR_SIGNING_SECRET": "w" * 32,
            **values,
        }
    )
