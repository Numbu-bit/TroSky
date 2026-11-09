"""The solvers. Each takes the passengers already placed and seats the rest.

Why there are several: the blocking objective depends on two seats at once, so it
is a quadratic assignment problem. The Hungarian method solves linear costs exactly,
but here it can only optimise a linear stand-in. So the engine:

1. seats people by the sorted rule, which is optimal when nothing is constrained;
2. solves the linearised problem with the Hungarian method, which also gives a proven
   lower bound on blocking;
3. improves any seating with swaps and moves, judged on the true objective, adding
   exchanges of whole chains of riders when seats are shared along the route;
4. when the bound and the best seating still differ, proves the minimum with an
   exact search over sets of seats, while the trip is small enough.
"""

from __future__ import annotations

import itertools
from dataclasses import dataclass

from .hungarian import solve_assignment
from .model import UNSEATED, Problem


def _empty_assignment(problem: Problem, placed: dict[int, int]) -> list[int]:
    assign = [UNSEATED] * problem.n
    for p, s in placed.items():
        assign[p] = s
    return assign


def free_passengers(problem: Problem, placed: dict[int, int]) -> list[int]:
    return [p for p in range(problem.n) if p not in placed and p not in problem.unseated]


def free_seats(problem: Problem, placed: dict[int, int], passengers: list[int]) -> list[int]:
    """The seats still open to these passengers, rearmost first."""
    taken = set(placed.values())
    open_seats: set[int] = set()
    for p in passengers:
        open_seats.update(problem.domain[p])
    return sorted(open_seats - taken)


# ---------------------------------------------------------------- the sorted rule


def sorted_seating(problem: Problem, placed: dict[int, int]) -> list[int]:
    """Farthest passenger to the rearmost free seat, and so on towards the front."""
    assign = _empty_assignment(problem, placed)
    for p in problem.order_far_first:
        if p in placed or p in problem.unseated:
            continue
        for s in problem.domain[p]:
            if problem.fits(p, s, assign):
                assign[p] = s
                break
    return assign


def grouped_sorted_seating(problem: Problem, placed: dict[int, int]) -> list[int]:
    """The sorted rule, keeping people who travel together and get off together as one
    block. Single swaps move one person at a time, so they cannot walk a family down
    the vehicle; starting from here spares them having to."""
    assign = _empty_assignment(problem, placed)

    def room_from(seat: int, wanted: int, taken: set[int]) -> bool:
        """Can ``wanted`` connected free seats be found starting here?"""
        seen = {seat}
        frontier = [seat]
        while frontier and len(seen) < wanted:
            current = frontier.pop()
            for other in problem.bookable:
                if (
                    problem.neighbour_mask[current] >> other & 1
                    and other not in seen
                    and other not in taken
                ):
                    seen.add(other)
                    frontier.append(other)
        return len(seen) >= wanted

    for p in problem.order_far_first:
        if p in placed or p in problem.unseated:
            continue
        together = [
            q
            for q in problem.groups.get(problem.bookings[p].group_id or "", ())
            if q != p and problem.a[q] == problem.a[p]
        ]
        options = [s for s in problem.domain[p] if problem.fits(p, s, assign)]
        if not options:
            continue
        beside = 0
        for q in together:
            if assign[q] != UNSEATED:
                beside |= problem.neighbour_mask[assign[q]]
        next_to_group = [s for s in options if beside >> s & 1]
        if next_to_group:
            assign[p] = next_to_group[0]
            continue
        waiting = sum(1 for q in together if assign[q] == UNSEATED and q not in placed)
        if waiting:
            taken = {s for s in assign if s != UNSEATED}
            roomy = [s for s in options if room_from(s, waiting + 1, taken)]
            if roomy:
                assign[p] = roomy[0]
                continue
        assign[p] = options[0]
    return assign


def insertion_seating(problem: Problem, placed: dict[int, int], order: list[int]) -> list[int]:
    """Seat passengers one at a time in the seat that adds the least cost right now."""
    assign = _empty_assignment(problem, placed)
    span = max(problem.a, default=1) - min(problem.b, default=0) or 1
    start = min(problem.b, default=0)
    deepest = max((seat.depth_rank for seat in problem.seats), default=1)
    for p in order:
        if p in placed or p in problem.unseated:
            continue
        best: tuple | None = None
        for s in problem.domain[p]:
            if not problem.fits(p, s, assign):
                continue
            added = problem.pair_cost_of(p, s, assign) + problem.linear[p][s]
            # Among equal costs, aim for a depth in proportion to how far they go.
            aim = abs(problem.seats[s].depth_rank / deepest - (problem.a[p] - start) / span)
            key = (added, aim, s)
            if best is None or key < best:
                best = key
        if best is not None:
            assign[p] = best[2]
    return assign


# -------------------------------------------------------- linearising the problem


def _gilmore_lawler(
    problem: Problem, passengers: list[int], seats: list[int]
) -> dict[tuple[int, int], int]:
    """A lower bound on how many blocking pairs p takes part in if seated in s.

    If s has more seats in its path than there are empty seats plus passengers
    getting off no later than p, the extra ones must hold someone who gets off after
    p, and each of those is a blocking pair. The same reasoning applies to the seats
    behind s. Summed over everyone this counts each pair twice, which the caller
    allows for. It is the Gilmore-Lawler idea for bounding a quadratic assignment.
    """
    empties = len(seats) - len(passengers)
    blocks, a = problem.blocks, problem.a
    in_path = {s: sum(blocks[s][t] for t in seats) for s in seats}
    behind = {s: sum(blocks[t][s] for t in seats) for s in seats}
    bound = {}
    for p in passengers:
        not_later = sum(1 for q in passengers if q != p and a[q] <= a[p])
        not_earlier = sum(1 for q in passengers if q != p and a[q] >= a[p])
        for s in seats:
            bound[p, s] = max(0, in_path[s] - empties - not_later) + max(
                0, behind[s] - empties - not_earlier
            )
    return bound


def hungarian_seating(problem: Problem, placed: dict[int, int]) -> list[int]:
    """Solve the linearised cost with the Hungarian method. All costs are doubled to
    keep the halved pair counts whole, and scaled so that closeness to the sorted
    order only ever breaks ties."""
    passengers = free_passengers(problem, placed)
    assign = _empty_assignment(problem, placed)
    if not passengers:
        return assign
    seats = free_seats(problem, placed, passengers)
    bound = _gilmore_lawler(problem, passengers, seats)
    seating = set(passengers)
    rank = {p: i for i, p in enumerate(q for q in problem.order_far_first if q in seating)}
    scale = len(passengers) * len(seats) + 1
    weight = problem.config.weights.blocking
    flow, blocks = problem.flow, problem.blocks
    cost: list[list[int | None]] = []
    for p in passengers:
        allowed = set(problem.domain[p])
        line: list[int | None] = []
        for position, s in enumerate(seats):
            if s not in allowed:
                line.append(None)
                continue
            against_placed = sum(
                flow[p][q] * blocks[s][t] + flow[q][p] * blocks[t][s] for q, t in placed.items()
            )
            base = 2 * (against_placed + problem.linear[p][s]) + weight * bound[p, s]
            line.append(base * scale + abs(position - rank[p]))
        cost.append(line)
    columns, _ = solve_assignment(cost)
    for row, column in enumerate(columns):
        assign[passengers[row]] = seats[column]
    return assign


def blocking_lower_bound(problem: Problem, placed: dict[int, int]) -> int:
    """No seating with these people placed can have fewer blocking pairs than this."""
    passengers = free_passengers(problem, placed)
    blocking, blocks = problem.blocking, problem.blocks
    constant = sum(
        1
        for p, s in placed.items()
        for q, t in placed.items()
        if p != q and blocking[p][q] and blocks[s][t]
    )
    if not passengers:
        return constant
    seats = free_seats(problem, placed, passengers)
    bound = _gilmore_lawler(problem, passengers, seats)
    cost: list[list[int | None]] = []
    for p in passengers:
        allowed = set(problem.domain[p])
        line: list[int | None] = []
        for s in seats:
            if s not in allowed:
                line.append(None)
                continue
            against_placed = sum(
                (1 if blocking[p][q] and blocks[s][t] else 0)
                + (1 if blocking[q][p] and blocks[t][s] else 0)
                for q, t in placed.items()
            )
            line.append(2 * against_placed + bound[p, s])
        cost.append(line)
    _, total = solve_assignment(cost)
    return constant + (total + 1) // 2  # the bound counted pairs twice; round up


# ------------------------------------------------------------------- local search


def improve(problem: Problem, assign: list[int], movable: list[int]) -> list[int]:
    """Moves and swaps, judged on the true objective, until none helps."""
    assign = list(assign)
    linear, flow, blocks = problem.linear, problem.flow, problem.blocks
    domains = [set(domain) for domain in problem.domain]

    def soft_of(*passengers: int) -> int:
        indexes = {i for p in passengers for i in problem.soft_of[p]}
        return sum(problem.term_cost(problem.soft_terms[i], assign) for i in indexes)

    for _sweep in range(problem.config.search.local_search_max_sweeps):
        improved = False
        for p in movable:
            here = assign[p]
            if here == UNSEATED:
                continue
            best_gain = 0
            best_move: tuple[int, int] | None = None  # (seat, swap partner or UNSEATED)
            base_p = problem.pair_cost_of(p, here, assign) + linear[p][here]
            soft_before_p = soft_of(p)

            for s in problem.domain[p]:
                if s == here or not problem.fits(p, s, assign):
                    continue
                assign[p] = s
                after = problem.pair_cost_of(p, s, assign) + linear[p][s] + soft_of(p)
                assign[p] = here
                gain = base_p + soft_before_p - after
                if gain > best_gain:
                    best_gain, best_move = gain, (s, UNSEATED)

            for q in movable:
                there = assign[q]
                if q == p or there in (UNSEATED, here):
                    continue
                if here not in domains[q] or there not in domains[p]:
                    continue
                if not problem.fits(p, there, assign, ignore=q):
                    continue
                if not problem.fits(q, here, assign, ignore=p):
                    continue
                cross_before = flow[p][q] * blocks[here][there] + flow[q][p] * blocks[there][here]
                before = (
                    base_p
                    + problem.pair_cost_of(q, there, assign)
                    + linear[q][there]
                    - cross_before
                    + soft_of(p, q)
                )
                assign[p], assign[q] = there, here
                cross_after = flow[p][q] * blocks[there][here] + flow[q][p] * blocks[here][there]
                after = (
                    problem.pair_cost_of(p, there, assign)
                    + linear[p][there]
                    + problem.pair_cost_of(q, here, assign)
                    + linear[q][here]
                    - cross_after
                    + soft_of(p, q)
                )
                assign[p], assign[q] = here, there
                gain = before - after
                if gain > best_gain:
                    best_gain, best_move = gain, (there, q)

            if best_move is not None:
                seat, partner = best_move
                if partner != UNSEATED:
                    assign[partner] = here
                assign[p] = seat
                improved = True
        if not improved:
            break
    return assign


def improve_chains(problem: Problem, assign: list[int], movable: list[int]) -> list[int]:
    """Exchange chains of riders between two seats, judged on the true objective.

    With several pickups a seat holds a succession of riders, and on a full vehicle one
    rider rarely fits anywhere else: every other seat holds someone overlapping them. So
    take everyone on two seats and link those whose stretches overlap. Exchanging the seats
    of one connected chain is always legal, because nobody in it overlaps anyone it leaves
    behind. Graph colouring calls this a Kempe chain.
    """
    assign = list(assign)
    overlap, flow, blocks, linear = problem.overlap, problem.flow, problem.blocks, problem.linear
    domains = [set(domain) for domain in problem.domain]
    can_move = set(movable)

    def chain_cost(chain: list[int]) -> int:
        total = sum(
            problem.pair_cost_of(p, assign[p], assign) + linear[p][assign[p]] for p in chain
        )
        for p, q in itertools.combinations(chain, 2):  # counted once from each side above
            s, t = assign[p], assign[q]
            total -= flow[p][q] * blocks[s][t] + flow[q][p] * blocks[t][s]
        terms = {i for p in chain for i in problem.soft_of[p]}
        return total + sum(problem.term_cost(problem.soft_terms[i], assign) for i in terms)

    def chains_of(riders: list[int]) -> list[list[int]]:
        seen: set[int] = set()
        found = []
        for first in riders:
            if first in seen:
                continue
            seen.add(first)
            chain, frontier = [first], [first]
            while frontier:
                x = frontier.pop()
                for y in riders:
                    if y not in seen and overlap[x][y]:
                        seen.add(y)
                        chain.append(y)
                        frontier.append(y)
            found.append(chain)
        return found

    for _sweep in range(problem.config.search.local_search_max_sweeps):
        improved = False
        for s, t in itertools.combinations(problem.bookable, 2):
            riders = [p for p, seat in enumerate(assign) if seat in (s, t)]
            for chain in chains_of(riders):
                other = {p: (t if assign[p] == s else s) for p in chain}
                if any(p not in can_move or other[p] not in domains[p] for p in chain):
                    continue
                before = chain_cost(chain)
                back = {p: assign[p] for p in chain}
                for p, seat in other.items():
                    assign[p] = seat
                if chain_cost(chain) < before:
                    improved = True
                else:
                    for p, seat in back.items():
                        assign[p] = seat
        if not improved:
            break
    return assign


# ------------------------------------------------------------------- exact search


@dataclass(frozen=True)
class ExactResult:
    finished: bool  # False: ran out of budget, so nothing is proven
    minimum: int | None  # the proven lowest blocking count
    assign: list[int] | None  # a seating reaching it; None when nothing beat the bound given


def exact_min_blocking(problem: Problem, placed: dict[int, int], upper_bound: int) -> ExactResult:
    """The true minimum of blocking pairs, with these people placed. One pickup only.

    Take passengers in the order they get off. Whether a new passenger's seat blocks
    someone earlier depends only on which seats are already filled, not on who sits
    in them, so the state is a set of seats: O(2^seats x seats) at worst. Passengers
    getting off at one stop may be placed in any order, which lets the search avoid
    counting them as blocking each other. Only strictly better seatings than
    ``upper_bound`` are kept, which prunes most of the search.
    """
    passengers = free_passengers(problem, placed)
    seats = free_seats(problem, placed, passengers)
    all_seats = sorted(set(seats) | set(placed.values()))
    if len(all_seats) > problem.config.search.exact_max_seats:
        return ExactResult(False, None, None)
    bit = {s: 1 << i for i, s in enumerate(all_seats)}
    blocks = problem.blocks
    # blocks_mask[t]: the seats that a passenger in t is in the way of.
    blocks_mask = {t: sum(bit[s] for s in all_seats if blocks[s][t]) for t in all_seats}
    free_mask = sum(bit[s] for s in seats)
    seat_of_bit = {bit[s]: s for s in all_seats}

    by_stop: dict[int, list[int]] = {}
    for p in [*placed, *passengers]:
        by_stop.setdefault(problem.a[p], []).append(p)
    stops = sorted(by_stop)

    budget = problem.config.search.exact_max_states
    layer = {0: 0}
    parents: list[dict[int, int]] = []
    states = 0
    for stop in stops:
        members = by_stop[stop]
        fixed_here = sum(bit[placed[p]] for p in members if p in placed)
        for step in range(len(members)):
            remaining = len(members) - step
            next_layer: dict[int, int] = {}
            parent: dict[int, int] = {}
            for mask, cost in layer.items():
                must = fixed_here & ~mask
                choices = must if must.bit_count() == remaining else (free_mask & ~mask) | must
                while choices:
                    choice = choices & -choices
                    choices ^= choice
                    added = cost + (mask & blocks_mask[seat_of_bit[choice]]).bit_count()
                    if added >= upper_bound:
                        continue
                    new_mask = mask | choice
                    if added < next_layer.get(new_mask, upper_bound):
                        next_layer[new_mask] = added
                        parent[new_mask] = mask
                        states += 1
                        if states > budget:
                            return ExactResult(False, None, None)
            layer = next_layer
            parents.append(parent)
            if not layer:
                # Nothing beats the bound, so the bound is the minimum.
                return ExactResult(True, upper_bound, None)

    minimum = min(layer.values())
    mask = min(mask for mask, cost in layer.items() if cost == minimum)
    # Walk back, then give each stop's free passengers that stop's free seats.
    trail = [mask]
    for parent in reversed(parents):
        mask = parent[mask]
        trail.append(mask)
    trail.reverse()
    assign = _empty_assignment(problem, placed)
    step = 0
    for stop in stops:
        members = by_stop[stop]
        filled = trail[step + len(members)] & ~trail[step]
        step += len(members)
        stop_seats = []
        while filled:
            choice = filled & -filled
            filled ^= choice
            seat = seat_of_bit[choice]
            if seat not in placed.values():
                stop_seats.append(seat)
        stop_seats.sort()
        free_here = sorted(
            (p for p in members if p not in placed), key=lambda p: problem.tie_key[p]
        )
        for p, seat in zip(free_here, stop_seats, strict=True):
            assign[p] = seat
    return ExactResult(True, minimum, assign)


def exact_interval_blocking(
    problem: Problem, placed: dict[int, int], assign: list[int], upper_bound: int
) -> ExactResult:
    """Branch and bound for trips with several pickups, within a work budget.

    Seats may be shared by passengers whose stretches do not overlap, so the set of
    seats no longer sums up the past, and this search is far less powerful than the
    one above. It proves small cases; on larger ones it runs out of budget and says so.
    """
    seated = [p for p in range(problem.n) if assign[p] != UNSEATED and p not in placed]
    order = sorted(seated, key=lambda p: (problem.b[p], -problem.a[p]))
    budget = problem.config.search.interval_max_nodes
    blocking, blocks, overlap = problem.blocking, problem.blocks, problem.overlap
    best = upper_bound
    best_assign: list[int] | None = None
    current = _empty_assignment(problem, placed)
    start = sum(
        1
        for p, s in placed.items()
        for q, t in placed.items()
        if p != q and blocking[p][q] and blocks[s][t]
    )
    nodes = 0
    placed_list = list(placed)

    def search(depth: int, cost: int, done: list[int]) -> bool:
        nonlocal best, best_assign, nodes
        if depth == len(order):
            best, best_assign = cost, list(current)
            return True
        p = order[depth]
        options = []
        for s in problem.domain[p]:
            added = 0
            clash = False
            for q in done:
                t = current[q]
                if t == s and overlap[p][q]:
                    clash = True
                    break
                if blocking[p][q] and blocks[s][t]:
                    added += 1
                if blocking[q][p] and blocks[t][s]:
                    added += 1
            if not clash and cost + added < best:
                options.append((added, s))
        options.sort()
        done.append(p)
        for added, s in options:
            if cost + added >= best:
                break
            nodes += 1
            if nodes > budget:
                done.pop()
                return False
            current[p] = s
            if not search(depth + 1, cost + added, done) and nodes > budget:
                done.pop()
                current[p] = UNSEATED
                return False
            current[p] = UNSEATED
        done.pop()
        return True

    if start >= upper_bound:
        return ExactResult(True, upper_bound, None)
    search(0, start, placed_list)
    if nodes > budget:
        return ExactResult(False, None, None)
    return ExactResult(True, best, best_assign)
