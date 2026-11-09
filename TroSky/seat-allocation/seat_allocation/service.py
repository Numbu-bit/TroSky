"""One trip's seats over time: the operations behind the API contract.

The rules it keeps, whatever order events arrive in:

- A passenger who has boarded never moves.
- After the lock, nobody moves without choosing to. The one exception is a passenger
  whose seat was taken by someone boarding in the wrong place.
- A seat holds one passenger at a time. Two may share it only on stretches of the route
  that do not overlap.
- Every seat change is written to an append-only audit log with its reason.

This is an in-memory reference. In the backend the same rules run against the tables in
``schema.sql``, inside one transaction per event.
"""

from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass, replace
from datetime import UTC, datetime, timedelta
from enum import StrEnum

from .allocator import Allocation, BlockingPair, allocate, evaluate
from .config import SeatConfig
from .layout import SeatLayout
from .messages import seat_reason
from .model import (
    UNSEATED,
    Booking,
    BookingError,
    FixedReason,
    FixedSeat,
    Problem,
    cluster_positions,
)
from .online import ZonePlan, build_zone_plan, choose_seat
from .route import Destination, DestinationStatus, Route, resolve_point, resolve_stop


class SeatStatus(StrEnum):
    PROVISIONAL = "provisional"
    LOCKED = "locked"
    BOARDED = "boarded"
    ALIGHTED = "alighted"
    CANCELLED = "cancelled"
    NO_SHOW = "no_show"


ACTIVE = (SeatStatus.PROVISIONAL, SeatStatus.LOCKED, SeatStatus.BOARDED)


class SeatServiceError(Exception):
    """An operation was refused. ``code`` matches the API's error envelope."""

    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code
        self.message = message


@dataclass(frozen=True)
class AuditEntry:
    seq: int
    at: datetime
    action: str
    booking_id: str | None
    from_seat: str | None
    to_seat: str | None
    reason: str
    run_id: int | None = None


@dataclass(frozen=True)
class AssignmentRun:
    id: int
    at: datetime
    trigger: str
    mode: str
    blocking_before: int
    blocking_after: int
    minimum_blocking: int | None
    proof: str
    seats_changed: int


@dataclass(frozen=True)
class Override:
    booking_id: str
    seat: str
    previous_seat: str | None
    added_blocking: int
    at: datetime


@dataclass(frozen=True)
class SeatMove:
    booking_id: str
    from_seat: str | None
    to_seat: str


@dataclass(frozen=True)
class BookingResult:
    booking_id: str
    seat: str
    provisional: bool
    message: str
    moved: tuple[SeatMove, ...] = ()
    warnings: tuple[str, ...] = ()


@dataclass(frozen=True)
class SwapQuote:
    allowed: bool
    reason: str
    booking_id: str
    current_seat: str | None
    target_seat: str
    blocking_now: int = 0
    blocking_after: int = 0
    added_blocking: int = 0
    other_moves: tuple[SeatMove, ...] = ()
    warning: str | None = None


@dataclass(frozen=True)
class AlightResult:
    booking_id: str
    seat: str | None
    had_to_move: tuple[str, ...]  # the blocking event, as it really happened


@dataclass(frozen=True)
class SeatRow:
    seat: str
    booking_id: str | None
    status: str | None
    alight: float | None
    next_off: bool


@dataclass(frozen=True)
class SeatMap:
    trip_id: str
    locked: bool
    rows: tuple[SeatRow, ...]  # rearmost seat first
    boarding_order: tuple[str, ...]
    next_off: tuple[str, ...]
    blocking_pairs: tuple[BlockingPair, ...]


@dataclass(frozen=True)
class Trip:
    id: str
    vehicle_id: str
    departure_cutoff: datetime
    route: Route | None = None
    pickup_position: float = 0.0


class TripSeatService:
    def __init__(
        self,
        trip: Trip,
        layout: SeatLayout,
        config: SeatConfig,
        *,
        clock: Callable[[], datetime] | None = None,
        demand_history: tuple[float, ...] = (),
    ) -> None:
        self.trip = trip
        self.layout = layout
        self.config = config
        self.clock = clock or (lambda: datetime.now(UTC))
        self.demand_history = demand_history
        self.bookings: dict[str, Booking] = {}
        self.status: dict[str, SeatStatus] = {}
        self.seats: dict[str, str] = {}
        self.overrides: dict[str, Override] = {}
        self.runs: list[AssignmentRun] = []
        self.locked = False
        self.blocking_events = 0  # moves that really happened, a pilot KPI
        self.seat_ignored_count = 0  # passengers who sat elsewhere, a pilot KPI
        self._audit: list[AuditEntry] = []
        self._destinations: dict[str, tuple] = {}
        self._booking_sequence = 0
        self.lock_at = trip.departure_cutoff - timedelta(
            minutes=config.assignment.lock_minutes_before_departure
        )

    # ---------------------------------------------------------------- reading

    @property
    def audit(self) -> tuple[AuditEntry, ...]:
        return tuple(self._audit)

    def active(self) -> list[Booking]:
        return [b for b in self.bookings.values() if self.status[b.id] in ACTIVE]

    def boarded(self) -> set[str]:
        return {b for b, status in self.status.items() if status is SeatStatus.BOARDED}

    def current_blocking(self) -> tuple[int, list[BlockingPair]]:
        count, _, pairs = evaluate(
            self.layout, self.active(), self.seats, self.config, boarded=self.boarded()
        )
        return count, pairs

    def seat_map(self) -> SeatMap:
        self._refresh_lock()
        active = self.active()
        by_seat: dict[str, list[Booking]] = {}
        for booking in active:
            by_seat.setdefault(self.seats[booking.id], []).append(booking)
        on_board_next = self._next_off(active)
        rows = []
        for seat in self.layout.bookable_seats():
            users = sorted(by_seat.get(seat.id, []), key=lambda b: b.board)
            if not users:
                rows.append(SeatRow(seat.id, None, None, None, False))
            for booking in users:
                rows.append(
                    SeatRow(
                        seat.id,
                        booking.id,
                        str(self.status[booking.id]),
                        booking.alight,
                        booking.id in on_board_next,
                    )
                )
        _, pairs = self.current_blocking()
        rank = {seat.id: i for i, seat in enumerate(self.layout.bookable_seats())}
        to_board = sorted(
            (b for b in active if self.status[b.id] is not SeatStatus.BOARDED),
            key=lambda b: (b.board, rank.get(self.seats[b.id], len(rank)), b.id),
        )
        return SeatMap(
            trip_id=self.trip.id,
            locked=self.locked,
            rows=tuple(rows),
            boarding_order=tuple(b.id for b in to_board),
            next_off=tuple(on_board_next),
            blocking_pairs=tuple(pairs),
        )

    def _next_off(self, active: list[Booking]) -> list[str]:
        """Passengers getting off at the next stop. Counts everyone before boarding starts."""
        on_board = [b for b in active if self.status[b.id] is SeatStatus.BOARDED] or active
        if not on_board:
            return []
        tolerance = self.config.assignment.same_stop_tolerance_km
        stops = cluster_positions([b.alight for b in on_board], tolerance)
        first = min(stops.values())
        return sorted(b.id for b in on_board if stops[b.alight] == first)

    def passenger_message(self, booking_id: str) -> str:
        booking = self._active_booking(booking_id)
        return seat_reason(booking, self._view(), self.layout, chosen=booking_id in self.overrides)

    def _view(self) -> Allocation:
        """The seating as it stands, in the allocator's report form."""
        fixed = {
            b.id: FixedSeat(self.seats[b.id], FixedReason.LOCKED)
            for b in self.active()
            if b.id in self.seats
        }
        return allocate(
            self.layout, self.active(), self.config, fixed=fixed, boarded=self.boarded()
        )

    # ------------------------------------------------------------- the audit log

    def _log(
        self,
        action: str,
        booking_id: str | None,
        from_seat: str | None,
        to_seat: str | None,
        reason: str,
        run_id: int | None = None,
    ) -> None:
        self._audit.append(
            AuditEntry(
                len(self._audit) + 1,
                self.clock(),
                action,
                booking_id,
                from_seat,
                to_seat,
                reason,
                run_id,
            )
        )

    def _set_seat(self, booking_id: str, seat: str, reason: str, run_id: int | None = None) -> None:
        previous = self.seats.get(booking_id)
        if previous == seat:
            return
        self.seats[booking_id] = seat
        action = "seat_assigned" if previous is None else "seat_changed"
        self._log(action, booking_id, previous, seat, reason, run_id)

    # -------------------------------------------------------------- re-allocation

    def _refresh_lock(self) -> None:
        if not self.locked and self.clock() >= self.lock_at:
            self.lock("the lock time was reached")

    def _fixed(self) -> dict[str, FixedSeat]:
        fixed: dict[str, FixedSeat] = {}
        for booking in self.active():
            seat = self.seats.get(booking.id)
            if seat is None:
                continue
            if self.status[booking.id] is SeatStatus.BOARDED:
                fixed[booking.id] = FixedSeat(seat, FixedReason.BOARDED)
            elif booking.id in self.overrides:
                fixed[booking.id] = FixedSeat(seat, FixedReason.OVERRIDE)
            elif self.locked:
                fixed[booking.id] = FixedSeat(seat, FixedReason.LOCKED)
        return fixed

    def _allocate(self, provisional: dict[str, str] | None = None) -> Allocation:
        """Work out the best seating for everyone still free to move. Changes nothing."""
        online = self.config.assignment.mode == "online"
        return allocate(
            self.layout,
            self.active(),
            self.config,
            fixed=self._fixed(),
            current={**self.seats, **(provisional or {})} if online else None,
            boarded=self.boarded(),
            hold_reserved=online and not self.locked,
        )

    def _run(self, trigger: str) -> tuple[SeatMove, ...]:
        return self._apply(self._allocate(), trigger)

    def _apply(self, allocation: Allocation, trigger: str) -> tuple[SeatMove, ...]:
        """Put a seating into effect and record why."""
        run_id = len(self.runs) + 1
        moves = []
        for booking in self.active():
            new_seat = allocation.seats.get(booking.id)
            old_seat = self.seats.get(booking.id)
            if new_seat is not None and new_seat != old_seat:
                self._set_seat(booking.id, new_seat, trigger, run_id)
                if old_seat is not None:
                    moves.append(SeatMove(booking.id, old_seat, new_seat))
        self.runs.append(
            AssignmentRun(
                run_id,
                self.clock(),
                trigger,
                self.config.assignment.mode,
                allocation.blocking_before,
                allocation.blocking_after,
                allocation.minimum_blocking,
                allocation.proof,
                len(moves),
            )
        )
        return tuple(moves)

    def lock(self, reason: str = "locked by staff") -> None:
        """A last optimisation, then nobody moves unless they choose to."""
        if self.locked:
            return
        self._run(f"final seating: {reason}")
        self.locked = True
        for booking in self.active():
            if self.status[booking.id] is SeatStatus.PROVISIONAL:
                self.status[booking.id] = SeatStatus.LOCKED
        self._log("locked", None, None, None, reason)

    # -------------------------------------------------------------------- booking

    def _resolve(
        self,
        board: float,
        *,
        alight: float | None,
        destination_stop: str | None,
        destination_point: tuple[float, float] | None,
    ) -> Destination:
        route = self.trip.route
        if destination_stop is not None:
            if route is None:
                raise SeatServiceError("NO_ROUTE", "This trip has no route to find the stop on.")
            return resolve_stop(route, destination_stop, board)
        if destination_point is not None:
            if route is None:
                raise SeatServiceError("NO_ROUTE", "This trip has no route to place the point on.")
            return resolve_point(
                route,
                destination_point[0],
                destination_point[1],
                board,
                self.config.route,
                same_stop_km=self.config.assignment.same_stop_tolerance_km,
            )
        if alight is None:
            raise SeatServiceError("NO_DESTINATION", "A booking needs a destination.")
        if alight <= board:
            status = (
                DestinationStatus.SAME_AS_PICKUP
                if alight == board
                else DestinationStatus.BEHIND_PICKUP
            )
            return Destination(status, alight, "The destination must come after the pickup.")
        return Destination(DestinationStatus.OK, alight)

    def _board_position(self, pickup_stop: str | None, board: float | None) -> float:
        if pickup_stop is not None:
            position = self.trip.route.stop_position(pickup_stop) if self.trip.route else None
            if position is None:
                raise SeatServiceError("UNKNOWN_STOP", f"{pickup_stop} is not on this route.")
            return position
        return self.trip.pickup_position if board is None else board

    def create_booking(
        self,
        booking_id: str,
        *,
        alight: float | None = None,
        destination_stop: str | None = None,
        destination_point: tuple[float, float] | None = None,
        board: float | None = None,
        pickup_stop: str | None = None,
        category: str = "standard",
        group_id: str | None = None,
        seat_preference: str | None = None,
        needs_accessible: bool = False,
        luggage: str = "none",
    ) -> BookingResult:
        """Take a booking and return a provisional seat."""
        self._refresh_lock()
        if booking_id in self.bookings:
            raise SeatServiceError("DUPLICATE_BOOKING", f"{booking_id} already exists.")
        position = self._board_position(pickup_stop, board)
        destination = self._resolve(
            position,
            alight=alight,
            destination_stop=destination_stop,
            destination_point=destination_point,
        )
        if not destination.ok or destination.position is None:
            raise SeatServiceError(destination.status.upper(), destination.detail)
        self._booking_sequence += 1
        booking = Booking(
            id=booking_id,
            alight=destination.position,
            board=position,
            category=category,
            group_id=group_id,
            seat_preference=seat_preference,
            booked_at=self._booking_sequence,
            needs_accessible=needs_accessible,
            luggage=luggage,
            alight_name=destination.name,
        )
        self.bookings[booking_id] = booking
        self.status[booking_id] = SeatStatus.LOCKED if self.locked else SeatStatus.PROVISIONAL
        if destination_stop is not None:
            self._destinations[booking_id] = ("stop", destination_stop)
        elif destination_point is not None:
            self._destinations[booking_id] = ("point", *destination_point)
        try:
            moved, warnings = self._seat_new_booking(booking)
        except SeatServiceError:
            self._forget(booking_id)
            raise
        return BookingResult(
            booking_id=booking_id,
            seat=self.seats[booking_id],
            provisional=not self.locked,
            message=self.passenger_message(booking_id),
            moved=moved,
            warnings=warnings,
        )

    def _seat_new_booking(self, booking: Booking) -> tuple[tuple[SeatMove, ...], tuple[str, ...]]:
        """Nothing is moved or logged until it is certain everyone has a seat."""
        online = self.config.assignment.mode == "online"
        reoptimise = not online or self.config.online.reoptimise_on_booking
        provisional: dict[str, str] = {}
        if online or self.locked:
            seat = self._first_seat(booking)
            if seat is not None:
                provisional[booking.id] = seat
            if self.locked or not reoptimise:
                if seat is None:
                    raise SeatServiceError("NO_SEAT", f"{booking.id}: no seat is free.")
                self._set_seat(booking.id, seat, "new booking")
                return (), ()
        allocation = self._allocate(provisional)
        for name, reason in allocation.unseated:
            # A new booking never takes a seat from someone who already has one.
            detail = reason if name == booking.id else "the vehicle is full."
            raise SeatServiceError("NO_SEAT", f"{booking.id}: {detail}")
        return self._apply(allocation, f"new booking {booking.id}"), allocation.warnings

    def _forget(self, booking_id: str) -> None:
        self.bookings.pop(booking_id, None)
        self.status.pop(booking_id, None)
        self.seats.pop(booking_id, None)
        self._destinations.pop(booking_id, None)

    def _problem_for(self, booking: Booking) -> Problem:
        """The trip as it stands, with everyone but this booking staying where they are."""
        return Problem(
            self.layout,
            self.active(),
            self.config,
            fixed={
                b.id: FixedSeat(self.seats[b.id], FixedReason.LOCKED)
                for b in self.active()
                if b.id in self.seats and b.id != booking.id
            },
            boarded=self.boarded(),
            hold_reserved=self.config.assignment.mode == "online" and not self.locked,
        )

    def _zone_plan(self, problem: Problem) -> ZonePlan:
        route_km = self.trip.route.length if self.trip.route else 0.0
        if route_km <= 0:
            route_km = max((b.alight for b in problem.bookings), default=1.0)
        held = [problem.seats[s].id for s in problem.reserved_seats]
        return build_zone_plan(
            self.layout,
            self.config,
            route_km=route_km,
            history=self.demand_history,
            exclude=held if problem.hold_reserved else (),
        )

    def _first_seat(self, booking: Booking) -> str | None:
        """Online insertion: the free seat with the lowest added blocking, by zone. None
        when no seat is free for them unless someone else moves."""
        problem = self._problem_for(booking)
        p = problem.index[booking.id]
        if p in problem.unseated:
            return None
        assign = [UNSEATED] * problem.n
        for q, s in problem.fixed.items():
            assign[q] = s
        seat = choose_seat(problem, p, assign, self._zone_plan(problem))
        return None if seat == UNSEATED else problem.seats[seat].id

    # ---------------------------------------------------------------------- swaps

    def _occupant(self, booking: Booking, seat: str) -> Booking | None:
        tolerance = self.config.assignment.same_stop_tolerance_km
        for other in self.active():
            if other.id == booking.id or self.seats.get(other.id) != seat:
                continue
            if (
                other.board < booking.alight - tolerance
                and booking.board < other.alight - tolerance
            ):
                return other
        return None

    def quote_swap(self, booking_id: str, target_seat: str) -> SwapQuote:
        """What a seat change would cost. Changes nothing."""
        self._refresh_lock()
        booking = self._active_booking(booking_id)
        current = self.seats.get(booking_id)

        def refuse(reason: str) -> SwapQuote:
            return SwapQuote(False, reason, booking_id, current, target_seat)

        if not self.config.assignment.allow_passenger_override:
            return refuse("Seat changes are switched off for this trip.")
        if self.status[booking_id] is SeatStatus.BOARDED:
            return refuse("You are already on board, so your seat can no longer change here.")
        if current == target_seat:
            return refuse("This is already your seat.")
        try:
            seat = self.layout.seat(target_seat)
        except KeyError:
            return refuse("That seat does not exist on this vehicle.")
        if not seat.bookable:
            return refuse("That seat is not for passengers.")
        if booking.needs_accessible and not seat.accessible:
            return refuse("That seat is not accessible.")
        is_priority = booking.category in self.config.priority.categories
        holding_seats = self.config.assignment.mode == "online" and not self.locked
        if "priority" in seat.reserved_for and not is_priority and holding_seats:
            return refuse("That seat is kept for priority passengers until the seats lock.")
        occupant = self._occupant(booking, target_seat)
        if occupant is not None:
            if self.locked:
                return refuse("Seats are locked, and that one is taken.")
            if self.status[occupant.id] is SeatStatus.BOARDED or occupant.id in self.overrides:
                return refuse("That seat is taken.")
            if occupant.category in self.config.priority.categories or occupant.needs_accessible:
                return refuse("That seat is taken by a priority passenger.")

        blocking_now, _ = self.current_blocking()
        moves: tuple[SeatMove, ...] = ()
        if self.locked:
            trial = dict(self.seats)
            trial[booking_id] = target_seat
            blocking_after, _, _ = evaluate(
                self.layout, self.active(), trial, self.config, boarded=self.boarded()
            )
        else:
            fixed = self._fixed()
            fixed[booking_id] = FixedSeat(target_seat, FixedReason.OVERRIDE)
            allocation = allocate(
                self.layout,
                self.active(),
                self.config,
                fixed=fixed,
                current=self.seats,
                boarded=self.boarded(),
                hold_reserved=holding_seats,
            )
            if allocation.unseated:
                return refuse("That would leave another passenger without a seat.")
            blocking_after = allocation.blocking_after
            moves = tuple(
                SeatMove(other, self.seats.get(other), seat_id)
                for other, seat_id in allocation.seats.items()
                if other != booking_id and self.seats.get(other) != seat_id
            )
        added = blocking_after - blocking_now
        warning = None
        if added > 0:
            people = "passenger" if added == 1 else "passengers"
            warning = (
                f"In seat {target_seat}, {added} more {people} would have to move "
                "during the trip so that someone can get off."
            )
        return SwapQuote(
            True,
            "ok",
            booking_id,
            current,
            target_seat,
            blocking_now,
            blocking_after,
            added,
            moves,
            warning,
        )

    def confirm_swap(self, booking_id: str, target_seat: str) -> SwapQuote:
        """Honour a seat request the passenger has seen the cost of."""
        quote = self.quote_swap(booking_id, target_seat)
        if not quote.allowed:
            raise SeatServiceError("SWAP_REFUSED", quote.reason)
        self._set_seat(
            booking_id, target_seat, f"passenger chose it, adding {quote.added_blocking}"
        )
        self.overrides[booking_id] = Override(
            booking_id, target_seat, quote.current_seat, quote.added_blocking, self.clock()
        )
        self._log("override", booking_id, quote.current_seat, target_seat, "passenger's choice")
        for move in quote.other_moves:
            self._set_seat(move.booking_id, move.to_seat, f"{booking_id} chose seat {target_seat}")
        return quote

    # ---------------------------------------------------------------- trip events

    def _active_booking(self, booking_id: str) -> Booking:
        booking = self.bookings.get(booking_id)
        if booking is None or self.status[booking_id] not in ACTIVE:
            raise SeatServiceError("UNKNOWN_BOOKING", f"{booking_id} is not an active booking.")
        return booking

    def mark_boarded(self, booking_id: str, actual_seat: str | None = None) -> str:
        """The ticket was scanned. Returns the seat, which is now fixed for good."""
        self._refresh_lock()
        booking = self._active_booking(booking_id)
        if self.status[booking_id] is SeatStatus.BOARDED:
            return self.seats[booking_id]
        assigned = self.seats[booking_id]
        changed = actual_seat is not None and actual_seat != assigned
        if changed:
            assert actual_seat is not None
            try:
                self.layout.seat(actual_seat)
            except KeyError:
                raise SeatServiceError(
                    "UNKNOWN_SEAT", f"{actual_seat} is not a seat on this vehicle."
                ) from None
            occupant = self._occupant(booking, actual_seat)
            if occupant is not None and self.status[occupant.id] is SeatStatus.BOARDED:
                raise SeatServiceError(
                    "SEAT_TAKEN", f"{occupant.id} is already in seat {actual_seat}."
                )
            self._set_seat(booking_id, actual_seat, "sat somewhere other than their seat")
            self.seat_ignored_count += 1
            if occupant is not None:
                self._reseat_displaced(occupant, assigned, booking_id)
        self.status[booking_id] = SeatStatus.BOARDED
        self._log("boarded", booking_id, None, self.seats[booking_id], "ticket scanned")
        if changed and not self.locked:
            self._run(f"{booking_id} sat elsewhere")
        return self.seats[booking_id]

    def _reseat_displaced(self, occupant: Booking, vacated: str, taken_by: str) -> None:
        """Someone sat in this passenger's seat: the one case where a lock gives way."""
        reason = f"{taken_by} sat in their seat"
        if self._occupant(occupant, vacated) is None:
            self._set_seat(occupant.id, vacated, reason)
            return
        del self.seats[occupant.id]
        seat = self._first_seat(occupant)
        if seat is None:
            self.status[occupant.id] = SeatStatus.CANCELLED
            self._log("unseated", occupant.id, None, None, f"{reason}, and no seat is free")
            return
        self._set_seat(occupant.id, seat, reason)

    def mark_alighted(self, booking_id: str) -> AlightResult:
        """They got off. Records who really had to move, for the pilot's KPI."""
        self._refresh_lock()
        booking = self._active_booking(booking_id)
        seat_id = self.seats.get(booking_id)
        seat = self.layout.seat(seat_id) if seat_id else None
        tolerance = self.config.assignment.same_stop_tolerance_km
        moved = sorted(
            other.id
            for other in self.active()
            if seat is not None
            and other.id != booking_id
            and self.status[other.id] is SeatStatus.BOARDED
            and self.seats.get(other.id) in seat.blockers
            and other.alight - booking.alight > tolerance
        )
        self.blocking_events += len(moved)
        self.status[booking_id] = SeatStatus.ALIGHTED
        self._log("alighted", booking_id, seat_id, None, f"{len(moved)} passengers had to move")
        return AlightResult(booking_id, seat_id, tuple(moved))

    def _leave(self, booking_id: str, status: SeatStatus, reason: str) -> tuple[SeatMove, ...]:
        booking = self._active_booking(booking_id)
        if self.status[booking.id] is SeatStatus.BOARDED:
            raise SeatServiceError("ALREADY_BOARDED", f"{booking_id} is on board.")
        seat = self.seats.pop(booking_id, None)
        self.status[booking_id] = status
        self.overrides.pop(booking_id, None)
        self._log(str(status), booking_id, seat, None, reason)
        return () if self.locked or not self.active() else self._run(reason)

    def cancel_booking(self, booking_id: str) -> tuple[SeatMove, ...]:
        self._refresh_lock()
        return self._leave(booking_id, SeatStatus.CANCELLED, f"{booking_id} cancelled")

    def mark_no_show(self, booking_id: str) -> tuple[SeatMove, ...]:
        self._refresh_lock()
        return self._leave(booking_id, SeatStatus.NO_SHOW, f"{booking_id} did not show up")

    def change_destination(
        self,
        booking_id: str,
        *,
        alight: float | None = None,
        destination_stop: str | None = None,
        destination_point: tuple[float, float] | None = None,
    ) -> SwapQuote:
        """A new drop-off. Re-seats people before the lock; afterwards it reports the cost."""
        self._refresh_lock()
        booking = self._active_booking(booking_id)
        destination = self._resolve(
            booking.board,
            alight=alight,
            destination_stop=destination_stop,
            destination_point=destination_point,
        )
        if not destination.ok or destination.position is None:
            raise SeatServiceError(destination.status.upper(), destination.detail)
        before, _ = self.current_blocking()
        self.bookings[booking_id] = replace(
            booking, alight=destination.position, alight_name=destination.name
        )
        moves: tuple[SeatMove, ...] = ()
        fixed_now = self.locked or self.status[booking_id] is SeatStatus.BOARDED
        try:
            # Both of these refuse a seat that would now be needed by two people at once.
            allocation = None if self.locked else self._allocate()
            if allocation is None:
                after, _ = self.current_blocking()
            elif allocation.unseated:
                raise SeatServiceError(
                    "NO_SEAT", "The vehicle is full on the longer stretch of the route."
                )
        except BookingError:
            self.bookings[booking_id] = booking
            raise SeatServiceError(
                "SEAT_CONFLICT",
                f"Seat {self.seats[booking_id]} is promised to someone else on that stretch.",
            ) from None
        except SeatServiceError:
            self.bookings[booking_id] = booking
            raise
        if destination_stop is not None:
            self._destinations[booking_id] = ("stop", destination_stop)
        elif destination_point is not None:
            self._destinations[booking_id] = ("point", *destination_point)
        else:
            self._destinations.pop(booking_id, None)
        self._log("destination_changed", booking_id, None, None, f"now {destination.position:g}")
        if allocation is not None:
            moves = self._apply(allocation, f"{booking_id} changed destination")
        after, _ = self.current_blocking()
        added = after - before
        warning = None
        if fixed_now and added > 0:
            warning = (
                f"The seat cannot change now, so {added} more moves are expected on this trip."
            )
        seat = self.seats[booking_id]
        return SwapQuote(True, "ok", booking_id, seat, seat, before, after, added, moves, warning)

    def apply_route_change(self, route: Route, reason: str = "route changed") -> tuple[str, ...]:
        """A detour: work out every drop-off again. Returns anyone it strands, for a person."""
        self._refresh_lock()
        self.trip = replace(self.trip, route=route)
        stranded = []
        for booking in self.active():
            kept = self._destinations.get(booking.id)
            if kept is None or self.status[booking.id] is SeatStatus.ALIGHTED:
                continue
            if kept[0] == "stop":
                destination = resolve_stop(route, kept[1], booking.board)
            else:
                destination = resolve_point(
                    route,
                    kept[1],
                    kept[2],
                    booking.board,
                    self.config.route,
                    same_stop_km=self.config.assignment.same_stop_tolerance_km,
                )
            if not destination.ok or destination.position is None:
                stranded.append(booking.id)
                continue
            moved = replace(booking, alight=destination.position)
            seat = self.seats.get(booking.id)
            if (
                seat is not None
                and booking.id in self._fixed()
                and self._occupant(moved, seat) is not None
            ):
                stranded.append(booking.id)  # their seat is promised to someone on that stretch
                continue
            self.bookings[booking.id] = moved
        self._log("route_changed", None, None, None, reason)
        if not self.locked and self.active():
            self._run(reason)
        return tuple(stranded)
