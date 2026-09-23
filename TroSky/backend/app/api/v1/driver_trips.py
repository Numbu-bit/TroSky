"""Driver-facing trip lifecycle endpoints (start/pause/resume/end).

Every route requires the ``driver`` role; ``TripService`` additionally
verifies the caller is the *actively assigned* driver for the specific
trip being acted on — see ``TripService._resolve_assigned_driver_id``.
"""

from __future__ import annotations

import uuid
from datetime import UTC, datetime

from fastapi import APIRouter, Depends

from app.api.dependencies import (
    CurrentPrincipal,
    TicketServiceDep,
    TrackingServiceDep,
    TripServiceDep,
)
from app.core.permissions import SystemRole, require_roles
from app.core.ratelimit import rate_limit
from app.schemas.ticket import TicketResponse, ValidateTicketRequest
from app.schemas.tracking import LiveLocationResponse, LocationPingRequest
from app.schemas.trip import EndTripRequest, PauseTripRequest, TripResponse

router = APIRouter(dependencies=[Depends(require_roles(SystemRole.DRIVER))])


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
) -> LiveLocationResponse:
    """A driver's phone pushes a GPS ping while the trip is in progress.
    Restricted to the trip's actively assigned driver, same guard as
    start/pause/resume/end/validate."""
    await trips.assert_is_assigned_driver(trip_id, principal.user_id)
    live = await tracking.record_location(
        trip_id,
        latitude=body.latitude,
        longitude=body.longitude,
        speed_kmh=body.speed_kmh,
        heading_degrees=body.heading_degrees,
        accuracy_meters=body.accuracy_meters,
        recorded_at=body.recorded_at or datetime.now(UTC),
    )
    return LiveLocationResponse(
        trip_id=live.trip_id,
        latitude=live.latitude,
        longitude=live.longitude,
        speed_kmh=live.speed_kmh,
        heading_degrees=live.heading_degrees,
        recorded_at=live.recorded_at,
        is_stale=live.is_stale,
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
    await trips.assert_is_assigned_driver(trip_id, principal.user_id)
    ticket = await tickets.validate_qr(
        body.qr_token, trip_id=trip_id, validated_by=principal.user_id
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
