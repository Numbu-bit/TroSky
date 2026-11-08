import unittest
from decimal import Decimal as D

from fare_engine import ConfigError, DistanceOutOfRange, PricingError, load_config, price
from fare_engine.pricing import minimum_fare_reach_km
from fare_engine.settlement import settle

CONFIG = load_config()


def fare(km, surge="1.0", **kw):
    return price(km, "0", surge, CONFIG, **kw).fare


class TestRequiredRate(unittest.TestCase):
    def test_per_km_rate_is_derived_exactly(self):
        self.assertEqual(CONFIG.pricing.per_km_rate, D("0.8875"))
        self.assertEqual(CONFIG.pricing.fare_reference, D("7.10"))
        self.assertEqual(CONFIG.pricing.reference_distance_km, D("8"))

    def test_rate_that_does_not_divide_evenly_is_not_rounded_early(self):
        cfg = CONFIG.replace("pricing", fare_reference=D("7.10"), reference_distance_km=D("3"))
        # 7.10 x 3 / 3 must be exactly 7.10, not 3 x 2.3666...7
        self.assertEqual(price("3", "0", "1.0", cfg).raw_fare, D("7.10"))


class TestVectorsModeALinear(unittest.TestCase):
    """The prompt's test vectors: Mode A linear, base 0, per-minute 0, minimum GH¢1.90."""

    def test_half_km_minimum_applies(self):
        b = price("0.5", "0", "1.0", CONFIG)
        self.assertEqual(b.raw_fare, D("0.44375"))  # shown as 0.44 in the prompt
        self.assertTrue(b.minimum_applied)
        self.assertEqual(b.fare, D("1.90"))

    def test_1km_minimum_and_split(self):
        s = settle(fare("1"), CONFIG)
        self.assertEqual((s.fare, s.platform_fee, s.driver_payout), (D("1.90"), D("0.38"), D("1.52")))

    def test_4km_is_the_rounding_rule_test(self):
        b = price("4", "0", "1.0", CONFIG)
        self.assertEqual(b.raw_fare, D("3.55"))
        self.assertEqual(b.fare, D("3.60"))  # exactly halfway, ROUND_HALF_UP goes up

    def test_8km_20_percent(self):
        s = settle(fare("8"), CONFIG)
        self.assertEqual((s.fare, s.platform_fee, s.driver_payout), (D("7.10"), D("1.42"), D("5.68")))

    def test_8km_25_percent(self):
        s = settle(fare("8"), CONFIG, service_fee_rate="0.25")
        self.assertEqual((s.fare, s.platform_fee, s.driver_payout), (D("7.10"), D("1.78"), D("5.32")))

    def test_8km_surge_1_3_at_20_percent(self):
        b = price("8", "0", "1.3", CONFIG)
        self.assertEqual(b.raw_fare, D("9.230"))
        s = settle(b.fare, CONFIG)
        self.assertEqual((s.fare, s.platform_fee, s.driver_payout), (D("9.20"), D("1.84"), D("7.36")))

    def test_8km_surge_1_3_at_25_percent(self):
        s = settle(fare("8", "1.3"), CONFIG, service_fee_rate="0.25")
        self.assertEqual((s.fare, s.platform_fee, s.driver_payout), (D("9.20"), D("2.30"), D("6.90")))

    def test_16km_20_percent(self):
        s = settle(fare("16"), CONFIG)
        self.assertEqual((s.fare, s.platform_fee, s.driver_payout), (D("14.20"), D("2.84"), D("11.36")))

    def test_per_block_9km_is_two_blocks(self):
        b = price("9", "0", "1.0", CONFIG, distance_pricing="per_block")
        self.assertEqual(b.blocks, 2)
        self.assertEqual(b.fare, D("14.20"))


class TestComparisonTable(unittest.TestCase):
    EXPECTED_A = {"1": "1.90", "4": "3.60", "8": "7.10", "12": "10.70", "16": "14.20", "40": "35.50"}
    EXPECTED_B = {"1": "1.90", "4": "2.90", "8": "4.70", "12": "5.60", "16": "8.40", "40": "20.20"}

    def test_mode_a_linear(self):
        for km, expected in self.EXPECTED_A.items():
            with self.subTest(km=km):
                self.assertEqual(fare(km, mode="A", distance_pricing="linear"), D(expected))

    def test_mode_b_bands(self):
        for km, expected in self.EXPECTED_B.items():
            with self.subTest(km=km):
                self.assertEqual(fare(km, mode="B"), D(expected))

    def test_mode_a_is_above_mode_b_beyond_1km(self):
        for km in ("4", "8", "12", "16", "40"):
            self.assertGreater(fare(km, mode="A"), fare(km, mode="B"))
        self.assertEqual(fare("1", mode="A"), fare("1", mode="B"))


class TestPerBlock(unittest.TestCase):
    def test_block_edges(self):
        cases = {"0": "1.90", "0.1": "7.10", "8": "7.10", "8.001": "14.20", "16": "14.20", "16.5": "21.30"}
        for km, expected in cases.items():
            with self.subTest(km=km):
                self.assertEqual(fare(km, distance_pricing="per_block"), D(expected))

    def test_per_block_with_surge(self):
        self.assertEqual(fare("9", "1.3", distance_pricing="per_block"), D("18.50"))  # 14.20 x 1.3 = 18.46


class TestModeB(unittest.TestCase):
    def test_band_edges_are_inclusive(self):
        self.assertEqual(fare("4", mode="B"), D("2.90"))
        self.assertEqual(fare("4.001", mode="B"), D("4.70"))

    def test_surge_applies_to_the_band_fare(self):
        self.assertEqual(fare("8", "1.5", mode="B"), D("7.10"))  # 4.70 x 1.5 = 7.05 -> 7.10

    def test_beyond_last_band_is_refused(self):
        with self.assertRaises(DistanceOutOfRange):
            fare("40.5", mode="B")


class TestMinimumFareAndRounding(unittest.TestCase):
    def test_minimum_reach(self):
        reach, rise = minimum_fare_reach_km(CONFIG)
        self.assertEqual(reach.quantize(D("0.001")), D("2.141"))  # 1.90 / 0.8875
        self.assertEqual(rise.quantize(D("0.001")), D("2.197"))  # rounded fare first passes 1.90
        self.assertEqual(fare("2.19"), D("1.90"))
        self.assertEqual(fare("2.2"), D("2.00"))

    def test_zero_distance_charges_the_minimum(self):
        self.assertEqual(fare("0"), D("1.90"))

    def test_base_fare_and_per_minute(self):
        cfg = CONFIG.replace("pricing", base_fare=D("1.00"), per_minute_rate=D("0.10"))
        b = price("8", "20", "1.0", cfg)
        self.assertEqual(b.subtotal, D("10.10"))  # 1.00 + 7.10 + 2.00
        self.assertEqual(b.fare, D("10.10"))

    def test_surge_amount_on_breakdown(self):
        b = price("8", "0", "1.3", CONFIG)
        self.assertEqual((b.fare_before_surge, b.surge_amount), (D("7.10"), D("2.10")))

    def test_minimum_not_on_rounding_grid_is_refused(self):
        with self.assertRaises(ConfigError):
            CONFIG.replace("pricing", minimum_fare=D("1.95"))


class TestInputValidation(unittest.TestCase):
    def test_floats_are_refused(self):
        with self.assertRaises(TypeError):
            price(8.0, "0", "1.0", CONFIG)

    def test_negative_distance(self):
        with self.assertRaises(PricingError):
            price("-1", "0", "1.0", CONFIG)

    def test_surge_outside_range(self):
        for s in ("0.9", "2.01"):
            with self.subTest(s=s), self.assertRaises(PricingError):
                price("8", "0", s, CONFIG)

    def test_too_long(self):
        with self.assertRaises(DistanceOutOfRange):
            price("201", "0", "1.0", CONFIG)


if __name__ == "__main__":
    unittest.main()
