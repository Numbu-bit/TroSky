"""Which seats a passenger chooses from, by how far they ride from their pickup.

A short ride chooses from the front seats, nearest the door, and a long ride
from the back. Passengers still pick the seat themselves. Once their part of
the vehicle is full they may take any free seat, so nobody is turned away while
a seat is empty.

It goes by the length of the ride, not by where along the route it ends: with
passengers boarding along the route, a simulation left about half the blocking
of a free choice of seats this way, and more than a free choice the other way.
"""

from __future__ import annotations

import uuid
from collections.abc import Collection, Sequence

from app.models.vehicles import SeatZone, VehicleSeat
from app.repositories.route_geometry import RouteGeometry


def seat_zones(seats: Sequence[VehicleSeat]) -> dict[uuid.UUID, SeatZone]:
    """The front half of a vehicle's rows, then the back half. Rows count from
    the front, and with an odd number of them the middle row is in the front."""
    rows = sorted({seat.row_number for seat in seats})
    front_rows = set(rows[: (len(rows) + 1) // 2])
    return {
        seat.id: SeatZone.FRONT if seat.row_number in front_rows else SeatZone.BACK
        for seat in seats
    }


def ride_share(geometry: RouteGeometry, origin: uuid.UUID, destination: uuid.UUID) -> float:
    """How much of the whole route a ride covers, from 0 to 1: by distance when
    the stops are measured, otherwise by counting stops."""
    points, order = geometry.points, geometry.order
    start, end = points[order[origin]].offset_km, points[order[destination]].offset_km
    first, last = points[0].offset_km, points[-1].offset_km
    if (
        start is not None
        and end is not None
        and first is not None
        and last is not None
        and last > first
    ):
        return float((end - start) / (last - first))
    return (order[destination] - order[origin]) / max(len(points) - 1, 1)


def passenger_zone(
    geometry: RouteGeometry,
    origin: uuid.UUID | None,
    destination: uuid.UUID | None,
    *,
    near_share: float,
) -> SeatZone:
    """The zone for a ride, which covers the whole route where a stop is left
    out. Covering less than ``near_share`` of the route is a short ride."""
    share = ride_share(
        geometry,
        origin or geometry.origin_stop_id,
        destination or geometry.destination_stop_id,
    )
    return SeatZone.FRONT if share < near_share else SeatZone.BACK


def selectable_seats(
    seats: Sequence[VehicleSeat], *, taken: Collection[uuid.UUID], zone: SeatZone | None
) -> set[uuid.UUID]:
    """The seats to offer: the free ones in ``zone``, or every free one if that
    zone has none left or the ride isn't known."""
    free = {seat.id for seat in seats if seat.is_active and seat.id not in taken}
    if zone is None:
        return free
    zones = seat_zones(seats)
    return {seat_id for seat_id in free if zones[seat_id] == zone} or free


def seats_outside_zone(
    requested: Collection[uuid.UUID],
    *,
    seats: Sequence[VehicleSeat],
    taken: Collection[uuid.UUID],
    zone: SeatZone,
) -> list[uuid.UUID]:
    """The requested seats a booking may not have: those outside ``zone`` while
    the zone still has a seat free that this booking isn't taking. A group
    bigger than what's left of its zone fills the zone, then spills over."""
    zones = seat_zones(seats)
    outside = [seat_id for seat_id in requested if zones[seat_id] != zone]
    if not outside:
        return []
    still_free = selectable_seats(seats, taken={*taken, *requested}, zone=None)
    return outside if any(zones[seat_id] == zone for seat_id in still_free) else []
