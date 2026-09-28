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
from datetime import UTC, datetime
from decimal import Decimal

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings, get_settings
from app.core.exceptions import (
    ConflictError,
    ForbiddenError,
    InvalidStateTransitionError,
    NotFoundError,
)
from app.core.logging import get_logger
from app.models.bookings import BookingStatus
from app.models.drivers import ApprovalStatus
from app.models.payments import WalletReferenceType
from app.models.trips import Trip, TripEventType, TripStatus
from app.repositories.booking_repository import BookingRepository
from app.repositories.driver_repository import DriverRepository
from app.repositories.trip_repository import TripRepository
from app.repositories.vehicle_repository import VehicleRepository
from app.services.wallet_service import WalletService

logger = get_logger(__name__)

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
        self._wallets = WalletService(session)

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
        await self._trips.set_status(
            trip, new_status=TripStatus.CANCELLED, changed_by=cancelled_by, reason=reason
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

    async def assert_is_assigned_driver(self, trip_id: uuid.UUID, user_id: uuid.UUID) -> uuid.UUID:
        """Public wrapper around :meth:`_resolve_assigned_driver_id` — the
        same "is this caller actually the trip's assigned driver" guard,
        exposed for other domains (ticket validation) that need it without
        duplicating the check."""
        return await self._resolve_assigned_driver_id(trip_id, user_id)

    async def start_trip(self, trip_id: uuid.UUID, user_id: uuid.UUID) -> Trip:
        trip = await self._trips.get_for_update(trip_id)
        if trip is None:
            raise NotFoundError("Trip not found.")

        driver_id = await self._resolve_assigned_driver_id(trip_id, user_id)

        if trip.status == TripStatus.IN_PROGRESS:
            return trip  # idempotent: already started by this same driver
        self._assert_transition_allowed(trip.status, TripStatus.IN_PROGRESS)

        vehicle_assignment = await self._trips.get_active_vehicle_assignment(trip_id)
        if vehicle_assignment is None:
            raise ConflictError("This trip has no vehicle assigned yet.")
        vehicle = await self._vehicles.get_by_id(vehicle_assignment.vehicle_id)
        if vehicle is None or vehicle.status != ApprovalStatus.APPROVED:
            raise ForbiddenError("The assigned vehicle is not approved.")

        conflict = await self._trips.find_conflicting_active_trip_for_driver(
            driver_id, exclude_trip_id=trip_id
        )
        if conflict is not None:
            raise ConflictError(
                "This driver already has another active trip in progress.",
                code="DRIVER_HAS_CONFLICTING_TRIP",
            )

        trip.actual_departure_at = datetime.now(UTC)
        await self._trips.set_status(
            trip, new_status=TripStatus.IN_PROGRESS, changed_by=user_id, reason="Trip started"
        )
        await self._trips.record_event(trip.id, TripEventType.TRIP_STARTED)
        logger.info("trip_started", trip_id=str(trip_id), driver_id=str(driver_id))
        return trip

    async def pause_trip(self, trip_id: uuid.UUID, user_id: uuid.UUID, reason: str | None) -> Trip:
        trip = await self._trips.get_for_update(trip_id)
        if trip is None:
            raise NotFoundError("Trip not found.")
        await self._resolve_assigned_driver_id(trip_id, user_id)

        if trip.status == TripStatus.PAUSED:
            return trip  # idempotent
        self._assert_transition_allowed(trip.status, TripStatus.PAUSED)

        await self._trips.set_status(
            trip, new_status=TripStatus.PAUSED, changed_by=user_id, reason=reason
        )
        await self._trips.record_event(
            trip.id, TripEventType.TRIP_PAUSED, {"reason": reason} if reason else None
        )
        return trip

    async def resume_trip(self, trip_id: uuid.UUID, user_id: uuid.UUID) -> Trip:
        trip = await self._trips.get_for_update(trip_id)
        if trip is None:
            raise NotFoundError("Trip not found.")
        await self._resolve_assigned_driver_id(trip_id, user_id)

        if trip.status == TripStatus.IN_PROGRESS:
            return trip  # idempotent
        self._assert_transition_allowed(trip.status, TripStatus.IN_PROGRESS)

        await self._trips.set_status(
            trip, new_status=TripStatus.IN_PROGRESS, changed_by=user_id, reason="Trip resumed"
        )
        await self._trips.record_event(trip.id, TripEventType.TRIP_RESUMED)
        return trip

    async def end_trip(
        self,
        trip_id: uuid.UUID,
        user_id: uuid.UUID,
        *,
        latitude: Decimal | None = None,
        longitude: Decimal | None = None,
    ) -> Trip:
        trip = await self._trips.get_for_update(trip_id)
        if trip is None:
            raise NotFoundError("Trip not found.")
        driver_id = await self._resolve_assigned_driver_id(trip_id, user_id)

        if trip.status == TripStatus.COMPLETED:
            return trip  # idempotent: already ended

        self._assert_transition_allowed(trip.status, TripStatus.COMPLETED)

        trip.actual_arrival_at = datetime.now(UTC)
        await self._trips.set_status(
            trip,
            new_status=TripStatus.COMPLETED,
            changed_by=user_id,
            reason="Trip completed",
            latitude=latitude,
            longitude=longitude,
        )
        confirmed_bookings = await self._bookings.list_confirmed_for_trip(trip.id)
        share_percent = self._settings.DRIVER_EARNINGS_SHARE_PERCENT
        for booking in confirmed_bookings:
            await self._bookings.set_status(
                booking,
                new_status=BookingStatus.COMPLETED,
                changed_by=user_id,
                reason="Trip completed",
            )
            # A share of the fare only: total_amount also carries TroSky's
            # platform fee, which is not the driver's to share in.
            driver_share = (booking.fare_amount * share_percent / Decimal("100")).quantize(
                Decimal("0.01")
            )
            if driver_share > 0:
                # `user_id` here is the calling driver's own account — the
                # same identity `_resolve_assigned_driver_id` just verified
                # is this trip's assigned driver, so no extra lookup is
                # needed to know whose wallet to credit.
                await self._wallets.credit(
                    user_id,
                    amount=driver_share,
                    reference_type=WalletReferenceType.TRIP_EARNING,
                    reference_id=booking.id,
                    description=f"Trip earning for booking {booking.booking_reference}",
                    idempotency_key=f"trip-earning-{booking.id}",
                )
        # Remaining downstream effects that depend on later phases
        # (fleet-owner revenue share, settlement batching, a "trip
        # completed" passenger notification, analytics) are not yet
        # wired — this event is the hook those phases' consumers
        # subscribe to. Booking completion (-> rating eligibility, Phase 9)
        # and driver earnings (Phase 10) are wired as of now.
        end_location: dict[str, object] = {
            "latitude": str(latitude) if latitude else None,
            "longitude": str(longitude) if longitude else None,
        }
        await self._trips.record_event(trip.id, TripEventType.TRIP_COMPLETED, end_location)
        logger.info("trip_completed", trip_id=str(trip_id), driver_id=str(driver_id))
        return trip

    @staticmethod
    def _assert_transition_allowed(current: TripStatus, target: TripStatus) -> None:
        if target not in TRIP_TRANSITIONS.get(current, set()):
            raise InvalidStateTransitionError(
                f"Cannot transition a trip from '{current.value}' to '{target.value}'."
            )
