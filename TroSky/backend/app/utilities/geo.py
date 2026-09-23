"""Geospatial conversion helpers for PostGIS geography columns.

Coordinates are always handled as ``(latitude, longitude)`` at the Python/API
boundary (the conventional human-facing order) and converted to WKT
``POINT(longitude latitude)`` — PostGIS/WKT order — only at the persistence
boundary.
"""

from __future__ import annotations

from geoalchemy2.elements import WKBElement
from geoalchemy2.shape import to_shape


def latlng_to_wkt(latitude: float, longitude: float) -> str:
    """Build a WKT POINT literal from (lat, lng). Note WKT is (lng, lat)."""
    return f"POINT({longitude} {latitude})"


def wkb_to_latlng(point: WKBElement | None) -> tuple[float, float] | None:
    """Convert a stored Geography point back to (latitude, longitude)."""
    if point is None:
        return None
    shape = to_shape(point)
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
