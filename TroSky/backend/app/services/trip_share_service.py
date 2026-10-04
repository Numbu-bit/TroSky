"""Live-trip links a passenger shares with family and friends.

``POST /bookings/{id}/share`` hands the passenger a link; anyone holding it
sees, without an account, where the vehicle is and roughly when it gets to
the passenger's stop. The link carries a signed token, not a database row
(see ``app.utilities.share_link``), and stops working when it expires or
when the booking is cancelled.

What it shows is kept to what a worried relative needs: the passenger's
and driver's first names, the vehicle, the stops, and the vehicle's
position while the trip is under way. No phone numbers, no other
passengers.
"""

from __future__ import annotations

import uuid
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta

from redis.asyncio import Redis
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings, get_settings
from app.core.exceptions import (
    ConflictError,
    FeatureDisabledError,
    NotFoundError,
    ShareLinkGoneError,
)
from app.models.bookings import BookingStatus
from app.repositories.booking_repository import BookingRepository
from app.repositories.route_geometry import RouteGeometryRepository
from app.repositories.trip_view_repository import (
    ACTIVE_TRIP_STATUSES,
    TripSummary,
    TripViewRepository,
)
from app.repositories.user_repository import UserRepository
from app.services.system_settings_service import is_enabled
from app.services.tracking_service import LiveLocation, TrackingService
from app.utilities.geo import travel_minutes
from app.utilities.share_link import decode_share_token, encode_share_token

_SHAREABLE = (BookingStatus.CONFIRMED,)
# Still worth opening after the trip ends: it then just says "arrived".
_VIEWABLE = (BookingStatus.CONFIRMED, BookingStatus.COMPLETED)


@dataclass(frozen=True, slots=True)
class SharedTrip:
    expires_at: datetime
    passenger_first_name: str | None
    summary: TripSummary
    boarding_stop_name: str
    alighting_stop_name: str
    location: LiveLocation | None
    minutes_to_dropoff: int | None


def first_name(full_name: str | None) -> str | None:
    return full_name.split()[0] if full_name and full_name.strip() else None


class TripShareService:
    def __init__(
        self, session: AsyncSession, redis: Redis, settings: Settings | None = None
    ) -> None:
        self._settings = settings or get_settings()
        self._session = session
        self._bookings = BookingRepository(session)
        self._views = TripViewRepository(session)
        self._geometries = RouteGeometryRepository(session)
        self._users = UserRepository(session)
        self._tracking = TrackingService(session, redis, self._settings)

    def _secret(self) -> str:
        return self._settings.SECRET_KEY.get_secret_value()

    async def create_link(self, user_id: uuid.UUID, booking_id: uuid.UUID) -> tuple[str, datetime]:
        if not await is_enabled(self._session, "trip_share_links", user_id):
            raise FeatureDisabledError("Sharing trips is not available right now.")
        booking = await self._bookings.get_by_id(booking_id)
        if booking is None or booking.passenger_id != user_id:
            raise NotFoundError("Booking not found.")
        if booking.status not in _SHAREABLE:
            raise ConflictError(
                "Only a paid, upcoming booking can be shared.", code="BOOKING_NOT_SHAREABLE"
            )
        expires_at = (
            datetime.now(UTC) + timedelta(seconds=self._settings.TRIP_SHARE_LINK_TTL_SECONDS)
        ).replace(microsecond=0)
        return encode_share_token(booking.id, expires_at, self._secret()), expires_at

    async def open_link(self, token: str) -> SharedTrip:
        decoded = decode_share_token(token, self._secret())
        if decoded is None:
            raise NotFoundError("This link is not valid.")
        booking_id, expires_at = decoded
        if expires_at <= datetime.now(UTC):
            raise ShareLinkGoneError("This link has expired.")
        booking = await self._bookings.get_by_id(booking_id)
        if booking is None:
            raise NotFoundError("This link is not valid.")
        if booking.status not in _VIEWABLE:
            raise ShareLinkGoneError()

        summary = (await self._views.summaries_by_ids([booking.trip_id]))[booking.trip_id]
        geometry = (await self._geometries.for_routes([summary.route_id]))[summary.route_id]
        boards_at = booking.origin_stop_id or geometry.origin_stop_id
        alights_at = booking.destination_stop_id or geometry.destination_stop_id
        boarding, alighting = geometry.point(boards_at), geometry.point(alights_at)

        location: LiveLocation | None = None
        minutes: int | None = None
        if summary.status in ACTIVE_TRIP_STATUSES:
            location = await self._tracking.get_live_location(summary.trip_id)
            if location is not None and not location.is_stale:
                km = geometry.km_until(alights_at, location.latitude, location.longitude)
                if km is not None:
                    minutes = travel_minutes(
                        km,
                        location.speed_kmh,
                        fallback_kmh=self._settings.PICKUP_ETA_AVERAGE_SPEED_KMH,
                    )

        passenger = await self._users.get_by_id(booking.passenger_id)
        return SharedTrip(
            expires_at=expires_at,
            passenger_first_name=first_name(
                passenger.profile.full_name if passenger and passenger.profile else None
            ),
            summary=summary,
            boarding_stop_name=boarding.name if boarding else summary.origin_stop_name,
            alighting_stop_name=alighting.name if alighting else summary.destination_stop_name,
            location=location,
            minutes_to_dropoff=minutes,
        )
