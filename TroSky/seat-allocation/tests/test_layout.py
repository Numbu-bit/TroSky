import json
import unittest

import jsonschema

from seat_allocation.layout import (
    LAYOUT_DIR,
    VERIFY,
    LayoutError,
    from_grid,
    layout_from_dict,
    load_layout,
    minibus,
    minibus_variant,
    single_file,
    two_door_bus,
)


def seat(seat_id, rank=1, blocked_by=(), **extra):
    return {
        "id": seat_id,
        "row": rank,
        "column": 1,
        "depth_rank": rank,
        "exit_door": "d",
        "blocked_by": list(blocked_by),
        **extra,
    }


def layout(*seats, doors=("d",), verification=VERIFY):
    return {
        "model": "test",
        "verification": verification,
        "doors": [{"id": door} for door in doors],
        "seats": list(seats),
    }


class TestValidation(unittest.TestCase):
    def test_a_valid_layout_loads(self):
        loaded = layout_from_dict(layout(seat("a"), seat("b", 2, ["a"])))
        self.assertEqual(loaded.seat("b").blockers_count, 1)

    def test_blockers_include_the_blockers_of_blockers(self):
        loaded = layout_from_dict(layout(seat("a"), seat("b", 2, ["a"]), seat("c", 3, ["b"])))
        self.assertEqual(loaded.seat("c").blockers, {"a", "b"})
        self.assertTrue(loaded.blocks("a", "c"))
        self.assertFalse(loaded.blocks("c", "a"))

    def test_a_loop_is_refused(self):
        with self.assertRaisesRegex(LayoutError, "loop"):
            layout_from_dict(layout(seat("a", 1, ["b"]), seat("b", 2, ["a"])))

    def test_a_seat_cannot_block_itself(self):
        with self.assertRaisesRegex(LayoutError, "itself"):
            layout_from_dict(layout(seat("a", 1, ["a"])))

    def test_an_unknown_blocker_is_refused(self):
        with self.assertRaisesRegex(LayoutError, "unknown seats"):
            layout_from_dict(layout(seat("a", 1, ["ghost"])))

    def test_a_blocker_must_be_nearer_the_exit(self):
        with self.assertRaisesRegex(LayoutError, "lower depth_rank"):
            layout_from_dict(layout(seat("a", 2), seat("b", 2, ["a"])))

    def test_a_wrong_blocker_count_is_refused(self):
        with self.assertRaisesRegex(LayoutError, "states 5 blockers"):
            layout_from_dict(layout(seat("a"), seat("b", 2, ["a"], blockers_count=5)))

    def test_an_unknown_door_is_refused(self):
        with self.assertRaisesRegex(LayoutError, "unknown door"):
            layout_from_dict(layout(seat("a", exit_door="ghost")))

    def test_duplicate_seat_ids_are_refused(self):
        with self.assertRaisesRegex(LayoutError, "unique"):
            layout_from_dict(layout(seat("a"), seat("a")))

    def test_a_layout_must_say_how_it_was_checked(self):
        with self.assertRaisesRegex(LayoutError, "verify against the actual fleet"):
            layout_from_dict(layout(seat("a"), verification=""))

    def test_explicit_neighbours_survive_a_round_trip(self):
        original = layout_from_dict(
            layout(seat("a", neighbours=["b"]), seat("b", 2, neighbours=["a"]))
        )
        again = layout_from_dict(original.to_dict())
        self.assertEqual(again.seat("a").neighbours, ("b",))


class TestExamples(unittest.TestCase):
    NAMES = ("single_file_5", "minibus_15", "bus_30_two_door")

    def test_files_match_the_generators(self):
        self.assertEqual(load_layout("single_file_5").to_dict(), single_file(5).to_dict())
        self.assertEqual(load_layout("minibus_15").to_dict(), minibus_variant(15).to_dict())
        self.assertEqual(load_layout("bus_30_two_door").to_dict(), two_door_bus().to_dict())

    def test_files_follow_the_schema(self):
        schema = json.loads((LAYOUT_DIR / "seat_layout.schema.json").read_text(encoding="utf-8"))
        for name in self.NAMES:
            with self.subTest(name=name):
                data = json.loads((LAYOUT_DIR / f"{name}.json").read_text(encoding="utf-8"))
                jsonschema.validate(data, schema)

    def test_every_example_says_it_must_be_verified(self):
        for name in self.NAMES:
            with self.subTest(name=name):
                self.assertIn(VERIFY, load_layout(name).verification)
        table = json.loads((LAYOUT_DIR / "minibus_variants.json").read_text(encoding="utf-8"))
        self.assertEqual(table["verification"], VERIFY)

    def test_the_variants_have_the_seats_they_claim(self):
        for size in (14, 15, 16, 17, 18):
            with self.subTest(size=size):
                self.assertEqual(len(minibus_variant(size).bookable_seats()), size)

    def test_an_unknown_variant_is_refused(self):
        with self.assertRaisesRegex(LayoutError, "no 13-seat variant"):
            minibus_variant(13)

    def test_the_driver_seat_cannot_be_booked(self):
        bus = minibus_variant(15)
        self.assertFalse(bus.seat("DRV").bookable)
        self.assertNotIn("DRV", [seat.id for seat in bus.bookable_seats()])

    def test_minibus_exit_paths(self):
        bus = minibus_variant(15)
        self.assertEqual(bus.seat("A1").blockers, frozenset())
        self.assertEqual(bus.seat("A3").blockers, {"A1", "A2"})
        self.assertEqual(bus.seat("B3").blockers, {"A1", "B1", "B2"})
        self.assertEqual(bus.seat("Z4").blockers, {"A1", "B1", "C1", "Z1", "Z2", "Z3"})
        self.assertEqual(bus.seat("F1").blockers, frozenset())
        self.assertTrue(bus.seat("A1").folding)

    def test_two_door_paths_do_not_cross(self):
        bus = two_door_bus()
        self.assertEqual(len(bus.bookable_seats()), 30)
        self.assertEqual(bus.seat("1LW").blockers, {"1LA"})
        self.assertEqual(bus.seat("3LW").blockers, {"3LA", "J1"})
        self.assertEqual(bus.seat("7RW").blockers, {"7RA", "J2"})
        self.assertEqual(bus.seat("4LW").blockers, {"4LA"})
        self.assertEqual(bus.seat("7RW").exit_door, "rear")
        self.assertEqual(bus.seat("1LW").exit_door, "front")

    def test_a_grid_gives_a_usable_first_guess(self):
        grid = from_grid(5, 3)
        self.assertEqual(len(grid.bookable_seats()), 15)
        self.assertEqual(grid.seat("B3").blockers, {"A1", "B1", "B2"})
        self.assertIn("guessed", grid.verification)

    def test_single_file_is_recognised(self):
        self.assertTrue(single_file(5).is_single_file())
        self.assertFalse(minibus_variant(15).is_single_file())

    def test_bad_minibus_plans_are_refused(self):
        with self.assertRaises(LayoutError):
            minibus(cab_seats=3, rows_of_three=3, back_row=4)


if __name__ == "__main__":
    unittest.main()
