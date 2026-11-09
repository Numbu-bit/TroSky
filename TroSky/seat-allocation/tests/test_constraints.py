"""Priority seats, accessibility, groups, children, preferences and luggage."""

import unittest

from seat_allocation import (
    Booking,
    FixedReason,
    FixedSeat,
    allocate,
    evaluate,
    load_config,
    minibus_variant,
    single_file,
)
from seat_allocation.allocator import PROOF_EXACT
from seat_allocation.layout import from_grid, layout_from_dict, two_door_bus

CONFIG = load_config()
BUS = minibus_variant(15)


class TestPriority(unittest.TestCase):
    def test_a_priority_passenger_gets_a_reserved_seat(self):
        allocation = allocate(
            BUS,
            [Booking("old", 5, category="elderly"), *[Booking(f"p{i}", i + 1) for i in range(8)]],
            CONFIG,
        )
        self.assertIn(allocation.seats["old"], ("F1", "F2"))

    def test_a_reserved_cab_seat_forces_no_blocking_even_for_the_farthest_passenger(self):
        """Why the example reserves cab seats: they are in nobody's way but each other's."""
        allocation = allocate(
            BUS,
            [Booking("old", 12, category="elderly"), *[Booking(f"p{i}", i + 1) for i in range(11)]],
            CONFIG,
        )
        self.assertEqual(allocation.blocking_after, 0)

    def test_two_priority_passengers_sit_in_the_order_they_get_off(self):
        allocation = allocate(
            BUS,
            [Booking("near", 2, category="pregnant"), Booking("far", 9, category="elderly")],
            CONFIG,
        )
        self.assertEqual(allocation.seats, {"far": "F2", "near": "F1"})
        self.assertEqual(allocation.blocking_after, 0)

    def test_more_priority_passengers_than_reserved_seats_gets_a_warning(self):
        bookings = [Booking(f"old{i}", 3 + i, category="elderly", booked_at=i) for i in range(3)]
        allocation = allocate(BUS, bookings, CONFIG)
        self.assertEqual(
            sorted(allocation.seats[f"old{i}"] in ("F1", "F2") for i in range(3)),
            [False, True, True],
        )
        self.assertTrue(any("reserved seat is taken" in w for w in allocation.warnings))

    def test_reserved_seats_are_used_by_others_when_needed(self):
        allocation = allocate(BUS, [Booking(f"p{i}", 1 + i % 5) for i in range(15)], CONFIG)
        self.assertEqual(len(allocation.seats), 15)
        self.assertEqual(allocation.blocking_after, 0)

    def test_layout_with_no_marked_seats_uses_the_frontmost_seats_that_do_not_fold(self):
        allocation = allocate(
            from_grid(4, 3),
            [Booking("old", 4, category="elderly"), Booking("p", 2)],
            CONFIG,
        )
        self.assertNotEqual(allocation.seats["old"], "A1")  # A1 folds
        self.assertIn(allocation.seats["old"], ("A2", "A3", "B1"))

    def test_child_is_not_a_priority_category_by_default(self):
        self.assertNotIn("child", CONFIG.priority.categories)

    def test_priority_categories_come_from_config(self):
        config = CONFIG.replace("priority", categories=frozenset({"pregnant"}))
        allocation = allocate(
            single_file(3), [Booking("old", 9, category="elderly"), Booking("p", 1)], config
        )
        self.assertEqual(allocation.blocking_after, 0)
        self.assertEqual(allocation.seats["old"], "3")


class TestAccessibility(unittest.TestCase):
    def test_a_passenger_needing_access_gets_an_accessible_seat(self):
        allocation = allocate(
            BUS, [Booking("a", 3, needs_accessible=True), Booking("b", 9)], CONFIG
        )
        self.assertEqual(allocation.seats["a"], "F1")

    def test_no_accessible_seat_is_refused_rather_than_guessed(self):
        no_access = layout_from_dict(
            {
                "model": "plain",
                "verification": "a test",
                "doors": [{"id": "d"}],
                "seats": [
                    {
                        "id": "1",
                        "row": 1,
                        "column": 1,
                        "depth_rank": 1,
                        "exit_door": "d",
                        "blocked_by": [],
                    }
                ],
            }
        )
        allocation = allocate(no_access, [Booking("a", 3, needs_accessible=True)], CONFIG)
        self.assertEqual(allocation.seats, {})
        self.assertIn("A person must arrange this trip", allocation.unseated[0][1])

    def test_accessible_seat_taken_means_unseated(self):
        bookings = [
            Booking("a", 3, needs_accessible=True, booked_at=0),
            Booking("b", 4, needs_accessible=True, booked_at=1),
        ]
        allocation = allocate(
            BUS, bookings, CONFIG, fixed={"a": FixedSeat("F1", FixedReason.BOARDED)}
        )
        self.assertEqual(allocation.seats, {"a": "F1"})
        self.assertEqual(allocation.unseated[0][0], "b")


class TestGroups(unittest.TestCase):
    def test_a_group_going_to_one_stop_sits_together_with_no_blocking(self):
        bookings = [
            Booking("g1", 6, group_id="fam", booked_at=1),
            Booking("g2", 6, group_id="fam", booked_at=2),
            Booking("g3", 6, group_id="fam", booked_at=3),
            *[Booking(f"p{i}", 2 + 2 * (i % 5), booked_at=10 + i) for i in range(9)],
        ]
        allocation = allocate(BUS, bookings, CONFIG)
        self.assertEqual(allocation.blocking_after, 0)
        self.assertEqual(allocation.split_groups, ())

    def test_a_group_is_split_when_sitting_together_would_add_blocking(self):
        """Friends getting off at 1 km and 12 km cannot be neighbours in single file
        with three others getting off in between, without blocking."""
        bookings = [
            Booking("friend-near", 1, group_id="friends"),
            Booking("friend-far", 12, group_id="friends"),
            Booking("a", 3),
            Booking("b", 6),
            Booking("c", 8),
        ]
        allocation = allocate(single_file(5), bookings, CONFIG)
        self.assertEqual(allocation.blocking_after, 0)
        [split] = allocation.split_groups
        self.assertEqual(split.group_id, "friends")
        self.assertIn("would add blocking", split.reason)

    def test_a_group_is_not_split_when_that_saves_nothing(self):
        bookings = [
            Booking("friend-near", 3, group_id="friends"),
            Booking("friend-far", 6, group_id="friends"),
            Booking("a", 1),
            Booking("b", 8),
        ]
        allocation = allocate(single_file(4), bookings, CONFIG)
        self.assertEqual(allocation.blocking_after, 0)
        self.assertEqual(allocation.split_groups, ())

    def test_a_group_wider_than_the_free_seats_together_is_split_and_reported(self):
        # Seats 2 and 4 are taken, so no three free seats are neighbours.
        fixed = {
            "x": FixedSeat("2", FixedReason.BOARDED),
            "y": FixedSeat("4", FixedReason.BOARDED),
        }
        bookings = [
            Booking("x", 5),
            Booking("y", 5),
            Booking("g1", 5, group_id="g"),
            Booking("g2", 5, group_id="g"),
            Booking("g3", 5, group_id="g"),
        ]
        allocation = allocate(single_file(5), bookings, CONFIG, fixed=fixed, boarded={"x", "y"})
        [split] = allocation.split_groups
        self.assertEqual(split.group_id, "g")
        self.assertIn("No adjacent seats", split.reason)

    def test_tie_break_is_group_first_then_booking_time(self):
        bookings = [
            Booking("solo-early", 5, booked_at=1),
            Booking("g-a", 5, group_id="g", booked_at=2),
            Booking("g-b", 5, group_id="g", booked_at=3),
            Booking("solo-late", 5, booked_at=4),
        ]
        allocation = allocate(single_file(4), bookings, CONFIG)
        self.assertEqual(
            allocation.seats, {"g-a": "4", "g-b": "3", "solo-early": "2", "solo-late": "1"}
        )

    def test_tie_break_can_ignore_groups(self):
        config = CONFIG.replace("assignment", tie_break=("booking_time",)).replace(
            "weights", group_split=0
        )
        bookings = [Booking("early", 5, booked_at=1), Booking("g-a", 5, group_id="g", booked_at=2)]
        self.assertEqual(
            allocate(single_file(2), bookings, config).seats, {"early": "2", "g-a": "1"}
        )


class TestChildren(unittest.TestCase):
    def test_a_child_sits_next_to_their_adult(self):
        bookings = [
            Booking("mum", 6, group_id="fam", booked_at=1),
            Booking("kid", 6, group_id="fam", category="child", booked_at=2),
            *[Booking(f"p{i}", 2 + i, booked_at=10 + i) for i in range(10)],
        ]
        allocation = allocate(BUS, bookings, CONFIG)
        self.assertIn(allocation.seats["kid"], BUS.seat(allocation.seats["mum"]).neighbours)
        self.assertEqual(allocation.blocking_after, 0)

    def test_the_rule_holds_even_when_it_costs_blocking(self):
        """The child's own stop is earlier, so sitting together costs a blocking pair."""
        bookings = [
            Booking("mum", 8, group_id="fam", booked_at=1),
            Booking("kid", 2, group_id="fam", category="child", booked_at=2),
            Booking("a", 5, booked_at=3),
            Booking("b", 1, booked_at=4),
        ]
        allocation = allocate(single_file(4), bookings, CONFIG)
        self.assertIn(
            allocation.seats["kid"], single_file(4).seat(allocation.seats["mum"]).neighbours
        )
        self.assertGreater(allocation.blocking_after, 0)
        self.assertEqual(allocation.minimum_blocking, 0)
        self.assertTrue(any("above the minimum" in w for w in allocation.warnings))

    def test_a_child_next_to_a_boarded_adult(self):
        bookings = [
            Booking("mum", 6, group_id="fam", booked_at=1),
            Booking("kid", 6, group_id="fam", category="child", booked_at=2),
            Booking("a", 9, booked_at=3),
        ]
        allocation = allocate(
            BUS,
            bookings,
            CONFIG,
            fixed={"mum": FixedSeat("B2", FixedReason.BOARDED)},
            boarded={"mum"},
        )
        self.assertIn(allocation.seats["kid"], BUS.seat("B2").neighbours)

    def test_a_child_alone_is_reserved_a_seat_and_flagged(self):
        allocation = allocate(BUS, [Booking("kid", 6, category="child"), Booking("a", 9)], CONFIG)
        self.assertIn(allocation.seats["kid"], ("F1", "F2"))
        self.assertTrue(any("child with no adult" in w for w in allocation.warnings))


class TestPreferencesAndLuggage(unittest.TestCase):
    def test_a_preference_is_honoured_when_it_costs_no_blocking(self):
        bookings = [Booking("a", 5, seat_preference="A3"), Booking("b", 9)]
        self.assertEqual(allocate(BUS, bookings, CONFIG).seats["a"], "A3")

    def test_a_tag_preference_is_honoured(self):
        allocation = allocate(
            BUS, [Booking("a", 5, seat_preference="window"), Booking("b", 9)], CONFIG
        )
        self.assertIn("window", BUS.seat(allocation.seats["a"]).tags)

    def test_blocking_outweighs_a_preference(self):
        bookings = [
            Booking("wants-front", 12, seat_preference="1"),
            Booking("b", 8),
            Booking("c", 3),
        ]
        allocation = allocate(single_file(3), bookings, CONFIG)
        self.assertEqual(allocation.seats["wants-front"], "3")
        self.assertEqual(allocation.blocking_after, 0)

    def test_a_bulky_bag_goes_where_there_is_room_if_it_costs_nothing(self):
        allocation = allocate(BUS, [Booking("bag", 5, luggage="bulky"), Booking("b", 2)], CONFIG)
        self.assertIn("luggage", BUS.seat(allocation.seats["bag"]).tags)


class TestSpecialSeats(unittest.TestCase):
    def test_the_driver_seat_is_never_assigned(self):
        allocation = allocate(BUS, [Booking(f"p{i}", 1 + i) for i in range(15)], CONFIG)
        self.assertNotIn("DRV", allocation.seats.values())

    def test_a_conductor_seat_is_never_assigned(self):
        data = single_file(3).to_dict()
        data["seats"][0]["bookable"] = False
        data["seats"][0]["reserved_for"] = ["conductor"]
        layout = layout_from_dict(data)
        allocation = allocate(layout, [Booking("a", 5), Booking("b", 9)], CONFIG)
        self.assertEqual(allocation.seats, {"b": "3", "a": "2"})

    def test_a_full_vehicle_seats_who_fits_and_says_who_does_not(self):
        bookings = [Booking(f"p{i}", 5, booked_at=i) for i in range(7)]
        allocation = allocate(single_file(5), bookings, CONFIG)
        self.assertEqual(len(allocation.seats), 5)
        self.assertEqual([name for name, _ in allocation.unseated], ["p5", "p6"])
        self.assertIn("full", allocation.unseated[0][1])

    def test_one_passenger_alone_sits_near_the_driver(self):
        allocation = allocate(BUS, [Booking("solo", 9)], CONFIG)
        self.assertTrue(BUS.seat(allocation.seats["solo"]).near_driver)
        self.assertEqual(allocation.blocking_after, 0)

    def test_one_passenger_with_no_seat_near_a_driver_takes_the_rearmost(self):
        allocation = allocate(single_file(5), [Booking("solo", 9)], CONFIG)
        self.assertEqual(allocation.seats["solo"], "5")

    def test_no_passengers_is_not_an_error(self):
        allocation = allocate(BUS, [], CONFIG)
        self.assertEqual(allocation.seats, {})
        self.assertEqual(allocation.blocking_after, 0)


class TestSameStopTolerance(unittest.TestCase):
    def test_drop_offs_a_few_metres_apart_count_as_one_stop(self):
        bookings = [Booking("a", 6.00), Booking("b", 6.03)]
        for seats in ({"a": "1", "b": "2"}, {"a": "2", "b": "1"}):
            pairs, _, _ = evaluate(single_file(2), bookings, seats, CONFIG)
            self.assertEqual(pairs, 0)

    def test_a_chain_of_close_drop_offs_does_not_become_one_long_stop(self):
        bookings = [Booking(f"p{i}", 6 + 0.04 * i) for i in range(5)]
        pairs, _, _ = evaluate(
            single_file(5), bookings, {f"p{i}": str(i + 1) for i in range(5)}, CONFIG
        )
        # Seat 1 goes least far, so this order is fine whichever way stops group.
        self.assertEqual(pairs, 0)
        pairs, _, _ = evaluate(
            single_file(5), bookings, {f"p{i}": str(5 - i) for i in range(5)}, CONFIG
        )
        self.assertGreater(pairs, 0)


class TestFarthestAtTheBack(unittest.TestCase):
    """On a branching layout many seatings have no blocking. The brief wants this one."""

    def test_the_farthest_passengers_get_the_rearmost_seats(self):
        bookings = [Booking(f"p{i}", (4.0, 9.0, 14.0)[i % 3], booked_at=i) for i in range(12)]
        allocation = allocate(BUS, bookings, CONFIG)
        self.assertEqual(allocation.blocking_after, 0)
        depth = {use.passenger: BUS.seat(use.seat).depth_rank for use in allocation.seat_map}
        km = {booking.id: booking.alight for booking in bookings}
        mean_depth = {
            stop: sum(depth[p] for p in depth if km[p] == stop) / 4 for stop in (4.0, 9.0, 14.0)
        }
        self.assertLess(mean_depth[4.0], mean_depth[9.0])
        self.assertLess(mean_depth[9.0], mean_depth[14.0])

    def test_the_rearmost_corner_goes_to_someone_going_all_the_way(self):
        bookings = [Booking(f"p{i}", (4.0, 9.0, 14.0)[i % 3], booked_at=i) for i in range(15)]
        allocation = allocate(BUS, bookings, CONFIG)
        by_seat = {use.seat: use.alight for use in allocation.seat_map}
        self.assertEqual(by_seat["Z4"], 14.0)
        self.assertEqual(by_seat["F1"], 4.0)

    def test_a_family_does_not_pull_those_going_farther_forward(self):
        bookings = [
            *[Booking(f"far{i}", 14.0, booked_at=i) for i in range(3)],
            Booking("mum", 9.0, group_id="fam", booked_at=10),
            Booking("kid", 9.0, group_id="fam", category="child", booked_at=11),
            *[Booking(f"mid{i}", 9.0, booked_at=20 + i) for i in range(4)],
            *[Booking(f"near{i}", 4.0, booked_at=30 + i) for i in range(3)],
        ]
        allocation = allocate(BUS, bookings, CONFIG)
        self.assertEqual(allocation.blocking_after, 0)
        self.assertIn(allocation.seats["kid"], BUS.seat(allocation.seats["mum"]).neighbours)
        self.assertEqual({allocation.seats[f"far{i}"] for i in range(3)}, {"Z4", "Z3", "Z2"})

    def test_a_group_can_still_pull_someone_out_of_order_when_blocking_stays_zero(self):
        bookings = [
            Booking("mum", 9.0, group_id="fam", booked_at=0),
            Booking("kid", 9.0, group_id="fam", category="child", booked_at=1),
            *[Booking(f"p{i}", (4.0, 14.0)[i % 2], booked_at=i + 2) for i in range(10)],
        ]
        allocation = allocate(BUS, bookings, CONFIG)
        self.assertEqual(allocation.blocking_after, 0)
        self.assertIn(allocation.seats["kid"], BUS.seat(allocation.seats["mum"]).neighbours)


class TestGeneralLayouts(unittest.TestCase):
    def test_zero_blocking_on_a_two_door_bus(self):
        allocation = allocate(
            two_door_bus(), [Booking(f"p{i}", 1 + i % 9, booked_at=i) for i in range(30)], CONFIG
        )
        self.assertEqual(allocation.blocking_after, 0)

    def test_passengers_on_different_doors_never_block_each_other(self):
        bus = two_door_bus()
        far, near = Booking("far", 9), Booking("near", 1)
        pairs, _, _ = evaluate(bus, [far, near], {"near": "1LW", "far": "4LA"}, CONFIG)
        self.assertEqual(pairs, 0)

    def test_a_folding_seat_blocks_only_its_own_side_of_the_bus(self):
        bus = two_door_bus()
        far, near = Booking("far", 9), Booking("near", 1)
        pairs, _, _ = evaluate(bus, [far, near], {"near": "7LW", "far": "J2"}, CONFIG)
        self.assertEqual(pairs, 1)
        pairs, _, _ = evaluate(bus, [far, near], {"near": "2LW", "far": "J2"}, CONFIG)
        self.assertEqual(pairs, 0)

    def test_the_final_result_can_beat_both_sorted_and_hungarian_seating(self):
        """A far-going passenger already in the door-side folding seat, and a part-full
        bus: who sits behind them is a real choice, and it takes search to get it right."""
        bookings = [
            Booking("stuck", 11, booked_at=0),
            *[Booking(f"p{i}", 1 + (i * 3) % 10, booked_at=i + 1) for i in range(9)],
        ]
        allocation = allocate(
            BUS,
            bookings,
            CONFIG,
            fixed={"stuck": FixedSeat("A1", FixedReason.BOARDED)},
            boarded={"stuck"},
        )
        methods = allocation.method_blocking
        self.assertEqual(allocation.minimum_blocking, allocation.blocking_after)
        self.assertLess(methods["optimised"], methods["sorted"])
        self.assertLess(methods["optimised"], methods["hungarian"])

    def test_exact_search_is_used_when_the_bound_is_not_tight(self):
        # Stuck far-going passengers on two branches: the bound cannot see the interplay.
        bookings = [
            Booking("x", 9, booked_at=0),
            Booking("y", 2, booked_at=1),
            *[Booking(f"p{i}", 1 + i, booked_at=i + 2) for i in range(5)],
        ]
        fixed = {
            "x": FixedSeat("A2", FixedReason.BOARDED),
            "y": FixedSeat("B1", FixedReason.BOARDED),
        }
        allocation = allocate(BUS, bookings, CONFIG, fixed=fixed, boarded=set(fixed))
        self.assertIsNotNone(allocation.minimum_blocking)
        self.assertEqual(allocation.blocking_after, allocation.minimum_blocking)
        self.assertIn(
            allocation.proof, (PROOF_EXACT, "matches a proven lower bound", "no blocking at all")
        )


if __name__ == "__main__":
    unittest.main()
