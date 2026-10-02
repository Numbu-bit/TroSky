"""Geospatial conversion helpers for PostGIS geography columns.

Coordinates are always handled as ``(latitude, longitude)`` at the Python/API
boundary (the conventional human-facing order) and converted to WKT
``POINT(longitude latitude)`` — PostGIS/WKT order — only at the persistence
boundary.
"""

from __future__ import annotations

import math
from collections.abc import Sequence
from decimal import Decimal
from itertools import pairwise

from geoalchemy2.elements import WKBElement
from geoalchemy2.shape import to_shape
from shapely import wkt


def latlng_to_wkt(latitude: float, longitude: float) -> str:
    """Build a WKT POINT literal from (lat, lng). Note WKT is (lng, lat)."""
    return f"POINT({longitude} {latitude})"


def wkb_to_latlng(point: WKBElement | str | None) -> tuple[float, float] | None:
    """Convert a stored Geography point back to (latitude, longitude).

    Also takes the WKT text a stop holds between being created and being
    read back from the database (see ``latlng_to_wkt``).
    """
    if point is None:
        return None
    shape = wkt.loads(point) if isinstance(point, str) else to_shape(point)
    return (shape.y, shape.x)


def haversine_distance_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Great-circle distance in kilometers. Used for lightweight distance
    estimates where a PostGIS server-side calculation isn't warranted."""
    from math import asin, cos, radians, sin, sqrt

    earth_radius_km = 6371.0
    d_lat = radians(lat2 - lat1)
    d_lng = radians(lng2 - lng1)
    a = sin(d_lat / 2) ** 2 + cos(radians(lat1)) * cos(radians(lat2)) * sin(d_lng / 2) ** 2
    return 2 * earth_radius_km * asin(sqrt(a))


def stop_offsets_km(
    points: Sequence[tuple[float, float] | None], *, route_km: Decimal | None
) -> list[Decimal] | None:
    """Each stop's distance from the first, following the stops in order.

    Straight lines between neighbouring stops are shorter than the road, so
    when the route's real length is known the offsets are scaled to end
    exactly at it and only the proportions come from the map. None when a
    stop has no location or the stops do not spread out at all.
    """
    if len(points) < 2 or any(point is None for point in points):
        return None
    located = [point for point in points if point is not None]
    legs = [haversine_distance_km(a[0], a[1], b[0], b[1]) for a, b in pairwise(located)]
    straight_line_km = sum(legs)
    if straight_line_km == 0:
        return None
    scale = float(route_km) / straight_line_km if route_km else 1.0
    offsets, travelled = [Decimal("0.00")], 0.0
    for leg in legs:
        travelled += leg
        offsets.append(Decimal(str(round(travelled * scale, 2))))
    if route_km:
        offsets[-1] = Decimal(route_km).quantize(Decimal("0.01"))
    return offsets


def travel_minutes(km: float, speed_kmh: Decimal | None, *, fallback_kmh: Decimal) -> int:
    """Whole minutes to cover ``km``: at the vehicle's own speed while it is
    moving, else at ``fallback_kmh``. Rounded up, so "0" means "there now"."""
    speed = speed_kmh if speed_kmh is not None and speed_kmh >= _MOVING_KMH else fallback_kmh
    return math.ceil(max(km, 0.0) / float(speed) * 60)


# Below this a reported speed means "stuck in traffic or stopped", not a
# pace to extrapolate from.
_MOVING_KMH = Decimal("5")


def progress_along_route_km(
    stops: Sequence[tuple[float, float, float]], latitude: float, longitude: float
) -> float | None:
    """How far along a route a vehicle at ``(latitude, longitude)`` is.

    ``stops`` are ``(latitude, longitude, offset_km)`` in route order, the
    offset being the stop's distance from the start along the road. The
    route is treated as straight lines between neighbouring stops: the
    vehicle is placed on the nearest of those lines, and its progress is
    read off that line's two offsets in proportion. None for fewer than two
    stops.

    Straight lines are close enough between neighbouring stops to tell
    which stops a vehicle has passed, which is what this is for; it is not
    a road-accurate distance.
    """
    if len(stops) < 2:
        return None
    # Equirectangular projection around the vehicle: metres-accurate over
    # the few kilometres between stops, and cheap.
    km_per_deg_lat = 111.32
    km_per_deg_lng = 111.32 * math.cos(math.radians(latitude))

    def to_xy(lat: float, lng: float) -> tuple[float, float]:
        return (lng - longitude) * km_per_deg_lng, (lat - latitude) * km_per_deg_lat

    best: tuple[float, float] | None = None  # (distance off the line, progress)
    for (lat_a, lng_a, km_a), (lat_b, lng_b, km_b) in pairwise(stops):
        ax, ay = to_xy(lat_a, lng_a)
        bx, by = to_xy(lat_b, lng_b)
        dx, dy = bx - ax, by - ay
        length_sq = dx * dx + dy * dy
        # The vehicle sits at the origin of this projection.
        t = 0.0 if length_sq == 0 else max(0.0, min(1.0, (-ax * dx - ay * dy) / length_sq))
        off_line = math.hypot(ax + t * dx, ay + t * dy)
        progress = km_a + t * (km_b - km_a)
        if best is None or off_line < best[0]:
            best = (off_line, progress)
    return best[1] if best is not None else None
