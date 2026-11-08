import unittest
from datetime import datetime, timedelta
from decimal import Decimal as D

from fare_engine import load_config, price, settle
from fare_engine.config import ConfigError
from fare_engine.quotes import (
    QuoteExpired,
    cancelled_fare,
    confirm_quote,
    create_quote,
    final_fare,
    gps_track_km,
    measured_distance,
)
from fare_engine.settlement import SettlementError, driver_receipt, rider_breakdown
from fare_engine.surge import SurgeResult, no_surge

CONFIG = load_config()
NOW = datetime(2026, 11, 4, 17, 30)
SURGE_1_3 = SurgeResult(D("1.30"), D("1.30"), False, ("evening_rush",), ("evening rush",))


def quote(km="8", minutes="20", surge=None):
    return create_quote(
        quote_id="q1", rider_id="r1", pickup_zone="accra-osu", distance_km=km, minutes=minutes,
        surge=surge or no_surge(), config=CONFIG, now=NOW,
    )


class TestSettlement(unittest.TestCase):
    def test_tolls_and_tips_are_outside_the_fee(self):
        s = settle("7.10", CONFIG, tolls="1.00", tips="2.00", incentives="0.50")
        self.assertEqual(s.platform_fee, D("1.42"))
        self.assertEqual(s.driver_payout, D("9.18"))  # 7.10 - 1.42 + 1.00 + 2.00 + 0.50
        self.assertEqual(s.rider_pays, D("10.10"))

    def test_promotion_does_not_reduce_the_driver(self):
        s = settle("7.10", CONFIG, promo="2.00")
        self.assertEqual(s.rider_pays, D("5.10"))
        self.assertEqual(s.driver_payout, D("5.68"))
        self.assertEqual(s.platform_net, D("-0.58"))

    def test_promotion_larger_than_fare_is_refused(self):
        with self.assertRaises(SettlementError):
            settle("1.90", CONFIG, promo="2.00")

    def test_fare_must_be_whole_pesewas(self):
        with self.assertRaises(SettlementError):
            settle("7.105", CONFIG)

    def test_vat_placeholder_is_carved_out_of_the_fee(self):
        cfg = CONFIG.replace("taxes", vat_on_service_fee_rate=D("0.20"))  # illustrative rate only
        s = settle("7.10", cfg)
        self.assertEqual(s.platform_fee, D("1.42"))
        self.assertEqual(s.vat_on_fee + s.platform_revenue_ex_vat, s.platform_fee)
        self.assertEqual(s.driver_payout, D("5.68"))  # VAT never changes the driver's share

    def test_exclusive_vat_is_not_assumed(self):
        cfg = CONFIG.replace("taxes", vat_on_service_fee_rate=D("0.15"), vat_inclusive=False)
        with self.assertRaises(ConfigError):
            settle("7.10", cfg)

    def test_receipts(self):
        b = price("8", "0", "1.3", CONFIG)
        s = settle(b.fare, CONFIG)
        rider = dict(rider_breakdown(b, s, SURGE_1_3))
        self.assertEqual(rider["You pay"], "GH¢9.20")
        self.assertEqual(rider["High demand: evening rush (x1.3)"], "GH¢2.10")
        driver = dict(driver_receipt(b, s))
        self.assertEqual(driver["Platform fee (20%)"], "-GH¢1.84")
        self.assertEqual(driver["Your earnings"], "GH¢7.36")


class TestQuotes(unittest.TestCase):
    def test_quote_locks_the_price_and_expires(self):
        q = quote(surge=SURGE_1_3)
        self.assertEqual(q.fare, D("9.20"))
        self.assertIs(confirm_quote(q, NOW + timedelta(seconds=299)), q)
        with self.assertRaises(QuoteExpired):
            confirm_quote(q, NOW + timedelta(seconds=301))

    def test_surge_change_after_quote_does_not_change_the_fare(self):
        q = quote(surge=SURGE_1_3)
        # Surge in the zone is now 2.0, but the trip matched the quote.
        result = final_fare(q, "8.4", "22", CONFIG)
        self.assertEqual((result.basis, result.amount), ("quoted", D("9.20")))

    def test_material_change_reprices_at_the_locked_multiplier(self):
        q = quote(surge=SURGE_1_3)
        result = final_fare(q, "12", "30", CONFIG)  # 50% longer
        self.assertEqual(result.basis, "repriced")
        self.assertEqual(result.amount, D("13.80"))  # 12 km x 0.8875 x 1.3 = 13.845 -> 13.80
        self.assertEqual(result.breakdown.surge_multiplier, D("1.30"))

    def test_route_change_reprices_even_inside_tolerance(self):
        result = final_fare(quote(), "8.2", "20", CONFIG, route_changed=True)
        self.assertEqual((result.basis, result.amount), ("repriced", D("7.30")))  # 7.2775 -> 7.30

    def test_short_trips_use_the_absolute_tolerance(self):
        q = quote(km="1")
        self.assertEqual(final_fare(q, "1.4", "5", CONFIG).basis, "quoted")  # 0.4 km off, under 0.5 km

    def test_cancelled_before_pickup_charges_the_configured_fee(self):
        result = cancelled_fare(quote(), started=False, config=CONFIG)
        self.assertEqual((result.basis, result.amount), ("cancelled_before_pickup", D("0.00")))

    def test_cancelled_mid_trip_charges_distance_travelled_capped_at_quote(self):
        q = quote(surge=SURGE_1_3)
        mid = cancelled_fare(q, started=True, travelled_km="3", config=CONFIG)
        self.assertEqual(mid.amount, D("3.50"))  # 3 x 0.8875 x 1.3 = 3.46125 -> 3.50
        longer = cancelled_fare(q, started=True, travelled_km="10", config=CONFIG)
        self.assertEqual(longer.amount, q.fare)  # never more than the quote

    def test_gps_lost_and_gps_overrun(self):
        self.assertEqual(measured_distance(None, "8", CONFIG), (D("8"), "gps_lost_used_routed_distance"))
        self.assertEqual(measured_distance("14", "8", CONFIG)[0], D("10.000"))  # capped at 8 + 25%
        self.assertEqual(measured_distance("8.3", "8", CONFIG), (D("8.3"), "gps"))

    def test_gps_jumps_are_dropped(self):
        t0 = NOW
        track = [
            (5.6000, -0.1800, t0),
            (5.6090, -0.1800, t0 + timedelta(minutes=2)),  # about 1 km in 2 minutes
            (6.6000, -0.1800, t0 + timedelta(minutes=3)),  # 110 km in a minute: a GPS jump
            (5.6180, -0.1800, t0 + timedelta(minutes=4)),  # back on the road
        ]
        self.assertEqual(gps_track_km(track, CONFIG), D("2.002"))  # two steps of 1.0008 km


if __name__ == "__main__":
    unittest.main()
