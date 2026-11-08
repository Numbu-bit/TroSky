"""Compare seating methods over many synthetic trips.

All trips are synthetic. Stops, destinations, occupancy, priority shares and group
sizes are assumptions, set in ``Scenario``. The results compare methods with each other;
they do not predict what real trips will show.
"""

from __future__ import annotations

import random
import statistics
import time
from collections.abc import Callable
from dataclasses import dataclass, field

from .allocator import allocate, solve
from .config import SeatConfig, load_config
from .layout import SeatLayout, layout_from_dict, minibus_variant, single_file, two_door_bus
from .model import UNSEATED, Booking, BookingError, FixedReason, FixedSeat, Problem
from .online import ZonePlan, build_zone_plan, choose_seat
from .solvers import hungarian_seating, sorted_seating


@dataclass(frozen=True)
class Scenario:
    name: str
    layout: Callable[[], SeatLayout]
    stops: tuple[int, int] = (5, 12)  # how many stops a route has [ASSUMPTION]
    occupancy: tuple[float, float] = (0.6, 1.0)  # booking requests per seat [ASSUMPTION]
    priority_share: float = 0.0  # chance a passenger has priority [ASSUMPTION]
    group_share: float = 0.0  # chance a booking is a group of 2 or 3 [ASSUMPTION]
    boarded_share: float = 0.0  # already seated somewhere, and cannot move [ASSUMPTION]
    multi_pickup: bool = False  # passengers may board along the route
    route_km_per_stop: float = 2.0  # [ASSUMPTION]


@dataclass
class MethodResult:
    counts: list[int] = field(default_factory=list)

    def summary(self) -> dict[str, float]:
        ordered = sorted(self.counts)
        return {
            "mean": round(statistics.fmean(ordered), 3) if ordered else 0.0,
            "p95": ordered[int(0.95 * (len(ordered) - 1))] if ordered else 0,
            "worst": ordered[-1] if ordered else 0,
            "zero_share": round(sum(1 for c in ordered if c == 0) / len(ordered), 3)
            if ordered
            else 0.0,
        }


def synthetic_bookings(rng: random.Random, scenario: Scenario, seats: int) -> list[Booking]:
    """One trip's bookings, in the order they were made."""
    stop_count = rng.randint(*scenario.stops)
    wanted = max(1, round(seats * rng.uniform(*scenario.occupancy)))
    bookings: list[Booking] = []
    on_board = [0] * stop_count  # riders between each stop and the next
    sequence = 0
    for _attempt in range(wanted):
        if len(bookings) >= wanted:
            break
        sequence += 1
        size = 1
        group = None
        if rng.random() < scenario.group_share:
            size = min(rng.randint(2, 3), wanted - len(bookings))
            group = f"g{sequence}" if size > 1 else None
        board_stop = 0
        if scenario.multi_pickup:
            board_stop = rng.randint(0, stop_count - 2)
        alight_stop = rng.randint(board_stop + 1, stop_count - 1)
        stretch = range(board_stop, alight_stop)
        # As in real booking, a request with no seat free on its stretch is refused.
        if size < 1 or any(on_board[stop] + size > seats for stop in stretch):
            continue
        for stop in stretch:
            on_board[stop] += size
        for member in range(size):
            category = "standard"
            if member == 0 and rng.random() < scenario.priority_share:
                category = rng.choice(("elderly", "pregnant", "disabled"))
            bookings.append(
                Booking(
                    id=f"p{len(bookings)}",
                    alight=alight_stop * scenario.route_km_per_stop,
                    board=board_stop * scenario.route_km_per_stop,
                    category=category,
                    group_id=group,
                    booked_at=sequence,
                )
            )
    return bookings


def _blocking(problem: Problem, assign: list[int]) -> int:
    return len(problem.blocking_pairs(assign))


def _random_seating(problem: Problem, placed: dict[int, int], rng: random.Random) -> list[int]:
    assign = [UNSEATED] * problem.n
    for p, s in placed.items():
        assign[p] = s
    for p in rng.sample(range(problem.n), problem.n):
        if p in placed or p in problem.unseated:
            continue
        options = [s for s in problem.domain[p] if problem.fits(p, s, assign)]
        if options:
            assign[p] = rng.choice(options)
    return assign


def _fixed_for_boarded(
    rng: random.Random, bookings: list[Booking], layout: SeatLayout, share: float
) -> dict[str, FixedSeat]:
    """Some passengers are already seated, anywhere, and may not move."""
    seats = [seat.id for seat in layout.bookable_seats()]
    rng.shuffle(seats)
    fixed = {}
    for booking in bookings:
        if seats and rng.random() < share:
            fixed[booking.id] = FixedSeat(seats.pop(), FixedReason.BOARDED)
    return fixed


def run_scenario(
    scenario: Scenario, config: SeatConfig, trips: int, seed: int
) -> dict[str, object]:
    """Seat ``trips`` synthetic trips by each method, under the same constraints."""
    rng = random.Random(seed)
    layout = scenario.layout()
    seats = len(layout.bookable_seats())
    results = {
        name: MethodResult()
        for name in ("random", "first_come", "greedy", "hungarian", "optimised")
    }
    exact_counts = MethodResult()
    proven = 0
    beaten_by_random = 0
    boarding = {"first_come": 0, "optimised": 0}
    unseated = 0
    started = time.perf_counter()
    worst_ms = 0.0
    for _ in range(trips):
        bookings = synthetic_bookings(rng, scenario, seats)
        fixed = (
            _fixed_for_boarded(rng, bookings, layout, scenario.boarded_share)
            if scenario.boarded_share
            else {}
        )
        try:
            problem = Problem(layout, bookings, config, fixed=fixed, boarded=set(fixed))
        except BookingError:
            continue
        one = time.perf_counter()
        outcome = solve(problem)
        worst_ms = max(worst_ms, (time.perf_counter() - one) * 1000)
        placed = {p: outcome.assign[p] for p in problem.fixed}
        for p in problem.constrained:
            if outcome.assign[p] != UNSEATED:
                placed[p] = outcome.assign[p]

        optimised = _blocking(problem, outcome.assign)
        random_count = _blocking(problem, _random_seating(problem, placed, rng))
        results["random"].counts.append(random_count)
        first_come = problem.first_come_seating()
        results["first_come"].counts.append(_blocking(problem, first_come))
        results["optimised"].counts.append(optimised)
        boarding["first_come"] += len(problem.boarding_pairs(first_come))
        boarding["optimised"] += len(problem.boarding_pairs(outcome.assign))
        unseated += sum(1 for s in outcome.assign if s == UNSEATED)
        if problem.single_pickup:
            results["greedy"].counts.append(_blocking(problem, sorted_seating(problem, placed)))
            results["hungarian"].counts.append(
                _blocking(problem, hungarian_seating(problem, placed))
            )
            if outcome.minimum is not None:
                proven += 1
                exact_counts.counts.append(outcome.minimum)
        else:
            results["greedy"].counts.append(outcome.methods.get("sorted", optimised))
            if outcome.minimum is not None:
                proven += 1
                exact_counts.counts.append(outcome.minimum)
        # Possible only by a trade the weights allow, such as one blocking pair to spare
        # six seated passengers standing up. So it is counted, and shown.
        beaten_by_random += optimised > random_count
    elapsed = time.perf_counter() - started
    measured = max(len(results["optimised"].counts), 1)
    return {
        "scenario": scenario.name,
        "layout": layout.model,
        "seats": seats,
        "trips": measured,
        "methods": {name: result.summary() for name, result in results.items() if result.counts},
        "proven_minimum_share": round(proven / measured, 3),
        "proven_minimum_mean": exact_counts.summary()["mean"],
        "trips_with_more_blocking_than_random": beaten_by_random,
        "boarding_blocks_mean": {
            name: round(total / measured, 3) for name, total in boarding.items()
        },
        "unseated_per_trip": round(unseated / measured, 3),
        "ms_per_trip_all_methods": round(elapsed * 1000 / measured, 1),
        "worst_solve_ms": round(worst_ms, 1),
    }


def run_online(
    config: SeatConfig, trips: int, seed: int, passengers_late: float
) -> dict[str, object]:
    """Passengers book one at a time on a 15-seat minibus.

    Compares first come, lowest added cost alone, lowest added cost with distance zones,
    and re-optimising until the lock with ``passengers_late`` of bookings after it.
    """
    rng = random.Random(seed)
    layout = minibus_variant(15)
    scenario = Scenario("online", lambda: layout, occupancy=(0.8, 1.0))
    seats = len(layout.bookable_seats())
    online = config.replace("assignment", mode="online")
    plain_config = online.replace("weights", seat_change=0)
    methods = {
        name: MethodResult() for name in ("first_come", "lowest_added", "with_zones", "reoptimised")
    }
    moves: list[int] = []
    for _ in range(trips):
        bookings = synthetic_bookings(rng, scenario, seats)
        rng.shuffle(bookings)
        bookings = [
            Booking(id=b.id, alight=b.alight, board=b.board, booked_at=i)
            for i, b in enumerate(bookings)
        ]
        route_km = max(b.alight for b in bookings)
        plan = build_zone_plan(layout, online, route_km=route_km)
        for name, zone_plan in (("lowest_added", None), ("with_zones", plan)):
            problem = Problem(layout, bookings, plain_config)
            assign = [UNSEATED] * problem.n
            for p in range(problem.n):
                assign[p] = choose_seat(problem, p, assign, zone_plan)
            methods[name].counts.append(len(problem.blocking_pairs(assign)))
        problem = Problem(layout, bookings, plain_config)
        methods["first_come"].counts.append(
            len(problem.blocking_pairs(problem.first_come_seating()))
        )
        count, changed = _reoptimised_trip(layout, online, bookings, plan, passengers_late)
        methods["reoptimised"].counts.append(count)
        moves.append(changed)
    return {
        "scenario": f"online, {round(passengers_late * 100)}% of bookings after the lock",
        "layout": layout.model,
        "trips": trips,
        "methods": {name: result.summary() for name, result in methods.items()},
        "mean_seat_changes_per_trip": round(statistics.fmean(moves), 2),
    }


def _reoptimised_trip(
    layout: SeatLayout,
    config: SeatConfig,
    bookings: list[Booking],
    plan: ZonePlan,
    passengers_late: float,
) -> tuple[int, int]:
    """Before the lock, each booking re-optimises everyone. After it, late bookings only
    take a free seat. Returns final blocking and how many times someone was moved."""
    late_from = len(bookings) - round(len(bookings) * passengers_late)
    seats: dict[str, str] = {}
    changes = 0
    for index, booking in enumerate(bookings):
        so_far = bookings[: index + 1]
        problem = Problem(
            layout,
            so_far,
            config,
            fixed={
                b.id: FixedSeat(seats[b.id], FixedReason.LOCKED) for b in so_far if b.id in seats
            },
        )
        assign = [UNSEATED] * problem.n
        for q, s in problem.fixed.items():
            assign[q] = s
        seat = choose_seat(problem, index, assign, plan)
        seats[booking.id] = problem.seats[seat].id
        if index < late_from:
            result = allocate(layout, so_far, config, current=seats)
            for name, new_seat in result.seats.items():
                if seats.get(name) != new_seat:
                    changes += 1
                seats[name] = new_seat
    final = Problem(
        layout,
        bookings,
        config,
        fixed={b.id: FixedSeat(seats[b.id], FixedReason.LOCKED) for b in bookings},
    )
    assign = [UNSEATED] * final.n
    for q, s in final.fixed.items():
        assign[q] = s
    return len(final.blocking_pairs(assign)), changes


def _minibus_with_side_door_priority_seats() -> SeatLayout:
    """The same minibus with priority seats at the side door instead of in the cab."""
    data = minibus_variant(15).to_dict()
    for seat in data["seats"]:
        if seat["id"] in ("F1", "F2"):
            seat["reserved_for"] = []
        if seat["id"] in ("A1", "A2"):
            seat["reserved_for"] = ["priority"]
    data["model"] = "minibus-15-side-door-priority"
    return layout_from_dict(data)


def default_scenarios() -> list[Scenario]:
    return [
        Scenario("Single file, 5 seats, no constraints", lambda: single_file(5), stops=(3, 8)),
        Scenario("Minibus, 15 seats, no constraints", lambda: minibus_variant(15)),
        Scenario(
            "Minibus, 15 seats, priority passengers and groups",
            lambda: minibus_variant(15),
            priority_share=0.15,
            group_share=0.2,
        ),
        Scenario(
            "Minibus, 15 seats, priority seats at the side door, not the cab",
            _minibus_with_side_door_priority_seats,
            priority_share=0.15,
            group_share=0.2,
        ),
        Scenario(
            "Minibus, 15 seats, a third already seated anywhere",
            lambda: minibus_variant(15),
            boarded_share=0.33,
        ),
        Scenario(
            "Bus, 30 seats, two doors, a third already seated anywhere",
            two_door_bus,
            boarded_share=0.33,
        ),
        Scenario(
            "Minibus, 15 seats, boarding along the route",
            lambda: minibus_variant(15),
            multi_pickup=True,
            occupancy=(0.8, 1.3),
        ),
        Scenario(
            "Minibus, 15 seats, boarding along the route, vehicle often full",
            lambda: minibus_variant(15),
            multi_pickup=True,
            occupancy=(1.6, 2.4),
            stops=(4, 7),
        ),
    ]


def run_all(trips: int, seed: int, online_trips: int | None = None) -> dict[str, object]:
    config = load_config()
    results: dict[str, object] = {
        "trips_per_scenario": trips,
        "seed": seed,
        "scenarios": [
            run_scenario(scenario, config, trips, seed + index)
            for index, scenario in enumerate(default_scenarios())
        ],
    }
    if online_trips is None:
        online_trips = min(trips, 500)
    results["online"] = [
        run_online(config, online_trips, seed + 100, 0.0),
        run_online(config, online_trips, seed + 101, 0.2),
    ]
    return results
