"""Unit tests for geospatial conversion helpers (pure logic, no database)."""

from __future__ import annotations

from app.utilities.geo import haversine_distance_km, latlng_to_wkt


class TestHaversineDistanceKm:
    def test_same_point_is_zero_distance(self) -> None:
        assert haversine_distance_km(5.6037, -0.1870, 5.6037, -0.1870) == 0.0

    def test_known_distance_accra_to_kumasi(self) -> None:
        # Accra (5.6037, -0.1870) to Kumasi (6.6885, -1.6244) is
        # approximately 200 km great-circle (the actual road distance is
        # longer, ~250 km, since roads aren't straight lines).
        distance = haversine_distance_km(5.6037, -0.1870, 6.6885, -1.6244)
        assert 195 < distance < 205

    def test_symmetric(self) -> None:
        a = haversine_distance_km(5.6037, -0.1870, 6.6885, -1.6244)
        b = haversine_distance_km(6.6885, -1.6244, 5.6037, -0.1870)
        assert a == b


class TestLatLngToWkt:
    def test_wkt_uses_longitude_latitude_order(self) -> None:
        assert latlng_to_wkt(5.6037, -0.1870) == "POINT(-0.187 5.6037)"
