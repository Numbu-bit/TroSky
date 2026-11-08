import random
import unittest
from collections import defaultdict
from decimal import Decimal as D

from fare_engine import load_config, price, settle
from fare_engine.ledger import FEES, MOMO, Ledger, payable, receivable, record_collection, settle_trip, start_payout
from fare_engine.money import is_multiple_of
from fare_engine.reconciliation import MomoLine, PaymentAttempt, reconcile

CONFIG = load_config()


class TestReconciliation(unittest.TestCase):
    def test_categories(self):
        attempts = [
            PaymentAttempt("p1", "t1", "collection", D("7.10"), "succeeded"),
            PaymentAttempt("p2", "t2", "collection", D("9.20"), "succeeded"),  # MoMo has no record
            PaymentAttempt("p3", "t3", "collection", D("3.60"), "timed_out"),  # approved late at MTN
            PaymentAttempt("p4", "t4", "collection", D("14.20"), "succeeded"),  # amount differs
            PaymentAttempt("p5", "t5", "collection", D("1.90"), "succeeded"),  # charged twice
        ]
        statement = [
            MomoLine("p1", "f1", "collection", D("7.10"), "SUCCESSFUL"),
            MomoLine("p3", "f3", "collection", D("3.60"), "SUCCESSFUL"),
            MomoLine("p4", "f4", "collection", D("14.00"), "SUCCESSFUL"),
            MomoLine("p5", "f5", "collection", D("1.90"), "SUCCESSFUL"),
            MomoLine("p5", "f6", "collection", D("1.90"), "SUCCESSFUL"),
            MomoLine("zz", "f7", "collection", D("5.00"), "SUCCESSFUL"),  # not ours at all
        ]
        report = reconcile(attempts, statement, ["t1", "t2", "t3", "t4", "t5", "t6"])
        self.assertEqual(report.matched, ["p1", "p5"])
        self.assertEqual(report.missing_at_momo, ["p2"])
        self.assertEqual(sorted(report.unexpected_at_momo), ["p3", "zz"])
        self.assertEqual(report.amount_mismatches, ["p4"])
        self.assertEqual(report.duplicate_charges, ["p5"])
        self.assertEqual(report.trips_without_payment, ["t2", "t3", "t4", "t6"])
        self.assertEqual(report.checked, 5)


class TestSimulation(unittest.TestCase):
    """10,000 synthetic trips: every invariant must hold on every trip."""

    def test_ten_thousand_trips(self):
        rng = random.Random(20261031)
        led = Ledger()
        fee_total = D("0")
        momo_in = D("0")
        drivers = [f"d{i}" for i in range(200)]
        for n in range(10_000):
            km = D(rng.randint(0, 40_000)) / 1000
            surge = D(rng.choice(range(100, 201, 5))) / 100
            mode = rng.choice(("A", "A", "B"))
            dp = rng.choice(("linear", "per_block"))
            b = price(km, "0", surge, CONFIG, mode=mode, distance_pricing=dp)
            self.assertGreaterEqual(b.fare, CONFIG.pricing.minimum_fare)
            self.assertTrue(is_multiple_of(b.fare, D("0.10")))

            rate = rng.choice(("0.20", "0.25"))
            tips = D(rng.choice((0, 0, 0, 1, 2, 5)))
            promo = min(b.fare, D(rng.choice((0, 0, 0, 1, 2))))
            s = settle(b.fare, CONFIG, tips=tips, promo=promo, service_fee_rate=rate)
            self.assertEqual(s.platform_fee + s.driver_fare_share, s.fare)
            self.assertTrue(is_multiple_of(s.platform_fee, D("0.01")))
            self.assertEqual(s.rider_pays + s.promo + s.incentives, s.driver_payout + s.platform_fee)

            driver, payment = rng.choice(drivers), rng.choice(("cash", "digital"))
            if payment == "digital" and s.rider_pays > 0:
                record_collection(led, rider_id=f"r{n}", amount=s.rider_pays, reference=f"pay-{n}")
                momo_in += s.rider_pays
            settle_trip(led, trip_id=f"t{n}", rider_id=f"r{n}", driver_id=driver, settlement=s, payment=payment)
            fee_total += s.platform_fee

        self.assertEqual(led.trial_balance(), D("0"))
        self.assertEqual(led.balance(FEES), fee_total)
        self.assertEqual(led.balance(MOMO), momo_in)

        for driver in drivers:
            start_payout(led, driver_id=driver, run_id="sim", minimum_payout=CONFIG.payouts.minimum_payout)
            # After netting, a driver either is owed money or owes fees, never both.
            self.assertFalse(led.balance(payable(driver)) > 0 and led.balance(receivable(driver)) > 0)
        self.assertEqual(led.trial_balance(), D("0"))


if __name__ == "__main__":
    unittest.main()
