import unittest
from datetime import datetime
from decimal import Decimal as D

from fare_engine import SurgeContext, live_surge, load_config, price, settle, static_surge
from fare_engine.surge import smooth, target_from_ratio

CONFIG = load_config()
WEEKDAY = datetime(2026, 11, 4)  # an ordinary Wednesday, no occasions in the calendar


def at(hour, minute=0, day=WEEKDAY):
    return day.replace(hour=hour, minute=minute)


class TestFactorVectors(unittest.TestCase):
    def test_evening_rush_and_light_rain(self):
        result = static_surge(SurgeContext(at=at(17, 30), weather="light_rain"), CONFIG)
        self.assertEqual(result.multiplier, D("1.50"))
        self.assertEqual(result.rider_message, "High demand: evening rush, rain")
        s = settle(price("8", "0", result.multiplier, CONFIG).fare, CONFIG)
        self.assertEqual((s.fare, s.platform_fee, s.driver_payout), (D("10.70"), D("2.14"), D("8.56")))

    def test_four_factors_stacked_hit_the_cap(self):
        # Evening rush 0.30 + heavy rain 0.40 + festive season 0.25 + major event 0.30 = 1.25
        ctx = SurgeContext(
            at=at(18, 0), weather="heavy_rain", occasions=frozenset({"festive_season", "major_event"})
        )
        result = static_surge(ctx, CONFIG)
        self.assertEqual(result.uncapped, D("2.25"))
        self.assertTrue(result.capped)
        self.assertEqual(result.multiplier, D("2.00"))
        s = settle(price("8", "0", result.multiplier, CONFIG).fare, CONFIG)
        self.assertEqual((s.fare, s.platform_fee, s.driver_payout), (D("14.20"), D("2.84"), D("11.36")))

    def test_no_factors_means_no_surge(self):
        result = static_surge(SurgeContext(at=at(11, 0)), CONFIG)
        self.assertEqual(result.multiplier, D("1.0"))
        self.assertIsNone(result.rider_message)


class TestTimeWindows(unittest.TestCase):
    def test_start_inclusive_end_exclusive(self):
        self.assertIn("evening_rush", static_surge(SurgeContext(at=at(16, 30)), CONFIG).factors)
        self.assertNotIn("evening_rush", static_surge(SurgeContext(at=at(20, 0)), CONFIG).factors)

    def test_late_night_wraps_midnight(self):
        for hour, minute, expected in ((22, 0, True), (23, 59, True), (0, 30, True), (4, 59, True), (5, 0, False)):
            with self.subTest(hour=hour, minute=minute):
                factors = static_surge(SurgeContext(at=at(hour, minute)), CONFIG).factors
                self.assertEqual("late_night" in factors, expected)

    def test_expired_factor_is_ignored(self):
        later = datetime(2028, 1, 5, 17, 30)  # every factor in the file ends on 2027-12-31
        self.assertEqual(static_surge(SurgeContext(at=later, weather="light_rain"), CONFIG).multiplier, D("1.0"))


class TestWeatherAndOccasions(unittest.TestCase):
    def test_storm_counts_as_heavy_rain(self):
        self.assertEqual(static_surge(SurgeContext(at=at(11, 0), weather="storm"), CONFIG).multiplier, D("1.40"))

    def test_calendar_public_holiday(self):
        result = static_surge(SurgeContext(at=datetime(2027, 3, 6, 11, 0)), CONFIG)
        self.assertEqual(result.factors, ("public_holiday",))
        self.assertEqual(result.multiplier, D("1.10"))

    def test_major_event_needs_the_pickup_inside_the_radius(self):
        during = datetime(2026, 11, 14, 18, 0)
        near = SurgeContext(at=during, lat=D("5.5600"), lon=D("-0.1900"))  # about 1 km away
        far = SurgeContext(at=during, lat=D("5.6500"), lon=D("-0.1900"))  # about 11 km away
        self.assertIn("major_event", static_surge(near, CONFIG).factors)
        self.assertNotIn("major_event", static_surge(far, CONFIG).factors)


class TestKillSwitchAndLive(unittest.TestCase):
    def test_kill_switch(self):
        cfg = CONFIG.replace("surge", kill_switch=True)
        result = static_surge(SurgeContext(at=at(17, 30), weather="heavy_rain"), cfg)
        self.assertEqual(result.multiplier, D("1"))
        self.assertEqual(result.source, "kill_switch")

    def test_ratio_targets(self):
        self.assertEqual(target_from_ratio(10, 10, CONFIG), D("1.0"))
        self.assertEqual(target_from_ratio(20, 10, CONFIG), D("1.5"))
        self.assertEqual(target_from_ratio(25, 10, CONFIG), D("1.75"))
        self.assertEqual(target_from_ratio(90, 10, CONFIG), D("2.0"))
        self.assertEqual(target_from_ratio(5, 0, CONFIG), D("2.0"))  # no drivers counts as one

    def test_smoothing_limits_each_step(self):
        self.assertEqual(smooth(D("1.0"), D("2.0"), D("0.3"), D("0.10")), D("1.10"))
        self.assertEqual(smooth(D("1.5"), D("1.4"), D("0.3"), D("0.10")), D("1.47"))

    def test_live_surge_climbs_gradually_and_stays_capped(self):
        m = D("1.0")
        seen = []
        for _ in range(30):
            m = live_surge(m, 90, 10, CONFIG).multiplier
            seen.append(m)
        self.assertEqual(seen[0], D("1.10"))
        self.assertTrue(all(b - a <= D("0.10") for a, b in zip([D("1.0")] + seen, seen)))
        self.assertEqual(seen[-1], D("2.00"))


if __name__ == "__main__":
    unittest.main()
