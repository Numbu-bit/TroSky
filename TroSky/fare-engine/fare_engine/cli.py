"""Try the engine from a terminal.

    python -m fare_engine quote 8                         8 km, no surge, fee from the config
    python -m fare_engine quote 8 --surge 1.3 --fee 0.25  a set multiplier and the 25% scenario
    python -m fare_engine quote 9 --per-block             GH¢7.10 per started 8 km block
    python -m fare_engine quote 8 --mode B                tapered shared-taxi bands
    python -m fare_engine quote 8 --at "2026-11-04 17:30" --weather light_rain
                                                          surge from the factor table
    python -m fare_engine quote 8 --tips 2 --promo 2 --payment cash
    python -m fare_engine compare                         Mode A vs Mode B, 1 to 40 km

Numbers are read as text and turned into Decimal, so 8.5 is exact.
"""

from __future__ import annotations

import argparse
import sys
from datetime import datetime
from decimal import Decimal

from .config import ConfigError, load_config
from .money import cedis, show
from .pricing import PricingError, price
from .settlement import SettlementError, driver_receipt, rider_breakdown, settle
from .surge import SurgeContext, SurgeResult, static_surge


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="python -m fare_engine", description="Price a trip and split it between driver and platform.")
    parser.add_argument("--config", help="path to a fare_config.toml (default: the one next to the package)")
    sub = parser.add_subparsers(dest="command", required=True)

    q = sub.add_parser("quote", help="price one trip and show both receipts")
    q.add_argument("km", help="trip distance in km, e.g. 8 or 8.5")
    q.add_argument("--minutes", default="0", help="trip time in minutes (only matters if per_minute_rate > 0)")
    q.add_argument("--surge", help="a fixed multiplier between 1.0 and the cap, e.g. 1.3")
    q.add_argument("--at", help='pickup time for the factor table, e.g. "2026-11-04 17:30"')
    q.add_argument("--weather", default="clear", choices=["clear", "light_rain", "heavy_rain", "storm"])
    q.add_argument("--occasion", action="append", choices=["public_holiday", "festive_season", "major_event"], help="mark an occasion as active (repeatable)")
    q.add_argument("--fee", help="service fee rate, e.g. 0.25 (default: the config's rate)")
    q.add_argument("--mode", choices=["A", "B"], help="pricing mode (default: the config's)")
    q.add_argument("--per-block", action="store_true", help="Mode A per-block distance pricing")
    q.add_argument("--tolls", default="0")
    q.add_argument("--tips", default="0")
    q.add_argument("--incentives", default="0")
    q.add_argument("--promo", default="0", help="platform-funded rider discount")
    q.add_argument("--payment", choices=["digital", "cash"], default="digital")

    sub.add_parser("compare", help="Mode A linear, Mode A per block and Mode B side by side")
    return parser


def _surge(args: argparse.Namespace, config) -> SurgeResult:
    if args.surge and args.at:
        raise PricingError("use either --surge or --at, not both")
    if args.at:
        ctx = SurgeContext(
            at=datetime.fromisoformat(args.at),
            weather=args.weather,
            occasions=frozenset(args.occasion) if args.occasion else None,
        )
        return static_surge(ctx, config)
    multiplier = Decimal(args.surge or "1.0")
    return SurgeResult(multiplier, multiplier, False, (), (), "manual")


def _quote(args: argparse.Namespace, config) -> None:
    surge = _surge(args, config)
    b = price(args.km, args.minutes, surge.multiplier, config, mode=args.mode, distance_pricing="per_block" if args.per_block else None)
    s = settle(b.fare, config, tolls=args.tolls, tips=args.tips, incentives=args.incentives, promo=args.promo, service_fee_rate=args.fee)

    how = f"Mode {b.mode}" + (f", {b.distance_pricing}" if b.distance_pricing else ", bands")
    if b.blocks is not None:
        how += f", {b.blocks} block{'s' if b.blocks != 1 else ''}"
    reason = f" ({surge.rider_message})" if surge.rider_message else ""
    print(f"Trip: {b.distance_km} km · {how} · surge x{show(surge.multiplier)}{reason}")
    if surge.capped:
        print(f"Surge factors add up to x{show(surge.uncapped)}; capped at x{show(config.surge.cap)}.")
    print(f"Raw fare {show(b.raw_fare)} -> fare {cedis(b.fare)}" + (" (minimum fare applies)" if b.minimum_applied else ""))
    print()
    print("Rider sees")
    for label, value in rider_breakdown(b, s, surge):
        print(f"  {label:<44} {value:>12}")
    print()
    print("Driver receipt")
    for label, value in driver_receipt(b, s):
        print(f"  {label:<44} {value:>12}")
    print()
    print(f"Platform fee {cedis(s.platform_fee)}; platform keeps {cedis(s.platform_net)} after promotions and incentives.")
    if args.payment == "cash":
        owed = s.platform_fee - s.promo - s.incentives
        if owed >= 0:
            print(f"Cash trip: the driver collects {cedis(s.rider_pays)} and owes the platform {cedis(owed)}.")
        else:
            print(f"Cash trip: the driver collects {cedis(s.rider_pays)} and the platform owes the driver {cedis(-owed)}.")
    else:
        print(f"MoMo trip: the platform collects {cedis(s.rider_pays)} and pays the driver {cedis(s.driver_payout)} at the next payout.")


def _compare(config) -> None:
    print(f"{'km':>4}  {'A linear':>9}  {'A per block':>11}  {'B bands':>8}")
    for km in ("1", "2", "4", "8", "12", "16", "24", "40"):
        a = price(km, "0", "1.0", config, mode="A", distance_pricing="linear")
        blk = price(km, "0", "1.0", config, mode="A", distance_pricing="per_block")
        b = price(km, "0", "1.0", config, mode="B")
        print(f"{km:>4}  {show(a.fare):>9}  {show(blk.fare):>11}  {show(b.fare):>8}")


def main(argv: list[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    try:
        config = load_config(args.config)
        if args.command == "quote":
            _quote(args, config)
        else:
            _compare(config)
    except (ConfigError, PricingError, SettlementError, ValueError, TypeError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2
    return 0
