"""Geospatial conversion helpers for PostGIS geography columns.

Coordinates are always handled as ``(latitude, longitude)`` at the Python/API
boundary (the conventional human-facing order) and converted to WKT
``POINT(longitude latitude)`` — PostGIS/WKT order — only at the persistence
boundary.
"""

from __future__ import annotations

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
