"""Period arithmetic behind the driver earnings summary (G7)."""

from __future__ import annotations

from datetime import date

from app.services.wallet_service import period_start, period_starts


def test_period_starts() -> None:
    assert period_start(date(2031, 3, 5), "week") == date(2031, 3, 3)  # Wednesday -> Monday
    assert period_start(date(2031, 3, 5), "month") == date(2031, 3, 1)
    assert period_starts("month", date(2031, 1, 31), date(2031, 3, 1)) == [
        date(2031, 1, 1),
        date(2031, 2, 1),
        date(2031, 3, 1),
    ]
    assert period_starts("day", date(2031, 2, 27), date(2031, 3, 1)) == [
        date(2031, 2, 27),
        date(2031, 2, 28),
        date(2031, 3, 1),
    ]
