"""Online mode: passengers book over time, and each needs a seat straight away.

A new passenger takes the free seat with the lowest added blocking cost. Most seats
tie on that, so the tie is what decides the trip: seat a short-trip passenger at the
back now, and every later passenger going farther must sit in front of them. Distance
zones break the tie by keeping rear seats for far destinations and front seats for
near ones, so the seats stay in order even before anyone has been moved.
"""

from __future__ import annotations

from bisect import bisect_left, bisect_right
from collections.abc import Sequence
from dataclasses import dataclass

from .config import SeatConfig
from .layout import SeatLayout
from .model import UNSEATED, Problem


@dataclass(frozen=True)
class ZonePlan:
    """Which part of the route each band of seats is kept for."""

    boundaries: tuple[float, ...]  # upper position of each zone but the last
    zone_of_seat: dict[str, int]
    depth_share: dict[str, float]  # 0 at the front of the bookable seats, 1 at the rear
    history: tuple[float, ...]  # past alight positions on this route, sorted
    route_km: float

    def zone_of_position(self, position: float) -> int:
        return bisect_left(self.boundaries, position)

    def share_of_route(self, position: float) -> float:
        """How far along the demand this position is, from 0 to 1."""
        if self.history:
            return bisect_right(self.history, position) / len(self.history)
        return min(1.0, position / self.route_km) if self.route_km > 0 else 0.5


def build_zone_plan(
    layout: SeatLayout,
    config: SeatConfig,
    *,
    route_km: float,
    history: Sequence[float] = (),
    exclude: Sequence[str] = (),
) -> ZonePlan:
    """Split the seats into equal bands, front to rear, and the route to match.

    With past trips on the route, the zones hold equal shares of past passengers. With
    none, they are equal lengths of road, which is an assumption about demand.
    """
    zones = config.online.zones
    seats = sorted(
        (seat for seat in layout.bookable_seats() if seat.id not in exclude),
        key=lambda seat: (seat.depth_rank, seat.row, seat.id),
    )
    past = tuple(sorted(history))
    if past:
        boundaries = tuple(
            past[min(len(past) - 1, len(past) * i // zones)] for i in range(1, zones)
        )
    else:
        boundaries = tuple(route_km * i / zones for i in range(1, zones))
    count = max(len(seats), 1)
    return ZonePlan(
        boundaries=boundaries,
        zone_of_seat={seat.id: min(zones - 1, i * zones // count) for i, seat in enumerate(seats)},
        depth_share={seat.id: (i + 0.5) / count for i, seat in enumerate(seats)},
        history=past,
        route_km=route_km,
    )


def choose_seat(problem: Problem, p: int, assign: list[int], plan: ZonePlan | None) -> int:
    """The free seat with the lowest added cost, breaking ties by zone when there is a plan."""
    position = problem.bookings[p].alight
    best: tuple | None = None
    for s in problem.domain[p]:
        if not problem.fits(p, s, assign):
            continue
        # Without the rear-first tidying term, which the zones do better here.
        added = problem.pair_cost_of(p, s, assign) + problem.linear[p][s] - problem.depth_part[p][s]
        if plan is None:
            key = (added, s)
        else:
            seat = problem.seats[s].id
            zone = plan.zone_of_seat.get(seat)
            zone_gap = abs(zone - plan.zone_of_position(position)) if zone is not None else 0
            depth_gap = abs(plan.depth_share.get(seat, 0.5) - plan.share_of_route(position))
            key = (added, zone_gap, depth_gap, s)
        if best is None or key < best:
            best = key
    return UNSEATED if best is None else best[-1]
