"""A short ride chooses from the front seats, a long ride from the back."""

from __future__ import annotations

import uuid
from decimal import Decimal
from types import SimpleNamespace
from typing import Any

import pytest

from app.models.vehicles import SeatZone
from app.repositories.route_geometry import RouteGeometry, RoutePoint
from app.services.seat_zones import (
    passenger_zone,
    ride_share,
    seat_zones,
    seats_outside_zone,
    selectable_seats,
)


def _seats(rows: int, per_row: int = 2) -> list[Any]:
    """Seats front to back, as a vehicle's layout lists them."""
    return [
        SimpleNamespace(id=uuid.uuid4(), row_number=row, is_active=True)
        for row in range(1, rows + 1)
        for _ in range(per_row)
    ]


def _route(offsets: list[str | None]) -> RouteGeometry:
    stops = [uuid.uuid4() for _ in offsets]
    return RouteGeometry(
        route_id=uuid.uuid4(),
        route_name="Madina to Circle",
        origin_stop_id=stops[0],
        destination_stop_id=stops[-1],
        route_km=None,
        duration_minutes=None,
        points=tuple(
            RoutePoint(
                stop_id=stop,
                name=f"Stop {index}",
                offset_km=Decimal(offset) if offset is not None else None,
                offset_minutes=None,
                latitude=None,
                longitude=None,
            )
            for index, (stop, offset) in enumerate(zip(stops, offsets, strict=True))
        ),
        fare_distances={},
    )


class TestSeatZones:
    def test_the_front_half_of_the_rows_is_the_front(self) -> None:
        seats = _seats(rows=4)
        zones = seat_zones(seats)
        assert [zones[s.id] for s in seats if s.row_number <= 2] == [SeatZone.FRONT] * 4
        assert [zones[s.id] for s in seats if s.row_number > 2] == [SeatZone.BACK] * 4

    def test_a_middle_row_counts_as_front(self) -> None:
        seats = _seats(rows=5, per_row=1)
        zones = seat_zones(seats)
        assert [zones[s.id] for s in seats] == [
            SeatZone.FRONT,
            SeatZone.FRONT,
            SeatZone.FRONT,
            SeatZone.BACK,
            SeatZone.BACK,
        ]

    def test_a_single_row_is_all_front(self) -> None:
        seats = _seats(rows=1, per_row=4)
        assert set(seat_zones(seats).values()) == {SeatZone.FRONT}


class TestRideShare:
    def test_it_goes_by_distance_when_the_stops_are_measured(self) -> None:
        route = _route(["0", "2", "20"])
        stops = [point.stop_id for point in route.points]
        assert ride_share(route, stops[0], stops[1]) == pytest.approx(0.1)
        assert ride_share(route, stops[1], stops[2]) == pytest.approx(0.9)

    def test_it_counts_stops_when_any_stop_is_not_measured(self) -> None:
        route = _route(["0", None, "20"])
        stops = [point.stop_id for point in route.points]
        assert ride_share(route, stops[0], stops[1]) == pytest.approx(0.5)

    def test_it_counts_stops_when_the_route_has_no_length(self) -> None:
        route = _route(["0", "0", "0"])
        stops = [point.stop_id for point in route.points]
        assert ride_share(route, stops[0], stops[2]) == pytest.approx(1.0)


class TestPassengerZone:
    def test_a_short_ride_is_the_front_and_a_long_one_the_back(self) -> None:
        route = _route(["0", "5", "15", "20"])
        stops = [point.stop_id for point in route.points]
        assert passenger_zone(route, stops[0], stops[1], near_share=0.5) == SeatZone.FRONT
        assert passenger_zone(route, stops[0], stops[2], near_share=0.5) == SeatZone.BACK

    def test_it_goes_by_the_ride_not_by_where_on_the_route_it_ends(self) -> None:
        """Boarding late and getting off at the last stop is still a short ride."""
        route = _route(["0", "15", "20"])
        stops = [point.stop_id for point in route.points]
        assert passenger_zone(route, stops[1], stops[2], near_share=0.5) == SeatZone.FRONT

    def test_exactly_the_share_counts_as_far(self) -> None:
        route = _route(["0", "10", "20"])
        stops = [point.stop_id for point in route.points]
        assert passenger_zone(route, stops[0], stops[1], near_share=0.5) == SeatZone.BACK

    def test_a_stop_left_out_means_that_end_of_the_route(self) -> None:
        route = _route(["0", "2", "20"])
        stops = [point.stop_id for point in route.points]
        assert passenger_zone(route, None, None, near_share=0.5) == SeatZone.BACK
        assert passenger_zone(route, None, stops[1], near_share=0.5) == SeatZone.FRONT
        assert passenger_zone(route, stops[1], None, near_share=0.5) == SeatZone.BACK

    def test_the_share_can_be_changed(self) -> None:
        route = _route(["0", "6", "20"])
        stops = [point.stop_id for point in route.points]
        assert passenger_zone(route, stops[0], stops[1], near_share=0.25) == SeatZone.BACK
        assert passenger_zone(route, stops[0], stops[1], near_share=0.5) == SeatZone.FRONT


class TestSelectableSeats:
    def test_only_the_free_seats_of_the_zone_are_offered(self) -> None:
        seats = _seats(rows=2, per_row=2)
        front, back = seats[:2], seats[2:]
        offered = selectable_seats(seats, taken={front[0].id}, zone=SeatZone.FRONT)
        assert offered == {front[1].id}
        assert offered.isdisjoint(s.id for s in back)

    def test_every_free_seat_is_offered_once_the_zone_is_full(self) -> None:
        seats = _seats(rows=2, per_row=2)
        front, back = seats[:2], seats[2:]
        offered = selectable_seats(seats, taken={s.id for s in front}, zone=SeatZone.FRONT)
        assert offered == {s.id for s in back}

    def test_every_free_seat_is_offered_without_a_ride_to_go_by(self) -> None:
        seats = _seats(rows=2, per_row=2)
        assert selectable_seats(seats, taken={seats[0].id}, zone=None) == {s.id for s in seats[1:]}

    def test_a_seat_out_of_use_is_never_offered(self) -> None:
        seats = _seats(rows=2, per_row=1)
        seats[0].is_active = False
        assert selectable_seats(seats, taken=set(), zone=None) == {seats[1].id}
        assert selectable_seats(seats, taken=set(), zone=SeatZone.BACK) == {seats[1].id}

    def test_nothing_is_offered_on_a_full_vehicle(self) -> None:
        seats = _seats(rows=2, per_row=1)
        assert selectable_seats(seats, taken={s.id for s in seats}, zone=SeatZone.FRONT) == set()


class TestSeatsOutsideZone:
    def test_a_seat_in_the_zone_is_fine(self) -> None:
        seats = _seats(rows=2, per_row=2)
        assert not seats_outside_zone([seats[0].id], seats=seats, taken=set(), zone=SeatZone.FRONT)

    def test_a_seat_outside_it_is_refused_while_the_zone_has_room(self) -> None:
        seats = _seats(rows=2, per_row=2)
        assert seats_outside_zone([seats[3].id], seats=seats, taken=set(), zone=SeatZone.FRONT) == [
            seats[3].id
        ]

    def test_a_seat_outside_it_is_allowed_once_the_zone_is_full(self) -> None:
        seats = _seats(rows=2, per_row=2)
        taken = {seats[0].id, seats[1].id}
        assert not seats_outside_zone([seats[3].id], seats=seats, taken=taken, zone=SeatZone.FRONT)

    def test_a_group_filling_its_zone_may_spill_over(self) -> None:
        seats = _seats(rows=2, per_row=2)
        group = [seats[0].id, seats[1].id, seats[2].id]
        assert not seats_outside_zone(group, seats=seats, taken=set(), zone=SeatZone.FRONT)

    def test_a_group_may_not_spill_over_while_its_zone_has_room(self) -> None:
        seats = _seats(rows=2, per_row=2)
        group = [seats[0].id, seats[2].id]
        assert seats_outside_zone(group, seats=seats, taken=set(), zone=SeatZone.FRONT) == [
            seats[2].id
        ]
