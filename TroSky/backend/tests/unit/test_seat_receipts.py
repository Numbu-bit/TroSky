"""Splitting a booking's fare across its seats for the driver's receipts."""

from __future__ import annotations

from decimal import Decimal

import pytest

from app.services.trip_service import _seat_amounts


@pytest.mark.parametrize(
    ("fare", "seats", "expected"),
    [
        ("8.00", 1, ["8.00"]),
        ("8.00", 2, ["4.00", "4.00"]),
        ("10.00", 3, ["3.34", "3.33", "3.33"]),
        ("0.05", 2, ["0.03", "0.02"]),
    ],
)
def test_seats_add_up_to_the_booking_to_the_pesewa(
    fare: str, seats: int, expected: list[str]
) -> None:
    amounts = _seat_amounts(Decimal(fare), seats)

    assert amounts == [Decimal(a) for a in expected]
    assert sum(amounts) == Decimal(fare)
