"""``stop_offsets_km``: how far along a route each stop is, from the map."""

from __future__ import annotations

from decimal import Decimal

from app.utilities.geo import latlng_to_wkt, stop_offsets_km, wkb_to_latlng

# Five stops 0.1 degrees of latitude apart on one meridian: equal legs.
MERIDIAN = [(5.6 + i / 10, -1.0) for i in range(5)]


def test_offsets_are_scaled_to_the_road_length() -> None:
    offsets = stop_offsets_km(MERIDIAN, route_km=Decimal("200"))
    assert offsets == [Decimal(km) for km in ("0.00", "50.00", "100.00", "150.00", "200.00")]


def test_without_a_road_length_the_offsets_are_straight_line_distances() -> None:
    offsets = stop_offsets_km(MERIDIAN, route_km=None)
    assert offsets is not None
    assert offsets[0] == Decimal("0.00")
    assert Decimal("44") < offsets[-1] < Decimal("45")  # 4 x 0.1 degrees ~ 44.5 km


def test_uneven_legs_keep_their_proportions() -> None:
    points = [(5.6, -1.0), (5.7, -1.0), (6.0, -1.0)]  # legs of 1 : 3
    assert stop_offsets_km(points, route_km=Decimal("100")) == [
        Decimal("0.00"),
        Decimal("25.00"),
        Decimal("100.00"),
    ]


def test_no_offsets_without_every_location_or_any_spread() -> None:
    assert stop_offsets_km([(5.6, -1.0), None, (6.0, -1.0)], route_km=Decimal("100")) is None
    assert stop_offsets_km([(5.6, -1.0), (5.6, -1.0)], route_km=Decimal("100")) is None
    assert stop_offsets_km([(5.6, -1.0)], route_km=Decimal("100")) is None


def test_a_just_created_stop_location_can_be_read() -> None:
    assert wkb_to_latlng(latlng_to_wkt(5.5713, -0.2051)) == (5.5713, -0.2051)
