"""Driver-facing trip endpoints: accepting or declining the trip and the
bookings on it, the lifecycle (start/pause/resume/end), boarding and
marking passengers off.

Every route requires the ``driver`` role; the services additionally verify
the caller is the *actively assigned* driver for the specific trip being
acted on — see ``TripService._resolve_assigned_driver_id``.
"""

from __future__ import annotations

import uuid
from datetime import UTC, datetime

from fastapi import APIRouter, Depends, Query

from app.api.dependencies import (
    BookingServiceDep,
    CurrentPrincipal,
    Pagination,
    TicketServiceDep,
    TrackingServiceDep,
    TripServiceDep,
)
from app.api.tracking_dependencies import TripAutopilotDep
from app.api.trip_dependencies import AlightingServiceDep, BookingAcceptanceServiceDep
from app.api.v1.views import booking_responses
from app.core.permissions import SystemRole, require_roles
from app.core.ratelimit import rate_limit
from app.models.bookings import Booking, BookingPassenger
from app.models.trips import TripDriverAssignment
from app.repositories.booking_offer_repository import BookingRequest
from app.schemas.acceptance import (
    AlightRequest,
    AlightResponse,
    BookingRequestResponse,
    DeclineRequest,
    TripAnswerResponse,
)
from app.schemas.booking import BookingResponse
from app.schemas.common import MessageResponse, PaginatedResponse
from app.schemas.driver import (
    ChannelTotalResponse,
    SeatReceiptResponse,
    TripPaymentsResponse,
)
from app.schemas.ticket import TicketResponse, ValidateTicketRequest
from app.schemas.tracking import LiveLocationResponse, LocationPingRequest
from app.schemas.trip import (
    EndTripRequest,
    ManifestEntryResponse,
    PauseTripRequest,
    TripResponse,
)

router = APIRouter(dependencies=[Depends(require_roles(SystemRole.DRIVER))])


def trip_answer(assignment: TripDriverAssignment) -> TripAnswerResponse:
    return TripAnswerResponse(
        trip_id=assignment.trip_id,
        driver_id=assignment.driver_id,
        response=assignment.response,
        responded_at=assignment.responded_at,
        response_reason=assignment.response_reason,
        is_active=assignment.is_active,
    )


def booking_request(request: BookingRequest) -> BookingRequestResponse:
    seconds_left = int((request.expires_at - datetime.now(UTC)).total_seconds())
    return BookingRequestResponse(
        offer_id=request.offer_id,
        booking_id=request.booking_id,
        booking_reference=request.booking_reference,
        trip_id=request.trip_id,
        trip_departure_at=request.trip_departure_at,
        driver_id=request.driver_id,
        expires_at=request.expires_at,
        seconds_left=max(seconds_left, 0),
        passenger_count=request.passenger_count,
        passenger_name=request.passenger_name,
        seat_numbers=request.seat_numbers,
        origin_stop_id=request.origin_stop_id,
        origin_stop_name=request.origin_stop_name,
        destination_stop_id=request.destination_stop_id,
        destination_stop_name=request.destination_stop_name,
        fare_amount=request.fare_amount,
        attempt=request.attempt,
    )


@router.get("/booking-requests", response_model=PaginatedResponse[BookingRequestResponse])
async def list_booking_requests(
    principal: CurrentPrincipal,
    acceptance: BookingAcceptanceServiceDep,
    pagination: Pagination,
    trip_id: uuid.UUID | None = Query(default=None, description="Only this trip's."),
) -> PaginatedResponse[BookingRequestResponse]:
    """Bookings waiting for this driver to accept or decline them, the
    nearest deadline first. A booking still unanswered at ``expires_at``
    goes to another vehicle; the passenger pays only once it is accepted."""
    requests, total = await acceptance.requests_for_driver(
        principal.user_id, trip_id=trip_id, limit=pagination.limit, offset=pagination.offset
    )
    return PaginatedResponse(
        items=[booking_request(r) for r in requests],
        total=total,
        limit=pagination.limit,
        offset=pagination.offset,
    )


@router.post("/{trip_id}/accept", response_model=TripAnswerResponse)
async def accept_trip(
    trip_id: uuid.UUID, principal: CurrentPrincipal, service: TripServiceDep
) -> TripAnswerResponse:
    """Take the trip you were assigned. Starting it, or accepting a booking
    on it, also counts as accepting it."""
    assignment = await service.respond(
        trip_id, actor_id=principal.user_id, accept=True, reason=None, as_admin=False
    )
    return trip_answer(assignment)


@router.post("/{trip_id}/decline", response_model=TripAnswerResponse)
async def decline_trip(
    trip_id: uuid.UUID, body: DeclineRequest, principal: CurrentPrincipal, service: TripServiceDep
) -> TripAnswerResponse:
    """Turn the trip down, before it starts. You are taken off it and the
    operations team assigns another driver."""
    assignment = await service.respond(
        trip_id, actor_id=principal.user_id, accept=False, reason=body.reason, as_admin=False
    )
    return trip_answer(assignment)


@router.post("/{trip_id}/bookings/{booking_id}/accept", response_model=BookingResponse)
async def accept_booking(
    trip_id: uuid.UUID,
    booking_id: uuid.UUID,
    principal: CurrentPrincipal,
    acceptance: BookingAcceptanceServiceDep,
    bookings: BookingServiceDep,
) -> BookingResponse:
    """Take this passenger: they are asked to pay now. Idempotent."""
    booking = await acceptance.accept(
        booking_id, actor_id=principal.user_id, as_admin=False, trip_id=trip_id
    )
    [response] = await booking_responses(bookings, [booking])
    return response


@router.post("/{trip_id}/bookings/{booking_id}/decline", response_model=MessageResponse)
async def decline_booking(
    trip_id: uuid.UUID,
    booking_id: uuid.UUID,
    body: DeclineRequest,
    principal: CurrentPrincipal,
    acceptance: BookingAcceptanceServiceDep,
) -> MessageResponse:
    """Turn this booking down. It goes to another vehicle going the same
    way if one has seats; otherwise the passenger is told, uncharged."""
    await acceptance.decline(
        booking_id,
        actor_id=principal.user_id,
        as_admin=False,
        reason=body.reason,
        trip_id=trip_id,
    )
    return MessageResponse(message="Booking declined.")


@router.post("/{trip_id}/passengers/{booking_passenger_id}/alight", response_model=AlightResponse)
async def mark_passenger_off(
    trip_id: uuid.UUID,
    booking_passenger_id: uuid.UUID,
    principal: CurrentPrincipal,
    alighting: AlightingServiceDep,
    body: AlightRequest | None = None,
) -> AlightResponse:
    """This passenger got off -- at their stop or before it. Their seat is
    free for the rest of the route from now on. Passengers are also marked
    off automatically when the vehicle reaches the stop they booked to."""
    passenger, booking = await alighting.mark_off(
        trip_id,
        booking_passenger_id,
        actor_id=principal.user_id,
        as_admin=False,
        stop_id=body.stop_id if body is not None else None,
    )
    return alight_response(passenger, booking)


def alight_response(passenger: BookingPassenger, booking: Booking) -> AlightResponse:
    return AlightResponse(
        booking_passenger_id=passenger.id,
        booking_id=booking.id,
        alighted_at=passenger.alighted_at,
        alighted_stop_id=passenger.alighted_stop_id,
        alighted_how=passenger.alighted_how,
        booking_status=booking.status,
    )


@router.post("/{trip_id}/start", response_model=TripResponse)
async def start_trip(
    trip_id: uuid.UUID, principal: CurrentPrincipal, service: TripServiceDep
) -> TripResponse:
    """Idempotent: calling this again while the trip is already in progress
    (by the same driver) simply returns the current trip state."""
    trip = await service.start_trip(trip_id, principal.user_id)
    return TripResponse.model_validate(trip)


@router.post("/{trip_id}/pause", response_model=TripResponse)
async def pause_trip(
    trip_id: uuid.UUID,
    body: PauseTripRequest,
    principal: CurrentPrincipal,
    service: TripServiceDep,
) -> TripResponse:
    trip = await service.pause_trip(trip_id, principal.user_id, body.reason)
    return TripResponse.model_validate(trip)


@router.post("/{trip_id}/resume", response_model=TripResponse)
async def resume_trip(
    trip_id: uuid.UUID, principal: CurrentPrincipal, service: TripServiceDep
) -> TripResponse:
    trip = await service.resume_trip(trip_id, principal.user_id)
    return TripResponse.model_validate(trip)


@router.post("/{trip_id}/end", response_model=TripResponse)
async def end_trip(
    trip_id: uuid.UUID,
    body: EndTripRequest,
    principal: CurrentPrincipal,
    service: TripServiceDep,
) -> TripResponse:
    """Idempotent: calling this again after the trip has already completed
    (by the same driver) simply returns the current trip state."""
    trip = await service.end_trip(
        trip_id, principal.user_id, latitude=body.latitude, longitude=body.longitude
    )
    return TripResponse.model_validate(trip)


@router.post(
    "/{trip_id}/location",
    response_model=LiveLocationResponse,
    dependencies=[Depends(rate_limit("tracking:location_publish"))],
)
async def report_location(
    trip_id: uuid.UUID,
    body: LocationPingRequest,
    principal: CurrentPrincipal,
    trips: TripServiceDep,
    tracking: TrackingServiceDep,
    alighting: AlightingServiceDep,
    autopilot: TripAutopilotDep,
) -> LiveLocationResponse:
    """A driver's phone pushes a GPS ping while the trip is in progress, and
    (unless ``TRIP_AUTO_STATUS_ENABLED`` is off) also while it is paused and
    from ``TRIP_AUTO_WINDOW_MINUTES`` before departure: positions move the
    trip's status along on their own (see ``trip_status``). Restricted to the
    trip's actively assigned driver, same guard as
    start/pause/resume/end/validate."""
    await trips.assert_is_assigned_driver(trip_id, principal.user_id)
    recorded_at = body.recorded_at or datetime.now(UTC)
    if recorded_at.tzinfo is None:
        recorded_at = recorded_at.replace(tzinfo=UTC)  # a phone that sent no zone: UTC
    live = await tracking.record_location(
        trip_id,
        latitude=body.latitude,
        longitude=body.longitude,
        speed_kmh=body.speed_kmh,
        heading_degrees=body.heading_degrees,
        accuracy_meters=body.accuracy_meters,
        recorded_at=recorded_at,
    )
    # Whoever's stop this is has arrived: their seat frees up.
    await alighting.on_vehicle_moved(trip_id, live.latitude, live.longitude)
    # Then the trip itself: boarding, under way, paused, arrived.
    await autopilot.after_position(
        trip_id,
        latitude=live.latitude,
        longitude=live.longitude,
        recorded_at=live.recorded_at,
        accuracy_meters=body.accuracy_meters,
    )
    trip = await trips.get_trip(trip_id)
    return LiveLocationResponse(
        trip_id=live.trip_id,
        latitude=live.latitude,
        longitude=live.longitude,
        speed_kmh=live.speed_kmh,
        heading_degrees=live.heading_degrees,
        recorded_at=live.recorded_at,
        is_stale=live.is_stale,
        trip_status=trip.status,
    )


@router.post(
    "/{trip_id}/tickets/validate",
    response_model=TicketResponse,
    dependencies=[Depends(rate_limit("tickets:validate"))],
)
async def validate_ticket(
    trip_id: uuid.UUID,
    body: ValidateTicketRequest,
    principal: CurrentPrincipal,
    trips: TripServiceDep,
    tickets: TicketServiceDep,
) -> TicketResponse:
    """Boards a passenger: verifies the scanned QR code's signature, that
    it actually belongs to this trip, and that it hasn't already been used,
    expired, or been revoked — then marks it validated. Restricted to the
    trip's actively assigned driver, same guard as start/pause/resume/end."""
    driver_id = await trips.assert_is_assigned_driver(trip_id, principal.user_id)
    ticket = await tickets.validate_qr(
        body.qr_token, trip_id=trip_id, validated_by=principal.user_id
    )
    await trips.record_ticket_scan(
        trip_id,
        driver_id=driver_id,
        actor_id=principal.user_id,
        booking_id=ticket.booking_id,
        ticket_reference=ticket.ticket_reference,
    )
    return TicketResponse(
        id=ticket.id,
        ticket_reference=ticket.ticket_reference,
        booking_id=ticket.booking_id,
        booking_passenger_id=ticket.booking_passenger_id,
        trip_id=ticket.trip_id,
        status=ticket.status,
        issued_at=ticket.issued_at,
        expires_at=ticket.expires_at,
        validated_at=ticket.validated_at,
        qr_token=tickets.get_qr_token(ticket),
    )


@router.get("/{trip_id}/passengers", response_model=list[ManifestEntryResponse])
async def list_trip_passengers(
    trip_id: uuid.UUID, principal: CurrentPrincipal, trips: TripServiceDep
) -> list[ManifestEntryResponse]:
    """The trip's passenger manifest, in pickup order along the route. Only
    the trip's assigned driver may see it (403 otherwise). ``boarded``
    becomes true once the passenger's ticket is scanned with
    ``POST /driver-trips/{trip_id}/tickets/validate``. Phone numbers are
    masked."""
    entries = await trips.get_manifest(trip_id, principal.user_id)
    return [ManifestEntryResponse.model_validate(entry) for entry in entries]


@router.get("/{trip_id}/payments", response_model=TripPaymentsResponse)
async def get_trip_payments(
    trip_id: uuid.UUID, principal: CurrentPrincipal, trips: TripServiceDep
) -> TripPaymentsResponse:
    """What this trip's passengers paid, per seat and per payment channel.
    Only the trip's assigned driver may see it (403 otherwise). Amounts are
    fares, TroSky's platform fee excluded."""
    receipts = await trips.get_receipts(trip_id, principal.user_id)
    return TripPaymentsResponse(
        trip_id=receipts.trip_id,
        currency=receipts.currency,
        fare_per_seat=receipts.fare_per_seat,
        total_collected=receipts.total_collected,
        by_channel=[ChannelTotalResponse.model_validate(t) for t in receipts.by_channel],
        receipts=[SeatReceiptResponse.model_validate(r) for r in receipts.receipts],
    )
