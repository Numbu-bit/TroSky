"""Countries TroSky serves, as areas on the map.

Used to check that a passenger signing up is where TroSky runs (for now,
Ghana). The outline is Natural Earth's 1:110m border, with the Volta
corner by Aflao added (that scale cuts it off), widened by a margin of
about 15 km so that towns on the border (Aflao, Paga, Elubo, Hamile) and
a phone's GPS error never turn a Ghanaian away. The price of that margin
is that places just across the border, such as Lomé or Bondoukou, also
pass; a finer border can replace this one without changing callers.
"""

from __future__ import annotations

from functools import cache

from shapely.geometry import Point, Polygon
from shapely.prepared import PreparedGeometry, prep

# (longitude, latitude), anticlockwise from Keta along the coast.
_GHANA = [
    (1.0601, 5.9288),
    (-0.5076, 5.3435),
    (-1.0636, 5.0005),
    (-1.9647, 4.7105),
    (-2.8561, 4.9945),
    (-2.8107, 5.3891),
    (-3.2444, 6.2505),
    (-2.9836, 7.3797),
    (-2.5622, 8.2196),
    (-2.8275, 9.6425),
    (-2.9639, 10.3953),
    (-2.9404, 10.9627),
    (-1.2034, 11.0098),
    (-0.7616, 10.9369),
    (-0.4387, 11.0983),
    (0.0238, 11.0187),
    (-0.0498, 10.7069),
    (0.3676, 10.1912),
    (0.3659, 9.4650),
    (0.4612, 8.6772),
    (0.7120, 8.3125),
    (0.4910, 7.4117),
    (0.5704, 6.9144),
    (0.8369, 6.2800),
    # The Volta corner: the border reaches the coast at Aflao.
    (1.0500, 6.2700),
    (1.2000, 6.1000),
]

# About 15 km at Ghana's latitudes.
_MARGIN_DEGREES = 0.15

_OUTLINES: dict[str, list[tuple[float, float]]] = {"GH": _GHANA}

# ISO 3166-1 alpha-2 codes of the countries with an outline here.
KNOWN_COUNTRIES = frozenset(_OUTLINES)

COUNTRY_NAMES = {"GH": "Ghana"}


def country_names(countries: frozenset[str]) -> str:
    """ "Ghana", or "Ghana or Togo": for messages."""
    return " or ".join(COUNTRY_NAMES.get(code, code) for code in sorted(countries))


@cache
def _area(country: str) -> PreparedGeometry:
    return prep(Polygon(_OUTLINES[country]).buffer(_MARGIN_DEGREES))


def country_at(latitude: float, longitude: float, countries: frozenset[str]) -> str | None:
    """Which of ``countries`` the point is in, or None when it is in none of them."""
    point = Point(longitude, latitude)
    for country in sorted(countries & KNOWN_COUNTRIES):
        if _area(country).contains(point):
            return country
    return None
