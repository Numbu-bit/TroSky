"""The required test vectors, on the 5-seat single-file model (seat 1 nearest the exit)."""

import unittest

from seat_allocation import Booking, allocate, evaluate, load_config, single_file

CONFIG = load_config()
SEATS = single_file(5)


def trip(*alights: float) -> list[Booking]:
    return [Booking(id=f"p{i}", alight=km, booked_at=i) for i, km in enumerate(alights)]


def seat_of_km(allocation, bookings) -> dict[str, float]:
    by_id = {booking.id: booking.alight for booking in bookings}
    return {seat: by_id[passenger] for passenger, seat in allocation.seats.items()}


class TestFirstVector(unittest.TestCase):
    """Alight positions 12, 3, 8, 1, 6 km."""

    def setUp(self):
        self.bookings = trip(12, 3, 8, 1, 6)
        self.allocation = allocate(SEATS, self.bookings, CONFIG)

    def test_expected_seats(self):
        self.assertEqual(
            seat_of_km(self.allocation, self.bookings),
            {"5": 12, "4": 8, "3": 6, "2": 3, "1": 1},
        )

    def test_no_blocking_pairs(self):
        self.assertEqual(self.allocation.blocking_after, 0)
        self.assertEqual(self.allocation.minimum_blocking, 0)
        self.assertIs(self.allocation.zero_blocking_possible, True)

    def test_fully_reversed_arrangement_has_ten_pairs(self):
        reversed_seats = {"p0": "1", "p2": "2", "p4": "3", "p1": "4", "p3": "5"}
        pairs, _, _ = evaluate(SEATS, self.bookings, reversed_seats, CONFIG)
        self.assertEqual(pairs, 10)


class TestSecondVector(unittest.TestCase):
    """Alight positions 12, 6, 6, 3, 1 km: two passengers share a stop."""

    def setUp(self):
        self.bookings = trip(12, 6, 6, 3, 1)
        self.allocation = allocate(SEATS, self.bookings, CONFIG)

    def test_expected_seats(self):
        self.assertEqual(
            seat_of_km(self.allocation, self.bookings),
            {"5": 12, "4": 6, "3": 6, "2": 3, "1": 1},
        )

    def test_no_blocking_pairs(self):
        self.assertEqual(self.allocation.blocking_after, 0)

    def test_the_two_at_the_same_stop_are_adjacent(self):
        self.assertEqual(
            {self.allocation.seats["p1"], self.allocation.seats["p2"]},
            {"4", "3"},
        )
        self.assertIn(
            self.allocation.seats["p2"], SEATS.seat(self.allocation.seats["p1"]).neighbours
        )

    def test_same_stop_passengers_never_block_each_other(self):
        for seats in ({"p1": "3", "p2": "4"}, {"p1": "4", "p2": "3"}):
            pairs, _, _ = evaluate(SEATS, self.bookings[1:3], seats, CONFIG)
            self.assertEqual(pairs, 0)


class TestThirdVector(unittest.TestCase):
    """A priority passenger going 12 km is fixed in seat 1; the others go 8, 6, 3 and 1 km."""

    def setUp(self):
        self.bookings = [
            Booking(id="priority", alight=12, category="elderly", booked_at=0),
            Booking(id="p8", alight=8, booked_at=1),
            Booking(id="p6", alight=6, booked_at=2),
            Booking(id="p3", alight=3, booked_at=3),
            Booking(id="p1", alight=1, booked_at=4),
        ]
        self.allocation = allocate(SEATS, self.bookings, CONFIG)

    def test_expected_seats(self):
        self.assertEqual(
            self.allocation.seats,
            {"priority": "1", "p8": "5", "p6": "4", "p3": "3", "p1": "2"},
        )

    def test_four_unavoidable_pairs_are_reported(self):
        self.assertEqual(self.allocation.blocking_after, 4)
        self.assertEqual(self.allocation.unavoidable_blocking, 4)
        self.assertIs(self.allocation.zero_blocking_possible, False)

    def test_each_pair_is_someone_getting_past_the_priority_passenger(self):
        self.assertEqual(
            sorted((pair.passenger, pair.blocker) for pair in self.allocation.blocking_pairs),
            [("p1", "priority"), ("p3", "priority"), ("p6", "priority"), ("p8", "priority")],
        )

    def test_the_report_says_why(self):
        [forced] = self.allocation.forced
        self.assertEqual(forced.constraint, "priority_seat")
        self.assertEqual(forced.passenger, "priority")
        self.assertEqual(forced.seat, "1")
        self.assertEqual(forced.pairs, 4)
        self.assertIn("4 passengers seated behind them", forced.reason)

    def test_the_report_shows_what_another_seat_would_cost(self):
        [forced] = self.allocation.forced
        self.assertEqual((forced.other_seat, forced.pairs_in_other_seat), ("5", 0))


if __name__ == "__main__":
    unittest.main()
