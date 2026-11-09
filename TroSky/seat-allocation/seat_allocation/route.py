"""Alight positions: how far along the route a passenger gets off.

Never straight-line distance. On a route that bends back on itself, a place close to
the pickup on the map can be the last stop on the road.

TroSky routes are stops today: each has a sequence number and, when measured, a road
distance (``route_stops.distance_from_origin_km``). A route can also carry a polyline,
which is how a typed destination is placed. A routing engine such as OSRM or Valhalla
can stand behind the same ``locate`` call.
"""

from __future__ import annotations

import math
from collections.abc import Sequence
from dataclasses import dataclass
from enum import StrEnum
from itertools import pairwise
from typing import Protocol

from .config import RouteConfig

EARTH_RADIUS_KM = 6371.0088
KM_PER_DEGREE = 111.32


class DestinationStatus(StrEnum):
    OK = "ok"
    GPS_ERROR = "gps_error"  # not a believable coordinate
    OFF_ROUTE = "off_route"  # an impossible destination: the route does not go there
    BEHIND_PICKUP = "behind_pickup"  # the route passes it only before the pickup
    SAME_AS_PICKUP = "same_as_pickup"  # no ride to speak of
    UNKNOWN_STOP = "unknown_stop"


@dataclass(frozen=True)
class Destination:
    status: DestinationStatus
    position: float | None = None
    detail: str = ""
    name: str | None = None

    @property
    def ok(self) -> bool:
        return self.status is DestinationStatus.OK


@dataclass(frozen=True)
class Stop:
    id: str
    name: str
    sequence: int
    road_km: float | None = None
    latitude: float | None = None
    longitude: float | None = None


def haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Straight-line distance. Used only to measure along a polyline's short segments."""
    p1, p2 = math.radians(lat1), math.radians(lat2)
    a = (
        math.sin((p2 - p1) / 2) ** 2
        + math.cos(p1) * math.cos(p2) * math.sin(math.radians(lon2 - lon1) / 2) ** 2
    )
    return 2 * EARTH_RADIUS_KM * math.asin(math.sqrt(a))


class RoutingEngine(Protocol):
    """What the allocator needs from a routing engine."""

    def locate(self, latitude: float, longitude: float) -> list[tuple[float, float]]:
        """Each pass of the route near this point: (km along the route, km off it)."""
        ...


class Route:
    """A planned route: stops, a polyline, or both."""

    def __init__(
        self,
        stops: Sequence[Stop] = (),
        polyline: Sequence[tuple[float, float]] | None = None,
        name: str = "",
    ) -> None:
        self.name = name
        self.stops = tuple(sorted(stops, key=lambda stop: stop.sequence))
        self._by_id = {stop.id: stop for stop in self.stops}
        self.polyline = tuple(polyline or ())
        self._offsets = [0.0]
        for (lat1, lon1), (lat2, lon2) in pairwise(self.polyline):
            self._offsets.append(self._offsets[-1] + haversine_km(lat1, lon1, lat2, lon2))

    @property
    def uses_road_km(self) -> bool:
        """True when every stop has a measured road distance. Otherwise positions are
        stop sequence numbers, which keep the order but not the distance."""
        return bool(self.stops) and all(stop.road_km is not None for stop in self.stops)

    @property
    def length(self) -> float:
        if self.polyline:
            return self._offsets[-1]
        if self.uses_road_km:
            return max(stop.road_km or 0.0 for stop in self.stops)
        return float(self.stops[-1].sequence) if self.stops else 0.0

    def stop_position(self, stop_id: str) -> float | None:
        stop = self._by_id.get(stop_id)
        if stop is None:
            return None
        if self.uses_road_km:
            return float(stop.road_km)  # type: ignore[arg-type]
        return float(stop.sequence)

    def locate(self, latitude: float, longitude: float) -> list[tuple[float, float]]:
        """Each segment's nearest point to here: (km along the route, km off it)."""
        scale_x = KM_PER_DEGREE * math.cos(math.radians(latitude))
        found = []
        for index, ((lat_a, lon_a), (lat_b, lon_b)) in enumerate(pairwise(self.polyline)):
            ax, ay = (lon_a - longitude) * scale_x, (lat_a - latitude) * KM_PER_DEGREE
            bx, by = (lon_b - longitude) * scale_x, (lat_b - latitude) * KM_PER_DEGREE
            dx, dy = bx - ax, by - ay
            length_squared = dx * dx + dy * dy
            share = (
                0.0
                if length_squared == 0
                else max(0.0, min(1.0, -(ax * dx + ay * dy) / length_squared))
            )
            off = math.hypot(ax + share * dx, ay + share * dy)
            along = self._offsets[index] + share * (self._offsets[index + 1] - self._offsets[index])
            found.append((along, off))
        return found


def resolve_stop(route: Route, stop_id: str, board_position: float) -> Destination:
    """A destination selected from the route's stops."""
    position = route.stop_position(stop_id)
    if position is None:
        return Destination(
            DestinationStatus.UNKNOWN_STOP, detail=f"{stop_id} is not on this route."
        )
    name = route._by_id[stop_id].name
    if position < board_position:
        return Destination(
            DestinationStatus.BEHIND_PICKUP,
            position,
            f"{name} comes before the pickup on this route.",
            name,
        )
    if position == board_position:
        return Destination(
            DestinationStatus.SAME_AS_PICKUP, position, f"{name} is the pickup stop.", name
        )
    return Destination(DestinationStatus.OK, position, name=name)


def resolve_point(
    route: Route | RoutingEngine,
    latitude: float,
    longitude: float,
    board_position: float,
    config: RouteConfig,
    *,
    same_stop_km: float = 0.05,
) -> Destination:
    """A typed or dropped destination, placed along the route.

    A route that passes near the point twice is taken at its first pass after the
    pickup, since that is when the passenger would get off.
    """
    believable = (
        math.isfinite(latitude)
        and math.isfinite(longitude)
        and not (latitude == 0 and longitude == 0)
        and config.min_lat <= latitude <= config.max_lat
        and config.min_lon <= longitude <= config.max_lon
    )
    if not believable:
        return Destination(
            DestinationStatus.GPS_ERROR,
            detail=f"({latitude}, {longitude}) is outside the service area.",
        )
    near = sorted(
        (along, off)
        for along, off in route.locate(latitude, longitude)
        if off <= config.max_off_route_km
    )
    if not near:
        return Destination(
            DestinationStatus.OFF_ROUTE,
            detail=f"This route passes no closer than {config.max_off_route_km} km to there.",
        )
    # Neighbouring segments report the same pass; split the passes by the gap between them.
    passes: list[list[tuple[float, float]]] = []
    for point in near:
        if passes and point[0] - passes[-1][-1][0] <= 2 * config.max_off_route_km:
            passes[-1].append(point)
        else:
            passes.append([point])
    closest = [min(one_pass, key=lambda point: point[1])[0] for one_pass in passes]
    ahead = [position for position in closest if position > board_position + same_stop_km]
    if ahead:
        return Destination(DestinationStatus.OK, ahead[0])
    if any(abs(position - board_position) <= same_stop_km for position in closest):
        return Destination(
            DestinationStatus.SAME_AS_PICKUP,
            board_position,
            "That is where the passenger boards.",
        )
    return Destination(
        DestinationStatus.BEHIND_PICKUP,
        closest[-1],
        "This route passes there only before the pickup.",
    )
