"""Column values as the audit log stores them (JSON)."""

from __future__ import annotations

import enum
import uuid
from datetime import UTC, date, datetime
from decimal import Decimal

import pytest

from app.core.audit import _json


class Colour(enum.Enum):
    RED = "red"


ID = uuid.UUID("12345678-1234-5678-1234-567812345678")


@pytest.mark.parametrize(
    ("value", "stored"),
    [
        (None, None),
        (True, True),
        (3, 3),
        ("text", "text"),
        (ID, "12345678-1234-5678-1234-567812345678"),
        (Decimal("12.50"), "12.50"),  # exact, not a float
        (datetime(2026, 10, 2, 9, 30, tzinfo=UTC), "2026-10-02T09:30:00+00:00"),
        (date(2026, 10, 2), "2026-10-02"),
        (Colour.RED, "red"),
        ([ID, Decimal("1")], ["12345678-1234-5678-1234-567812345678", "1"]),
        ({"amount": Decimal("2.00"), 1: Colour.RED}, {"amount": "2.00", "1": "red"}),
        (b"\x01\x02", "<bytes>"),  # geometry and binary: noted, not copied
    ],
)
def test_values_are_stored_as_json(value: object, stored: object) -> None:
    assert _json(value) == stored
