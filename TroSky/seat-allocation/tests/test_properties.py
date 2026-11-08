"""Property-based tests: claims the engine makes, checked against brute force."""

import itertools
import unittest

from hypothesis import assume, given, settings
from hypothesis import strategies as st

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
from seat_allocation.hungarian import solve_assignment
from seat_allocation.layout import SeatLayout, from_grid, layout_from_dict, two_door_bus
from seat_allocation.model import UNSEATED, Problem
from seat_allocation.solvers import (
    blocking_lower_bound,
    exact_min_blocking,
    hungarian_seating,
    improve,
    sorted_seating,
)

CONFIG = load_config()
LAYOUTS = {
    "single_file_8": single_file(8),
    "minibus_14": minibus_variant(14),
    "minibus_15": minibus_variant(15),
    "minibus_18": minibus_variant(18),
    "grid_4x3": from_grid(4, 3),
    "bus_30": two_door_bus(),
}


def trip_of(alights: list[int]) -> list[Booking]:
    return [Booking(id=f"p{i}", alight=km, booked_at=i) for i, km in enumerate(alights)]


alight_lists = st.lists(st.integers(min_value=1, max_value=12), min_size=1, max_size=8)


def poset_layouts() -> st.SearchStrategy[SeatLayout]:
    """Small random layouts: each seat is blocked by a few seats before it."""

    def build(parents: list[list[int]]) -> SeatLayout:
        depth = []
        seats = []
        for index, chosen in enumerate(parents):
            blockers = sorted({c % index for c in chosen}) if index else []
            depth.append(1 + max((depth[b] for b in blockers), default=0))
            seats.append(
                {
                    "id": f"s{index}",
                    "row": index + 1,
                    "column": 1,
                    "depth_rank": depth[index],
                    "exit_door": "d",
                    "blocked_by": [f"s{b}" for b in blockers],
                }
            )
        return layout_from_dict(
            {"model": "random", "verification": "a test", "doors": [{"id": "d"}], "seats": seats}
        )

    return st.lists(st.lists(st.integers(0, 50), max_size=2), min_size=2, max_size=6).map(build)


def brute_force_minimum(problem: Problem, placed: dict[int, int]) -> int:
    """The true minimum, by trying every seating of the free passengers."""
    free = [p for p in range(problem.n) if p not in placed]
    taken = set(placed.values())
    open_seats = [s for s in problem.bookable if s not in taken]
    assign = [UNSEATED] * problem.n
    for p, s in placed.items():
        assign[p] = s
    best = None
    for seats in itertools.permutations(open_seats, len(free)):
        for p, s in zip(free, seats, strict=True):
            assign[p] = s
        count = len(problem.blocking_pairs(assign))
        if best is None or count < best:
            best = count
    assert best is not None
    return best


class TestRequiredProperties(unittest.TestCase):
    """The two properties the brief asks for by name."""

    @settings(max_examples=60, deadline=None)
    @given(st.sampled_from(sorted(LAYOUTS)), alight_lists, st.randoms(use_true_random=False))
    def test_optimised_is_never_worse_than_a_random_seating(self, name, alights, rng):
        layout = LAYOUTS[name]
        bookings = trip_of(alights)
        seat_ids = [seat.id for seat in layout.bookable_seats()]
        assume(len(bookings) <= len(seat_ids))
        random_seats = dict(
            zip((b.id for b in bookings), rng.sample(seat_ids, len(bookings)), strict=False)
        )
        random_count, _, _ = evaluate(layout, bookings, random_seats, CONFIG)
        allocation = allocate(layout, bookings, CONFIG)
        self.assertLessEqual(allocation.blocking_after, random_count)

    @settings(max_examples=60, deadline=None)
    @given(st.sampled_from(sorted(LAYOUTS)), alight_lists, st.randoms(use_true_random=False))
    def test_never_worse_than_random_with_passengers_already_seated(self, name, alights, rng):
        layout = LAYOUTS[name]
        bookings = trip_of(alights)
        seat_ids = [seat.id for seat in layout.bookable_seats()]
        assume(len(bookings) <= len(seat_ids))
        chosen = rng.sample(seat_ids, len(bookings))
        random_seats = dict(zip((b.id for b in bookings), chosen, strict=True))
        fixed = {b.id: FixedSeat(random_seats[b.id], FixedReason.BOARDED) for b in bookings[:2]}
        config = CONFIG.replace("weights", boarding_blocking=0)
        random_count, _, _ = evaluate(layout, bookings, random_seats, config, boarded=set(fixed))
        allocation = allocate(layout, bookings, config, fixed=fixed, boarded=set(fixed))
        self.assertLessEqual(allocation.blocking_after, random_count)

    @settings(max_examples=80, deadline=None)
    @given(st.integers(1, 12), st.lists(st.integers(1, 15), min_size=1, max_size=12))
    def test_zero_blocking_with_no_constraints_and_one_exit_path(self, seat_count, alights):
        assume(len(alights) <= seat_count)
        allocation = allocate(single_file(seat_count), trip_of(alights), CONFIG)
        self.assertEqual(allocation.blocking_after, 0)
        self.assertEqual(allocation.minimum_blocking, 0)


class TestTheorems(unittest.TestCase):
    @settings(max_examples=60, deadline=None)
    @given(st.sampled_from(sorted(LAYOUTS)), alight_lists)
    def test_sorted_seating_has_no_blocking_on_any_layout_without_constraints(self, name, alights):
        layout = LAYOUTS[name]
        bookings = trip_of(alights)
        assume(len(bookings) <= len(layout.bookable_seats()))
        problem = Problem(layout, bookings, CONFIG)
        self.assertEqual(problem.blocking_pairs(sorted_seating(problem, {})), [])

    @settings(max_examples=60, deadline=None)
    @given(
        st.permutations(range(6)),
        st.lists(st.integers(1, 9), min_size=6, max_size=6),
        st.integers(0, 2),
    )
    def test_exchange_argument_on_a_full_single_file(self, seats_for, alights, fixed_count):
        """Single file, every seat full, any passengers fixed: sorted is optimal."""
        layout = single_file(6)
        bookings = trip_of(alights)
        fixed = {
            f"p{p}": FixedSeat(str(seats_for[p] + 1), FixedReason.BOARDED)
            for p in range(fixed_count)
        }
        problem = Problem(layout, bookings, CONFIG, fixed=fixed, boarded=set(fixed))
        sorted_count = len(problem.blocking_pairs(sorted_seating(problem, problem.fixed)))
        self.assertEqual(sorted_count, brute_force_minimum(problem, problem.fixed))


class TestExactSearchAndBound(unittest.TestCase):
    @settings(max_examples=120, deadline=None)
    @given(
        poset_layouts(),
        st.lists(st.integers(1, 6), min_size=1, max_size=6),
        st.integers(0, 2),
        st.integers(0, 5),
    )
    def test_exact_search_matches_brute_force(self, layout, alights, fixed_count, offset):
        seat_ids = [seat.id for seat in layout.bookable_seats()]
        assume(len(alights) <= len(seat_ids))
        fixed_count = min(fixed_count, len(alights))
        bookings = trip_of(alights)
        fixed = {
            f"p{p}": FixedSeat(seat_ids[(p + offset) % len(seat_ids)], FixedReason.BOARDED)
            for p in range(fixed_count)
        }
        assume(len({seat.seat for seat in fixed.values()}) == len(fixed))
        problem = Problem(layout, bookings, CONFIG, fixed=fixed, boarded=set(fixed))
        truth = brute_force_minimum(problem, problem.fixed)
        # A loose starting bound makes the search find the answer itself.
        result = exact_min_blocking(problem, problem.fixed, truth + 1)
        self.assertTrue(result.finished)
        self.assertEqual(result.minimum, truth)
        self.assertIsNotNone(result.assign)
        self.assertEqual(len(problem.blocking_pairs(result.assign)), truth)
        # Told the true minimum as its bound, it proves nothing beats it.
        proof = exact_min_blocking(problem, problem.fixed, truth)
        self.assertEqual((proof.finished, proof.minimum), (True, truth))

    @settings(max_examples=120, deadline=None)
    @given(
        poset_layouts(),
        st.lists(st.integers(1, 6), min_size=1, max_size=6),
        st.integers(0, 2),
        st.integers(0, 5),
    )
    def test_lower_bound_never_exceeds_the_truth(self, layout, alights, fixed_count, offset):
        seat_ids = [seat.id for seat in layout.bookable_seats()]
        assume(len(alights) <= len(seat_ids))
        fixed_count = min(fixed_count, len(alights))
        bookings = trip_of(alights)
        fixed = {
            f"p{p}": FixedSeat(seat_ids[(p + offset) % len(seat_ids)], FixedReason.BOARDED)
            for p in range(fixed_count)
        }
        assume(len({seat.seat for seat in fixed.values()}) == len(fixed))
        problem = Problem(layout, bookings, CONFIG, fixed=fixed, boarded=set(fixed))
        self.assertLessEqual(
            blocking_lower_bound(problem, problem.fixed),
            brute_force_minimum(problem, problem.fixed),
        )

    @settings(max_examples=120, deadline=None)
    @given(
        poset_layouts(),
        st.lists(st.integers(1, 6), min_size=1, max_size=6),
        st.integers(0, 2),
        st.integers(0, 5),
    )
    def test_allocate_reaches_the_true_minimum_and_says_so(
        self, layout, alights, fixed_count, offset
    ):
        seat_ids = [seat.id for seat in layout.bookable_seats()]
        assume(len(alights) <= len(seat_ids))
        fixed_count = min(fixed_count, len(alights))
        bookings = trip_of(alights)
        fixed = {
            f"p{p}": FixedSeat(seat_ids[(p + offset) % len(seat_ids)], FixedReason.BOARDED)
            for p in range(fixed_count)
        }
        assume(len({seat.seat for seat in fixed.values()}) == len(fixed))
        # With boarding weighted at zero, nothing can be traded against blocking.
        config = CONFIG.replace("weights", boarding_blocking=0)
        problem = Problem(layout, bookings, config, fixed=fixed, boarded=set(fixed))
        truth = brute_force_minimum(problem, problem.fixed)
        allocation = allocate(layout, bookings, config, fixed=fixed, boarded=set(fixed))
        self.assertEqual(allocation.minimum_blocking, truth)
        self.assertEqual(allocation.blocking_after, truth)


class TestHungarian(unittest.TestCase):
    @settings(max_examples=150, deadline=None)
    @given(
        st.integers(1, 5).flatmap(
            lambda rows: st.integers(rows, 6).flatmap(
                lambda columns: st.lists(
                    st.lists(st.integers(-20, 50), min_size=columns, max_size=columns),
                    min_size=rows,
                    max_size=rows,
                )
            )
        )
    )
    def test_matches_brute_force(self, matrix):
        rows, columns = len(matrix), len(matrix[0])
        truth = min(
            sum(matrix[i][j] for i, j in enumerate(chosen))
            for chosen in itertools.permutations(range(columns), rows)
        )
        assignment, total = solve_assignment(matrix)
        self.assertEqual(total, truth)
        self.assertEqual(len(set(assignment)), rows)
        self.assertEqual(sum(matrix[i][j] for i, j in enumerate(assignment)), total)

    @settings(max_examples=50, deadline=None)
    @given(
        poset_layouts(),
        st.lists(st.integers(1, 6), min_size=1, max_size=6),
    )
    def test_linearised_seating_is_a_valid_seating(self, layout, alights):
        seats = layout.bookable_seats()
        assume(len(alights) <= len(seats))
        problem = Problem(layout, trip_of(alights), CONFIG)
        assign = hungarian_seating(problem, {})
        self.assertNotIn(UNSEATED, assign)
        self.assertEqual(len(set(assign)), len(assign))


class TestDefinitions(unittest.TestCase):
    @settings(max_examples=80, deadline=None)
    @given(
        st.lists(
            st.tuples(st.integers(0, 6), st.integers(1, 6)).map(lambda t: (t[0], t[0] + t[1])),
            min_size=1,
            max_size=6,
        ),
        st.randoms(use_true_random=False),
    )
    def test_blocking_count_matches_the_written_definition(self, rides, rng):
        """q is nearer the exit than p, both on board as p alights, and q alights later."""
        layout = single_file(6)
        bookings = [
            Booking(id=f"p{i}", board=board, alight=alight, booked_at=i)
            for i, (board, alight) in enumerate(rides)
        ]
        seats = rng.sample(range(1, 7), len(rides))
        seating = {f"p{i}": str(seat) for i, seat in enumerate(seats)}
        expected = sum(
            1
            for (i, (_, a_p)), (j, (b_q, a_q)) in itertools.permutations(enumerate(rides), 2)
            if seats[j] < seats[i] and b_q < a_p < a_q
        )
        count, _, pairs = evaluate(layout, bookings, seating, CONFIG)
        self.assertEqual(count, expected)
        self.assertEqual(len(pairs), expected)

    @settings(max_examples=40, deadline=None)
    @given(st.sampled_from(sorted(LAYOUTS)), alight_lists)
    def test_the_same_input_gives_the_same_seats(self, name, alights):
        layout = LAYOUTS[name]
        bookings = trip_of(alights)
        assume(len(bookings) <= len(layout.bookable_seats()))
        first = allocate(layout, bookings, CONFIG)
        second = allocate(layout, list(reversed(bookings)), CONFIG)
        self.assertEqual(first.seats, allocate(layout, bookings, CONFIG).seats)
        self.assertEqual(first.blocking_after, second.blocking_after)

    @settings(max_examples=60, deadline=None)
    @given(st.sampled_from(sorted(LAYOUTS)), alight_lists, st.randoms(use_true_random=False))
    def test_improve_never_makes_a_seating_worse(self, name, alights, rng):
        layout = LAYOUTS[name]
        bookings = trip_of(alights)
        seat_count = len(layout.bookable_seats())
        assume(len(bookings) <= seat_count)
        problem = Problem(layout, bookings, CONFIG)
        assign = rng.sample(problem.bookable, len(bookings))
        better = improve(problem, assign, list(range(problem.n)))
        self.assertLessEqual(problem.total_cost(better), problem.total_cost(assign))


if __name__ == "__main__":
    unittest.main()
