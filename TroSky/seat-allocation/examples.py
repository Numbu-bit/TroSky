"""Every worked example in the specification, printed by the engine itself.

Run: python examples.py
Distances and passengers are made up to illustrate the rules [PLACEHOLDER]. The route
name and stops come from the demo data in backend/scripts/seed_demo_data.py.
"""

from __future__ import annotations

import json
from datetime import UTC, datetime, timedelta

from seat_allocation import Booking, allocate, evaluate, load_config, minibus_variant, single_file
from seat_allocation.messages import conductor_sheet, seat_reason, sms_confirmation
from seat_allocation.model import FixedReason, FixedSeat
from seat_allocation.route import Route, Stop
from seat_allocation.service import Trip, TripSeatService

CONFIG = load_config()
FIVE = single_file(5)
BUS = minibus_variant(15)
DEPARTURE = datetime(2026, 11, 9, 7, 30, tzinfo=UTC)
ROUTE = Route(
    stops=[
        Stop("MAD", "Madina", 0, 0.0),
        Stop("LEG", "Legon", 1, 4.0),
        Stop("37", "37 Station", 2, 9.0),
        Stop("CIR", "Circle", 3, 14.0),
    ],
    name="Madina to Circle",
)
STOP_NAMES = {4.0: "Legon", 9.0: "37 Station", 14.0: "Circle"}


def _trip(*alights: float) -> list[Booking]:
    return [Booking(id=f"p{i}", alight=km, booked_at=i) for i, km in enumerate(alights)]


def _seat_line(allocation, bookings) -> str:
    km = {booking.id: booking.alight for booking in bookings}
    pairs = sorted(allocation.seats.items(), key=lambda item: item[1], reverse=True)
    return ", ".join(f"seat {seat} = {km[passenger]:g}" for passenger, seat in pairs)


def test_vectors() -> None:
    print("## Test vectors\n")
    print("| Input (km) | Seats, as computed | Blocking pairs | Unavoidable | Expected |")
    print("| --- | --- | --- | --- | --- |")
    first = _trip(12, 3, 8, 1, 6)
    result = allocate(FIVE, first, CONFIG)
    print(
        f"| 12, 3, 8, 1, 6 | {_seat_line(result, first)} | {result.blocking_after} | "
        f"{result.unavoidable_blocking} | seat 5 = 12 down to seat 1 = 1, with 0 pairs |"
    )
    backwards = {"p0": "1", "p2": "2", "p4": "3", "p1": "4", "p3": "5"}
    count, _, _ = evaluate(FIVE, first, backwards, CONFIG)
    print(f"| The same, fully reversed | seat 1 = 12 up to seat 5 = 1 | {count} | | 10 pairs |")
    second = _trip(12, 6, 6, 3, 1)
    result = allocate(FIVE, second, CONFIG)
    print(
        f"| 12, 6, 6, 3, 1 | {_seat_line(result, second)} | {result.blocking_after} | "
        f"{result.unavoidable_blocking} | the 6 km pair in seats 4 and 3, with 0 pairs |"
    )
    third = [
        Booking("p0", 12, category="elderly"),
        *[Booking(f"p{i + 1}", km) for i, km in enumerate((8, 6, 3, 1))],
    ]
    result = allocate(FIVE, third, CONFIG)
    print(
        f"| 12 (priority, fixed in seat 1), 8, 6, 3, 1 | {_seat_line(result, third)} | "
        f"{result.blocking_after} | {result.unavoidable_blocking} | "
        "seat 5 = 8 down to seat 2 = 1, with 4 unavoidable pairs |"
    )
    print(f"\nWhy, as reported: {result.forced[0].reason}")
    print(f"Proof: {result.proof}.")
    print(
        f"Another seat: {result.forced[0].other_seat} would cost "
        f"{result.forced[0].pairs_in_other_seat} pairs.\n"
    )


def _sample_bookings() -> list[Booking]:
    """Fourteen passengers on the 15-seat minibus, some of them with needs."""
    people = [
        ("Esi", 14.0, "elderly", None, None),
        ("Kofi", 14.0, "standard", None, None),
        ("Abena", 14.0, "standard", None, None),
        ("Yaw", 14.0, "standard", None, None),
        ("Akua", 9.0, "standard", "family", None),
        ("Kwame", 9.0, "child", "family", None),
        ("Adjoa", 9.0, "standard", None, None),
        ("Kojo", 9.0, "standard", None, None),
        ("Afia", 9.0, "standard", None, "window"),
        ("Mensah", 9.0, "standard", None, None),
        ("Ama", 4.0, "pregnant", None, None),
        ("Kwesi", 4.0, "standard", None, None),
        ("Efua", 4.0, "standard", None, None),
        ("Nana", 4.0, "standard", None, None),
    ]
    order = [13, 2, 9, 0, 11, 5, 4, 7, 12, 1, 3, 8, 10, 6]  # the order they booked in
    bookings = []
    for sequence, index in enumerate(order):
        name, km, category, group, preference = people[index]
        bookings.append(
            Booking(
                id=name,
                alight=km,
                category=category,
                group_id=group,
                seat_preference=preference,
                booked_at=sequence,
                alight_name=STOP_NAMES[km],
            )
        )
    return bookings


def worked_trip() -> None:
    bookings = _sample_bookings()
    result = allocate(BUS, bookings, CONFIG)
    print("## Worked trip: 14 passengers on the 15-seat minibus, Madina to Circle\n")
    print(f"Blocking pairs before (first come, rear first): {result.blocking_before}")
    print(f"Blocking pairs after: {result.blocking_after}")
    print(f"Boarding blocks if called in order: {result.boarding_blocks}")
    print(f"Proof: {result.proof}. Cost: {result.total_cost}.")
    print(f"Groups split: {[split.group_id for split in result.split_groups]}\n")
    print(conductor_sheet(result, title="MADINA TO CIRCLE 07:30", stop_names=STOP_NAMES))
    print("| Passenger | Seat | Told |")
    print("| --- | --- | --- |")
    by_id = {booking.id: booking for booking in bookings}
    for use in result.seat_map:
        print(
            f"| {use.passenger} | {use.seat} | {seat_reason(by_id[use.passenger], result, BUS)} |"
        )
    print()
    turn = result.boarding_order.index("Kofi") + 1
    print(
        "SMS:",
        sms_confirmation(
            by_id["Kofi"],
            result.seats["Kofi"],
            route_name=ROUTE.name,
            departure="07:30",
            boarding_turn=turn,
        ),
    )
    print()


def priority_seat_cost() -> None:
    print("## What a priority seat costs: an elderly passenger going to the last stop\n")
    print("Thirteen others on the 15-seat minibus, spread over the three stops.\n")
    others = [Booking(f"p{i}", (4.0, 9.0, 14.0)[i % 3], booked_at=i + 1) for i in range(13)]
    elder = Booking("elder", 14.0, category="standard", booked_at=0)
    print("| Seat | Kind of seat | Seats it can block | Blocking pairs, at best |")
    print("| --- | --- | --- | --- |")
    for seat_id, kind in (
        ("F1", "cab, own door"),
        ("F2", "cab, behind F1"),
        ("A1", "side door, folds"),
        ("A2", "first row, beside the folding seat"),
        ("B1", "second row, folds"),
        ("Z4", "back row, far corner"),
    ):
        result = allocate(
            BUS,
            [elder, *others],
            CONFIG,
            fixed={"elder": FixedSeat(seat_id, FixedReason.OVERRIDE)},
        )
        print(
            f"| {seat_id} | {kind} | {len(BUS.seats_blocked_by(seat_id))} | "
            f"{result.blocking_after} |"
        )
    print()


def service_walkthrough() -> None:
    print("## A trip through the service, online mode\n")
    online = CONFIG.replace("assignment", mode="online")
    clock = {"now": DEPARTURE - timedelta(hours=1)}
    service = TripSeatService(
        Trip("trip-1", "vehicle-1", DEPARTURE, route=ROUTE), BUS, online, clock=lambda: clock["now"]
    )
    first = service.create_booking("Nana", destination_stop="LEG", group_id=None)
    print("Near passenger books first:", first.seat, "-", first.message)
    second = service.create_booking("Kofi", destination_stop="CIR")
    print("Far passenger books next:", second.seat, "-", second.message, "- moved:", second.moved)
    third = service.create_booking("Adjoa", destination_stop="37")
    print("Middle passenger:", third.seat, "-", third.message, "- moved:", third.moved)
    quote = service.quote_swap("Kofi", first.seat)
    print("\nKofi asks for Nana's seat:")
    print(json.dumps(_quote_json(quote), indent=2))
    quote = service.quote_swap("Kofi", "A1")
    print("\nKofi asks for the folding seat by the door:")
    print(json.dumps(_quote_json(quote), indent=2))
    clock["now"] = DEPARTURE - timedelta(minutes=9)
    view = service.seat_map()
    print("\nLocked by time:", view.locked, "- boarding order:", view.boarding_order)
    print("Next off:", view.next_off)
    print("\nAudit log:")
    for entry in service.audit:
        change = f"{entry.from_seat} to {entry.to_seat}"
        print(f"  {entry.seq} {entry.action} {entry.booking_id} {change}: {entry.reason}")
    print()


def _quote_json(quote) -> dict:
    return {
        "allowed": quote.allowed,
        "reason": quote.reason,
        "current_seat": quote.current_seat,
        "target_seat": quote.target_seat,
        "blocking_now": quote.blocking_now,
        "blocking_after": quote.blocking_after,
        "added_blocking": quote.added_blocking,
        "other_moves": [
            {"booking_id": m.booking_id, "from": m.from_seat, "to": m.to_seat}
            for m in quote.other_moves
        ],
        "warning": quote.warning,
    }


if __name__ == "__main__":
    test_vectors()
    worked_trip()
    priority_seat_cost()
    service_walkthrough()
