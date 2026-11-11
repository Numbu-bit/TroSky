import math
import unittest

from seat_allocation import Booking, allocate, load_config, single_file
from seat_allocation.route import (
    DestinationStatus,
    Route,
    Stop,
    haversine_km,
    resolve_point,
    resolve_stop,
)

CONFIG = load_config()
ROUTE_CONFIG = CONFIG.route

# A route that goes 5 km east, 1 km north, then 5 km back west: a U, ending 1 km from
# where it started. About 0.009 degrees of latitude is 1 km; 0.045 degrees of longitude
# is about 5 km at this latitude.
START = (5.600, -0.200)
U_ROUTE = Route(
    polyline=[
        START,
        (5.600, -0.155),
        (5.609, -0.155),
        (5.609, -0.200),
    ]
)
EARLY = (5.600, -0.173)  # about 3 km along the first leg
LATE = (5.609, -0.200)  # the end of the route: about 1 km from the start in a straight line


class TestAlongTheRoadNotAcrossTheMap(unittest.TestCase):
    def test_straight_line_distance_would_put_them_in_the_wrong_order(self):
        early = haversine_km(*START, *EARLY)
        late = haversine_km(*START, *LATE)
        self.assertGreater(early, late)

    def test_along_the_route_puts_them_in_the_right_order(self):
        early = resolve_point(U_ROUTE, *EARLY, 0.0, ROUTE_CONFIG)
        late = resolve_point(U_ROUTE, *LATE, 0.0, ROUTE_CONFIG)
        self.assertTrue(early.ok and late.ok)
        self.assertAlmostEqual(early.position, 3.0, delta=0.1)
        self.assertAlmostEqual(late.position, 11.0, delta=0.2)

    def test_the_passenger_who_is_near_on_the_map_but_last_on_the_road_sits_at_the_back(self):
        early = resolve_point(U_ROUTE, *EARLY, 0.0, ROUTE_CONFIG).position
        late = resolve_point(U_ROUTE, *LATE, 0.0, ROUTE_CONFIG).position
        allocation = allocate(
            single_file(2),
            [Booking("near-on-road", early), Booking("near-on-map", late)],
            CONFIG,
        )
        self.assertEqual(allocation.seats, {"near-on-map": "2", "near-on-road": "1"})


class TestDestinationChecks(unittest.TestCase):
    def test_coordinates_at_zero_are_a_gps_error(self):
        result = resolve_point(U_ROUTE, 0.0, 0.0, 0.0, ROUTE_CONFIG)
        self.assertIs(result.status, DestinationStatus.GPS_ERROR)

    def test_a_point_outside_the_service_area_is_a_gps_error(self):
        result = resolve_point(U_ROUTE, 51.5, -0.12, 0.0, ROUTE_CONFIG)
        self.assertIs(result.status, DestinationStatus.GPS_ERROR)

    def test_a_non_number_is_a_gps_error(self):
        result = resolve_point(U_ROUTE, math.nan, -0.2, 0.0, ROUTE_CONFIG)
        self.assertIs(result.status, DestinationStatus.GPS_ERROR)

    def test_a_place_the_route_never_passes_is_impossible(self):
        result = resolve_point(U_ROUTE, 5.70, -0.17, 0.0, ROUTE_CONFIG)
        self.assertIs(result.status, DestinationStatus.OFF_ROUTE)

    def test_a_place_behind_the_pickup_is_flagged(self):
        result = resolve_point(U_ROUTE, *EARLY, 6.0, ROUTE_CONFIG)
        self.assertIs(result.status, DestinationStatus.BEHIND_PICKUP)

    def test_the_pickup_itself_is_no_ride(self):
        result = resolve_point(U_ROUTE, *EARLY, 3.0, ROUTE_CONFIG, same_stop_km=0.2)
        self.assertIs(result.status, DestinationStatus.SAME_AS_PICKUP)

    def test_a_route_passing_twice_is_taken_at_the_first_pass_after_the_pickup(self):
        loop = Route(
            polyline=[
                (5.600, -0.200),
                (5.600, -0.155),
                (5.609, -0.155),
                (5.600, -0.155),
                (5.600, -0.100),
            ]
        )
        point = (5.600, -0.155)  # passed about 5 km in, and again about 7 km in
        first = resolve_point(loop, *point, 0.0, ROUTE_CONFIG)
        second = resolve_point(loop, *point, 6.0, ROUTE_CONFIG)
        self.assertLess(first.position, 5.5)
        self.assertGreater(second.position, 6.5)


class TestStops(unittest.TestCase):
    MEASURED = Route(
        stops=[
            Stop("madina", "Madina", 0, 0.0),
            Stop("legon", "Legon", 1, 3.5),
            Stop("circle", "Circle", 2, 14.0),
        ]
    )
    UNMEASURED = Route(
        stops=[
            Stop("madina", "Madina", 0, 0.0),
            Stop("legon", "Legon", 1),
            Stop("circle", "Circle", 2),
        ]
    )

    def test_a_measured_route_uses_road_distance(self):
        self.assertTrue(self.MEASURED.uses_road_km)
        self.assertEqual(self.MEASURED.stop_position("circle"), 14.0)

    def test_an_unmeasured_route_falls_back_to_stop_order(self):
        self.assertFalse(self.UNMEASURED.uses_road_km)
        self.assertEqual(self.UNMEASURED.stop_position("circle"), 2.0)

    def test_stop_results(self):
        self.assertTrue(resolve_stop(self.MEASURED, "legon", 0.0).ok)
        self.assertEqual(resolve_stop(self.MEASURED, "legon", 0.0).name, "Legon")
        self.assertIs(
            resolve_stop(self.MEASURED, "tema", 0.0).status, DestinationStatus.UNKNOWN_STOP
        )
        self.assertIs(
            resolve_stop(self.MEASURED, "legon", 3.5).status, DestinationStatus.SAME_AS_PICKUP
        )
        self.assertIs(
            resolve_stop(self.MEASURED, "legon", 10.0).status, DestinationStatus.BEHIND_PICKUP
        )

    def test_route_length(self):
        self.assertEqual(self.MEASURED.length, 14.0)
        self.assertEqual(self.UNMEASURED.length, 2.0)
        self.assertAlmostEqual(U_ROUTE.length, 11.0, delta=0.2)


if __name__ == "__main__":
    unittest.main()
