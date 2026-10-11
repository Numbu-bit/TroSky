"""Trip scheduling, assignment, and lifecycle (state machine) business logic.

The state machine is intentionally small and explicit — see
``TRIP_TRANSITIONS`` — and every transition goes through
:meth:`TripService._transition`, which takes a row lock
(``SELECT ... FOR UPDATE``) before checking/changing status so concurrent
requests (an admin cancelling while a driver starts, a double-tapped
"start" button) resolve safely at the database level, not just in
application logic.
"""

from __future__ import annotations

import uuid
from collections.abc import Collection
from dataclasses import dataclass, replace
from datetime import UTC, date, datetime
from decimal import ROUND_DOWN, Decimal

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.admin_events import announce
from app.core.config import Settings, get_settings
from app.core.exceptions import (
    ConflictError,
    ForbiddenError,
    InvalidStateTransitionError,
    NotFoundError,
)
from app.core.logging import get_logger
from app.models.driver_actions import ActedAs, DriverActionKind
from app.models.drivers import ApprovalStatus
from app.models.notifications import NotificationCategory
from app.models.routes import Route
from app.models.trips import (
    AssignmentResponse,
    Trip,
    TripDriverAssignment,
    TripEventType,
    TripStatus,
)
from app.providers.payments.base import PaymentChannel
from app.repositories.booking_repository import BookingRepository
from app.repositories.driver_action_repository import DriverActionRepository
from app.repositories.driver_repository import DriverRepository
from app.repositories.route_geometry import RouteGeometryRepository
from app.repositories.trip_repository import TripRepository
from app.repositories.trip_view_repository import (
    ManifestEntry,
    TripSummary,
    TripViewRepository,
    day_window,
)
from app.repositories.vehicle_repository import VehicleRepository
from app.services.alighting_service import AlightingService
from app.services.notification_service import NotificationService
from app.utilities.phone import (
    InvalidPhoneNumberError,
    mask_phone_number,
    normalize_phone_number,
)

logger = get_logger(__name__)


@dataclass(frozen=True, slots=True)
class SeatReceipt:
    booking_reference: str
    passenger_name: str
    seat_label: str
    # This seat's part of the booking's fare (TroSky's fee excluded).
    amount: Decimal
    channel: PaymentChannel
    paid_at: datetime | None


@dataclass(frozen=True, slots=True)
class ChannelTotal:
    channel: PaymentChannel
    passengers: int
    amount: Decimal


@dataclass(frozen=True, slots=True)
class TripReceipts:
    trip_id: uuid.UUID
    currency: str
    fare_per_seat: Decimal
    total_collected: Decimal
    by_channel: list[ChannelTotal]
    receipts: list[SeatReceipt]


def _seat_amounts(fare: Decimal, seats: int) -> list[Decimal]:
    """Split a booking's fare across its seats to the pesewa, the first seat
    taking any remainder, so the seats always add up to the booking."""
    each = (fare / seats).quantize(Decimal("0.01"), rounding=ROUND_DOWN)
    return [fare - each * (seats - 1)] + [each] * (seats - 1)


@dataclass(frozen=True, slots=True)
class _Driving:
    """The driver a lifecycle change is for, and whether the system made it
    (from the vehicle's position or the clock) rather than the driver."""

    driver_id: uuid.UUID
    driver_user_id: uuid.UUID
    automatic: bool

    @property
    def actor_id(self) -> uuid.UUID | None:
        return None if self.automatic else self.driver_user_id

    @property
    def by(self) -> str:
        return "system" if self.automatic else "driver"


def _automatic(payload: dict[str, object], reason: str | None) -> dict[str, object] | None:
    """A trip event's payload, marked as the system's doing when ``reason``
    (the system's reason) is given."""
    if reason is not None:
        payload = {**payload, "automatic": True, "reason": reason}
    return payload or None


# The complete, explicit trip state machine. Any transition not listed here
# is rejected. Self-transitions are handled separately as idempotent no-ops
# by the driver-facing start/pause/resume/end methods below, not via this
# table (so e.g. IN_PROGRESS -> IN_PROGRESS is never "valid" in general, but
# calling `start_trip` twice is still safe).
TRIP_TRANSITIONS: dict[TripStatus, set[TripStatus]] = {
    TripStatus.SCHEDULED: {TripStatus.BOARDING, TripStatus.IN_PROGRESS, TripStatus.CANCELLED},
    TripStatus.BOARDING: {TripStatus.IN_PROGRESS, TripStatus.CANCELLED},
    TripStatus.IN_PROGRESS: {TripStatus.PAUSED, TripStatus.COMPLETED, TripStatus.CANCELLED},
    TripStatus.PAUSED: {TripStatus.IN_PROGRESS, TripStatus.CANCELLED},
    TripStatus.COMPLETED: set(),
    TripStatus.CANCELLED: set(),
}


class TripService:
    def __init__(self, session: AsyncSession, settings: Settings | None = None) -> None:
        self._session = session
        self._settings = settings or get_settings()
        self._trips = TripRepository(session)
        self._drivers = DriverRepository(session)
        self._vehicles = VehicleRepository(session)
        self._bookings = BookingRepository(session)
        self._views = TripViewRepository(session)
        self._actions = DriverActionRepository(session)
        self._geometries = RouteGeometryRepository(session)
        self._alighting = AlightingService(session, settings=self._settings)
        self._notifications = NotificationService(session, self._settings)

    # ------------------------------------------------------------------
    # Scheduling
    # ------------------------------------------------------------------
    async def create_trip(
        self,
        *,
        route_id: uuid.UUID,
        route_schedule_id: uuid.UUID | None,
        scheduled_departure_at: datetime,
        scheduled_arrival_at: datetime | None,
        fare_amount: Decimal,
        created_by: uuid.UUID | None,
    ) -> Trip:
        trip = await self._trips.create(
            route_id=route_id,
            route_schedule_id=route_schedule_id,
            scheduled_departure_at=scheduled_departure_at,
            scheduled_arrival_at=scheduled_arrival_at,
            fare_amount=fare_amount,
            created_by=created_by,
        )
        await self._trips.record_event(
            trip.id,
            TripEventType.TRIP_SCHEDULED,
            {"scheduled_departure_at": scheduled_departure_at.isoformat()},
        )
        return trip

    async def get_trip(self, trip_id: uuid.UUID) -> Trip:
        trip = await self._trips.get_by_id(trip_id)
        if trip is None:
            raise NotFoundError("Trip not found.")
        return trip

    async def assign_driver(
        self, trip_id: uuid.UUID, driver_id: uuid.UUID, *, assigned_by: uuid.UUID | None
    ) -> None:
        trip = await self.get_trip(trip_id)
        if trip.status not in (TripStatus.SCHEDULED, TripStatus.BOARDING):
            raise InvalidStateTransitionError(
                "Drivers can only be (re)assigned before a trip is in progress."
            )
        driver = await self._drivers.get_by_id(driver_id)
        if driver is None:
            raise NotFoundError("Driver not found.")
        if driver.status != ApprovalStatus.APPROVED:
            raise ForbiddenError("Only an approved driver may be assigned to a trip.")

        existing = await self._trips.get_active_driver_assignment(trip_id)
        if existing is not None:
            await self._trips.unassign_driver(existing)
        await self._trips.assign_driver(trip_id, driver_id, assigned_by)
        route = await self._session.get(Route, trip.route_id)
        await self._notifications.notify(
            driver.user_id,
            category=NotificationCategory.TRANSACTIONAL,
            title="New trip assigned",
            body=(
                f"{route.name if route else 'A trip'}, leaving "
                f"{trip.scheduled_departure_at:%d %b at %H:%M}. Accept or decline it in the app."
            ),
            data={"trip_id": str(trip_id), "action": "trip_assignment"},
        )

    # ------------------------------------------------------------------
    # The driver's answer to a trip
    # ------------------------------------------------------------------
    async def respond(
        self,
        trip_id: uuid.UUID,
        *,
        actor_id: uuid.UUID,
        accept: bool,
        reason: str | None,
        as_admin: bool,
    ) -> TripDriverAssignment:
        """The assigned driver accepts or declines the trip; an admin may
        answer for them. Declined, the trip is left without a driver for the
        operations team to reassign."""
        trip = await self._trips.get_for_update(trip_id)
        if trip is None:
            raise NotFoundError("Trip not found.")
        if trip.status in (TripStatus.COMPLETED, TripStatus.CANCELLED):
            raise InvalidStateTransitionError(f"This trip is {trip.status.value}.")
        if not as_admin:
            await self._resolve_assigned_driver_id(trip_id, actor_id)
        assignment = await self._trips.get_active_driver_assignment(trip_id)
        if assignment is None:
            raise ConflictError("This trip has no driver assigned.", code="TRIP_HAS_NO_DRIVER")

        wanted = AssignmentResponse.ACCEPTED if accept else AssignmentResponse.DECLINED
        if assignment.response == wanted:
            return assignment  # a second tap
        if not accept and trip.status not in (TripStatus.SCHEDULED, TripStatus.BOARDING):
            raise InvalidStateTransitionError(
                "A trip already on the road cannot be declined.", code="TRIP_ALREADY_STARTED"
            )
        await self._trips.record_response(
            assignment, response=wanted, responded_by=actor_id, reason=reason
        )
        await self._actions.record(
            kind=DriverActionKind.TRIP_ACCEPTED if accept else DriverActionKind.TRIP_DECLINED,
            trip_id=trip_id,
            driver_id=assignment.driver_id,
            acted_as=ActedAs.ADMIN if as_admin else ActedAs.DRIVER,
            actor_id=actor_id,
            reason=reason,
        )
        announce(
            self._session,
            "trip.accepted" if accept else "trip.declined",
            trip_id=trip_id,
            driver_id=assignment.driver_id,
            by="admin" if as_admin else "driver",
            reason=reason,
        )
        if as_admin:
            driver = await self._drivers.get_by_id(assignment.driver_id)
            if driver is not None:
                await self._notifications.notify(
                    driver.user_id,
                    category=NotificationCategory.TRANSACTIONAL,
                    title="Trip accepted for you" if accept else "Trip taken off you",
                    body=(
                        "The operations team accepted this trip for you."
                        if accept
                        else "The operations team declined this trip for you"
                        + (f": {reason}" if reason else ".")
                    ),
                    data={"trip_id": str(trip_id), "action": "trip_assignment"},
                )
        logger.info("trip_answered", trip_id=str(trip_id), accepted=accept, as_admin=as_admin)
        return assignment

    async def record_ticket_scan(
        self,
        trip_id: uuid.UUID,
        *,
        driver_id: uuid.UUID,
        actor_id: uuid.UUID,
        booking_id: uuid.UUID,
        ticket_reference: str,
    ) -> None:
        await self._actions.record(
            kind=DriverActionKind.TICKET_SCANNED,
            trip_id=trip_id,
            driver_id=driver_id,
            acted_as=ActedAs.DRIVER,
            actor_id=actor_id,
            booking_id=booking_id,
            details={"ticket_reference": ticket_reference},
        )
        # Passengers getting on: the trip is boarding.
        if self._settings.TRIP_AUTO_STATUS_ENABLED:
            await self.begin_boarding(trip_id, reason="First ticket scanned")

    async def _record_lifecycle(
        self,
        kind: DriverActionKind,
        trip_id: uuid.UUID,
        driver_id: uuid.UUID,
        actor_id: uuid.UUID | None,
        reason: str | None = None,
        *,
        automatic: bool = False,
    ) -> None:
        """What happened to the driver's trip. ``automatic``: the system did
        it from the vehicle's position or the clock, not the driver."""
        await self._actions.record(
            kind=kind,
            trip_id=trip_id,
            driver_id=driver_id,
            acted_as=ActedAs.SYSTEM if automatic else ActedAs.DRIVER,
            actor_id=None if automatic else actor_id,
            reason=reason,
        )

    async def _change_status(
        self,
        trip: Trip,
        new_status: TripStatus,
        *,
        changed_by: uuid.UUID | None,
        reason: str | None,
        by: str,
        latitude: Decimal | None = None,
        longitude: Decimal | None = None,
    ) -> None:
        """Every status change: recorded in the trip's history and shown to
        the operations team at once. ``by``: driver, admin or system."""
        previous = trip.status
        await self._trips.set_status(
            trip,
            new_status=new_status,
            changed_by=changed_by,
            reason=reason,
            latitude=latitude,
            longitude=longitude,
        )
        announce(
            self._session,
            "trip.status_changed",
            trip_id=trip.id,
            previous=previous,
            status=new_status,
            by=by,
            reason=reason,
        )

    async def assign_vehicle(
        self, trip_id: uuid.UUID, vehicle_id: uuid.UUID, *, assigned_by: uuid.UUID | None
    ) -> None:
        trip = await self.get_trip(trip_id)
        if trip.status not in (TripStatus.SCHEDULED, TripStatus.BOARDING):
            raise InvalidStateTransitionError(
                "A vehicle can only be (re)assigned before a trip is in progress."
            )
        vehicle = await self._vehicles.get_by_id(vehicle_id)
        if vehicle is None:
            raise NotFoundError("Vehicle not found.")
        if vehicle.status != ApprovalStatus.APPROVED:
            raise ForbiddenError("Only an approved vehicle may be assigned to a trip.")

        existing = await self._trips.get_active_vehicle_assignment(trip_id)
        if existing is not None:
            await self._trips.unassign_vehicle(existing)
        await self._trips.assign_vehicle(trip_id, vehicle_id, assigned_by)

    async def cancel_trip(
        self, trip_id: uuid.UUID, *, cancelled_by: uuid.UUID | None, reason: str | None
    ) -> Trip:
        trip = await self._trips.get_for_update(trip_id)
        if trip is None:
            raise NotFoundError("Trip not found.")
        if trip.status in (TripStatus.COMPLETED, TripStatus.CANCELLED):
            raise InvalidStateTransitionError(f"A {trip.status.value} trip cannot be cancelled.")
        await self._change_status(
            trip,
            TripStatus.CANCELLED,
            changed_by=cancelled_by,
            reason=reason,
            by="system" if cancelled_by is None else "admin",
        )
        await self._trips.record_event(
            trip.id, TripEventType.TRIP_CANCELLED, {"reason": reason} if reason else None
        )
        return trip

    # ------------------------------------------------------------------
    # Driver-facing lifecycle (state machine)
    # ------------------------------------------------------------------
    async def _resolve_assigned_driver_id(
        self, trip_id: uuid.UUID, user_id: uuid.UUID
    ) -> uuid.UUID:
        """Resolve the caller's driver profile and confirm it is the trip's
        actively assigned driver. Raises otherwise — this is the guard
        against a driver starting/pausing/ending a trip that isn't theirs."""
        driver = await self._drivers.get_by_user_id(user_id)
        if driver is None:
            raise ForbiddenError("No driver profile is associated with this account.")
        assignment = await self._trips.get_active_driver_assignment(trip_id)
        if assignment is None or assignment.driver_id != driver.id:
            raise ForbiddenError("You are not the assigned driver for this trip.")
        return driver.id

    async def get_manifest(self, trip_id: uuid.UUID, user_id: uuid.UUID) -> list[ManifestEntry]:
        """The trip's passenger list, for its assigned driver only. Phone
        numbers are masked: the driver sees enough to confirm a passenger,
        not enough to call them."""
        if await self._trips.get_by_id(trip_id) is None:
            raise NotFoundError("Trip not found.")
        await self._resolve_assigned_driver_id(trip_id, user_id)
        return [
            replace(entry, phone_number=mask_phone_number(_international(entry.phone_number)))
            for entry in await self._views.list_manifest(trip_id)
        ]

    async def get_receipts(self, trip_id: uuid.UUID, user_id: uuid.UUID) -> TripReceipts:
        """What the trip's passengers paid, seat by seat and by payment
        channel, for its assigned driver only. Amounts are the fare, which is
        what the driver's earnings are a share of; TroSky's platform fee is
        left out."""
        trip = await self._trips.get_by_id(trip_id)
        if trip is None:
            raise NotFoundError("Trip not found.")
        await self._resolve_assigned_driver_id(trip_id, user_id)

        seats = await self._views.list_paid_seats(trip_id)
        position: dict[uuid.UUID, int] = {}
        receipts: list[SeatReceipt] = []
        for seat in seats:
            index = position.get(seat.booking_id, 0)
            position[seat.booking_id] = index + 1
            receipts.append(
                SeatReceipt(
                    booking_reference=seat.booking_reference,
                    passenger_name=seat.passenger_name,
                    seat_label=seat.seat_label,
                    amount=_seat_amounts(seat.booking_fare, seat.passenger_count)[index],
                    channel=seat.channel,
                    paid_at=seat.paid_at,
                )
            )

        totals: dict[PaymentChannel, ChannelTotal] = {}
        for receipt in receipts:
            known = totals.get(receipt.channel)
            totals[receipt.channel] = ChannelTotal(
                channel=receipt.channel,
                passengers=(known.passengers if known else 0) + 1,
                amount=(known.amount if known else Decimal("0")) + receipt.amount,
            )
        return TripReceipts(
            trip_id=trip_id,
            currency=self._settings.PAYMENTS_DEFAULT_CURRENCY,
            fare_per_seat=trip.fare_amount,
            total_collected=sum((r.amount for r in receipts), Decimal("0.00")),
            by_channel=sorted(totals.values(), key=lambda total: -total.amount),
            receipts=receipts,
        )

    async def list_trips(
        self,
        *,
        statuses: Collection[TripStatus] | None,
        on_date: date | None,
        route_id: uuid.UUID | None,
        driver_id: uuid.UUID | None,
        limit: int,
        offset: int,
    ) -> tuple[list[TripSummary], int]:
        """Every trip matching the filters, soonest departure first."""
        departure_from, departure_before = day_window(on_date)
        return await self._views.list_summaries(
            statuses=statuses,
            departure_from=departure_from,
            departure_before=departure_before,
            route_id=route_id,
            driver_id=driver_id,
            limit=limit,
            offset=offset,
        )

    async def assert_is_assigned_driver(self, trip_id: uuid.UUID, user_id: uuid.UUID) -> uuid.UUID:
        """Public wrapper around :meth:`_resolve_assigned_driver_id` — the
        same "is this caller actually the trip's assigned driver" guard,
        exposed for other domains (ticket validation) that need it without
        duplicating the check."""
        return await self._resolve_assigned_driver_id(trip_id, user_id)

    async def start_trip(self, trip_id: uuid.UUID, user_id: uuid.UUID) -> Trip:
        trip = await self._locked(trip_id)
        driver_id = await self._resolve_assigned_driver_id(trip_id, user_id)

        if trip.status == TripStatus.IN_PROGRESS:
            return trip  # idempotent: already started by this same driver
        self._assert_transition_allowed(trip.status, TripStatus.IN_PROGRESS)
        await self._start(trip, _Driving(driver_id, user_id, automatic=False), reason=None)
        return trip

    async def pause_trip(self, trip_id: uuid.UUID, user_id: uuid.UUID, reason: str | None) -> Trip:
        trip = await self._locked(trip_id)
        driver_id = await self._resolve_assigned_driver_id(trip_id, user_id)

        if trip.status == TripStatus.PAUSED:
            return trip  # idempotent
        self._assert_transition_allowed(trip.status, TripStatus.PAUSED)
        await self._pause(trip, _Driving(driver_id, user_id, automatic=False), reason=reason)
        return trip

    async def resume_trip(self, trip_id: uuid.UUID, user_id: uuid.UUID) -> Trip:
        trip = await self._locked(trip_id)
        driver_id = await self._resolve_assigned_driver_id(trip_id, user_id)

        if trip.status == TripStatus.IN_PROGRESS:
            return trip  # idempotent
        self._assert_transition_allowed(trip.status, TripStatus.IN_PROGRESS)
        await self._resume(trip, _Driving(driver_id, user_id, automatic=False), reason=None)
        return trip

    async def end_trip(
        self,
        trip_id: uuid.UUID,
        user_id: uuid.UUID,
        *,
        latitude: Decimal | None = None,
        longitude: Decimal | None = None,
    ) -> Trip:
        trip = await self._locked(trip_id)
        driver_id = await self._resolve_assigned_driver_id(trip_id, user_id)

        if trip.status == TripStatus.COMPLETED:
            return trip  # idempotent: already ended

        self._assert_transition_allowed(trip.status, TripStatus.COMPLETED)
        await self._complete(
            trip,
            _Driving(driver_id, user_id, automatic=False),
            reason=None,
            latitude=latitude,
            longitude=longitude,
        )
        return trip

    # ------------------------------------------------------------------
    # The system's own changes, from the vehicle's position and the clock
    # (app.services.trip_autopilot). Each returns None, changing nothing,
    # when the trip is no longer in a status it applies to: a driver or an
    # admin got there first.
    # ------------------------------------------------------------------
    async def begin_boarding(self, trip_id: uuid.UUID, *, reason: str) -> Trip | None:
        trip = await self._locked(trip_id)
        if trip.status != TripStatus.SCHEDULED:
            return None
        await self._change_status(
            trip, TripStatus.BOARDING, changed_by=None, reason=reason, by="system"
        )
        await self._trips.record_event(
            trip.id, TripEventType.BOARDING_STARTED, _automatic({}, reason)
        )
        logger.info("trip_boarding", trip_id=str(trip_id), reason=reason)
        return trip

    async def auto_start(self, trip_id: uuid.UUID, *, reason: str) -> Trip | None:
        found = await self._for_the_system(trip_id, TripStatus.SCHEDULED, TripStatus.BOARDING)
        if found is None:
            return None
        await self._start(*found, reason=reason)
        return found[0]

    async def auto_pause(self, trip_id: uuid.UUID, *, reason: str) -> Trip | None:
        found = await self._for_the_system(trip_id, TripStatus.IN_PROGRESS)
        if found is None:
            return None
        await self._pause(*found, reason=reason)
        return found[0]

    async def auto_resume(self, trip_id: uuid.UUID, *, reason: str) -> Trip | None:
        found = await self._for_the_system(trip_id, TripStatus.PAUSED)
        if found is None:
            return None
        await self._resume(*found, reason=reason)
        return found[0]

    async def auto_complete(
        self,
        trip_id: uuid.UUID,
        *,
        reason: str,
        latitude: Decimal | None = None,
        longitude: Decimal | None = None,
    ) -> Trip | None:
        found = await self._for_the_system(trip_id, TripStatus.IN_PROGRESS)
        if found is None:
            return None
        await self._complete(*found, reason=reason, latitude=latitude, longitude=longitude)
        return found[0]

    async def auto_cancel(self, trip_id: uuid.UUID, *, reason: str) -> Trip | None:
        """Cancel a trip that never started. Only a scheduled one: a trip
        that is boarding has a vehicle and passengers, and is left to the
        operations team. The caller cancels its bookings."""
        trip = await self._locked(trip_id)
        if trip.status != TripStatus.SCHEDULED:
            return None
        await self.cancel_trip(trip_id, cancelled_by=None, reason=reason)
        assignment = await self._trips.get_active_driver_assignment(trip_id)
        driver = (
            await self._drivers.get_by_id(assignment.driver_id) if assignment is not None else None
        )
        if driver is not None:
            route = await self._session.get(Route, trip.route_id)
            await self._notifications.notify(
                driver.user_id,
                category=NotificationCategory.TRANSACTIONAL,
                title="Trip cancelled",
                body=(
                    f"{route.name if route else 'Your trip'}, due to leave "
                    f"{trip.scheduled_departure_at:%d %b at %H:%M}, was cancelled. {reason}."
                ),
                data={"trip_id": str(trip_id), "action": "trip_cancelled"},
            )
        logger.info("trip_cancelled_automatically", trip_id=str(trip_id), reason=reason)
        return trip

    async def _for_the_system(
        self, trip_id: uuid.UUID, *statuses: TripStatus
    ) -> tuple[Trip, _Driving] | None:
        """The trip, locked, and its driver, when it is in one of
        ``statuses``. A trip without a driver has nobody to drive it, or be
        paid for it, so the system leaves it alone."""
        trip = await self._locked(trip_id)
        if trip.status not in statuses:
            return None
        assignment = await self._trips.get_active_driver_assignment(trip_id)
        driver = (
            await self._drivers.get_by_id(assignment.driver_id) if assignment is not None else None
        )
        if driver is None:
            raise ConflictError("This trip has no driver assigned.", code="TRIP_HAS_NO_DRIVER")
        return trip, _Driving(driver.id, driver.user_id, automatic=True)

    # ------------------------------------------------------------------
    # The changes themselves, the trip's status already checked
    # ------------------------------------------------------------------
    async def _start(self, trip: Trip, who: _Driving, *, reason: str | None) -> None:
        vehicle_assignment = await self._trips.get_active_vehicle_assignment(trip.id)
        if vehicle_assignment is None:
            raise ConflictError("This trip has no vehicle assigned yet.")
        vehicle = await self._vehicles.get_by_id(vehicle_assignment.vehicle_id)
        if vehicle is None or vehicle.status != ApprovalStatus.APPROVED:
            raise ForbiddenError("The assigned vehicle is not approved.")

        conflict = await self._trips.find_conflicting_active_trip_for_driver(
            who.driver_id, exclude_trip_id=trip.id
        )
        if conflict is not None:
            raise ConflictError(
                "This driver already has another active trip in progress.",
                code="DRIVER_HAS_CONFLICTING_TRIP",
            )

        assignment = await self._trips.get_active_driver_assignment(trip.id)
        if assignment is not None and assignment.response == AssignmentResponse.PENDING:
            # Driving the trip is accepting it.
            await self._trips.record_response(
                assignment,
                response=AssignmentResponse.ACCEPTED,
                responded_by=who.driver_user_id,
                reason=None,
            )
            await self._record_lifecycle(
                DriverActionKind.TRIP_ACCEPTED,
                trip.id,
                who.driver_id,
                who.driver_user_id,
                "Started it",
                automatic=who.automatic,
            )

        trip.actual_departure_at = datetime.now(UTC)
        await self._change_status(
            trip,
            TripStatus.IN_PROGRESS,
            changed_by=who.actor_id,
            reason=reason or "Trip started",
            by=who.by,
        )
        await self._trips.record_event(
            trip.id, TripEventType.TRIP_STARTED, _automatic({}, reason if who.automatic else None)
        )
        await self._record_lifecycle(
            DriverActionKind.TRIP_STARTED,
            trip.id,
            who.driver_id,
            who.driver_user_id,
            reason,
            automatic=who.automatic,
        )
        logger.info("trip_started", trip_id=str(trip.id), driver_id=str(who.driver_id), by=who.by)

    async def _pause(self, trip: Trip, who: _Driving, *, reason: str | None) -> None:
        await self._change_status(
            trip, TripStatus.PAUSED, changed_by=who.actor_id, reason=reason, by=who.by
        )
        await self._trips.record_event(
            trip.id,
            TripEventType.TRIP_PAUSED,
            _automatic({"reason": reason} if reason else {}, reason if who.automatic else None),
        )
        await self._record_lifecycle(
            DriverActionKind.TRIP_PAUSED,
            trip.id,
            who.driver_id,
            who.driver_user_id,
            reason,
            automatic=who.automatic,
        )
        logger.info("trip_paused", trip_id=str(trip.id), by=who.by, reason=reason)

    async def _resume(self, trip: Trip, who: _Driving, *, reason: str | None) -> None:
        await self._change_status(
            trip,
            TripStatus.IN_PROGRESS,
            changed_by=who.actor_id,
            reason=reason or "Trip resumed",
            by=who.by,
        )
        await self._trips.record_event(
            trip.id, TripEventType.TRIP_RESUMED, _automatic({}, reason if who.automatic else None)
        )
        await self._record_lifecycle(
            DriverActionKind.TRIP_RESUMED,
            trip.id,
            who.driver_id,
            who.driver_user_id,
            reason,
            automatic=who.automatic,
        )
        logger.info("trip_resumed", trip_id=str(trip.id), by=who.by)

    async def _complete(
        self,
        trip: Trip,
        who: _Driving,
        *,
        reason: str | None,
        latitude: Decimal | None,
        longitude: Decimal | None,
    ) -> None:
        trip.actual_arrival_at = datetime.now(UTC)
        await self._change_status(
            trip,
            TripStatus.COMPLETED,
            changed_by=who.actor_id,
            reason=reason or "Trip completed",
            by=who.by,
            latitude=latitude,
            longitude=longitude,
        )
        # Everyone still aboard has arrived. Those who got off earlier were
        # completed (and the driver's share credited) then.
        confirmed_bookings = await self._bookings.list_confirmed_for_trip(trip.id)
        last_stop = (
            (await self._geometries.for_routes([trip.route_id]))[trip.route_id].destination_stop_id
            if confirmed_bookings
            else None
        )
        for booking in confirmed_bookings:
            # The trip's assigned driver is paid: the caller, when the
            # driver ended it (``_resolve_assigned_driver_id`` checked them),
            # else the driver the trip is assigned to.
            await self._alighting.complete(
                booking,
                changed_by=who.actor_id,
                reason=reason or "Trip completed",
                driver_user_id=who.driver_user_id,
                stop_id=booking.destination_stop_id or last_stop,
            )
        # Remaining downstream effects that depend on later phases
        # (fleet-owner revenue share, settlement batching, a "trip
        # completed" passenger notification, analytics) are not yet
        # wired: this event is the hook those phases' consumers
        # subscribe to. Booking completion (-> rating eligibility, Phase 9)
        # and driver earnings (Phase 10) are wired as of now.
        end_location: dict[str, object] = {
            "latitude": str(latitude) if latitude else None,
            "longitude": str(longitude) if longitude else None,
        }
        await self._trips.record_event(
            trip.id,
            TripEventType.TRIP_COMPLETED,
            _automatic(end_location, reason if who.automatic else None),
        )
        await self._record_lifecycle(
            DriverActionKind.TRIP_ENDED,
            trip.id,
            who.driver_id,
            who.driver_user_id,
            reason,
            automatic=who.automatic,
        )
        logger.info("trip_completed", trip_id=str(trip.id), driver_id=str(who.driver_id), by=who.by)

    async def _locked(self, trip_id: uuid.UUID) -> Trip:
        trip = await self._trips.get_for_update(trip_id)
        if trip is None:
            raise NotFoundError("Trip not found.")
        return trip

    @staticmethod
    def _assert_transition_allowed(current: TripStatus, target: TripStatus) -> None:
        if target not in TRIP_TRANSITIONS.get(current, set()):
            raise InvalidStateTransitionError(
                f"Cannot transition a trip from '{current.value}' to '{target.value}'."
            )


def _international(phone: str) -> str:
    """``+233...`` form, so masking keeps the same digits whichever way the
    number was typed at booking."""
    try:
        return normalize_phone_number(phone)
    except InvalidPhoneNumberError:
        return phone
