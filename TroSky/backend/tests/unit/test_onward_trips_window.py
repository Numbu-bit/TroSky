"""Onward trips are vehicles leaving within ONWARD_TRIPS_WINDOW_MINUTES of a
passenger getting off. Late at night that window runs past midnight, and the
search must then look at tomorrow's early departures too."""

from __future__ import annotations

import uuid
from datetime import UTC, date, datetime, time
from types import SimpleNamespace

import pytest

from app.services import trip_search_service
from app.services.trip_search_service import TripSearchService

STOP = uuid.uuid4()


def _offer(name: str) -> SimpleNamespace:
    return SimpleNamespace(
        name=name,
        summary=SimpleNamespace(trip_id=uuid.uuid4(), available_seats=3),
        has_passed_pickup=False,
    )


def _service(monkeypatch: pytest.MonkeyPatch, now: datetime, by_date: dict[date, list]):
    class FrozenDatetime(datetime):
        @classmethod
        def now(cls, tz=None):  # type: ignore[override]
            return now

    monkeypatch.setattr(trip_search_service, "datetime", FrozenDatetime)
    service = object.__new__(TripSearchService)
    service._settings = SimpleNamespace(
        ONWARD_TRIPS_WINDOW_MINUTES=120, TRIP_SEARCH_MAX_CANDIDATES=50
    )
    calls: list[tuple[date, time | None]] = []

    async def search(**kwargs):
        calls.append((kwargs["travel_date"], kwargs["departure_before"]))
        return list(by_date.get(kwargs["travel_date"], [])), 0

    service.search = search  # type: ignore[method-assign]
    return service, calls


@pytest.mark.asyncio
async def test_window_inside_one_day_searches_today_only(monkeypatch: pytest.MonkeyPatch) -> None:
    today = date(2026, 10, 29)
    later = _offer("today 14:20")
    service, calls = _service(
        monkeypatch, datetime(2026, 10, 29, 13, 0, tzinfo=UTC), {today: [later]}
    )

    offers = await service.onward(STOP, exclude_trip_id=None, limit=5)

    assert calls == [(today, time(15, 0))]
    assert offers == [later]


@pytest.mark.asyncio
async def test_window_past_midnight_includes_tomorrow(monkeypatch: pytest.MonkeyPatch) -> None:
    today, tomorrow = date(2026, 10, 29), date(2026, 10, 30)
    tonight, after_midnight = _offer("today 23:55"), _offer("tomorrow 00:10")
    service, calls = _service(
        monkeypatch,
        datetime(2026, 10, 29, 23, 46, tzinfo=UTC),
        {today: [tonight], tomorrow: [after_midnight]},
    )

    offers = await service.onward(STOP, exclude_trip_id=None, limit=5)

    # The rest of today, then tomorrow up to 01:46; soonest first.
    assert calls == [(today, None), (tomorrow, time(1, 46))]
    assert offers == [tonight, after_midnight]


@pytest.mark.asyncio
async def test_the_trip_they_left_is_not_offered_again(monkeypatch: pytest.MonkeyPatch) -> None:
    tomorrow = date(2026, 10, 30)
    same, other = _offer("their own trip"), _offer("another vehicle")
    service, _ = _service(
        monkeypatch, datetime(2026, 10, 29, 23, 30, tzinfo=UTC), {tomorrow: [same, other]}
    )

    offers = await service.onward(STOP, exclude_trip_id=same.summary.trip_id, limit=5)

    assert offers == [other]
