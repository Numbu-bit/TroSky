"""Bookings and the seating problem built from them.

The objective has the form of a quadratic assignment problem:

    sum over passengers p, q of  flow[p][q] * blocks[seat(p)][seat(q)]
    + sum over passengers p of   linear[p][seat(p)]
    + soft terms for split groups and separated same-stop passengers

``blocks[s][t]`` is 1 when a passenger in seat t is in the way of seat s.
``flow[p][q]`` is what that costs for this pair of passengers: the blocking weight
when q is on board as p gets off and q gets off later, plus the boarding weight
when q is already seated as p boards.

All solvers work on whole cost units, so ties are exact.
"""

from __future__ import annotations

import itertools
from collections import defaultdict
from collections.abc import Iterable, Mapping
from dataclasses import dataclass
from enum import StrEnum

from .config import CATEGORIES, SeatConfig
from .layout import Seat, SeatLayout

UNSEATED = -1


class BookingError(ValueError):
    """A booking cannot be seated as given."""


class FixedReason(StrEnum):
    BOARDED = "boarded"  # never moves
    LOCKED = "locked"  # past the re-assignment lock
    OVERRIDE = "override"  # the passenger chose this seat


@dataclass(frozen=True)
class FixedSeat:
    seat: str
    reason: FixedReason


@dataclass(frozen=True)
class Booking:
    """One traveller. Positions are km along the route, or stop sequence numbers."""

    id: str
    alight: float
    board: float = 0.0
    category: str = "standard"
    group_id: str | None = None
    seat_preference: str | None = None  # a seat id, or a tag such as "window"
    booked_at: int = 0  # booking sequence or timestamp
    needs_accessible: bool = False
    luggage: str = "none"  # "none", "small" or "bulky"
    alight_name: str | None = None  # stop name, for messages

    def __post_init__(self) -> None:
        if self.category not in CATEGORIES:
            raise BookingError(f"{self.id}: unknown category {self.category!r}")
        if self.luggage not in ("none", "small", "bulky"):
            raise BookingError(f"{self.id}: unknown luggage size {self.luggage!r}")


def cluster_positions(positions: Iterable[float], tolerance: float) -> dict[float, int]:
    """Map each position to a stop number. Positions within ``tolerance`` of the
    first position in their run share a stop, so a long chain of close drop-offs
    cannot drift into one giant stop."""
    numbers: dict[float, int] = {}
    number = -1
    start: float | None = None
    for position in sorted(set(positions)):
        if start is None or position - start > tolerance:
            number += 1
            start = position
        numbers[position] = number
    return numbers


def tie_break_key(
    booking: Booking, group_start: Mapping[str, int], order: tuple[str, ...]
) -> tuple:
    """The order among passengers getting off at the same stop: group first, then
    booking time. Group members stay consecutive, so they land on adjacent seats."""
    key: list = []
    for rule in order:
        if rule == "group":
            if booking.group_id is None:
                key.extend((1, 0, ""))
            else:
                key.extend((0, group_start[booking.group_id], booking.group_id))
        elif rule == "booking_time":
            key.append(booking.booked_at)
    key.append(booking.id)
    return tuple(key)


@dataclass(frozen=True)
class SoftTerm:
    kind: str  # "components" or "child"
    members: tuple[int, ...]
    weight: int
    name: str = ""


class Problem:
    """A trip's bookings compiled into arrays. Passengers and seats become indexes."""

    def __init__(
        self,
        layout: SeatLayout,
        bookings: list[Booking],
        config: SeatConfig,
        *,
        fixed: Mapping[str, FixedSeat] | None = None,
        current: Mapping[str, str] | None = None,
        boarded: Iterable[str] = (),
        hold_reserved: bool = False,
    ) -> None:
        self.layout = layout
        self.config = config
        self.bookings = list(bookings)
        self.fixed_input = dict(fixed or {})
        self.current = dict(current or {})
        self.boarded = frozenset(boarded) | {
            booking_id
            for booking_id, seat in self.fixed_input.items()
            if seat.reason is FixedReason.BOARDED
        }
        self.hold_reserved = hold_reserved

        self.seats: list[Seat] = sorted(
            layout.seats, key=lambda s: (-s.depth_rank, -s.row, s.column, s.id)
        )
        self.seat_index = {seat.id: index for index, seat in enumerate(self.seats)}
        self.m = len(self.seats)
        self.n = len(self.bookings)
        self.index = {booking.id: i for i, booking in enumerate(self.bookings)}
        if len(self.index) != self.n:
            raise BookingError("booking ids must be unique")

        self.bookable = [i for i, seat in enumerate(self.seats) if seat.bookable]
        self.blocks = [
            [1 if other.id in seat.blockers else 0 for other in self.seats] for seat in self.seats
        ]
        self.neighbour_mask = [0] * self.m
        for i, seat in enumerate(self.seats):
            for name in seat.neighbours:
                if name in self.seat_index:
                    self.neighbour_mask[i] |= 1 << self.seat_index[name]

        stops = cluster_positions(
            [b.alight for b in self.bookings] + [b.board for b in self.bookings],
            config.assignment.same_stop_tolerance_km,
        )
        self.a = [stops[b.alight] for b in self.bookings]
        self.b = [stops[b.board] for b in self.bookings]
        for booking, alight, board in zip(self.bookings, self.a, self.b, strict=True):
            if alight <= board:
                raise BookingError(
                    f"{booking.id}: gets off at {booking.alight}, which is not after "
                    f"boarding at {booking.board}"
                )
        self.single_pickup = len(set(self.b)) <= 1

        group_start: dict[str, int] = {}
        for booking in self.bookings:
            if booking.group_id is not None:
                start = group_start.get(booking.group_id, booking.booked_at)
                group_start[booking.group_id] = min(start, booking.booked_at)
        self.tie_key = [
            tie_break_key(b, group_start, config.assignment.tie_break) for b in self.bookings
        ]
        # Farthest first, then the tie-break: the order the batch rule seats people.
        self.order_far_first = sorted(range(self.n), key=lambda p: (-self.a[p], self.tie_key[p]))

        self._build_pair_costs()
        self._build_group_terms()
        self._build_domains()
        self._build_same_stop_terms()
        self._build_linear_costs()

    # ----------------------------------------------------------- pair costs

    def boards_before(self, q: int, p: int) -> bool:
        """Is q on board, or boarding ahead of p, by the time p boards?"""
        if self.b[q] != self.b[p]:
            return self.b[q] < self.b[p]
        q_on = self.bookings[q].id in self.boarded
        p_on = self.bookings[p].id in self.boarded
        if q_on != p_on:
            return q_on
        if q_on:
            return False  # both already seated; neither walked past the other
        if self.config.assignment.boarding_discipline == "arrival":
            return self.bookings[q].booked_at < self.bookings[p].booked_at
        return False  # called rearmost-first: no one at this stop passes anyone from it

    def _build_pair_costs(self) -> None:
        w = self.config.weights
        n, a, b = self.n, self.a, self.b
        self.blocking = [[False] * n for _ in range(n)]
        self.boarding = [[False] * n for _ in range(n)]
        self.flow = [[0] * n for _ in range(n)]
        self.overlap = [[False] * n for _ in range(n)]
        for p in range(n):
            for q in range(n):
                if p == q:
                    continue
                self.overlap[p][q] = b[p] < a[q] and b[q] < a[p]
                # q is on board as p gets off, and gets off later.
                self.blocking[p][q] = b[q] < a[p] < a[q]
                # q is seated as p boards, and stays on past that stop. Someone
                # already on board has no boarding left to obstruct.
                self.boarding[p][q] = (
                    self.bookings[p].id not in self.boarded
                    and self.boards_before(q, p)
                    and a[q] > b[p]
                )
                self.flow[p][q] = (
                    w.blocking * self.blocking[p][q] + w.boarding_blocking * self.boarding[p][q]
                )

    # --------------------------------------------------------- linear costs

    def _depth_targets(self) -> dict[int, tuple[int, int]]:
        """Which rear-to-front seat positions fit each free passenger's place in the
        far-first order. Passengers getting off at one stop share a range of positions."""
        free = [
            p
            for p in self.order_far_first
            if p not in self.fixed and p not in self.constrained and p not in self.unseated
        ]
        targets: dict[int, tuple[int, int]] = {}
        start = 0
        while start < len(free):
            end = start
            while end + 1 < len(free) and self.a[free[end + 1]] == self.a[free[start]]:
                end += 1
            for p in free[start : end + 1]:
                targets[p] = (start, end)
            start = end + 1
        return targets

    def _build_linear_costs(self) -> None:
        w = self.config.weights
        self.linear = [[0] * self.m for _ in range(self.n)]
        self.depth_part = [[0] * self.m for _ in range(self.n)]
        # Only before anyone holds a seat: nobody is moved just to tidy the order.
        targets = {} if self.current else self._depth_targets()
        position = {s: i for i, s in enumerate(self.bookable)}
        for p, booking in enumerate(self.bookings):
            was_in = self.current.get(booking.id)
            lowest, highest = targets.get(p, (None, None))
            for s, seat in enumerate(self.seats):
                cost = 0
                if lowest is not None and s in position:
                    off_by = max(0, lowest - position[s], position[s] - highest)
                    self.depth_part[p][s] = w.depth_order * off_by
                    cost += self.depth_part[p][s]
                wanted = booking.seat_preference
                if wanted and seat.id != wanted and wanted not in seat.tags:
                    cost += w.preference
                if booking.luggage == "bulky" and "luggage" not in seat.tags:
                    cost += w.luggage
                if was_in is not None and seat.id != was_in:
                    cost += w.seat_change
                self.linear[p][s] = cost

    # ----------------------------------------------------------- soft terms

    def _build_group_terms(self) -> None:
        w = self.config.weights
        terms: list[SoftTerm] = []
        groups: dict[str, list[int]] = defaultdict(list)
        for p, booking in enumerate(self.bookings):
            if booking.group_id is not None:
                groups[booking.group_id].append(p)
        self.groups = {name: tuple(members) for name, members in groups.items()}
        for name, members in self.groups.items():
            if len(members) > 1:
                terms.append(SoftTerm("components", tuple(members), w.group_split, name))
        self.unaccompanied_children: list[int] = []
        if self.config.groups.child_requires_adult:
            for p, booking in enumerate(self.bookings):
                if booking.category != "child":
                    continue
                adults = tuple(
                    q
                    for q in self.groups.get(booking.group_id or "", ())
                    if self.bookings[q].category != "child"
                )
                if adults:
                    terms.append(SoftTerm("child", (p, *adults), w.child_apart))
                else:
                    self.unaccompanied_children.append(p)
        self.soft_terms = terms

    def _build_same_stop_terms(self) -> None:
        """Passengers free to move sit together at their stop. Someone in a fixed or
        reserved seat is left out, so they do not pull everyone else out of order."""
        stops: dict[int, list[int]] = defaultdict(list)
        for p in range(self.n):
            if p not in self.fixed and p not in self.constrained:
                stops[self.a[p]].append(p)
        for members in stops.values():
            if len(members) > 1:
                self.soft_terms.append(
                    SoftTerm("components", tuple(members), self.config.weights.same_stop_apart)
                )
        self.soft_of: list[list[int]] = [[] for _ in range(self.n)]
        for index, term in enumerate(self.soft_terms):
            for p in term.members:
                self.soft_of[p].append(index)

    def components(self, seats: Iterable[int]) -> int:
        """How many separate clusters these seats form."""
        remaining = 0
        for seat in seats:
            remaining |= 1 << seat
        count = 0
        mask_of = self.neighbour_mask
        while remaining:
            count += 1
            frontier = remaining & -remaining
            remaining ^= frontier
            while frontier:
                bit = frontier & -frontier
                frontier ^= bit
                reached = mask_of[bit.bit_length() - 1] & remaining
                remaining ^= reached
                frontier |= reached
        return count

    def term_cost(self, term: SoftTerm, assign: list[int]) -> int:
        if term.kind == "components":
            seats = [assign[p] for p in term.members if assign[p] != UNSEATED]
            if len(seats) < 2:
                return 0
            return term.weight * (self.components(set(seats)) - 1)
        child, *adults = term.members
        seat = assign[child]
        if seat == UNSEATED:
            return 0
        adult_seats = 0
        for q in adults:
            if assign[q] != UNSEATED:
                adult_seats |= 1 << assign[q]
        return 0 if self.neighbour_mask[seat] & adult_seats else term.weight

    def soft_cost(self, assign: list[int]) -> int:
        return sum(self.term_cost(term, assign) for term in self.soft_terms)

    # -------------------------------------------------------------- domains

    def _build_domains(self) -> None:
        """Which seats each passenger may have, and who must be placed first."""
        priority = self.config.priority
        reserved = [s for s in self.bookable if "priority" in self.seats[s].reserved_for]
        if not reserved:
            frontmost = sorted(
                (s for s in self.bookable if not self.seats[s].folding),
                key=lambda s: (self.seats[s].depth_rank, self.seats[s].row, self.seats[s].id),
            )
            reserved = frontmost[: priority.default_reserved_count]
        self.reserved_seats = reserved

        self.fixed: dict[int, int] = {}
        for booking_id, seat in self.fixed_input.items():
            if booking_id not in self.index:
                raise BookingError(f"fixed seat for unknown booking {booking_id}")
            if seat.seat not in self.seat_index:
                raise BookingError(f"{booking_id}: unknown seat {seat.seat}")
            self.fixed[self.index[booking_id]] = self.seat_index[seat.seat]
        for (p, s), (q, t) in itertools.combinations(self.fixed.items(), 2):
            if s == t and self.overlap[p][q]:
                raise BookingError(
                    f"{self.bookings[p].id} and {self.bookings[q].id} are fixed in the same seat"
                )

        taken = set(self.fixed.values()) if self.single_pickup else set()
        free_reserved = [s for s in reserved if s not in taken]

        self.warnings: list[str] = []
        self.unseated: dict[int, str] = {}
        self.domain: list[list[int]] = [[] for _ in range(self.n)]
        self.constrained: list[int] = []

        wanting_priority = sorted(
            (
                p
                for p in range(self.n)
                if p not in self.fixed
                and not self.bookings[p].needs_accessible
                and (
                    self.bookings[p].category in priority.categories
                    or p in self.unaccompanied_children
                )
            ),
            key=lambda p: (self.bookings[p].booked_at, self.bookings[p].id),
        )
        for p in self.unaccompanied_children:
            self.warnings.append(
                f"{self.bookings[p].id} is a child with no adult in their group: "
                "seated in a reserved seat for the conductor to watch."
            )
        accessible = [s for s in self.bookable if self.seats[s].accessible]
        needing_access = [
            p for p in range(self.n) if p not in self.fixed and self.bookings[p].needs_accessible
        ]
        for p in needing_access:
            options = [s for s in accessible if s not in taken]
            if options:
                self.domain[p] = options
                self.constrained.append(p)
            else:
                self.unseated[p] = (
                    "needs an accessible seat, and this vehicle has none free. "
                    "A person must arrange this trip."
                )
        overflow = wanting_priority[len(free_reserved) :]
        for p in wanting_priority[: len(free_reserved)]:
            self.domain[p] = free_reserved
            self.constrained.append(p)
        for p in overflow:
            self.warnings.append(
                f"{self.bookings[p].id} has priority, but every reserved seat is taken: "
                "seated by the normal rule."
            )

        standard = [
            p
            for p in range(self.n)
            if p not in self.fixed and p not in self.unseated and p not in self.constrained
        ]
        held = set(reserved) if self.hold_reserved else set()
        open_seats = [s for s in self.bookable if s not in held]
        if self.single_pickup:
            free_open = {s for s in open_seats if s not in taken}
            needed = len(standard) + sum(
                1 for p in self.constrained if set(self.domain[p]) <= free_open
            )
            if len(free_open) < needed:
                open_seats = self.bookable  # capacity beats holding seats back
            capacity = len([s for s in self.bookable if s not in taken]) - len(self.constrained)
            by_booking = sorted(
                standard, key=lambda p: (self.bookings[p].booked_at, self.bookings[p].id)
            )
            for p in by_booking[max(capacity, 0) :]:
                self.unseated[p] = "the vehicle is full."
            standard = [p for p in standard if p not in self.unseated]
        for p in standard:
            self.domain[p] = open_seats
        for p, seat in self.fixed.items():
            self.domain[p] = [seat]

    # ---------------------------------------------------------------- costs

    def pair_cost_of(self, p: int, s: int, assign: list[int]) -> int:
        """What passenger p in seat s costs against everyone else as assigned."""
        flow, blocks = self.flow, self.blocks
        flow_p, blocks_s = flow[p], blocks[s]
        total = 0
        for q, t in enumerate(assign):
            if t == UNSEATED or q == p:
                continue
            if blocks_s[t]:
                total += flow_p[q]
            if blocks[t][s]:
                total += flow[q][p]
        return total

    def total_cost(self, assign: list[int]) -> int:
        total = self.soft_cost(assign)
        for p, s in enumerate(assign):
            if s == UNSEATED:
                continue
            total += self.linear[p][s]
            flow_p, blocks_s = self.flow[p], self.blocks[s]
            for q, t in enumerate(assign):
                if t != UNSEATED and q != p and blocks_s[t]:
                    total += flow_p[q]
        return total

    def blocking_pairs(self, assign: list[int]) -> list[tuple[int, int]]:
        """Every (p, q) where q must move for p to get off."""
        pairs = []
        for p, s in enumerate(assign):
            if s == UNSEATED:
                continue
            for q, t in enumerate(assign):
                if q != p and t != UNSEATED and self.blocking[p][q] and self.blocks[s][t]:
                    pairs.append((p, q))
        return pairs

    def boarding_pairs(self, assign: list[int]) -> list[tuple[int, int]]:
        """Every (p, q) where q must stand for p to reach their seat."""
        pairs = []
        for p, s in enumerate(assign):
            if s == UNSEATED:
                continue
            for q, t in enumerate(assign):
                if q != p and t != UNSEATED and self.boarding[p][q] and self.blocks[s][t]:
                    pairs.append((p, q))
        return pairs

    def fits(self, p: int, s: int, assign: list[int], ignore: int = UNSEATED) -> bool:
        """May p sit in seat s, given who else uses it and when?"""
        overlap_p = self.overlap[p]
        for q, t in enumerate(assign):
            if t == s and q != p and q != ignore and overlap_p[q]:
                return False
        return True

    def first_come_seating(self) -> list[int]:
        """The 'before' number: in booking order, each takes the rearmost free seat.

        An assumption about what happens with no allocation: people fill a vehicle
        from the back so that later boarders need not climb past them. Fixed and
        priority seats are respected, so before and after obey the same constraints.
        """
        assign = [UNSEATED] * self.n
        for p, s in self.fixed.items():
            assign[p] = s
        for p in self.constrained:
            for s in self.domain[p]:
                if self.fits(p, s, assign):
                    assign[p] = s
                    break
        order = sorted(
            (p for p in range(self.n) if assign[p] == UNSEATED and p not in self.unseated),
            key=lambda p: (self.bookings[p].booked_at, self.bookings[p].id),
        )
        for p in order:
            for s in self.domain[p]:
                if self.fits(p, s, assign):
                    assign[p] = s
                    break
        return assign
