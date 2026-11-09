"""Online mode: distance zones, re-optimising, and reserved seats."""

import unittest
from datetime import UTC, datetime, timedelta

from seat_allocation import Booking, load_config, minibus_variant, single_file
from seat_allocation.model import UNSEATED, Problem
from seat_allocation.online import build_zone_plan, choose_seat
from seat_allocation.route import Route, Stop
from seat_allocation.service import SeatStatus, Trip, TripSeatService

CONFIG = load_config()
ONLINE = CONFIG.replace("assignment", mode="online")
NO_REOPT = ONLINE.replace("online", reoptimise_on_booking=False)
DEPARTURE = datetime(2026, 11, 9, 7, 30, tzinfo=UTC)
ROUTE = Route(
    stops=[
        Stop("s0", "Madina", 0, 0.0),
        Stop("s1", "Legon", 1, 4.0),
        Stop("s2", "37", 2, 8.0),
        Stop("s3", "Circle", 3, 12.0),
    ],
    name="Madina to Circle",
)


def service(config=ONLINE, layout=None, now=None, history=()):
    clock = lambda: now or DEPARTURE - timedelta(hours=1)  # noqa: E731
    trip = Trip("t1", "v1", DEPARTURE, route=ROUTE)
    return TripSeatService(
        trip, layout or minibus_variant(15), config, clock=clock, demand_history=history
    )


class TestZonePlan(unittest.TestCase):
    def test_equal_lengths_of_road_without_history(self):
        plan = build_zone_plan(minibus_variant(15), CONFIG, route_km=12.0)
        self.assertEqual(plan.boundaries, (4.0, 8.0))
        self.assertEqual(plan.zone_of_position(1.0), 0)
        self.assertEqual(plan.zone_of_position(6.0), 1)
        self.assertEqual(plan.zone_of_position(11.0), 2)

    def test_equal_shares_of_past_passengers_with_history(self):
        history = [1.0] * 6 + [2.0] * 6 + [12.0] * 6
        plan = build_zone_plan(single_file(9), CONFIG, route_km=12.0, history=history)
        self.assertEqual(plan.boundaries, (2.0, 12.0))
        self.assertEqual(plan.zone_of_position(1.0), 0)
        self.assertEqual(plan.zone_of_position(12.0), 1)

    def test_rear_seats_are_kept_for_far_destinations(self):
        plan = build_zone_plan(single_file(9), CONFIG, route_km=12.0)
        self.assertEqual(plan.zone_of_seat["1"], 0)
        self.assertEqual(plan.zone_of_seat["9"], 2)

    def test_seats_held_back_are_left_out_of_the_bands(self):
        plan = build_zone_plan(minibus_variant(15), CONFIG, route_km=12.0, exclude=("F1", "F2"))
        self.assertNotIn("F1", plan.zone_of_seat)


class TestChoosingASeat(unittest.TestCase):
    def test_lowest_added_blocking_comes_first(self):
        layout = single_file(5)
        problem = Problem(
            layout, [Booking("a", 6, booked_at=0), Booking("b", 12, booked_at=1)], CONFIG
        )
        assign = [problem.seat_index["3"], UNSEATED]
        seat = choose_seat(problem, 1, assign, None)
        # Seats 1 and 2 would put the far passenger in front of a; 4 and 5 add nothing.
        self.assertIn(problem.seats[seat].id, ("4", "5"))

    def test_zones_keep_a_near_passenger_out_of_the_back(self):
        layout = single_file(9)
        plan = build_zone_plan(layout, CONFIG, route_km=12.0)
        problem = Problem(layout, [Booking("near", 1)], CONFIG)
        without = choose_seat(problem, 0, [UNSEATED], None)
        with_zones = choose_seat(problem, 0, [UNSEATED], plan)
        self.assertEqual(problem.seats[without].id, "9")
        self.assertEqual(problem.seats[with_zones].id, "1")

    def test_the_order_of_arrival_stops_mattering_with_zones(self):
        """Near first then far, or far first then near: no blocking either way."""
        layout = single_file(9)
        plan = build_zone_plan(layout, CONFIG, route_km=12.0)
        for order in ((1, 12, 6), (12, 1, 6), (6, 1, 12)):
            bookings = [Booking(f"p{i}", km, booked_at=i) for i, km in enumerate(order)]
            problem = Problem(layout, bookings, CONFIG)
            assign = [UNSEATED] * 3
            for p in range(3):
                assign[p] = choose_seat(problem, p, assign, plan)
            self.assertEqual(problem.blocking_pairs(assign), [], order)


class TestOnlineService(unittest.TestCase):
    def test_a_booking_returns_a_provisional_seat(self):
        result = service().create_booking("a", destination_stop="s2")
        self.assertTrue(result.provisional)
        self.assertTrue(result.seat)
        self.assertTrue(result.message.startswith(f"Seat {result.seat}:"))

    def test_seats_stay_put_when_nothing_needs_to_move(self):
        s = service()
        moved = [
            s.create_booking(f"p{i}", destination_stop=stop).moved
            for i, stop in enumerate(("s1", "s3", "s2"))
        ]
        self.assertEqual(moved, [(), (), ()])

    def test_re_optimising_clears_blocking_that_insertion_could_not_avoid(self):
        s = service(config=ONLINE, layout=single_file(3))
        for name, km in (
            ("a", 2.0),
            ("b", 4.0),
            ("c", 3.0),
        ):
            s.create_booking(name, alight=km)
        self.assertEqual(s.current_blocking()[0], 0)

    def test_without_re_optimising_nobody_moves_and_blocking_can_remain(self):
        s = service(config=NO_REOPT, layout=single_file(2))
        s.create_booking("a", alight=10.0)
        result = s.create_booking("b", alight=11.0)
        # With two seats, a took the rear zone, so b must sit in front of a or behind.
        self.assertEqual(result.moved, ())

    def test_priority_seats_are_held_for_later_bookings(self):
        s = service()
        for i in range(6):
            result = s.create_booking(f"p{i}", destination_stop="s1")
            self.assertNotIn(result.seat, ("F1", "F2"))
        result = s.create_booking("old", destination_stop="s3", category="elderly")
        self.assertIn(result.seat, ("F1", "F2"))

    def test_held_seats_are_released_when_the_rest_are_full(self):
        s = service()
        for i in range(15):
            s.create_booking(f"p{i}", destination_stop="s2")
        seats = set(s.seats.values())
        self.assertEqual(len(seats), 15)
        self.assertTrue({"F1", "F2"} <= seats)

    def test_history_shapes_the_zones(self):
        s = service(history=(4.0,) * 10 + (8.0,) * 10 + (12.0,) * 10)
        self.assertEqual(s.create_booking("a", destination_stop="s1").moved, ())

    def test_late_bookings_only_take_a_free_seat(self):
        s = service()
        for i, stop in enumerate(("s1", "s2", "s3")):
            s.create_booking(f"p{i}", destination_stop=stop)
        before = dict(s.seats)
        s.lock()
        result = s.create_booking("late", destination_stop="s1")
        self.assertEqual(result.moved, ())
        self.assertFalse(result.provisional)
        self.assertEqual({k: s.seats[k] for k in before}, before)
        self.assertEqual(s.status["late"], SeatStatus.LOCKED)


if __name__ == "__main__":
    unittest.main()
