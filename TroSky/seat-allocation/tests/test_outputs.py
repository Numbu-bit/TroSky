"""Messages, the conductor's sheet, config loading, the simulator and the command line."""

import contextlib
import io
import json
import random
import tempfile
import tomllib
import unittest
from pathlib import Path

from seat_allocation import Booking, allocate, load_config, minibus_variant, single_file
from seat_allocation.cli import main
from seat_allocation.config import DEFAULT_CONFIG_PATH, ConfigError, parse_config
from seat_allocation.messages import SMS_LIMIT, conductor_sheet, seat_reason, sms_confirmation
from seat_allocation.simulator import Scenario, run_online, run_scenario, synthetic_bookings

CONFIG = load_config()
FIVE = single_file(5)


def trip(*alights):
    return [Booking(f"p{i}", km, booked_at=i) for i, km in enumerate(alights)]


class TestSeatReasons(unittest.TestCase):
    def setUp(self):
        self.bookings = trip(12, 3, 8, 1, 6)
        self.allocation = allocate(FIVE, self.bookings, CONFIG)

    def reason(self, name, **kwargs):
        booking = next(b for b in self.bookings if b.id == name)
        return seat_reason(booking, self.allocation, FIVE, **kwargs)

    def test_last_off(self):
        self.assertEqual(self.reason("p0"), "Seat 5: you get off at the last stop.")

    def test_first_off(self):
        self.assertEqual(self.reason("p3"), "Seat 1: you get off first, so you sit near the door.")

    def test_in_between(self):
        self.assertEqual(self.reason("p4"), "Seat 3: no one will be in your way when you get off.")

    def test_their_own_choice(self):
        self.assertEqual(self.reason("p0", chosen=True), "Seat 5: the seat you chose.")

    def test_a_blocked_passenger_is_told_so(self):
        bookings = [Booking("old", 12, category="elderly"), Booking("a", 3)]
        allocation = allocate(single_file(2), bookings, CONFIG)
        self.assertEqual(
            seat_reason(bookings[1], allocation, single_file(2)),
            "Seat 2: 1 passenger may need to move when you get off.",
        )

    def test_a_priority_passenger_is_told_their_seat_was_kept(self):
        bookings = [Booking("old", 3, category="elderly"), Booking("a", 12)]
        allocation = allocate(single_file(2), bookings, CONFIG)
        self.assertEqual(
            seat_reason(bookings[0], allocation, single_file(2)),
            "Seat 1: kept for you, close to the door.",
        )

    def test_a_group_is_told_they_are_together(self):
        bookings = [Booking("a", 6, group_id="g"), Booking("b", 6, group_id="g"), Booking("c", 2)]
        allocation = allocate(FIVE, bookings, CONFIG)
        self.assertIn("with your group", seat_reason(bookings[0], allocation, FIVE))

    def test_alone_on_the_vehicle(self):
        bookings = [Booking("solo", 9)]
        allocation = allocate(minibus_variant(15), bookings, CONFIG)
        self.assertIn("empty", seat_reason(bookings[0], allocation, minibus_variant(15)))


class TestFallbacks(unittest.TestCase):
    def test_sms_fits_one_message_in_plain_characters(self):
        booking = Booking("a", 12, alight_name="Circle")
        text = sms_confirmation(
            booking, "Z4", route_name="Madina to Circle", departure="07:30", boarding_turn=1
        )
        self.assertEqual(
            text, "TroSky: seat Z4, Madina to Circle 07:30, off at Circle. Board 1st when called."
        )
        self.assertLessEqual(len(text), SMS_LIMIT)
        text.encode("ascii")

    def test_sms_shortens_a_long_route_name(self):
        booking = Booking("a", 12, alight_name="Circle")
        text = sms_confirmation(
            booking, "Z4", route_name="x" * 200, departure="07:30", boarding_turn=11
        )
        self.assertLessEqual(len(text), SMS_LIMIT)
        self.assertIn("seat Z4", text)
        self.assertIn("Board 11th", text)

    def test_conductor_sheet_lists_seats_order_and_moves(self):
        bookings = [Booking("old", 12, category="elderly"), Booking("a", 3)]
        allocation = allocate(single_file(2), bookings, CONFIG)
        sheet = conductor_sheet(
            allocation,
            title="TRIP 07:30",
            names={"old": "Esi", "a": "Kofi"},
            stop_names={12: "Circle", 3: "Legon"},
        )
        self.assertIn("TRIP 07:30", sheet)
        self.assertIn("Esi", sheet)
        self.assertIn("At Legon: Esi moves for Kofi", sheet)
        self.assertLess(sheet.index("CALL TO BOARD"), sheet.index("GETTING OFF"))


class TestConfig(unittest.TestCase):
    def data(self):
        with open(DEFAULT_CONFIG_PATH, "rb") as handle:
            return tomllib.load(handle)

    def test_the_given_weights(self):
        self.assertEqual(CONFIG.weights.blocking, 1000)
        self.assertEqual(CONFIG.weights.boarding_blocking, 200)
        self.assertEqual(CONFIG.weights.preference, 100)

    def test_other_given_defaults(self):
        self.assertEqual(CONFIG.groups.togetherness, "soft")
        self.assertTrue(CONFIG.assignment.allow_passenger_override)
        self.assertEqual(CONFIG.assignment.mode, "batch")
        self.assertEqual(CONFIG.assignment.tie_break, ("group", "booking_time"))

    def test_a_float_weight_is_refused(self):
        data = self.data()
        data["weights"]["blocking"] = 1.0
        with self.assertRaisesRegex(ConfigError, "is a float"):
            parse_config(data)

    def test_a_weight_with_too_many_decimals_is_refused(self):
        data = self.data()
        data["weights"]["preference"] = "0.1234"
        with self.assertRaisesRegex(ConfigError, "three decimal places"):
            parse_config(data)

    def test_soft_groups_must_cost_less_than_a_blocking_pair(self):
        data = self.data()
        data["weights"]["group_split"] = "1.5"
        with self.assertRaisesRegex(ConfigError, "group_split"):
            parse_config(data)

    def test_a_bad_mode_is_refused(self):
        with self.assertRaisesRegex(ConfigError, "mode"):
            CONFIG.replace("assignment", mode="sometimes")

    def test_a_bad_tie_break_is_refused(self):
        with self.assertRaisesRegex(ConfigError, "tie_break"):
            CONFIG.replace("assignment", tie_break=("age",))

    def test_an_unknown_priority_category_is_refused(self):
        with self.assertRaisesRegex(ConfigError, "unknown values"):
            CONFIG.replace("priority", categories=frozenset({"vip"}))

    def test_a_missing_value_is_named(self):
        data = self.data()
        del data["assignment"]["mode"]
        with self.assertRaisesRegex(ConfigError, "assignment.mode"):
            parse_config(data)


class TestSimulator(unittest.TestCase):
    def run_small(self, **options):
        scenario = Scenario("test", lambda: minibus_variant(15), **options)
        return run_scenario(scenario, CONFIG, trips=15, seed=3)

    def test_optimised_beats_the_baselines(self):
        methods = self.run_small()["methods"]
        self.assertEqual(methods["optimised"]["mean"], 0)
        self.assertGreater(methods["random"]["mean"], 0)
        self.assertGreater(methods["first_come"]["mean"], 0)

    def test_constraints_can_force_blocking_and_optimised_stays_lowest(self):
        methods = self.run_small(boarded_share=0.33)["methods"]
        self.assertLessEqual(methods["optimised"]["mean"], methods["greedy"]["mean"])
        self.assertLessEqual(methods["optimised"]["mean"], methods["hungarian"]["mean"])
        self.assertLessEqual(methods["optimised"]["mean"], methods["random"]["mean"])

    def test_multi_pickup_runs(self):
        result = self.run_small(multi_pickup=True, occupancy=(0.8, 1.2))
        self.assertLessEqual(
            result["methods"]["optimised"]["mean"], result["methods"]["random"]["mean"]
        )

    def test_the_same_seed_gives_the_same_trips(self):
        scenario = Scenario(
            "test", lambda: minibus_variant(15), group_share=0.3, priority_share=0.2
        )
        first = synthetic_bookings(random.Random(1), scenario, 15)
        second = synthetic_bookings(random.Random(1), scenario, 15)
        self.assertEqual(first, second)

    def test_online_comparison(self):
        result = run_online(CONFIG, trips=8, seed=4, passengers_late=0.0)
        methods = result["methods"]
        self.assertEqual(methods["reoptimised"]["mean"], 0)
        self.assertLessEqual(methods["with_zones"]["mean"], methods["first_come"]["mean"])


class TestSyntheticTrips(unittest.TestCase):
    def test_a_request_with_no_seat_on_its_stretch_is_refused(self):
        scenario = Scenario(
            "often full", lambda: single_file(5), multi_pickup=True, occupancy=(3, 4), stops=(4, 7)
        )
        rng = random.Random(1)
        fuller_than_seats = 0
        for _ in range(200):
            bookings = synthetic_bookings(rng, scenario, 5)
            fuller_than_seats += len(bookings) > 5
            for stop in {b.board for b in bookings}:
                riding = [b for b in bookings if b.board <= stop < b.alight]
                self.assertLessEqual(len(riding), 5)
        self.assertGreater(fuller_than_seats, 0)

    def test_a_trip_stops_at_the_number_of_passengers_wanted(self):
        scenario = Scenario("groups", lambda: single_file(5), occupancy=(1, 1), group_share=0.5)
        rng = random.Random(1)
        for _ in range(200):
            self.assertEqual(len(synthetic_bookings(rng, scenario, 5)), 5)


class TestCommandLine(unittest.TestCase):
    def capture(self, *argv):
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = main(list(argv))
        return code, out.getvalue(), err.getvalue()

    def test_allocate(self):
        code, out, _ = self.capture("allocate", "12", "3", "8", "1", "6")
        self.assertEqual(code, 0)
        self.assertIn("Blocking pairs after:  0", out)

    def test_allocate_with_a_priority_passenger_explains_the_blocking(self):
        code, out, _ = self.capture("allocate", "12", "8", "6", "3", "1", "--priority", "12")
        self.assertEqual(code, 0)
        self.assertIn("Blocking pairs after:  4", out)
        self.assertIn("Unavoidable blocking:  4", out)
        self.assertIn("Why:", out)

    def test_allocate_on_a_minibus(self):
        code, out, _ = self.capture("allocate", "1", "2", "3", "--seats", "15")
        self.assertEqual(code, 0)
        self.assertIn("Z4", out)

    def test_a_bad_layout_is_a_clean_error(self):
        code, _, err = self.capture("allocate", "1", "--layout", "no_such_layout")
        self.assertEqual(code, 2)
        self.assertIn("Error", err)

    def test_simulate_writes_json(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "results.json"
            code, out, _ = self.capture("simulate", "--trips", "3", "--json", str(path))
            self.assertEqual(code, 0)
            self.assertIn("optimised", out)
            results = json.loads(path.read_text(encoding="utf-8"))
            self.assertEqual(results["trips_per_scenario"], 3)


if __name__ == "__main__":
    unittest.main()
