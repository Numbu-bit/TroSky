"""Allocate seats for a trip and say what could not be avoided, and why.

``allocate`` is the one entry point. It places fixed and constrained passengers
first, seats everyone else, and returns the seat map, the boarding order, the
blocking count before and after, and every constraint that forced blocking.
"""

from __future__ import annotations

from collections.abc import Iterable, Mapping
from dataclasses import dataclass
from decimal import Decimal

from .config import UNITS_PER_WEIGHT, SeatConfig
from .hungarian import InfeasibleAssignment
from .layout import SeatLayout
from .model import UNSEATED, Booking, FixedReason, FixedSeat, Problem
from .solvers import (
    blocking_lower_bound,
    exact_interval_blocking,
    exact_min_blocking,
    free_passengers,
    grouped_sorted_seating,
    hungarian_seating,
    improve,
    improve_chains,
    insertion_seating,
    sorted_seating,
)

# How the minimum blocking count was established.
PROOF_ZERO = "no blocking at all"
PROOF_BOUND = "matches a proven lower bound"
PROOF_EXCHANGE = "single-file seats, all full: the sorted order is optimal (exchange argument)"
PROOF_EXACT = "exact search"
PROOF_NONE = "not proven: the best seating found"


@dataclass(frozen=True)
class BlockingPair:
    passenger: str  # getting off
    seat: str
    blocker: str  # must move
    blocker_seat: str
    position: float  # where it happens along the route


@dataclass(frozen=True)
class ForcedBlocking:
    """One constraint and the blocking it causes."""

    constraint: str  # priority_seat, accessible_seat, boarded, locked, override
    passenger: str
    seat: str
    pairs: int
    reason: str
    other_seat: str | None = None  # the seat that would cost least instead
    pairs_in_other_seat: int | None = None


@dataclass(frozen=True)
class SplitGroup:
    group_id: str
    clusters: int
    reason: str


@dataclass(frozen=True)
class SeatUse:
    seat: str
    passenger: str
    board: float
    alight: float


@dataclass(frozen=True)
class Allocation:
    seats: dict[str, str]  # passenger id to seat id
    seat_map: tuple[SeatUse, ...]  # rearmost seat first
    boarding_order: tuple[str, ...]  # who to call, first to last
    alighting_order: tuple[tuple[float, tuple[str, ...]], ...]
    blocking_before: int
    blocking_after: int
    blocking_pairs: tuple[BlockingPair, ...]
    boarding_blocks: int
    minimum_blocking: int | None  # None: not proven
    lower_bound: int
    proof: str
    forced: tuple[ForcedBlocking, ...]
    split_groups: tuple[SplitGroup, ...]
    unseated: tuple[tuple[str, str], ...]
    warnings: tuple[str, ...]
    total_cost: Decimal
    method_blocking: dict[str, int]  # blocking from each method tried

    @property
    def zero_blocking_possible(self) -> bool | None:
        """True or False when known; None when the minimum is not proven."""
        if self.blocking_after == 0:
            return True
        if self.minimum_blocking is None:
            return None
        return self.minimum_blocking == 0

    @property
    def unavoidable_blocking(self) -> int | None:
        return self.minimum_blocking


@dataclass
class Outcome:
    assign: list[int]
    minimum: int | None
    lower_bound: int
    proof: str
    methods: dict[str, int]


def placed_assign(problem: Problem, placed: dict[int, int]) -> list[int]:
    assign = [UNSEATED] * problem.n
    for p, s in placed.items():
        assign[p] = s
    return assign


def _mappings(problem: Problem) -> tuple[list[dict[int, int]], bool]:
    """Every way to seat the constrained passengers in their allowed seats, the sorted
    one first. Returns them with True if the list is complete."""
    constrained = set(problem.constrained)
    people = [p for p in problem.order_far_first if p in constrained]
    limit = problem.config.search.max_constrained_mappings
    found: list[dict[int, int]] = []
    complete = True

    def walk(index: int, used: set[int], so_far: dict[int, int]) -> None:
        nonlocal complete
        if len(found) >= limit:
            complete = False
            return
        if index == len(people):
            found.append(dict(so_far))
            return
        p = people[index]
        for s in problem.domain[p]:
            if s in used:
                continue
            so_far[p] = s
            used.add(s)
            walk(index + 1, used, so_far)
            used.discard(s)
            del so_far[p]

    walk(0, set(problem.fixed.values()), dict(problem.fixed))
    if not found:  # not enough allowed seats for everyone: first booked, first served
        placed = dict(problem.fixed)
        used = set(placed.values())
        for p in sorted(
            people, key=lambda q: (problem.bookings[q].booked_at, problem.bookings[q].id)
        ):
            for s in problem.domain[p]:
                if s not in used:
                    placed[p] = s
                    used.add(s)
                    break
            else:
                problem.unseated[p] = (
                    "needs an accessible seat, and this vehicle has none free. "
                    "A person must arrange this trip."
                )
        found.append(placed)
    return found, complete


def _from_current(problem: Problem, placed: dict[int, int]) -> list[int]:
    """Keep people where they are, and add newcomers where they cost least."""
    assign = [UNSEATED] * problem.n
    for p, s in placed.items():
        assign[p] = s
    for p, booking in enumerate(problem.bookings):
        seat = problem.current.get(booking.id)
        if p in placed or p in problem.unseated or seat is None:
            continue
        s = problem.seat_index.get(seat)
        if s is not None and s in problem.domain[p] and problem.fits(p, s, assign):
            assign[p] = s
    still_free = [p for p in problem.order_far_first if assign[p] == UNSEATED]
    kept = {p: s for p, s in enumerate(assign) if s != UNSEATED}
    return insertion_seating(problem, kept, still_free)


def _best(problem: Problem, seatings: list[list[int]]) -> list[int]:
    def key(assign: list[int]) -> tuple[int, int, list[int]]:
        unseated = sum(1 for s in assign if s == UNSEATED)
        return (unseated, problem.total_cost(assign), assign)

    return min(seatings, key=key)


def _solve_mapping(
    problem: Problem, placed: dict[int, int], methods: dict[str, int]
) -> tuple[list[int], int | None, int, str]:
    movable = free_passengers(problem, placed)

    def blocking(assign: list[int]) -> int:
        return len(problem.blocking_pairs(assign))

    greedy = sorted_seating(problem, placed)
    methods.setdefault("sorted", blocking(greedy))
    candidates = [greedy]
    if any(len(members) > 1 for members in problem.groups.values()):
        candidates.append(grouped_sorted_seating(problem, placed))
    if problem.current:
        candidates.append(_from_current(problem, placed))

    if problem.total_cost(_best(problem, candidates)) == 0:
        best = _best(problem, candidates)
        methods.setdefault("hungarian", blocking(best))
        return best, 0, 0, PROOF_ZERO

    try:
        linearised = hungarian_seating(problem, placed)
    except InfeasibleAssignment:
        linearised = None
    if linearised is not None:
        methods.setdefault("hungarian", blocking(linearised))
        candidates.append(linearised)

    polished = [improve(problem, seating, movable) for seating in candidates]
    best = _best(problem, candidates + polished)
    fewest = min(blocking(seating) for seating in candidates + polished)
    if fewest == 0:
        return best, 0, 0, PROOF_ZERO

    bound = blocking_lower_bound(problem, placed)
    if fewest == bound:
        return best, fewest, bound, PROOF_BOUND
    open_seats = {s for p in movable for s in problem.domain[p]} - set(placed.values())
    if problem.layout.is_single_file() and len(movable) == len(open_seats):
        return best, fewest, bound, PROOF_EXCHANGE

    exact = exact_min_blocking(problem, placed, fewest)
    if not exact.finished:
        return best, None, bound, PROOF_NONE
    if exact.assign is not None:
        best = _best(problem, [best, improve(problem, exact.assign, movable)])
    return best, exact.minimum, exact.minimum if exact.minimum is not None else bound, PROOF_EXACT


def _solve_single_pickup(problem: Problem) -> Outcome:
    nobody_constrained = not problem.fixed and not problem.constrained
    wants_seat = problem.n == 1 and not problem.bookings[0].seat_preference
    if nobody_constrained and wants_seat and problem.config.assignment.single_passenger_near_driver:
        # Any seat has zero blocking, and a lone passenger is safer near the driver.
        near = [s for s in problem.domain[0] if problem.seats[s].near_driver]
        if near:
            seat = max(near)  # the highest index is the frontmost
            assign = [seat]
            return Outcome(assign, 0, 0, PROOF_ZERO, {"sorted": 0, "hungarian": 0})

    mappings, complete = _mappings(problem)
    methods: dict[str, int] = {}
    best: list[int] | None = None
    best_cost: tuple[int, int] | None = None
    minimum: int | None = None
    lower_bound: int | None = None
    proof = PROOF_ZERO
    all_proven = complete
    for placed in mappings:
        bound_here = blocking_lower_bound(problem, placed) if len(mappings) > 1 else 0
        if minimum is not None and bound_here >= minimum and best is not None:
            # This seating of the constrained passengers cannot have less blocking.
            lower_bound = min(lower_bound if lower_bound is not None else bound_here, bound_here)
            continue
        assign, minimum_here, bound, proof_here = _solve_mapping(problem, placed, methods)
        cost = (sum(1 for s in assign if s == UNSEATED), problem.total_cost(assign))
        if best is None or best_cost is None or cost < best_cost:
            best, best_cost = assign, cost
        lower_bound = bound if lower_bound is None else min(lower_bound, bound)
        if minimum_here is None:
            all_proven = False
        elif minimum is None or minimum_here < minimum:
            minimum, proof = minimum_here, proof_here
    assert best is not None  # at least one mapping always exists
    if not all_proven:
        return Outcome(best, None, lower_bound or 0, PROOF_NONE, methods)
    return Outcome(best, minimum, lower_bound or 0, proof, methods)


def _seating_orders(problem: Problem, free: list[int]) -> list[list[int]]:
    """The orders to try seating people in when several pickups share the vehicle.

    Boarding order comes first because, with nothing constrained, it always seats everyone
    when no stretch has more riders than seats: all those seated so far have boarded, so
    any seat free at this rider's boarding stop stays free for their whole stretch. No
    order blocks least on every trip, so the others are tried as well.
    """
    a, b, tie = problem.a, problem.b, problem.tie_key
    return [
        sorted(free, key=lambda p: (b[p], -a[p], tie[p])),
        sorted(free, key=lambda p: (-a[p], b[p], tie[p])),
        sorted(free, key=lambda p: (b[p], a[p], tie[p])),
    ]


def _polish_intervals(problem: Problem, assign: list[int], movable: list[int]) -> list[int]:
    """Alternate single moves and chain exchanges until neither lowers the cost."""
    current = improve(problem, assign, movable)
    while True:
        before = problem.total_cost(current)
        current = improve(problem, improve_chains(problem, current, movable), movable)
        if problem.total_cost(current) >= before:
            return current


def _solve_intervals(problem: Problem) -> Outcome:
    """Several pickups: seats can be shared by stretches that do not overlap."""

    def blocking(assign: list[int]) -> int:
        return len(problem.blocking_pairs(assign))

    placed = dict(problem.fixed)
    constrained = set(problem.constrained)
    order = [p for p in problem.order_far_first if p in constrained]
    first = insertion_seating(problem, placed, order)
    for p in order:
        if first[p] != UNSEATED:
            placed[p] = first[p]
    free = [p for p in range(problem.n) if p not in placed]
    starts = [insertion_seating(problem, placed, seq) for seq in _seating_orders(problem, free)]
    if problem.current:
        starts.append(_from_current(problem, placed))
    movable = [p for p in range(problem.n) if p not in problem.fixed]
    candidates = starts + [_polish_intervals(problem, start, movable) for start in starts]
    best = _best(problem, candidates)
    methods = {"sorted": blocking(starts[0])}
    fewest_unseated = sum(1 for s in best if s == UNSEATED)
    count = min(
        blocking(seating)
        for seating in candidates
        if sum(1 for s in seating if s == UNSEATED) == fewest_unseated
    )
    if count == 0:
        return Outcome(best, 0, 0, PROOF_ZERO, methods)
    exact = exact_interval_blocking(problem, dict(problem.fixed), best, count)
    if not exact.finished:
        return Outcome(best, None, 0, PROOF_NONE, methods)
    if exact.assign is not None:
        best = _best(problem, [best, improve(problem, exact.assign, movable)])
    return Outcome(best, exact.minimum, exact.minimum or 0, PROOF_EXACT, methods)


def solve(problem: Problem) -> Outcome:
    if problem.n == 0:
        return Outcome([], 0, 0, PROOF_ZERO, {})
    return _solve_single_pickup(problem) if problem.single_pickup else _solve_intervals(problem)


# ------------------------------------------------------------------------ reporting


def _constraint_of(problem: Problem, p: int, placed_by_rule: set[int]) -> str | None:
    booking = problem.bookings[p]
    fixed = problem.fixed_input.get(booking.id)
    if fixed is not None:
        return str(fixed.reason)
    if p in placed_by_rule:
        return "accessible_seat" if booking.needs_accessible else "priority_seat"
    return None


_CONSTRAINT_WORDS = {
    "priority_seat": "a seat kept for priority passengers",
    "accessible_seat": "an accessible seat",
    "boarded": "already on board",
    "locked": "seats are locked for departure",
    "override": "the seat they chose",
}


def _least_costly_other_seat(
    problem: Problem, p: int, assign: list[int]
) -> tuple[str | None, int | None]:
    """If this one passenger sat elsewhere, with the others re-sorted, what is the
    fewest blocking pairs? Shown for information: the seat may not suit them."""
    placed = {q: assign[q] for q in problem.fixed if q != p}
    for q in problem.constrained:
        if q != p and assign[q] != UNSEATED:
            placed[q] = assign[q]
    around = placed_assign(problem, placed)
    options = problem.domain[p] if problem.bookings[p].needs_accessible else problem.bookable
    best: tuple[int, int, str] | None = None
    for s in options:
        if s == assign[p] or not problem.fits(p, s, around):
            continue
        trial = sorted_seating(problem, {**placed, p: s})
        key = (len(problem.blocking_pairs(trial)), problem.seats[s].depth_rank, problem.seats[s].id)
        if best is None or key < best:
            best = key
    return (best[2], best[0]) if best else (None, None)


def _forced(
    problem: Problem, assign: list[int], pairs: list[tuple[int, int]]
) -> tuple[ForcedBlocking, ...]:
    placed_by_rule = set(problem.constrained)
    found = []
    for p in sorted(set(problem.fixed) | placed_by_rule, key=lambda q: problem.bookings[q].id):
        if assign[p] == UNSEATED:
            continue
        kind = _constraint_of(problem, p, placed_by_rule)
        if kind is None:
            continue
        in_way_of = [x for x, y in pairs if y == p]
        behind_others = [y for x, y in pairs if x == p]
        if not in_way_of and not behind_others:
            continue
        booking = problem.bookings[p]
        seat = problem.seats[assign[p]].id
        words = [f"{booking.id} keeps seat {seat} ({_CONSTRAINT_WORDS[kind]})."]
        if in_way_of:
            count = len(in_way_of)
            people = "passenger" if count == 1 else "passengers"
            words.append(
                f"They get off after {count} {people} seated behind them, "
                f"who must each get them to move."
            )
        if behind_others:
            count = len(behind_others)
            people = "passenger" if count == 1 else "passengers"
            words.append(f"{count} {people} in front of them get off later and must move for them.")
        other_seat, other_pairs = (None, None)
        if kind in ("priority_seat", "accessible_seat", "override"):
            other_seat, other_pairs = _least_costly_other_seat(problem, p, assign)
        found.append(
            ForcedBlocking(
                constraint=kind,
                passenger=booking.id,
                seat=seat,
                pairs=len(in_way_of) + len(behind_others),
                reason=" ".join(words),
                other_seat=other_seat,
                pairs_in_other_seat=other_pairs,
            )
        )
    return tuple(found)


def _split_groups(problem: Problem, assign: list[int]) -> tuple[SplitGroup, ...]:
    found = []
    for name, members in sorted(problem.groups.items()):
        seats = [assign[p] for p in members if assign[p] != UNSEATED]
        if len(seats) < 2:
            continue
        clusters = problem.components(set(seats))
        if clusters > 1:
            same_stop = len({problem.a[p] for p in members}) == 1
            reason = (
                "No adjacent seats were free for the whole group."
                if same_stop
                else "They get off at different stops, and sitting together would add blocking."
            )
            found.append(SplitGroup(name, clusters, reason))
    return tuple(found)


def _report(problem: Problem, outcome: Outcome) -> Allocation:
    assign = outcome.assign
    unseated = dict(problem.unseated)
    for p, s in enumerate(assign):
        if s == UNSEATED and p not in unseated:
            unseated[p] = "no free seat for this stretch of the route."
    pairs = problem.blocking_pairs(assign)
    bookings, seats = problem.bookings, problem.seats

    if problem.current:
        before_assign = [
            problem.seat_index.get(problem.current.get(b.id, ""), UNSEATED) for b in bookings
        ]
        for p, s in problem.fixed.items():
            if before_assign[p] == UNSEATED:
                before_assign[p] = s
    else:
        before_assign = problem.first_come_seating()
    seated = [p for p, s in enumerate(assign) if s != UNSEATED]
    seat_map = tuple(
        SeatUse(seats[assign[p]].id, bookings[p].id, bookings[p].board, bookings[p].alight)
        for p in sorted(seated, key=lambda q: (assign[q], problem.b[q]))
    )
    to_call = [p for p in seated if bookings[p].id not in problem.boarded]
    boarding_order = tuple(
        bookings[p].id
        for p in sorted(to_call, key=lambda q: (problem.b[q], assign[q], problem.tie_key[q]))
    )
    stops: dict[int, list[int]] = {}
    for p in seated:
        stops.setdefault(problem.a[p], []).append(p)
    alighting = tuple(
        (bookings[members[0]].alight, tuple(bookings[p].id for p in members))
        for _, members in sorted(stops.items())
    )
    methods = dict(outcome.methods)
    methods["optimised"] = len(pairs)
    warnings = list(problem.warnings)
    if outcome.minimum is not None and len(pairs) > outcome.minimum:
        warnings.append(
            f"{len(pairs) - outcome.minimum} blocking pair(s) above the minimum were accepted "
            "to honour a softer rule, such as a child sitting with their adult."
        )
    return Allocation(
        seats={bookings[p].id: seats[assign[p]].id for p in seated},
        seat_map=seat_map,
        boarding_order=boarding_order,
        alighting_order=alighting,
        blocking_before=len(problem.blocking_pairs(before_assign)),
        blocking_after=len(pairs),
        blocking_pairs=tuple(
            BlockingPair(
                bookings[p].id,
                seats[assign[p]].id,
                bookings[q].id,
                seats[assign[q]].id,
                bookings[p].alight,
            )
            for p, q in pairs
        ),
        boarding_blocks=len(problem.boarding_pairs(assign)),
        minimum_blocking=outcome.minimum,
        lower_bound=outcome.lower_bound,
        proof=outcome.proof,
        forced=_forced(problem, assign, pairs),
        split_groups=_split_groups(problem, assign),
        unseated=tuple((bookings[p].id, reason) for p, reason in sorted(unseated.items())),
        warnings=tuple(warnings),
        total_cost=Decimal(problem.total_cost(assign)) / UNITS_PER_WEIGHT,
        method_blocking=methods,
    )


def allocate(
    layout: SeatLayout,
    bookings: Iterable[Booking],
    config: SeatConfig,
    *,
    fixed: Mapping[str, FixedSeat] | None = None,
    current: Mapping[str, str] | None = None,
    boarded: Iterable[str] = (),
    hold_reserved: bool = False,
) -> Allocation:
    """Seat a trip.

    ``fixed``: passengers who may not move, and why.
    ``current``: seats people have already been told, so needless moves cost a little.
    ``boarded``: passengers on board. Pass them in ``fixed`` with reason BOARDED too.
    ``hold_reserved``: keep priority seats back for later bookings while there is room.
    """
    problem = Problem(
        layout,
        list(bookings),
        config,
        fixed=fixed,
        current=current,
        boarded=boarded,
        hold_reserved=hold_reserved,
    )
    return _report(problem, solve(problem))


def evaluate(
    layout: SeatLayout,
    bookings: Iterable[Booking],
    seats: Mapping[str, str],
    config: SeatConfig,
    *,
    boarded: Iterable[str] = (),
) -> tuple[int, int, list[BlockingPair]]:
    """Blocking pairs and boarding blocks for a seating as it stands."""
    bookings = list(bookings)
    problem = Problem(
        layout,
        bookings,
        config,
        fixed={b.id: FixedSeat(seats[b.id], FixedReason.LOCKED) for b in bookings if b.id in seats},
        boarded=boarded,
    )
    assign = placed_assign(problem, problem.fixed)
    pairs = problem.blocking_pairs(assign)
    return (
        len(pairs),
        len(problem.boarding_pairs(assign)),
        [
            BlockingPair(
                problem.bookings[p].id,
                problem.seats[assign[p]].id,
                problem.bookings[q].id,
                problem.seats[assign[q]].id,
                problem.bookings[p].alight,
            )
            for p, q in pairs
        ],
    )
