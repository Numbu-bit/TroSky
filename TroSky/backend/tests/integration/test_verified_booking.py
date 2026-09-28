"""With REQUIRE_VERIFIED_ACCOUNT on, only a verified passenger can book."""

from __future__ import annotations

from datetime import UTC, datetime

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.exceptions import AccountNotVerifiedError
from app.models.bookings import BookingStatus
from app.schemas.booking import BookingCreateRequest, PassengerInput
from app.services.booking_service import BookingService
from tests.integration.test_booking_service import _make_bookable_trip

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]


async def test_only_a_verified_passenger_can_book(db_session: AsyncSession, make_user) -> None:
    trip_id, seat_ids, _ = await _make_bookable_trip(db_session, seat_count=1, make_user=make_user)
    request = BookingCreateRequest(
        trip_id=trip_id, passengers=[PassengerInput(seat_id=seat_ids[0], full_name="Ama")]
    )
    service = BookingService(
        db_session, settings=get_settings().model_copy(update={"REQUIRE_VERIFIED_ACCOUNT": True})
    )

    unverified = await make_user()
    with pytest.raises(AccountNotVerifiedError):
        await service.create_booking(unverified.id, request, idempotency_key=None)

    verified = await make_user(email_verified_at=datetime.now(UTC))
    booking = await service.create_booking(verified.id, request, idempotency_key=None)
    assert booking.status == BookingStatus.PENDING
