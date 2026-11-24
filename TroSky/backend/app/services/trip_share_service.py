"""Live-trip links a passenger shares with family and friends.

``POST /bookings/{id}/share`` hands the passenger a link; anyone holding it
sees, without an account, where the vehicle is and roughly when it gets to
the passenger's stop. The link carries a signed token, not a database row
(see ``app.utilities.share_link``).

A link stops working (410, with a ``reason``) when it expires, when the
passenger stops sharing (``DELETE /bookings/{id}/share``), when they arrive
or the trip ends, or when the booking is cancelled.

What it shows is kept to what a worried relative needs: the vehicle, the
driver's first name, the stops, and the vehicle's position while the trip
is under way. No passenger name, no phone numbers, no fares, no other
passengers.
"""

from __future__ import annotations

import uuid
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from enum import StrEnum

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
from app.models.trips import TripStatus
from app.repositories.booking_repository import BookingRepository
from app.repositories.route_geometry import RouteGeometryRepository
from app.repositories.trip_view_repository import (
    ACTIVE_TRIP_STATUSES,
    TripSummary,
    TripViewRepository,
)
from app.services.system_settings_service import is_enabled
from app.services.tracking_service import LiveLocation, TrackingService
from app.utilities.geo import travel_minutes
from app.utilities.share_link import decode_share_token, encode_share_token

_SHAREABLE = (BookingStatus.CONFIRMED,)


class LinkEnded(StrEnum):
    """Why a link no longer opens: ``details.reason`` on its 410."""

    EXPIRED = "expired"
    STOPPED = "stopped"  # the passenger stopped sharing
    ARRIVED = "arrived"  # the passenger got off at their stop
    ENDED = "ended"  # the trip was completed
    CANCELLED = "cancelled"


_ENDED_MESSAGES = {
    LinkEnded.EXPIRED: "This link has expired.",
    LinkEnded.STOPPED: "The passenger stopped sharing this trip.",
    LinkEnded.ARRIVED: "They have arrived. This trip is no longer being shared.",
    LinkEnded.ENDED: "This trip has ended.",
    LinkEnded.CANCELLED: "This trip was cancelled.",
}


def _gone(reason: LinkEnded) -> ShareLinkGoneError:
    return ShareLinkGoneError(_ENDED_MESSAGES[reason], details={"reason": reason.value})


@dataclass(frozen=True, slots=True)
class SharedTrip:
    expires_at: datetime
    summary: TripSummary
    boarding_stop_name: str
    alighting_stop_name: str
    # Where the passenger gets off, for the map; None if the stop has no position.
    alighting_point: tuple[float, float] | None
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
        self._tracking = TrackingService(session, redis, self._settings)

    def _secret(self) -> str:
        return self._settings.SECRET_KEY.get_secret_value()

    async def create_link(
        self, user_id: uuid.UUID, booking_id: uuid.UUID, *, lasts: timedelta | None = None
    ) -> tuple[str, datetime]:
        """A link for the passenger's own paid booking, lasting ``lasts`` or
        ``TRIP_SHARE_LINK_TTL_SECONDS``, whichever is shorter."""
        if not await is_enabled(self._session, "trip_share_links", user_id):
            raise FeatureDisabledError("Sharing trips is not available right now.")
        booking = await self._bookings.get_by_id(booking_id)
        if booking is None or booking.passenger_id != user_id:
            raise NotFoundError("Booking not found.")
        if booking.status not in _SHAREABLE:
            raise ConflictError(
                "Only a paid, upcoming booking can be shared.", code="BOOKING_NOT_SHAREABLE"
            )
        longest = timedelta(seconds=self._settings.TRIP_SHARE_LINK_TTL_SECONDS)
        issued_at = datetime.now(UTC)
        expires_at = (issued_at + min(lasts or longest, longest)).replace(microsecond=0)
        token = encode_share_token(booking.id, expires_at, self._secret(), issued_at=issued_at)
        return token, expires_at

    async def stop_links(self, user_id: uuid.UUID, booking_id: uuid.UUID) -> None:
        """Every link shared for the passenger's booking so far stops opening.
        A link made afterwards works again."""
        booking = await self._bookings.get_by_id(booking_id)
        if booking is None or booking.passenger_id != user_id:
            raise NotFoundError("Booking not found.")
        booking.share_links_revoked_at = datetime.now(UTC)
        await self._session.flush()

    async def open_link(self, token: str) -> SharedTrip:
        decoded = decode_share_token(token, self._secret())
        if decoded is None:
            raise NotFoundError("This link is not valid.")
        if decoded.expires_at <= datetime.now(UTC):
            raise _gone(LinkEnded.EXPIRED)
        booking = await self._bookings.get_by_id(decoded.booking_id)
        if booking is None:
            raise NotFoundError("This link is not valid.")
        stopped = booking.share_links_revoked_at
        if stopped is not None and (decoded.issued_at is None or decoded.issued_at <= stopped):
            raise _gone(LinkEnded.STOPPED)
        if booking.status == BookingStatus.COMPLETED:
            raise _gone(LinkEnded.ARRIVED)
        if booking.status != BookingStatus.CONFIRMED:
            raise _gone(LinkEnded.CANCELLED)

        summary = (await self._views.summaries_by_ids([booking.trip_id]))[booking.trip_id]
        if summary.status == TripStatus.COMPLETED:
            raise _gone(LinkEnded.ENDED)
        if summary.status == TripStatus.CANCELLED:
            raise _gone(LinkEnded.CANCELLED)
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

        point = None
        if alighting and alighting.latitude is not None and alighting.longitude is not None:
            point = (alighting.latitude, alighting.longitude)
        return SharedTrip(
            expires_at=decoded.expires_at,
            summary=summary,
            boarding_stop_name=boarding.name if boarding else summary.origin_stop_name,
            alighting_stop_name=alighting.name if alighting else summary.destination_stop_name,
            alighting_point=point,
            location=location,
            minutes_to_dropoff=minutes,
        )
