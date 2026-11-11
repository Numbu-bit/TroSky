"""Several pickups: seats are shared by stretches of the route that do not overlap."""

import itertools
import random
import time
import unittest

from seat_allocation import Booking, allocate, evaluate, load_config, minibus_variant, single_file
from seat_allocation.allocator import (
    PROOF_EXACT,
    PROOF_NONE,
    PROOF_ZERO,
    _from_current,
    solve,
)
from seat_allocation.model import UNSEATED, FixedReason, FixedSeat, Problem
from seat_allocation.simulator import Scenario, synthetic_bookings
from seat_allocation.solvers import exact_interval_blocking, improve, improve_chains

CONFIG = load_config()

FULL_VEHICLE = Scenario(
    "often full",
    lambda: minibus_variant(15),
    multi_pickup=True,
    occupancy=(1.6, 2.4),
    stops=(4, 7),
)


def best_by_brute_force(layout, bookings) -> int:
    """The fewest blocking pairs over every legal seating, sharing seats where allowed."""
    problem = Problem(layout, bookings, CONFIG)
    best = None
    for seats in itertools.product(problem.bookable, repeat=problem.n):
        assign = list(seats)
        if any(
            assign[p] == assign[q] and problem.overlap[p][q]
            for p, q in itertools.combinations(range(problem.n), 2)
        ):
            continue
        count = len(problem.blocking_pairs(assign))
        if best is None or count < best:
            best = count
    assert best is not None
    return best


class TestDefinitionWithIntervals(unittest.TestCase):
    def test_no_blocking_when_they_are_not_on_board_together(self):
        # q in the way of p's seat, but q boards only after p has got off.
        bookings = [Booking("p", alight=5, board=0), Booking("q", alight=10, board=6)]
        pairs, _, _ = evaluate(single_file(2), bookings, {"p": "2", "q": "1"}, CONFIG)
        self.assertEqual(pairs, 0)

    def test_blocking_when_they_overlap_at_the_moment_of_alighting(self):
        bookings = [Booking("p", alight=5, board=0), Booking("q", alight=10, board=3)]
        pairs, _, _ = evaluate(single_file(2), bookings, {"p": "2", "q": "1"}, CONFIG)
        self.assertEqual(pairs, 1)

    def test_someone_boarding_at_the_stop_where_another_gets_off_does_not_block(self):
        # People get off before others get on.
        bookings = [Booking("p", alight=5, board=0), Booking("q", alight=10, board=5)]
        pairs, _, _ = evaluate(single_file(2), bookings, {"p": "2", "q": "1"}, CONFIG)
        self.assertEqual(pairs, 0)

    def test_someone_getting_off_first_is_no_obstacle_to_someone_behind(self):
        bookings = [Booking("near", alight=3, board=0), Booking("far", alight=9, board=0)]
        pairs, _, _ = evaluate(single_file(2), bookings, {"near": "1", "far": "2"}, CONFIG)
        self.assertEqual(pairs, 0)


class TestSeatSharing(unittest.TestCase):
    def test_a_seat_can_be_shared_by_stretches_that_do_not_overlap(self):
        bookings = [Booking("first", alight=5, board=0), Booking("second", alight=9, board=5)]
        allocation = allocate(single_file(1), bookings, CONFIG)
        self.assertEqual(allocation.seats, {"first": "1", "second": "1"})
        self.assertEqual(allocation.unseated, ())

    def test_a_seat_is_never_given_to_two_overlapping_passengers(self):
        rng = random.Random(7)
        layout = minibus_variant(15)
        for _ in range(20):
            bookings = []
            for i in range(18):
                board = rng.randint(0, 8)
                bookings.append(
                    Booking(f"p{i}", alight=rng.randint(board + 1, 10), board=board, booked_at=i)
                )
            allocation = allocate(layout, bookings, CONFIG)
            uses = allocation.seat_map
            for a, b in itertools.combinations(uses, 2):
                if a.seat == b.seat:
                    self.assertTrue(a.alight <= b.board or b.alight <= a.board, (a, b))

    def test_more_riders_than_seats_on_one_stretch_are_reported(self):
        bookings = [Booking(f"p{i}", alight=9, board=i, booked_at=i) for i in range(3)]
        allocation = allocate(single_file(2), bookings, CONFIG)
        self.assertEqual(len(allocation.seats), 2)
        self.assertEqual(allocation.unseated[0][0], "p2")
        self.assertIn("no free seat", allocation.unseated[0][1])

    def test_more_riders_than_seats_in_total_can_still_all_ride(self):
        bookings = [
            Booking("a", alight=4, board=0),
            Booking("b", alight=4, board=0),
            Booking("c", alight=8, board=4),
            Booking("d", alight=8, board=4),
        ]
        allocation = allocate(single_file(2), bookings, CONFIG)
        self.assertEqual(len(allocation.seats), 4)
        self.assertEqual(allocation.blocking_after, 0)


class TestBoardingBlocking(unittest.TestCase):
    def test_someone_seated_must_stand_for_a_later_boarder_behind_them(self):
        bookings = [Booking("seated", alight=9, board=0), Booking("later", alight=9, board=4)]
        _, boarding, _ = evaluate(single_file(2), bookings, {"seated": "1", "later": "2"}, CONFIG)
        self.assertEqual(boarding, 1)

    def test_the_engine_avoids_it_when_it_can(self):
        bookings = [Booking("seated", alight=9, board=0), Booking("later", alight=9, board=4)]
        allocation = allocate(single_file(2), bookings, CONFIG)
        self.assertEqual(allocation.seats, {"seated": "2", "later": "1"})
        self.assertEqual(allocation.boarding_blocks, 0)

    def test_blocking_outweighs_boarding_blocking(self):
        # Keeping the later boarder in front avoids a boarding block but causes a blocking
        # pair, so they sit behind and the seated passenger stands once to let them in.
        bookings = [Booking("seated", alight=5, board=0), Booking("later", alight=9, board=3)]
        allocation = allocate(single_file(2), bookings, CONFIG)
        self.assertEqual(allocation.seats, {"later": "2", "seated": "1"})
        self.assertEqual(allocation.blocking_after, 0)
        self.assertEqual(allocation.boarding_blocks, 1)

    def test_nobody_at_one_stop_blocks_when_called_rearmost_first(self):
        bookings = [Booking(f"p{i}", alight=1 + i) for i in range(5)]
        allocation = allocate(single_file(5), bookings, CONFIG)
        self.assertEqual(allocation.boarding_blocks, 0)
        self.assertEqual(allocation.boarding_order, ("p4", "p3", "p2", "p1", "p0"))

    def test_boarding_in_arrival_order_counts_real_obstruction(self):
        config = CONFIG.replace("assignment", boarding_discipline="arrival")
        bookings = [Booking("first", 9, booked_at=1), Booking("second", 9, booked_at=2)]
        self.assertEqual(allocate(single_file(2), bookings, config).boarding_blocks, 0)
        _, boarding, _ = evaluate(single_file(2), bookings, {"first": "1", "second": "2"}, config)
        self.assertEqual(boarding, 1)

    def test_equal_stops_seat_the_earlier_arrival_deeper_when_arrival_order_rules(self):
        config = CONFIG.replace("assignment", boarding_discipline="arrival")
        bookings = [Booking("second", 9, booked_at=2), Booking("first", 9, booked_at=1)]
        allocation = allocate(single_file(2), bookings, config)
        self.assertEqual(allocation.seats, {"first": "2", "second": "1"})

    def test_boarding_order_runs_stop_by_stop_rearmost_first(self):
        bookings = [
            Booking("a", alight=9, board=0),
            Booking("b", alight=5, board=0),
            Booking("c", alight=9, board=6),
        ]
        allocation = allocate(single_file(3), bookings, CONFIG)
        self.assertEqual(allocation.boarding_order[-1], "c")
        self.assertEqual(allocation.boarding_order[:2], ("a", "b"))


class TestZeroIsNotAlwaysPossible(unittest.TestCase):
    def test_overlapping_stretches_can_force_blocking_with_no_constraint_at_all(self):
        """Two seats, one exit path. Whatever you do, someone blocks someone.

        a and b overlap, so they use different seats. c boards after a has left, and
        only a's seat is free for c. Going farther than b, c needs the rear seat, which
        means a must have had it, and a gets off before b."""
        bookings = [
            Booking("a", alight=5, board=0),
            Booking("b", alight=10, board=0),
            Booking("c", alight=12, board=5),
        ]
        allocation = allocate(single_file(2), bookings, CONFIG)
        self.assertEqual(best_by_brute_force(single_file(2), bookings), 1)
        self.assertEqual(allocation.blocking_after, 1)
        self.assertEqual(allocation.minimum_blocking, 1)
        self.assertEqual(allocation.proof, PROOF_EXACT)
        self.assertIs(allocation.zero_blocking_possible, False)


class TestChainExchange(unittest.TestCase):
    """One rider rarely fits elsewhere on a full vehicle, so whole chains are exchanged."""

    BOOKINGS = (
        Booking("long", alight=7, board=2),
        Booking("short", alight=6, board=5),
        Booking("early", alight=4, board=0),
    )

    def stuck(self):
        """Long sits by the exit and gets off last, in the way of both others behind them."""
        problem = Problem(single_file(2), list(self.BOOKINGS), CONFIG)
        front, rear = problem.seat_index["1"], problem.seat_index["2"]
        return problem, [front, rear, rear]

    def test_single_moves_are_stuck_here(self):
        problem, assign = self.stuck()
        self.assertEqual(len(problem.blocking_pairs(assign)), 2)
        self.assertEqual(improve(problem, assign, [0, 1, 2]), assign)

    def test_exchanging_the_chain_clears_it(self):
        problem, assign = self.stuck()
        better = improve_chains(problem, assign, [0, 1, 2])
        self.assertEqual(better, [assign[1], assign[0], assign[0]])
        self.assertEqual(len(problem.blocking_pairs(better)), 0)

    def test_the_engine_finds_it(self):
        allocation = allocate(single_file(2), list(self.BOOKINGS), CONFIG)
        self.assertEqual(allocation.seats, {"long": "2", "short": "1", "early": "1"})
        self.assertEqual(allocation.blocking_after, 0)

    def test_a_chain_holding_someone_who_may_not_move_stays_put(self):
        problem, assign = self.stuck()
        self.assertEqual(improve_chains(problem, assign, [1, 2]), assign)

    def test_exchanges_stay_legal_and_never_cost_more(self):
        rng = random.Random(20261108)
        layout = minibus_variant(15)
        seats = [seat.id for seat in layout.bookable_seats()]
        for _ in range(40):
            bookings = synthetic_bookings(rng, FULL_VEHICLE, len(seats))
            bookings = [
                Booking(
                    id=b.id,
                    alight=b.alight,
                    board=b.board,
                    booked_at=b.booked_at,
                    category="elderly" if rng.random() < 0.1 else "standard",
                )
                for b in bookings
            ]
            fixed = {bookings[0].id: FixedSeat(rng.choice(seats), FixedReason.BOARDED)}
            problem = Problem(layout, bookings, CONFIG, fixed=fixed)
            order = rng.sample(range(problem.n), problem.n)
            assign = [UNSEATED] * problem.n
            assign[0] = problem.fixed[0]
            for p in order:
                if p != 0:
                    options = [s for s in problem.domain[p] if problem.fits(p, s, assign)]
                    assign[p] = rng.choice(options) if options else UNSEATED
            before = problem.total_cost(assign)
            after = improve_chains(problem, assign, [p for p in order if p != 0])
            self.assertLessEqual(problem.total_cost(after), before)
            self.assertEqual(after[0], assign[0])
            for p, q in itertools.combinations(range(problem.n), 2):
                if after[p] != UNSEATED and after[p] == after[q]:
                    self.assertFalse(problem.overlap[p][q], (bookings[p], bookings[q]))
            for p, seat in enumerate(after):
                self.assertEqual(seat == UNSEATED, assign[p] == UNSEATED)
                if seat != UNSEATED:
                    self.assertIn(seat, problem.domain[p])


class TestFullVehicles(unittest.TestCase):
    """Several pickups, with the vehicle full on parts of the route."""

    def trips(self, count, seed=20261108):
        rng = random.Random(seed)
        layout = minibus_variant(15)
        seats = len(layout.bookable_seats())
        for _ in range(count):
            yield layout, synthetic_bookings(rng, FULL_VEHICLE, seats)

    def test_everyone_rides_when_no_stretch_has_too_many_riders(self):
        """Stretches of a route form an interval graph, so seats equal to the busiest
        stretch are always enough, and seating in boarding order finds a way."""
        for layout, bookings in self.trips(60):
            self.assertEqual(allocate(layout, bookings, CONFIG).unseated, ())

    def test_the_search_stops_at_its_budget_and_says_nothing_is_proven(self):
        config = CONFIG.replace("search", interval_max_nodes=1)
        hard = 0
        for layout, bookings in self.trips(200):
            problem = Problem(layout, bookings, config)
            outcome = solve(problem)
            count = len(problem.blocking_pairs(outcome.assign))
            if count == 0:
                continue
            hard += 1
            exact = exact_interval_blocking(problem, {}, outcome.assign, count)
            self.assertFalse(exact.finished)
            self.assertIsNone(exact.minimum)
            allocation = allocate(layout, bookings, config)
            self.assertEqual(allocation.proof, PROOF_NONE)
            self.assertIsNone(allocation.minimum_blocking)
            self.assertIsNone(allocation.zero_blocking_possible)
        self.assertGreater(hard, 0, "no trip above zero to test on: choose a harder scenario")

    def test_a_full_trip_is_seated_in_time_for_a_live_booking(self):
        """Each solve once spent 20 seconds on this. The limit is generous for slow
        machines, and only meant to catch the search running away again."""
        for layout, bookings in self.trips(30):
            started = time.perf_counter()
            solve(Problem(layout, bookings, CONFIG))
            self.assertLess(time.perf_counter() - started, 5)


class TestReoptimising(unittest.TestCase):
    """People who have been told a seat keep it unless moving them saves something."""

    SCENARIO = Scenario(
        "ordinary",
        lambda: minibus_variant(15),
        multi_pickup=True,
        occupancy=(0.8, 1.3),
    )

    def trips(self, count):
        rng = random.Random(6)
        layout = minibus_variant(15)
        seats = len(layout.bookable_seats())
        for _ in range(count):
            yield layout, synthetic_bookings(rng, self.SCENARIO, seats)

    def test_a_new_booking_never_costs_more_than_keeping_everyone_in_place(self):
        for layout, bookings in self.trips(40):
            first = allocate(layout, bookings[:-1], CONFIG)
            problem = Problem(layout, bookings, CONFIG, current=first.seats)
            keep = _from_current(problem, {})
            self.assertLessEqual(
                problem.total_cost(solve(problem).assign), problem.total_cost(keep)
            )

    def test_seating_the_same_trip_again_moves_nobody_when_nothing_can_improve(self):
        checked = 0
        for layout, bookings in self.trips(20):
            first = allocate(layout, bookings, CONFIG)
            if first.blocking_after == 0 and first.boarding_blocks == 0:
                checked += 1
                again = allocate(layout, bookings, CONFIG, current=first.seats)
                self.assertEqual(again.seats, first.seats)
        self.assertGreater(checked, 0)


class TestAgainstBruteForce(unittest.TestCase):
    def test_small_trips_reach_the_true_minimum(self):
        rng = random.Random(20261108)
        layout = single_file(3)
        for _ in range(150):
            bookings = []
            for i in range(rng.randint(2, 5)):
                board = rng.randint(0, 5)
                bookings.append(
                    Booking(f"p{i}", alight=rng.randint(board + 1, 7), board=board, booked_at=i)
                )
            allocation = allocate(layout, bookings, CONFIG)
            if allocation.unseated:
                continue
            truth = best_by_brute_force(layout, bookings)
            self.assertEqual(allocation.minimum_blocking, truth, bookings)
            self.assertEqual(allocation.blocking_after, truth, bookings)
            self.assertIn(allocation.proof, (PROOF_ZERO, PROOF_EXACT))


if __name__ == "__main__":
    unittest.main()
