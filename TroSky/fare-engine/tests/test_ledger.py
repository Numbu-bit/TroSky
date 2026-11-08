import unittest
from decimal import Decimal as D

from fare_engine import load_config, price, settle
from fare_engine.ledger import (
    FEES,
    IN_FLIGHT,
    MOMO,
    PROMOS,
    REFUNDS,
    IdempotencyConflict,
    Ledger,
    LedgerError,
    Line,
    finish_payout,
    payable,
    receivable,
    record_collection,
    refund_rider,
    rider,
    settle_fee_arrears,
    settle_trip,
    start_payout,
)

CONFIG = load_config()
MIN_PAYOUT = CONFIG.payouts.minimum_payout


def trip_settlement(km, surge="1.0", **kw):
    return settle(price(km, "0", surge, CONFIG).fare, CONFIG, **kw)


class TestMomoTrip(unittest.TestCase):
    """8 km at x1.3, paid by MoMo: the platform collects GH¢9.20 and pays the driver GH¢7.36."""

    def test_full_cycle(self):
        led = Ledger()
        s = trip_settlement("8", "1.3")
        record_collection(led, rider_id="r1", amount=s.rider_pays, reference="pay-001")
        settle_trip(led, trip_id="t1", rider_id="r1", driver_id="d1", settlement=s, payment="digital")
        self.assertEqual(led.balance(rider("r1")), D("0.00"))
        self.assertEqual(led.balance(FEES), D("1.84"))
        self.assertEqual(led.balance(payable("d1")), D("7.36"))
        self.assertEqual(led.balance(MOMO), D("9.20"))

        payout = start_payout(led, driver_id="d1", run_id="2026-W45", minimum_payout=D("5.00"))
        self.assertEqual((payout.amount, payout.status), (D("7.36"), "pending"))
        self.assertEqual(led.balance(IN_FLIGHT), D("7.36"))
        finish_payout(led, payout, succeeded=True)
        self.assertEqual(led.balance(MOMO), D("1.84"))  # what the platform keeps
        self.assertEqual(led.balance(payable("d1")), D("0.00"))
        self.assertEqual(led.trial_balance(), D("0"))

    def test_failed_payout_returns_money_to_the_driver_balance(self):
        led = Ledger()
        s = trip_settlement("16")
        record_collection(led, rider_id="r1", amount=s.rider_pays, reference="pay-002")
        settle_trip(led, trip_id="t2", rider_id="r1", driver_id="d1", settlement=s, payment="digital")
        payout = start_payout(led, driver_id="d1", run_id="w1", minimum_payout=MIN_PAYOUT)
        finish_payout(led, payout, succeeded=False)
        self.assertEqual(led.balance(payable("d1")), D("11.36"))
        self.assertEqual(led.balance(IN_FLIGHT), D("0.00"))

    def test_payment_after_completion_leaves_rider_owing_until_collected(self):
        led = Ledger()
        s = trip_settlement("8")
        settle_trip(led, trip_id="t3", rider_id="r9", driver_id="d1", settlement=s, payment="digital")
        self.assertEqual(led.balance(rider("r9")), D("-7.10"))  # rider owes
        record_collection(led, rider_id="r9", amount=D("7.10"), reference="pay-late")
        self.assertEqual(led.balance(rider("r9")), D("0.00"))


class TestCashTrip(unittest.TestCase):
    """8 km cash trip: the driver keeps GH¢7.10, so the GH¢1.42 fee becomes a receivable."""

    def test_fee_becomes_receivable_and_is_netted_against_digital_earnings(self):
        led = Ledger()
        cash = trip_settlement("8")
        settle_trip(led, trip_id="c1", rider_id="r1", driver_id="d1", settlement=cash, payment="cash")
        self.assertEqual(led.balance(receivable("d1")), D("1.42"))
        self.assertEqual(led.balance(FEES), D("1.42"))
        self.assertEqual(led.balance(MOMO), D("0.00"))  # no money touched the platform

        digital = trip_settlement("8", "1.3")
        record_collection(led, rider_id="r2", amount=digital.rider_pays, reference="pay-010")
        settle_trip(led, trip_id="m1", rider_id="r2", driver_id="d1", settlement=digital, payment="digital")
        payout = start_payout(led, driver_id="d1", run_id="w1", minimum_payout=D("5.00"))
        self.assertEqual((payout.fees_netted, payout.amount), (D("1.42"), D("5.94")))  # 7.36 - 1.42
        self.assertEqual(led.balance(receivable("d1")), D("0.00"))

    def test_driver_settles_arrears_by_momo(self):
        led = Ledger()
        settle_trip(led, trip_id="c2", rider_id="r1", driver_id="d2", settlement=trip_settlement("16"), payment="cash")
        self.assertEqual(led.balance(receivable("d2")), D("2.84"))
        settle_fee_arrears(led, driver_id="d2", amount=D("2.84"), reference="fee-77")
        self.assertEqual(led.balance(receivable("d2")), D("0.00"))
        self.assertEqual(led.balance(MOMO), D("2.84"))
        # A retried callback is harmless.
        settle_fee_arrears(led, driver_id="d2", amount=D("2.84"), reference="fee-77")
        self.assertEqual(led.balance(MOMO), D("2.84"))

    def test_overpaying_arrears_is_refused(self):
        led = Ledger()
        settle_trip(led, trip_id="c3", rider_id="r1", driver_id="d3", settlement=trip_settlement("8"), payment="cash")
        with self.assertRaises(LedgerError):
            settle_fee_arrears(led, driver_id="d3", amount=D("5.00"), reference="fee-78")

    def test_cash_trip_with_promotion_credits_the_driver(self):
        led = Ledger()
        s = trip_settlement("8", promo="2.00")  # rider hands over GH¢5.10 in cash
        settle_trip(led, trip_id="c4", rider_id="r1", driver_id="d4", settlement=s, payment="cash")
        self.assertEqual(led.balance(receivable("d4")), D("1.42"))
        self.assertEqual(led.balance(payable("d4")), D("2.00"))
        self.assertEqual(led.balance(PROMOS), D("2.00"))
        payout = start_payout(led, driver_id="d4", run_id="w1", minimum_payout=D("0.01"))
        self.assertEqual(payout.amount, D("0.58"))  # 5.10 cash + 0.58 = 5.68, the full driver share


class TestLedgerRules(unittest.TestCase):
    def test_unbalanced_transactions_are_refused(self):
        with self.assertRaises(LedgerError):
            Ledger().post("k1", "bad", [Line.dr(MOMO, D("1.00")), Line.cr(FEES, D("0.99"))])

    def test_fractions_of_a_pesewa_are_refused(self):
        with self.assertRaises(LedgerError):
            Ledger().post("k2", "bad", [Line.dr(MOMO, D("1.005")), Line.cr(FEES, D("1.005"))])

    def test_idempotency(self):
        led = Ledger()
        first = record_collection(led, rider_id="r1", amount=D("7.10"), reference="pay-1")
        again = record_collection(led, rider_id="r1", amount=D("7.10"), reference="pay-1")
        self.assertIs(first, again)
        self.assertEqual(led.balance(MOMO), D("7.10"))
        with self.assertRaises(IdempotencyConflict):
            record_collection(led, rider_id="r1", amount=D("9.99"), reference="pay-1")

    def test_payout_run_is_idempotent(self):
        led = Ledger()
        s = trip_settlement("16")
        record_collection(led, rider_id="r1", amount=s.rider_pays, reference="p")
        settle_trip(led, trip_id="t", rider_id="r1", driver_id="d1", settlement=s, payment="digital")
        a = start_payout(led, driver_id="d1", run_id="w1", minimum_payout=MIN_PAYOUT)
        b = start_payout(led, driver_id="d1", run_id="w1", minimum_payout=MIN_PAYOUT)
        self.assertEqual(a, b)
        self.assertEqual(led.balance(IN_FLIGHT), D("11.36"))

    def test_below_minimum_rolls_over(self):
        led = Ledger()
        s = trip_settlement("8")
        record_collection(led, rider_id="r1", amount=s.rider_pays, reference="p")
        settle_trip(led, trip_id="t", rider_id="r1", driver_id="d1", settlement=s, payment="digital")
        payout = start_payout(led, driver_id="d1", run_id="w1", minimum_payout=D("10.00"))
        self.assertEqual(payout.status, "below_minimum")
        self.assertEqual(led.balance(payable("d1")), D("5.68"))

    def test_entries_are_immutable_and_corrections_are_reversals(self):
        led = Ledger()
        txn = record_collection(led, rider_id="r1", amount=D("7.10"), reference="pay-x")
        with self.assertRaises(AttributeError):
            txn.lines[0].debit = D("0")  # type: ignore[misc]
        led.reverse("pay-x:reversal", "collection:pay-x")
        self.assertEqual(led.balance(MOMO), D("0.00"))
        self.assertEqual(len(led.transactions), 2)

    def test_refunds(self):
        led = Ledger()
        record_collection(led, rider_id="r1", amount=D("7.10"), reference="p")
        refund_rider(led, trip_id="t1", amount=D("7.10"), reference="rf-1")
        self.assertEqual(led.balance(REFUNDS), D("7.10"))
        refund_rider(led, trip_id="t2", amount=D("2.00"), reference="rf-2", charged_to="driver", driver_id="d1")
        self.assertEqual(led.balance(receivable("d1")), D("2.00"))
        self.assertEqual(led.trial_balance(), D("0"))


if __name__ == "__main__":
    unittest.main()
