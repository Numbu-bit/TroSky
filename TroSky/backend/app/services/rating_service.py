"""Post-trip ratings: a passenger rates the trip once their booking has
actually completed (``BookingStatus.COMPLETED``, set by
``TripService.end_trip`` — never earlier, so a rating can't be left for a
trip that hasn't happened yet)."""

from __future__ import annotations

import uuid
from decimal import Decimal

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ConflictError, NotFoundError
from app.core.logging import get_logger
from app.models.bookings import BookingStatus
from app.models.feedback import Rating
from app.repositories.booking_repository import BookingRepository
from app.repositories.feedback_repository import RatingAlreadyExistsError, RatingRepository
from app.repositories.trip_repository import TripRepository

logger = get_logger(__name__)


class RatingService:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session
        self._ratings = RatingRepository(session)
        self._bookings = BookingRepository(session)
        self._trips = TripRepository(session)

    async def rate_booking(
        self,
        booking_id: uuid.UUID,
        *,
        passenger_id: uuid.UUID,
        score: int,
        comment: str | None,
        categories: dict[str, int | None] | None = None,
    ) -> Rating:
        booking = await self._bookings.get_by_id(booking_id)
        if booking is None or booking.passenger_id != passenger_id:
            raise NotFoundError("Booking not found.")
        if booking.status != BookingStatus.COMPLETED:
            raise ConflictError("Only a completed trip can be rated.", code="BOOKING_NOT_COMPLETED")

        assignment = await self._trips.get_active_driver_assignment(booking.trip_id)
        driver_id = assignment.driver_id if assignment is not None else None

        try:
            rating = await self._ratings.create(
                booking_id=booking.id,
                trip_id=booking.trip_id,
                passenger_id=passenger_id,
                driver_id=driver_id,
                score=score,
                comment=comment,
                categories=categories,
            )
        except RatingAlreadyExistsError as exc:
            raise ConflictError(
                "This booking has already been rated.", code="ALREADY_RATED"
            ) from exc

        logger.info("booking_rated", booking_id=str(booking_id), score=score)
        return rating

    async def get_rating_for_booking(self, booking_id: uuid.UUID) -> Rating | None:
        return await self._ratings.get_by_booking_id(booking_id)

    async def get_driver_category_averages(self, driver_id: uuid.UUID) -> dict[str, Decimal | None]:
        return await self._ratings.get_driver_category_averages(driver_id)

    async def get_driver_average_rating(self, driver_id: uuid.UUID) -> tuple[Decimal | None, int]:
        return await self._ratings.get_driver_average(driver_id)
