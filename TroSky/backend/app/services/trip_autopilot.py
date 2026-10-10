"""Trips changing status on their own, from what their vehicle does and the
clock, so the status shown is what is actually happening.

From each position the driver's phone sends (``after_position``):

* **Boarding**: the vehicle is at the first stop in the half hour before
  departure. (The first ticket scanned does it too: see
  ``TripService.record_ticket_scan``.)
* **In progress**: having been at the first stop, it has left it, going
  along the route. One first heard from further on, at a later stop after
  the departure time, is under way too.
* **Paused**: it has stood still (within ``TRIP_STILL_METERS``) for
  ``TRIP_AUTO_PAUSE_MINUTES`` away from any stop. Waiting at a stop is not a
  pause. **In progress** again once it moves.
* **Completed**: it has been at the last stop ``TRIP_ARRIVAL_MINUTES``.
  Passengers still aboard arrive, and the driver is paid, as when the
  driver ends the trip.

From the clock (``sweep``, every minute in the worker):

* An in-progress trip whose vehicle has not moved for
  ``TRIP_AUTO_PAUSE_MINUTES`` (still sending positions from the same place,
  or none since) is **paused**; one silent for
  ``TRIP_ARRIVAL_SILENCE_MINUTES`` at its last stop is **completed**.
* A trip still scheduled ``TRIP_NOT_STARTED_CANCEL_MINUTES`` after its
  departure time, with nothing heard from its vehicle for half an hour, is
  **cancelled**: passengers are told, paid ones get a refund request for an
  admin to approve, and the driver is told. Before that,
  ``TRIP_NOT_STARTED_ALERT_MINUTES`` after departure, the operations team
  is alerted (``AdminOpsService.alerts``). Boarding trips are only alerted
  on: their vehicle is there.

Each change is the same one the driver's buttons make, recorded as the
system's with the reason, and the driver can still make any of them by
hand. What the autopilot needs to remember of a vehicle between positions
is kept in Redis for a day (``trip:{id}:autopilot``).
"""

from __future__ import annotations

import json
import uuid
from collections.abc import Awaitable
from dataclasses import asdict, dataclass, fields, replace
from datetime import UTC, datetime, timedelta
from decimal import Decimal
from enum import StrEnum
from typing import Any, cast

from redis.asyncio import Redis
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings, get_settings
from app.core.exceptions import AppError
from app.core.logging import get_logger
from app.models.trips import Trip, TripStatus
from app.repositories.route_geometry import RouteGeometry, RouteGeometryRepository
from app.repositories.trip_repository import TripRepository
from app.services.booking_service import BookingService
from app.services.payment_service import PaymentService
from app.services.trip_service import TripService
from app.utilities.geo import haversine_distance_km

logger = get_logger(__name__)

Point = tuple[float, float]

_MEMORY_TTL_SECONDS = 24 * 3600
# Trips that should have left longer ago than this are left alone: switching
# this on must not sweep up a backlog of old trips.
LOOKBACK = timedelta(hours=24)
# A vehicle heard from this recently is around: its trip is not cancelled.
_HEARD_FROM = timedelta(minutes=30)
_SWEEP_LIMIT = 500

_WATCHED = (TripStatus.SCHEDULED, TripStatus.BOARDING, TripStatus.IN_PROGRESS, TripStatus.PAUSED)


class Move(StrEnum):
    BOARD = "board"
    START = "start"
    PAUSE = "pause"
    RESUME = "resume"
    COMPLETE = "complete"


@dataclass(frozen=True, slots=True)
class Rules:
    window: timedelta
    at_stop_km: float
    left_stop_km: float
    still_km: float
    pause_after: timedelta
    arrival_after: timedelta
    silence: timedelta

    @classmethod
    def from_settings(cls, settings: Settings) -> Rules:
        return cls(
            window=timedelta(minutes=settings.TRIP_AUTO_WINDOW_MINUTES),
            at_stop_km=settings.TRIP_AT_STOP_METERS / 1000,
            left_stop_km=settings.TRIP_LEFT_STOP_METERS / 1000,
            still_km=settings.TRIP_STILL_METERS / 1000,
            pause_after=timedelta(minutes=settings.TRIP_AUTO_PAUSE_MINUTES),
            arrival_after=timedelta(minutes=settings.TRIP_ARRIVAL_MINUTES),
            silence=timedelta(minutes=settings.TRIP_ARRIVAL_SILENCE_MINUTES),
        )


@dataclass(frozen=True, slots=True)
class Memory:
    """What is remembered of a trip's vehicle between positions."""

    # The last position heard, and when.
    seen: Point | None = None
    seen_at: datetime | None = None
    # Where it has been standing (within the still distance), since when.
    still: Point | None = None
    still_since: datetime | None = None
    # It has been at the first stop: leaving it now is departing.
    been_at_first_stop: bool = False
    # It has been away from the last stop (a round trip starts there).
    been_away_from_last_stop: bool = False
    at_last_stop_since: datetime | None = None

    def dumps(self) -> str:
        return json.dumps(asdict(self), default=lambda value: value.isoformat())

    @classmethod
    def loads(cls, raw: str | None) -> Memory:
        if not raw:
            return cls()
        known = {field.name for field in fields(cls)}
        data: dict[str, Any] = {k: v for k, v in json.loads(raw).items() if k in known}
        for name in ("seen_at", "still_since", "at_last_stop_since"):
            if data.get(name):
                data[name] = datetime.fromisoformat(data[name])
        for name in ("seen", "still"):
            if data.get(name):
                data[name] = (float(data[name][0]), float(data[name][1]))
        return cls(**data)


@dataclass(frozen=True, slots=True)
class Fix:
    """A position the driver's phone sent."""

    point: Point
    at: datetime
    # How far off it may be, as the phone says; None when it did not say.
    accuracy_km: float | None = None


@dataclass(frozen=True, slots=True)
class Decision:
    move: Move | None
    reason: str | None
    memory: Memory


# ---------------------------------------------------------------------------
# The decisions: no database, no Redis, no clock of their own.
# ---------------------------------------------------------------------------
def on_position(
    status: TripStatus,
    departure_at: datetime,
    geometry: RouteGeometry,
    memory: Memory,
    fix: Fix,
    rules: Rules,
) -> Decision:
    """What a new position of the trip's vehicle means for the trip."""
    if memory.seen_at is not None and fix.at < memory.seen_at:
        return Decision(None, None, memory)  # a late, out-of-order position
    here = fix.point
    first = _stop(geometry, geometry.origin_stop_id)
    last = _stop(geometry, geometry.destination_stop_id)
    memory = replace(memory, seen=here, seen_at=fix.at)

    moved = False
    if memory.still is None:
        memory = replace(memory, still=here, still_since=fix.at)
    elif _km(here, memory.still) > max(rules.still_km, fix.accuracy_km or 0.0):
        # Further than the phone's own error: it really has moved.
        moved = True
        memory = replace(memory, still=here, still_since=fix.at)

    if first is not None and _km(here, first) <= rules.at_stop_km:
        memory = replace(memory, been_at_first_stop=True)
    if last is not None and _km(here, last) <= rules.at_stop_km:
        if memory.at_last_stop_since is None:
            memory = replace(memory, at_last_stop_since=fix.at)
    else:
        memory = replace(memory, at_last_stop_since=None)
        if last is not None and _km(here, last) > rules.left_stop_km:
            memory = replace(memory, been_away_from_last_stop=True)

    if status in (TripStatus.SCHEDULED, TripStatus.BOARDING):
        departed = _departed(departure_at, geometry, memory, fix, rules)
        if departed is not None:
            return Decision(Move.START, departed, memory)
        if (
            status == TripStatus.SCHEDULED
            and first is not None
            and _km(here, first) <= rules.at_stop_km
            and fix.at >= departure_at - rules.window
        ):
            return Decision(Move.BOARD, "Vehicle at the first stop", memory)
    elif status == TripStatus.IN_PROGRESS:
        if _arrived(geometry, memory, rules) and (
            memory.at_last_stop_since is not None
            and fix.at - memory.at_last_stop_since >= rules.arrival_after
        ):
            return Decision(Move.COMPLETE, _at_last_stop_for(rules), memory)
        if _standing(geometry, memory, fix.at, rules):
            return Decision(Move.PAUSE, _still_for(rules), memory)
    elif status == TripStatus.PAUSED and moved:
        return Decision(Move.RESUME, "Vehicle moving again", memory)
    return Decision(None, None, memory)


def on_clock(
    status: TripStatus, geometry: RouteGeometry, memory: Memory, now: datetime, rules: Rules
) -> Decision:
    """What time passing, with no new position, means for a trip on the
    road."""
    if status != TripStatus.IN_PROGRESS or memory.seen_at is None:
        return Decision(None, None, memory)
    if (
        _arrived(geometry, memory, rules)
        and memory.at_last_stop_since is not None
        and now - memory.seen_at >= rules.silence
    ):
        return Decision(Move.COMPLETE, "GPS went quiet at the last stop", memory)
    if _standing(geometry, memory, now, rules):
        return Decision(Move.PAUSE, _still_for(rules), memory)
    return Decision(None, None, memory)


def _departed(
    departure_at: datetime, geometry: RouteGeometry, memory: Memory, fix: Fix, rules: Rules
) -> str | None:
    first = _stop(geometry, geometry.origin_stop_id)
    if first is None or _km(fix.point, first) <= rules.left_stop_km:
        return None
    if memory.been_at_first_stop and _ahead_on_route(geometry, fix.point, rules):
        return "Vehicle left the first stop"
    # First heard from further on (the phone sent nothing at the first
    # stop). Before the departure time it may just be on its way there.
    if fix.at >= departure_at and any(
        _km(fix.point, point) <= rules.at_stop_km for point in _later_stops(geometry)
    ):
        return "Vehicle on the route past its first stop"
    return None


def _ahead_on_route(geometry: RouteGeometry, here: Point, rules: Rules) -> bool:
    """Gone along the route, not just away from the stop (to fill up, say).
    A route whose stops are not measured cannot tell: then leaving is enough."""
    km = geometry.km_until(geometry.origin_stop_id, *here)
    return km is None or -km >= rules.left_stop_km


def _arrived(geometry: RouteGeometry, memory: Memory, rules: Rules) -> bool:
    """Whether being at the last stop can mean arriving: on a round trip,
    which starts there too, only once the vehicle has been away."""
    first = _stop(geometry, geometry.origin_stop_id)
    last = _stop(geometry, geometry.destination_stop_id)
    round_trip = first is not None and last is not None and _km(first, last) <= rules.left_stop_km
    return memory.been_away_from_last_stop or not round_trip


def _standing(geometry: RouteGeometry, memory: Memory, now: datetime, rules: Rules) -> bool:
    if memory.still is None or memory.still_since is None:
        return False
    if now - memory.still_since < rules.pause_after:
        return False
    # Waiting at a stop (for passengers, at the station) is part of the trip.
    return not any(_km(memory.still, point) <= rules.at_stop_km for point in _stops(geometry))


def _still_for(rules: Rules) -> str:
    return f"Not moved for {_minutes(rules.pause_after)}"


def _at_last_stop_for(rules: Rules) -> str:
    return f"At the last stop for {_minutes(rules.arrival_after)}"


def _minutes(span: timedelta) -> str:
    minutes = int(span.total_seconds() // 60)
    return f"{minutes} minute{'' if minutes == 1 else 's'}"


def _stop(geometry: RouteGeometry, stop_id: uuid.UUID) -> Point | None:
    point = geometry.point(stop_id)
    if point is None or point.latitude is None or point.longitude is None:
        return None
    return point.latitude, point.longitude


def _stops(geometry: RouteGeometry) -> list[Point]:
    return [
        (p.latitude, p.longitude)
        for p in geometry.points
        if p.latitude is not None and p.longitude is not None
    ]


def _later_stops(geometry: RouteGeometry) -> list[Point]:
    return [
        (p.latitude, p.longitude)
        for p in geometry.points
        if p.stop_id != geometry.origin_stop_id
        and p.latitude is not None
        and p.longitude is not None
    ]


def _km(a: Point, b: Point) -> float:
    return haversine_distance_km(a[0], a[1], b[0], b[1])


# ---------------------------------------------------------------------------
# Carrying them out
# ---------------------------------------------------------------------------
@dataclass(frozen=True, slots=True)
class SweepResult:
    paused: int = 0
    completed: int = 0
    cancelled: int = 0


def _memory_key(trip_id: uuid.UUID) -> str:
    return f"trip:{trip_id}:autopilot"


class TripAutopilot:
    def __init__(
        self, session: AsyncSession, redis: Redis, settings: Settings | None = None
    ) -> None:
        self._session = session
        self._redis = redis
        self._settings = settings or get_settings()
        self._rules = Rules.from_settings(self._settings)
        self._trips = TripRepository(session)
        self._geometries = RouteGeometryRepository(session)
        self._service = TripService(session, self._settings)

    @property
    def enabled(self) -> bool:
        return self._settings.TRIP_AUTO_STATUS_ENABLED

    async def after_position(
        self,
        trip_id: uuid.UUID,
        *,
        latitude: float,
        longitude: float,
        recorded_at: datetime,
        accuracy_meters: Decimal | None = None,
    ) -> TripStatus | None:
        """Change the trip's status if this position, just accepted, says
        it has changed. Returns the new status; None when it stays.

        Never raises for a change it cannot make (a driver with another
        trip still going, a vehicle no longer approved): the position was
        fine, and the driver can make the change by hand."""
        if not self.enabled:
            return None
        trip = await self._trips.get_by_id(trip_id)
        if trip is None or trip.status not in _WATCHED:
            return None
        geometry = (await self._geometries.for_routes([trip.route_id])).get(trip.route_id)
        if geometry is None:
            return None
        fix = Fix(
            (latitude, longitude),
            recorded_at,
            float(accuracy_meters) / 1000 if accuracy_meters is not None else None,
        )
        decision = on_position(
            trip.status,
            trip.scheduled_departure_at,
            geometry,
            await self.recall(trip_id),
            fix,
            self._rules,
        )
        return await self._carry_out(
            trip, decision, at=recorded_at, where=fix.point, always_remember=True
        )

    async def sweep(self, now: datetime | None = None) -> SweepResult:
        """What the clock decides: pauses and arrivals the positions could
        not show, and trips that never started."""
        if not self.enabled:
            return SweepResult()
        now = now or datetime.now(UTC)
        paused = completed = 0
        on_the_road = await self._trips.list_in_statuses(
            [TripStatus.IN_PROGRESS], limit=_SWEEP_LIMIT
        )
        geometries = await self._geometries.for_routes({trip.route_id for trip in on_the_road})
        for trip in on_the_road:
            geometry = geometries.get(trip.route_id)
            if geometry is None:
                continue
            memory = await self.recall(trip.id)
            if memory.seen_at is None:
                continue  # never heard from: nothing to go on
            decision = on_clock(trip.status, geometry, memory, now, self._rules)
            # Memory is written back only with a change: a position arriving
            # meanwhile has newer news.
            changed = await self._carry_out(
                trip, decision, at=now, where=memory.seen, always_remember=False
            )
            paused += changed == TripStatus.PAUSED
            completed += changed == TripStatus.COMPLETED
        cancelled = await self._cancel_never_started(now)
        if paused or completed or cancelled:
            logger.info(
                "trip_autopilot_swept", paused=paused, completed=completed, cancelled=cancelled
            )
        return SweepResult(paused=paused, completed=completed, cancelled=cancelled)

    async def recall(self, trip_id: uuid.UUID) -> Memory:
        raw = await cast(Awaitable[str | bytes | None], self._redis.get(_memory_key(trip_id)))
        return Memory.loads(raw.decode() if isinstance(raw, bytes) else raw)

    async def _remember(self, trip_id: uuid.UUID, memory: Memory) -> None:
        await self._redis.set(_memory_key(trip_id), memory.dumps(), ex=_MEMORY_TTL_SECONDS)

    async def _carry_out(
        self,
        trip: Trip,
        decision: Decision,
        *,
        at: datetime,
        where: Point | None,
        always_remember: bool,
    ) -> TripStatus | None:
        memory = decision.memory
        changed: Trip | None = None
        if decision.move is not None and decision.reason is not None:
            changed = await self._move(trip.id, decision.move, decision.reason, where)
        if changed is not None and changed.status == TripStatus.COMPLETED:
            await self._redis.delete(_memory_key(trip.id))
            return changed.status
        if changed is not None and changed.status == TripStatus.PAUSED:
            # Resumed by hand where it stands, it gets the full time again.
            memory = replace(memory, still_since=at)
        if changed is not None or always_remember:
            await self._remember(trip.id, memory)
        return changed.status if changed is not None else None

    async def _move(
        self, trip_id: uuid.UUID, move: Move, reason: str, where: Point | None
    ) -> Trip | None:
        try:
            async with self._session.begin_nested():
                match move:
                    case Move.BOARD:
                        return await self._service.begin_boarding(trip_id, reason=reason)
                    case Move.START:
                        return await self._service.auto_start(trip_id, reason=reason)
                    case Move.PAUSE:
                        return await self._service.auto_pause(trip_id, reason=reason)
                    case Move.RESUME:
                        return await self._service.auto_resume(trip_id, reason=reason)
                    case Move.COMPLETE:
                        return await self._service.auto_complete(
                            trip_id,
                            reason=reason,
                            latitude=_coordinate(where[0]) if where else None,
                            longitude=_coordinate(where[1]) if where else None,
                        )
        except AppError as error:
            logger.warning(
                "trip_autopilot_held_back",
                trip_id=str(trip_id),
                move=move.value,
                code=error.code,
                why=error.message,
            )
        return None

    async def _cancel_never_started(self, now: datetime) -> int:
        minutes = self._settings.TRIP_NOT_STARTED_CANCEL_MINUTES
        if not minutes:
            return 0
        overdue = await self._trips.list_in_statuses(
            [TripStatus.SCHEDULED],
            departure_from=now - LOOKBACK,
            departure_before=now - timedelta(minutes=minutes),
            limit=_SWEEP_LIMIT,
        )
        reason = f"Not started {_span(minutes)} after its departure time"
        cancelled = 0
        for trip in overdue:
            memory = await self.recall(trip.id)
            if memory.seen_at is not None and now - memory.seen_at < _HEARD_FROM:
                continue  # its vehicle is about: the operations team decides
            try:
                async with self._session.begin_nested():
                    if await self._service.auto_cancel(trip.id, reason=reason) is None:
                        continue
                    bookings = await BookingService(
                        self._session, self._redis, self._settings
                    ).cancel_all_for_trip(trip.id, cancelled_by=None, reason=reason)
                    await PaymentService(self._session, self._settings).queue_refunds(
                        bookings, requested_by=None
                    )
            except AppError as error:
                logger.warning(
                    "trip_autopilot_cancel_held_back", trip_id=str(trip.id), code=error.code
                )
                continue
            cancelled += 1
        return cancelled


def _span(minutes: int) -> str:
    if minutes % 60 == 0:
        hours = minutes // 60
        return f"{hours} hour{'' if hours == 1 else 's'}"
    return f"{minutes} minutes"


def _coordinate(value: float) -> Decimal:
    return Decimal(f"{value:.6f}")
