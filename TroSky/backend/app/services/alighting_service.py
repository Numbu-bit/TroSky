"""Passengers getting off, and the seat each one leaves.

A paid passenger is off when the driver (or an admin) marks them so -- at
their stop or before it -- or when the vehicle reaches the stop they booked
to (``on_vehicle_moved``, run for each position the driver's phone sends).
Their seat is then free for the rest of the route: a booking from a stop
still ahead can take it.

When everyone on a booking is off, the booking is complete: the driver's
share of the fare is credited then, as it is for everyone else when the trip
ends, and the passenger is offered vehicles leaving from where they are.
"""

from __future__ import annotations

import uuid
from collections.abc import Sequence
from datetime import UTC, datetime
from decimal import Decimal

from redis.asyncio import Redis
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.admin_events import announce
from app.core.config import Settings, get_settings
from app.core.exceptions import ConflictError, ForbiddenError, NotFoundError, StopNotOnRouteError
from app.core.logging import get_logger
from app.models.bookings import AlightedHow, Booking, BookingPassenger, BookingStatus
from app.models.driver_actions import ActedAs, DriverActionKind
from app.models.notifications import NotificationCategory
from app.models.payments import WalletReferenceType
from app.models.routes import Stop
from app.models.trips import Trip, TripStatus
from app.repositories.booking_repository import BookingRepository
from app.repositories.driver_action_repository import DriverActionRepository
from app.repositories.driver_repository import DriverRepository
from app.repositories.route_geometry import RouteGeometry, RouteGeometryRepository
from app.repositories.trip_repository import TripRepository
from app.services.notification_service import NotificationService
from app.services.vehicle_position import has_reached, latest_position
from app.services.wallet_service import WalletService

logger = get_logger(__name__)

_ON_THE_ROAD = (TripStatus.IN_PROGRESS, TripStatus.PAUSED)


class AlightingService:
    def __init__(
        self, session: AsyncSession, redis: Redis | None = None, settings: Settings | None = None
    ) -> None:
        self._session = session
        self._redis = redis
        self._settings = settings or get_settings()
        self._bookings = BookingRepository(session)
        self._trips = TripRepository(session)
        self._drivers = DriverRepository(session)
        self._geometries = RouteGeometryRepository(session)
        self._actions = DriverActionRepository(session)
        self._wallets = WalletService(session)
        self._notifications = NotificationService(session, self._settings)

    async def mark_off(
        self,
        trip_id: uuid.UUID,
        booking_passenger_id: uuid.UUID,
        *,
        actor_id: uuid.UUID,
        as_admin: bool,
        stop_id: uuid.UUID | None = None,
    ) -> tuple[BookingPassenger, Booking]:
        """The driver (or an admin) says this passenger got off, at
        ``stop_id`` or, not given, the stop the vehicle is nearest."""
        passenger = await self._bookings.get_passenger(booking_passenger_id)
        booking = (
            await self._bookings.get_for_update(passenger.booking_id)
            if passenger is not None
            else None
        )
        trip = await self._trips.get_by_id(trip_id)
        if passenger is None or booking is None or trip is None or booking.trip_id != trip_id:
            raise NotFoundError("Passenger not found on this trip.")
        if not as_admin:
            await self._assert_assigned_driver(trip_id, actor_id)
        if passenger.alighted_at is not None:
            return passenger, booking  # already off
        if trip.status not in _ON_THE_ROAD:
            raise ConflictError(
                "Passengers can only be marked off while the trip is on the road.",
                code="TRIP_NOT_ON_THE_ROAD",
            )
        if booking.status != BookingStatus.CONFIRMED:
            raise ConflictError(
                "Only a passenger who has paid can be marked off.", code="BOOKING_NOT_PAID"
            )
        geometry = (await self._geometries.for_routes([trip.route_id]))[trip.route_id]
        if stop_id is not None and stop_id not in geometry.order:
            raise StopNotOnRouteError(details={"stop_id": str(stop_id)})
        where = stop_id or await self._nearest_stop(trip, geometry)
        await self._alight(
            booking,
            [passenger],
            trip=trip,
            how=AlightedHow.ADMIN if as_admin else AlightedHow.DRIVER,
            stop_id=where,
            actor_id=actor_id,
        )
        return passenger, booking

    async def on_vehicle_moved(self, trip_id: uuid.UUID, latitude: float, longitude: float) -> int:
        """Everyone whose booked stop the vehicle at this position has
        reached is off. Returns how many passengers that was."""
        riding = await self._bookings.list_riding_for_trip(trip_id)
        trip = await self._trips.get_by_id(trip_id) if riding else None
        # Positions also come in before a trip starts (on its way to the
        # first stop, it may pass someone's destination): nobody has
        # arrived anywhere until it is on the road.
        if trip is None or trip.status not in _ON_THE_ROAD:
            return 0
        geometry = (await self._geometries.for_routes([trip.route_id]))[trip.route_id]
        arrived = 0
        for booking_id, stop_id in riding:
            if not has_reached(geometry, stop_id, (latitude, longitude)):
                continue
            booking = await self._bookings.get_for_update(booking_id)
            if booking is None or booking.status != BookingStatus.CONFIRMED:
                continue  # it changed meanwhile
            aboard = [
                p for p in await self._bookings.list_passengers(booking.id) if p.alighted_at is None
            ]
            if not aboard:
                continue
            await self._alight(
                booking, aboard, trip=trip, how=AlightedHow.ARRIVAL, stop_id=stop_id, actor_id=None
            )
            arrived += len(aboard)
        return arrived

    async def complete(
        self,
        booking: Booking,
        *,
        changed_by: uuid.UUID | None,
        reason: str,
        driver_user_id: uuid.UUID | None,
        stop_id: uuid.UUID | None,
    ) -> None:
        """The booking's ride is over: complete it, credit the driver their
        share of the fare, and offer the passenger a way on from ``stop_id``."""
        await self._bookings.set_status(
            booking, new_status=BookingStatus.COMPLETED, changed_by=changed_by, reason=reason
        )
        # A share of the fare only: total_amount also carries TroSky's
        # platform fee, which is not the driver's to share in.
        share_percent = self._settings.DRIVER_EARNINGS_SHARE_PERCENT
        driver_share = (booking.fare_amount * share_percent / Decimal("100")).quantize(
            Decimal("0.01")
        )
        if driver_share > 0 and driver_user_id is not None:
            await self._wallets.credit(
                driver_user_id,
                amount=driver_share,
                reference_type=WalletReferenceType.TRIP_EARNING,
                reference_id=booking.id,
                description=f"Trip earning for booking {booking.booking_reference}",
                idempotency_key=f"trip-earning-{booking.id}",
            )
        if stop_id is not None:
            await self._offer_onward(booking, stop_id)

    async def _alight(
        self,
        booking: Booking,
        passengers: Sequence[BookingPassenger],
        *,
        trip: Trip,
        how: AlightedHow,
        stop_id: uuid.UUID | None,
        actor_id: uuid.UUID | None,
    ) -> None:
        now = datetime.now(UTC)
        for passenger in passengers:
            passenger.alighted_at = now
            passenger.alighted_stop_id = stop_id
            passenger.alighted_how = how
            passenger.alighted_by = actor_id
            await self._bookings.complete_reservation(booking.id, passenger.seat_id)

        driver = await self._trips.get_driver_for_trip(trip.id)
        early = stop_id is not None and stop_id != booking.destination_stop_id
        await self._actions.record(
            kind=DriverActionKind.PASSENGER_ALIGHTED,
            trip_id=trip.id,
            driver_id=driver.id if driver is not None else None,
            acted_as={
                AlightedHow.DRIVER: ActedAs.DRIVER,
                AlightedHow.ADMIN: ActedAs.ADMIN,
                AlightedHow.ARRIVAL: ActedAs.SYSTEM,
            }[how],
            actor_id=actor_id,
            booking_id=booking.id,
            details={
                "passenger_ids": [str(p.id) for p in passengers],
                "stop_id": str(stop_id) if stop_id is not None else None,
                "before_their_stop": early,
            },
        )
        everyone = await self._bookings.list_passengers(booking.id)
        if all(p.alighted_at is not None for p in everyone):
            await self.complete(
                booking,
                changed_by=actor_id,
                reason="Arrived" if how == AlightedHow.ARRIVAL else "Got off",
                driver_user_id=driver.user_id if driver is not None else None,
                stop_id=stop_id,
            )
        if self._redis is not None:
            await self._redis.delete(f"trip:{trip.id}:held_seats")
        announce(
            self._session,
            "passenger.alighted",
            trip_id=trip.id,
            booking_id=booking.id,
            passengers=len(passengers),
            stop_id=stop_id,
            how=how.value,
            before_their_stop=early,
        )
        logger.info(
            "passengers_alighted",
            trip_id=str(trip.id),
            booking_id=str(booking.id),
            count=len(passengers),
            how=how.value,
        )

    async def _offer_onward(self, booking: Booking, stop_id: uuid.UUID) -> None:
        stop = await self._session.get(Stop, stop_id)
        if stop is None:
            return
        await self._notifications.notify(
            booking.passenger_id,
            category=NotificationCategory.TRANSACTIONAL,
            title=f"You're at {stop.name}",
            body=(
                f"Your ride on booking {booking.booking_reference} has ended. Going further? "
                f"See vehicles leaving from {stop.name} soon."
            ),
            data={"booking_id": str(booking.id), "stop_id": str(stop_id), "action": "onward_trips"},
        )

    async def _nearest_stop(self, trip: Trip, geometry: RouteGeometry) -> uuid.UUID | None:
        """The route stop the vehicle is closest to along the route, when its
        position is known."""
        where = await latest_position(self._session, self._redis, self._settings, trip.id)
        if where is None:
            return None
        distances = [
            (abs(km), point.stop_id)
            for point in geometry.points
            if (km := geometry.km_until(point.stop_id, *where)) is not None
        ]
        return min(distances)[1] if distances else None

    async def _assert_assigned_driver(self, trip_id: uuid.UUID, user_id: uuid.UUID) -> None:
        driver = await self._drivers.get_by_user_id(user_id)
        if driver is None:
            raise ForbiddenError("No driver profile is associated with this account.")
        assignment = await self._trips.get_active_driver_assignment(trip_id)
        if assignment is None or assignment.driver_id != driver.id:
            raise ForbiddenError("You are not the assigned driver for this trip.")
