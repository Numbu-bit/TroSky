"""The operations team over drivers' decisions: bookings waiting for an
answer, answering trips and bookings for a driver, moving a booking to
another vehicle, marking passengers off, and the log of everything drivers
did. Mounted under ``/admin``.
"""

from __future__ import annotations

import uuid
from datetime import datetime
from typing import Annotated

from fastapi import APIRouter, Depends, Query, Response

from app.api.common_dependencies import DbSession
from app.api.dependencies import BookingServiceDep, CurrentPrincipal, Pagination, TripServiceDep
from app.api.trip_dependencies import AlightingServiceDep, BookingAcceptanceServiceDep
from app.api.v1.driver_trips import alight_response, booking_request, trip_answer
from app.api.v1.listing import CSV_RESPONSE, ExportFormat, FormatQuery, csv_response, export_window
from app.api.v1.views import booking_responses
from app.core.permissions import Permission, require_permissions
from app.models.driver_actions import ActedAs, DriverActionKind
from app.repositories.driver_action_repository import DriverActionRepository
from app.schemas.acceptance import (
    AdminDeclineBookingRequest,
    AlightRequest,
    AlightResponse,
    BookingRequestResponse,
    DeclineRequest,
    DriverActionResponse,
    MoveBookingRequest,
    TripAnswerResponse,
)
from app.schemas.booking import BookingResponse
from app.schemas.common import PaginatedResponse
from app.utilities.query_params import parse_enum_list

router = APIRouter()

_WATCH = Depends(require_permissions(Permission.TRIPS_MANAGE, Permission.TRIPS_MONITOR_LIVE))
_CONTROL = Depends(require_permissions(Permission.TRIPS_MANAGE))


@router.get(
    "/booking-requests",
    response_model=PaginatedResponse[BookingRequestResponse],
    dependencies=[_WATCH],
)
async def list_booking_requests(
    acceptance: BookingAcceptanceServiceDep,
    pagination: Pagination,
    driver_id: uuid.UUID | None = None,
    trip_id: uuid.UUID | None = None,
) -> PaginatedResponse[BookingRequestResponse]:
    """Every booking waiting for a driver to accept it, the nearest deadline
    first. Unanswered at ``expires_at``, a booking goes to another vehicle."""
    requests, total = await acceptance.requests(
        driver_id=driver_id, trip_id=trip_id, limit=pagination.limit, offset=pagination.offset
    )
    return PaginatedResponse(
        items=[booking_request(r) for r in requests],
        total=total,
        limit=pagination.limit,
        offset=pagination.offset,
    )


@router.post(
    "/bookings/{booking_id}/accept", response_model=BookingResponse, dependencies=[_CONTROL]
)
async def accept_booking(
    booking_id: uuid.UUID,
    principal: CurrentPrincipal,
    acceptance: BookingAcceptanceServiceDep,
    bookings: BookingServiceDep,
) -> BookingResponse:
    """Accept a waiting booking for its driver: the passenger is asked to pay."""
    booking = await acceptance.accept(booking_id, actor_id=principal.user_id, as_admin=True)
    [response] = await booking_responses(bookings, [booking])
    return response


@router.post(
    "/bookings/{booking_id}/decline", response_model=BookingResponse, dependencies=[_CONTROL]
)
async def decline_booking(
    booking_id: uuid.UUID,
    body: AdminDeclineBookingRequest,
    principal: CurrentPrincipal,
    acceptance: BookingAcceptanceServiceDep,
    bookings: BookingServiceDep,
) -> BookingResponse:
    """Turn down a booking waiting for an answer, or accepted but not yet
    paid for. With ``move_to_another_trip`` it goes to another vehicle going
    the same way if one has seats; otherwise it ends and the passenger, who
    has paid nothing, is told."""
    booking = await acceptance.decline(
        booking_id,
        actor_id=principal.user_id,
        as_admin=True,
        reason=body.reason,
        move=body.move_to_another_trip,
    )
    [response] = await booking_responses(bookings, [booking])
    return response


@router.post("/bookings/{booking_id}/move", response_model=BookingResponse, dependencies=[_CONTROL])
async def move_booking(
    booking_id: uuid.UUID,
    body: MoveBookingRequest,
    principal: CurrentPrincipal,
    acceptance: BookingAcceptanceServiceDep,
    bookings: BookingServiceDep,
) -> BookingResponse:
    """Put a booking not yet paid for on another trip of your choosing, from
    the same pickup to the same destination. It then waits for that trip's
    driver to accept it."""
    booking = await acceptance.move_to(booking_id, body.trip_id, actor_id=principal.user_id)
    [response] = await booking_responses(bookings, [booking])
    return response


@router.post(
    "/trips/{trip_id}/accept-for-driver",
    response_model=TripAnswerResponse,
    dependencies=[_CONTROL],
)
async def accept_trip_for_driver(
    trip_id: uuid.UUID, principal: CurrentPrincipal, service: TripServiceDep
) -> TripAnswerResponse:
    """Accept the trip for its assigned driver, who is told."""
    assignment = await service.respond(
        trip_id, actor_id=principal.user_id, accept=True, reason=None, as_admin=True
    )
    return trip_answer(assignment)


@router.post(
    "/trips/{trip_id}/decline-for-driver",
    response_model=TripAnswerResponse,
    dependencies=[_CONTROL],
)
async def decline_trip_for_driver(
    trip_id: uuid.UUID, body: DeclineRequest, principal: CurrentPrincipal, service: TripServiceDep
) -> TripAnswerResponse:
    """Take the assigned driver off the trip (before it starts); they are
    told. Assign another with ``POST /admin/trips/{trip_id}/assign-driver``."""
    assignment = await service.respond(
        trip_id, actor_id=principal.user_id, accept=False, reason=body.reason, as_admin=True
    )
    return trip_answer(assignment)


@router.post(
    "/trips/{trip_id}/passengers/{booking_passenger_id}/alight",
    response_model=AlightResponse,
    dependencies=[_CONTROL],
)
async def mark_passenger_off(
    trip_id: uuid.UUID,
    booking_passenger_id: uuid.UUID,
    principal: CurrentPrincipal,
    alighting: AlightingServiceDep,
    body: AlightRequest | None = None,
) -> AlightResponse:
    """Mark a passenger off for the driver; their seat is free for the rest
    of the route from now on."""
    passenger, booking = await alighting.mark_off(
        trip_id,
        booking_passenger_id,
        actor_id=principal.user_id,
        as_admin=True,
        stop_id=body.stop_id if body is not None else None,
    )
    return alight_response(passenger, booking)


@router.get(
    "/driver-actions",
    responses=CSV_RESPONSE,
    response_model=PaginatedResponse[DriverActionResponse],
    dependencies=[_WATCH],
)
async def list_driver_actions(
    db: DbSession,
    pagination: Pagination,
    driver_id: uuid.UUID | None = None,
    trip_id: uuid.UUID | None = None,
    booking_id: uuid.UUID | None = None,
    kind: Annotated[
        str | None, Query(description="Comma-separated kinds, e.g. booking_declined,trip_declined.")
    ] = None,
    acted_as: ActedAs | None = None,
    since: datetime | None = None,
    until: datetime | None = None,
    export: ExportFormat = FormatQuery,
) -> PaginatedResponse[DriverActionResponse] | Response:
    """What drivers did, newest first: trips and bookings accepted or
    declined, trips started, paused, resumed and ended, tickets scanned and
    passengers marked off. ``acted_as`` says when it was an admin acting for
    the driver, or the system (nobody answered; a passenger reached their
    stop)."""
    limit, offset = export_window(pagination, export)
    rows, total = await DriverActionRepository(db).search(
        driver_id=driver_id,
        trip_id=trip_id,
        booking_id=booking_id,
        kinds=parse_enum_list(kind, DriverActionKind, param="kind"),
        acted_as=acted_as,
        since=since,
        until=until,
        limit=limit,
        offset=offset,
    )
    items = [
        DriverActionResponse(
            id=row.action.id,
            created_at=row.action.created_at,
            kind=row.action.kind,
            acted_as=row.action.acted_as,
            driver_id=row.action.driver_id,
            driver_name=row.driver_name,
            actor_id=row.action.actor_id,
            actor_name=row.actor_name,
            trip_id=row.action.trip_id,
            booking_id=row.action.booking_id,
            reason=row.action.reason,
            details=row.action.details,
        )
        for row in rows
    ]
    if export == "csv":
        return csv_response(items, name="driver-actions")
    return PaginatedResponse(
        items=items, total=total, limit=pagination.limit, offset=pagination.offset
    )
