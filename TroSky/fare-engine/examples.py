"""Worked examples, computed by the engine itself. Run: python examples.py

The specification's tables are generated from these functions, so every number
in the document is a number the code produces.
"""

from __future__ import annotations

from datetime import datetime
from decimal import Decimal as D

from fare_engine import SurgeContext, load_config, price, settle, static_surge
from fare_engine.ledger import (
    FEES,
    MOMO,
    Ledger,
    finish_payout,
    payable,
    receivable,
    record_collection,
    settle_fee_arrears,
    settle_trip,
    start_payout,
)
from fare_engine.money import show
from fare_engine.pricing import minimum_fare_reach_km

CONFIG = load_config()


def comparison_rows():
    rows = []
    for km in ("1", "4", "8", "12", "16", "40"):
        a = price(km, "0", "1.0", CONFIG, mode="A", distance_pricing="linear")
        blk = price(km, "0", "1.0", CONFIG, mode="A", distance_pricing="per_block")
        b = price(km, "0", "1.0", CONFIG, mode="B")
        gap = a.fare - b.fare
        rows.append(
            {
                "km": km,
                "a_raw": show(a.raw_fare),
                "a": show(a.fare),
                "a_note": "minimum fare" if a.minimum_applied else "",
                "block": show(blk.fare),
                "b": show(b.fare),
                "gap": show(gap),
                "gap_pct": f"{(gap / b.fare * 100).quantize(D('1'))}%",
            }
        )
    return rows


def vector_rows():
    spec = [
        ("0.5 km", "0.5", "1.0", "0.20", "linear", "raw 0.44, minimum fare, fare 1.90"),
        ("1 km", "1", "1.0", "0.20", "linear", "fare 1.90, platform 0.38, driver 1.52"),
        ("4 km", "4", "1.0", "0.20", "linear", "raw 3.55, fare 3.60"),
        ("8 km", "8", "1.0", "0.20", "linear", "fare 7.10, platform 1.42, driver 5.68"),
        ("8 km", "8", "1.0", "0.25", "linear", "fare 7.10, platform 1.78, driver 5.32"),
        ("8 km", "8", "1.3", "0.20", "linear", "raw 9.23, fare 9.20, platform 1.84, driver 7.36"),
        ("8 km", "8", "1.3", "0.25", "linear", "fare 9.20, platform 2.30, driver 6.90"),
        ("16 km", "16", "1.0", "0.20", "linear", "fare 14.20, platform 2.84, driver 11.36"),
        ("9 km per block", "9", "1.0", "0.20", "per_block", "two blocks, fare 14.20"),
    ]
    rows = []
    for label, km, surge, rate, dp, expected in spec:
        b = price(km, "0", surge, CONFIG, distance_pricing=dp)
        s = settle(b.fare, CONFIG, service_fee_rate=rate)
        rows.append(
            {
                "label": label,
                "surge": surge,
                "rate": f"{int(D(rate) * 100)}%",
                "raw": show(b.raw_fare),
                "fare": show(b.fare),
                "fee": show(s.platform_fee),
                "driver": show(s.driver_payout),
                "expected": expected,
                "note": "minimum fare" if b.minimum_applied else (f"{b.blocks} blocks" if b.blocks else ""),
            }
        )
    return rows


def surge_rows():
    wednesday = datetime(2026, 11, 4)
    cases = [
        ("Evening rush + light rain", SurgeContext(at=wednesday.replace(hour=17, minute=30), weather="light_rain")),
        (
            "Evening rush + heavy rain + festive season + major event",
            SurgeContext(
                at=wednesday.replace(hour=18), weather="heavy_rain", occasions=frozenset({"festive_season", "major_event"})
            ),
        ),
        ("Late night, dry", SurgeContext(at=wednesday.replace(hour=23, minute=15))),
        ("Midday, dry, no occasion", SurgeContext(at=wednesday.replace(hour=11))),
    ]
    rows = []
    for label, ctx in cases:
        r = static_surge(ctx, CONFIG)
        b = price("8", "0", r.multiplier, CONFIG)
        s = settle(b.fare, CONFIG)
        rows.append(
            {
                "label": label,
                "uncapped": show(r.uncapped),
                "multiplier": show(r.multiplier),
                "fare": show(b.fare),
                "fee": show(s.platform_fee),
                "driver": show(s.driver_payout),
                "message": r.rider_message or "(no message: normal price)",
            }
        )
    return rows


def _balances(led: Ledger, accounts: list[tuple[str, str]]):
    return [(label, show(led.balance(acct))) for label, acct in accounts]


def cash_example():
    led = Ledger()
    cash = settle(price("8", "0", "1.0", CONFIG).fare, CONFIG)
    settle_trip(led, trip_id="cash-1", rider_id="r1", driver_id="kofi", settlement=cash, payment="cash")
    after_trip = _balances(led, [("Driver owes in fees", receivable("kofi")), ("Platform fee income", FEES), ("Platform MoMo wallet", MOMO)])
    digital = settle(price("8", "0", "1.3", CONFIG).fare, CONFIG)
    record_collection(led, rider_id="r2", amount=digital.rider_pays, reference="pay-77")
    settle_trip(led, trip_id="momo-2", rider_id="r2", driver_id="kofi", settlement=digital, payment="digital")
    payout = start_payout(led, driver_id="kofi", run_id="2026-W45", minimum_payout=D("5.00"))
    finish_payout(led, payout, succeeded=True)
    alone = Ledger()
    settle_trip(alone, trip_id="cash-3", rider_id="r3", driver_id="ama", settlement=cash, payment="cash")
    settle_fee_arrears(alone, driver_id="ama", amount=D("1.42"), reference="fee-ama-1")
    return {
        "cash": cash,
        "after_trip": after_trip,
        "digital": digital,
        "payout": payout,
        "after_payout": _balances(led, [("Driver owes in fees", receivable("kofi")), ("Owed to driver", payable("kofi")), ("Platform MoMo wallet", MOMO), ("Platform fee income", FEES)]),
        "settled": _balances(alone, [("Driver owes in fees", receivable("ama")), ("Platform MoMo wallet", MOMO)]),
        "trial_balance": show(led.trial_balance()),
    }


def momo_example():
    led = Ledger()
    s = settle(price("8", "0", "1.3", CONFIG).fare, CONFIG)
    steps = []
    record_collection(led, rider_id="esi", amount=s.rider_pays, reference="pay-501")
    steps.append(("MoMo approves the rider's payment", _balances(led, [("MoMo wallet", MOMO), ("Held for rider", "liability:rider:esi")])))
    settle_trip(led, trip_id="t-501", rider_id="esi", driver_id="yaw", settlement=s, payment="digital")
    steps.append(("Trip completed", _balances(led, [("Held for rider", "liability:rider:esi"), ("Fee income", FEES), ("Owed to driver", payable("yaw"))])))
    payout = start_payout(led, driver_id="yaw", run_id="2026-W45", minimum_payout=D("5.00"))
    finish_payout(led, payout, succeeded=True)
    steps.append(("Weekly payout confirmed", _balances(led, [("Owed to driver", payable("yaw")), ("MoMo wallet", MOMO)])))
    return {"settlement": s, "steps": steps, "transactions": led.transactions, "trial_balance": show(led.trial_balance())}


def promo_example():
    return settle(price("8", "0", "1.0", CONFIG).fare, CONFIG, promo="2.00")


def minimum_reach():
    reach, rise = minimum_fare_reach_km(CONFIG)
    return show(reach.quantize(D("0.001"))), show(rise.quantize(D("0.001")))


if __name__ == "__main__":
    print("Mode A linear vs per-block vs Mode B (surge 1.0)")
    for r in comparison_rows():
        print(r)
    print("\nTest vectors")
    for r in vector_rows():
        print(r)
    print("\nSurge vectors (8 km, 20% fee)")
    for r in surge_rows():
        print(r)
    print("\nMinimum fare reach (km):", minimum_reach())
    print("\nCash example:", cash_example())
    print("\nMoMo example steps:")
    for step in momo_example()["steps"]:
        print(" ", step)
    print("\nPromo example:", promo_example())
