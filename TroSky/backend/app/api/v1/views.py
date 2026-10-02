"""Response builders shared by more than one router."""

from __future__ import annotations

import uuid
from collections.abc import Sequence

from app.core.config import get_settings
from app.models.bookings import Booking
from app.models.drivers import Driver
from app.models.identity import UserProfile
from app.models.payments import PaymentMethod
from app.models.safety import Incident
from app.providers.payments.base import PaymentChannel
from app.providers.storage.base import ObjectStorageProvider
from app.repositories.trip_view_repository import TripSummary
from app.schemas.booking import (
    BookingPassengerResponse,
    BookingResponse,
    BookingTripSummaryResponse,
)
from app.schemas.driver import DriverResponse
from app.schemas.feedback import DriverRatingSummaryResponse
from app.schemas.payment import (
    PayBookingRequest,
    PaymentMethodResponse,
    WalletTopupRequest,
)
from app.schemas.safety import IncidentResponse
from app.schemas.trip import LiveTripResponse
from app.services.booking_service import BookingService, BookingView
from app.services.driver_service import DriverService
from app.services.payment_method_service import PaymentMethodService
from app.services.rating_service import RatingService
from app.services.tracking_service import LiveLocation
from app.utilities.phone import mask_phone_number


async def avatar_url(profile: UserProfile, storage: ObjectStorageProvider) -> str | None:
    """A signed, short-lived URL for an uploaded photo; else the URL set by hand."""
    if profile.avatar_storage_key:
        return await storage.generate_download_url(
            profile.avatar_storage_key,
            expires_in_seconds=get_settings().AVATAR_URL_TTL_SECONDS,
        )
    return profile.avatar_url


async def incident_response(incident: Incident, storage: ObjectStorageProvider) -> IncidentResponse:
    photo_url = None
    if incident.photo_storage_key:
        photo_url = await storage.generate_download_url(
            incident.photo_storage_key,
            expires_in_seconds=get_settings().S3_PRESIGNED_URL_TTL_SECONDS,
        )
    return IncidentResponse.model_validate(incident).model_copy(update={"photo_url": photo_url})


async def driver_responses(
    drivers: Sequence[Driver], service: DriverService
) -> list[DriverResponse]:
    """Driver profiles with the account's name and phone, in one lookup."""
    contacts = await service.contacts_for(drivers)
    responses = []
    for driver in drivers:
        full_name, phone_number = contacts.get(driver.user_id, (None, None))
        responses.append(
            DriverResponse.model_validate(driver).model_copy(
                update={"full_name": full_name, "phone_number": phone_number}
            )
        )
    return responses


async def driver_response(driver: Driver, service: DriverService) -> DriverResponse:
    return (await driver_responses([driver], service))[0]


async def rating_summary(
    driver_id: uuid.UUID, ratings: RatingService
) -> DriverRatingSummaryResponse:
    average, count = await ratings.get_driver_average_rating(driver_id)
    categories = await ratings.get_driver_category_averages(driver_id)
    return DriverRatingSummaryResponse(
        driver_id=driver_id,
        average_score=average,
        rating_count=count,
        safety_average=categories["safety"],
        cleanliness_average=categories["cleanliness"],
        professionalism_average=categories["professionalism"],
        timeliness_average=categories["timeliness"],
    )


async def payment_source(
    body: PayBookingRequest | WalletTopupRequest,
    user_id: uuid.UUID,
    methods: PaymentMethodService,
) -> tuple[PaymentChannel, str | None]:
    """The channel and number to charge: a saved method's, or as sent."""
    if body.payment_method_id is not None:
        method = await methods.get_method(user_id, body.payment_method_id)
        return method.channel, method.phone_number
    assert body.channel is not None  # one of the two is required by the schema
    return body.channel, body.payer_phone_number


def payment_method_response(method: PaymentMethod) -> PaymentMethodResponse:
    return PaymentMethodResponse(
        id=method.id,
        channel=method.channel,
        masked_number=mask_phone_number(method.phone_number),
        label=method.label,
        is_default=method.is_default,
        created_at=method.created_at,
    )


def booking_response(view: BookingView) -> BookingResponse:
    booking, trip = view.booking, view.trip
    return BookingResponse(
        id=booking.id,
        booking_reference=booking.booking_reference,
        trip_id=booking.trip_id,
        status=booking.status,
        passenger_count=booking.passenger_count,
        origin_stop_id=booking.origin_stop_id,
        destination_stop_id=booking.destination_stop_id,
        fare_amount=booking.fare_amount,
        platform_fee=booking.platform_fee,
        total_amount=booking.total_amount,
        expires_at=booking.expires_at,
        created_at=booking.created_at,
        passengers=[BookingPassengerResponse.model_validate(p) for p in view.passengers],
        trip=(
            BookingTripSummaryResponse(
                scheduled_departure_at=trip.scheduled_departure_at,
                route_name=trip.route_name,
                origin_stop_name=trip.origin_stop_name,
                destination_stop_name=trip.destination_stop_name,
                status=trip.status,
                vehicle_registration_number=trip.vehicle_registration_number,
            )
            if trip is not None
            else None
        ),
        boarding_stop_name=view.boarding_stop_name,
        alighting_stop_name=view.alighting_stop_name,
    )


async def booking_responses(
    service: BookingService, bookings: Sequence[Booking]
) -> list[BookingResponse]:
    """Build a page of booking responses with a fixed number of queries."""
    return [booking_response(view) for view in await service.describe(bookings)]


def live_trip_response(summary: TripSummary, location: LiveLocation | None) -> LiveTripResponse:
    return LiveTripResponse(
        trip_id=summary.trip_id,
        route_name=summary.route_name,
        vehicle_registration_number=summary.vehicle_registration_number,
        driver_name=summary.driver_name,
        status=summary.status,
        latitude=location.latitude if location else None,
        longitude=location.longitude if location else None,
        heading=location.heading_degrees if location else None,
        updated_at=location.recorded_at if location else None,
        is_stale=location.is_stale if location else None,
    )
