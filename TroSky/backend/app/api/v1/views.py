"""Response builders shared by more than one router."""

from __future__ import annotations

from collections.abc import Sequence

from app.models.bookings import Booking
from app.repositories.trip_view_repository import TripSummary
from app.schemas.booking import (
    BookingPassengerResponse,
    BookingResponse,
    BookingTripSummaryResponse,
)
from app.schemas.trip import LiveTripResponse
from app.services.booking_service import BookingService, BookingView
from app.services.tracking_service import LiveLocation


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
