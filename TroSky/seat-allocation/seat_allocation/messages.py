"""What passengers and conductors are told, in plain words.

English only here; real strings belong in each app's translation files. Messages use
the seat's id, which is the label painted or printed in the vehicle.
"""

from __future__ import annotations

from collections.abc import Mapping

from .allocator import Allocation
from .layout import SeatLayout
from .model import Booking

SMS_LIMIT = 160


def seat_reason(
    booking: Booking,
    allocation: Allocation,
    layout: SeatLayout,
    *,
    chosen: bool = False,
) -> str:
    """One short reason for a seat, such as 'Seat 9: you get off at the last stop.'"""
    seat = allocation.seats[booking.id]
    if chosen:
        return f"Seat {seat}: the seat you chose."
    stops = [position for position, _ in allocation.alighting_order]
    delayed = sum(1 for pair in allocation.blocking_pairs if pair.passenger == booking.id)
    if delayed:
        people = "passenger" if delayed == 1 else "passengers"
        return f"Seat {seat}: {delayed} {people} may need to move when you get off."
    if "priority" in layout.seat(seat).reserved_for and booking.category != "standard":
        return f"Seat {seat}: kept for you, close to the door."
    if len(allocation.seats) == 1:
        return f"Seat {seat}: yours for now, as the vehicle is still empty."
    if booking.group_id is not None:
        together = [
            other
            for other, other_seat in allocation.seats.items()
            if other != booking.id and other_seat in layout.seat(seat).neighbours
        ]
        if together and booking.alight == stops[-1]:
            return f"Seat {seat}: with your group, and you get off at the last stop."
        if together:
            return f"Seat {seat}: with your group, and no one is in your way."
    if len(stops) > 1 and booking.alight == stops[-1]:
        return f"Seat {seat}: you get off at the last stop."
    if len(stops) > 1 and booking.alight == stops[0]:
        return f"Seat {seat}: you get off first, so you sit near the door."
    return f"Seat {seat}: no one will be in your way when you get off."


def sms_confirmation(
    booking: Booking,
    seat: str,
    *,
    route_name: str,
    departure: str,
    boarding_turn: int | None = None,
) -> str:
    """A seat confirmation that fits one SMS, for phones with no data."""
    stop = f", off at {booking.alight_name}" if booking.alight_name else ""
    turn = f" Board {_ordinal(boarding_turn)} when called." if boarding_turn else ""
    text = f"TroSky: seat {seat}, {route_name} {departure}{stop}.{turn}"
    if len(text) <= SMS_LIMIT:
        return text
    text = f"TroSky: seat {seat}, {departure}{stop}.{turn}"
    return text[:SMS_LIMIT]


def _ordinal(number: int) -> str:
    if 10 <= number % 100 <= 20:
        suffix = "th"
    else:
        suffix = {1: "st", 2: "nd", 3: "rd"}.get(number % 10, "th")
    return f"{number}{suffix}"


def conductor_sheet(
    allocation: Allocation,
    *,
    title: str,
    names: Mapping[str, str] | None = None,
    stop_names: Mapping[float, str] | None = None,
) -> str:
    """A plain-text sheet that prints on a small printer or reads on any phone."""
    names = names or {}
    stop_names = stop_names or {}

    def who(passenger: str) -> str:
        return names.get(passenger, passenger)

    def where(position: float) -> str:
        return stop_names.get(position, f"{position:g}")

    lines = [title, "", "SEATS, REAR TO FRONT"]
    for use in allocation.seat_map:
        lines.append(f"  {use.seat:<5} {who(use.passenger):<16} off at {where(use.alight)}")
    lines += ["", "CALL TO BOARD, IN THIS ORDER"]
    lines += [f"  {i:>2}. {who(p)}" for i, p in enumerate(allocation.boarding_order, 1)]
    lines += ["", "GETTING OFF, IN THIS ORDER"]
    for position, passengers in allocation.alighting_order:
        lines.append(f"  {where(position)}: " + ", ".join(who(p) for p in passengers))
    if allocation.blocking_pairs:
        lines += ["", "THESE PASSENGERS MUST MOVE"]
        for pair in allocation.blocking_pairs:
            lines.append(
                f"  At {where(pair.position)}: {who(pair.blocker)} moves for {who(pair.passenger)}"
            )
    return "\n".join(lines) + "\n"
