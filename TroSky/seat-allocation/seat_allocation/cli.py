"""Try the engine from a terminal: python -m seat_allocation --help"""

from __future__ import annotations

import argparse
import json
import sys

from .allocator import Allocation, allocate
from .config import ConfigError, load_config
from .layout import LayoutError, load_layout, minibus_variant
from .messages import conductor_sheet
from .model import Booking, BookingError
from .simulator import run_all


def _print_allocation(allocation: Allocation) -> None:
    print(conductor_sheet(allocation, title="SEAT PLAN"))
    print(f"Blocking pairs before: {allocation.blocking_before}")
    print(f"Blocking pairs after:  {allocation.blocking_after}")
    if allocation.minimum_blocking is None:
        print(f"Unavoidable blocking:  not proven (at least {allocation.lower_bound})")
    else:
        print(f"Unavoidable blocking:  {allocation.minimum_blocking} ({allocation.proof})")
    for forced in allocation.forced:
        print(f"\nWhy: {forced.reason}")
        if forced.other_seat is not None:
            print(f"     In seat {forced.other_seat} it would be {forced.pairs_in_other_seat}.")
    for name, reason in allocation.unseated:
        print(f"\nNot seated: {name}: {reason}")
    for warning in allocation.warnings:
        print(f"\nNote: {warning}")


def _allocate(args: argparse.Namespace) -> int:
    config = load_config(args.config)
    if args.seats:
        layout = minibus_variant(args.seats)
    else:
        layout = load_layout(args.layout)
    priority = set(args.priority or [])
    bookings = []
    for index, value in enumerate(args.alights):
        category = "elderly" if value in priority else "standard"
        priority.discard(value)
        bookings.append(
            Booking(id=f"{value:g}km#{index + 1}", alight=value, category=category, booked_at=index)
        )
    _print_allocation(allocate(layout, bookings, config))
    return 0


def _simulate(args: argparse.Namespace) -> int:
    results = run_all(args.trips, args.seed, args.online_trips)
    if args.json:
        with open(args.json, "w", encoding="utf-8") as handle:
            json.dump(results, handle, indent=2)
            handle.write("\n")
    for scenario in results["scenarios"]:  # type: ignore[union-attr]
        print(f"\n{scenario['scenario']} ({scenario['trips']} synthetic trips)")
        for method, numbers in scenario["methods"].items():
            print(
                f"  {method:<12} mean {numbers['mean']:>7}  p95 {numbers['p95']:>4}"
                f"  worst {numbers['worst']:>4}  zero on {numbers['zero_share']:.0%} of trips"
            )
        print(
            f"  minimum proven on {scenario['proven_minimum_share']:.0%} of trips;"
            f" boarding blocks per trip {scenario['boarding_blocks_mean']};"
            f" worst solve {scenario['worst_solve_ms']} ms"
        )
    for scenario in results["online"]:  # type: ignore[union-attr]
        print(f"\n{scenario['scenario']} ({scenario['trips']} synthetic trips)")
        for method, numbers in scenario["methods"].items():
            print(f"  {method:<14} mean {numbers['mean']:>7}  worst {numbers['worst']:>4}")
        print(
            f"  seat changes per trip when re-optimising: {scenario['mean_seat_changes_per_trip']}"
        )
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="python -m seat_allocation", description=__doc__)
    parser.add_argument("--config", default=None, help="another config file")
    commands = parser.add_subparsers(dest="command", required=True)

    seat = commands.add_parser("allocate", help="seat passengers by how far they go")
    seat.add_argument("alights", nargs="+", type=float, help="drop-off of each passenger, in km")
    seat.add_argument("--layout", default="single_file_5", help="a file in layouts/, or a path")
    seat.add_argument("--seats", type=int, help="use the minibus with this many seats (14 to 18)")
    seat.add_argument(
        "--priority",
        type=float,
        action="append",
        help="the passenger with this drop-off has priority (can repeat)",
    )
    seat.set_defaults(handler=_allocate)

    simulate = commands.add_parser("simulate", help="compare methods over synthetic trips")
    simulate.add_argument("--trips", type=int, default=500)
    simulate.add_argument("--seed", type=int, default=20261108)
    simulate.add_argument("--online-trips", type=int, help="trips for the slower online comparison")
    simulate.add_argument("--json", help="also write the results to this file")
    simulate.set_defaults(handler=_simulate)

    args = parser.parse_args(argv)
    try:
        return args.handler(args)
    except (BookingError, ConfigError, LayoutError, OSError) as error:
        print(f"Error: {error}", file=sys.stderr)
        return 2
