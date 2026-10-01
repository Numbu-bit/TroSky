"""Passenger booking endpoints: create, list, retrieve, cancel.

Every booking is scoped to its owning passenger — ``BookingService``
reports another passenger's booking as ``404`` (never ``403``) so its
existence isn't leaked, unless the caller holds ``bookings:view_any``
(admin review, see ``app.api.v1.admin``).
"""

from __future__ import annotations

import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, Query, status

from app.api.dependencies import (
    BookingServiceDep,
    CurrentPrincipal,
    OptionalIdempotencyKey,
    Pagination,
    PaymentServiceDep,
    RatingServiceDep,
    TicketServiceDep,
)
from app.api.v1.views import booking_responses
from app.core.exceptions import NotFoundError
from app.core.permissions import Permission
from app.core.ratelimit import rate_limit
from app.models.bookings import Booking, BookingStatus
from app.schemas.booking import (
    BookingCreateRequest,
    BookingResponse,
    CancelBookingRequest,
)
from app.schemas.common import PaginatedResponse
from app.schemas.feedback import RateBookingRequest, RatingResponse
from app.schemas.payment import PayBookingRequest, PaymentResponse
from app.schemas.ticket import TicketResponse
from app.services.booking_service import BookingService
from app.utilities.query_params import parse_enum_list

router = APIRouter()


async def _booking_response(service: BookingService, booking: Booking) -> BookingResponse:
    [response] = await booking_responses(service, [booking])
    return response


@router.post("", response_model=BookingResponse, status_code=status.HTTP_201_CREATED)
async def create_booking(
    body: BookingCreateRequest,
    principal: CurrentPrincipal,
    service: BookingServiceDep,
    idempotency_key: OptionalIdempotencyKey,
) -> BookingResponse:
    """Reserve one or more seats on a trip. Seats are held for a
    configurable window (``SEAT_RESERVATION_HOLD_SECONDS``) pending
    payment (Phase 6) and released automatically if it lapses."""
    booking = await service.create_booking(principal.user_id, body, idempotency_key=idempotency_key)
    return await _booking_response(service, booking)


@router.get("", response_model=PaginatedResponse[BookingResponse])
async def list_my_bookings(
    principal: CurrentPrincipal,
    service: BookingServiceDep,
    pagination: Pagination,
    status_filter: Annotated[
        str | None,
        Query(
            alias="status",
            description="Comma-separated booking statuses, e.g. confirmed,completed.",
        ),
    ] = None,
    upcoming: Annotated[
        bool | None,
        Query(
            description=(
                "true: trips still ahead -- departing now or later, or under way "
                "(soonest first). false: trips behind you (most recent first). "
                "Omit for both (newest booking first)."
            )
        ),
    ] = None,
) -> PaginatedResponse[BookingResponse]:
    """Your bookings, each with a short summary of its trip."""
    bookings, total = await service.list_own_bookings(
        principal.user_id,
        statuses=parse_enum_list(status_filter, BookingStatus, param="status"),
        upcoming=upcoming,
        limit=pagination.limit,
        offset=pagination.offset,
    )
    items = await booking_responses(service, bookings)
    return PaginatedResponse(
        items=items, total=total, limit=pagination.limit, offset=pagination.offset
    )


@router.get("/{booking_id}", response_model=BookingResponse)
async def get_booking(
    booking_id: uuid.UUID, principal: CurrentPrincipal, service: BookingServiceDep
) -> BookingResponse:
    is_privileged = principal.has_permission(Permission.BOOKINGS_VIEW_ANY)
    booking = await service.get_booking(
        booking_id, requesting_user_id=principal.user_id, is_privileged=is_privileged
    )
    return await _booking_response(service, booking)


@router.post("/{booking_id}/cancel", response_model=BookingResponse)
async def cancel_booking(
    booking_id: uuid.UUID,
    body: CancelBookingRequest,
    principal: CurrentPrincipal,
    service: BookingServiceDep,
    payments: PaymentServiceDep,
) -> BookingResponse:
    """Cancels a booking. If the trip hasn't started yet, this is decided
    immediately (refund-eligible if the booking was already paid); once
    boarding/departure has begun it's queued for admin review instead.

    A refund-eligible cancellation only opens a ``RefundRequest`` here —
    actually releasing money still needs a separate admin approval
    (``POST /admin/refund-requests/{id}/approve``), never happens
    automatically as a side effect of the passenger's own cancel call.
    """
    is_privileged = principal.has_permission(Permission.BOOKINGS_VIEW_ANY)
    booking = await service.cancel_booking(
        booking_id,
        requesting_user_id=principal.user_id,
        reason=body.reason,
        is_privileged=is_privileged,
    )
    await payments.create_refund_request_for_cancelled_booking(
        booking, requested_by=principal.user_id
    )
    return await _booking_response(service, booking)


@router.post(
    "/{booking_id}/pay",
    response_model=PaymentResponse,
    status_code=status.HTTP_201_CREATED,
    dependencies=[Depends(rate_limit("payments:initiate"))],
)
async def pay_for_booking(
    booking_id: uuid.UUID,
    body: PayBookingRequest,
    principal: CurrentPrincipal,
    service: PaymentServiceDep,
    idempotency_key: OptionalIdempotencyKey,
) -> PaymentResponse:
    """Initiates payment for a held booking. Wallet payments are debited
    and confirmed synchronously; every other channel returns a
    ``processing`` payment that is later confirmed by that channel's
    webhook (``POST /payments/webhooks/{channel}``) — never by this
    response."""
    payment = await service.pay_for_booking(
        principal.user_id,
        booking_id,
        channel=body.channel,
        payer_phone=body.payer_phone_number,
        idempotency_key=idempotency_key,
    )
    return PaymentResponse.model_validate(payment)


@router.get("/{booking_id}/tickets", response_model=list[TicketResponse])
async def list_booking_tickets(
    booking_id: uuid.UUID, principal: CurrentPrincipal, service: TicketServiceDep
) -> list[TicketResponse]:
    """One ticket per booked seat, issued automatically once the booking is
    confirmed (see ``BookingService.confirm_booking``) — empty until then."""
    is_privileged = principal.has_permission(Permission.BOOKINGS_VIEW_ANY)
    tickets = await service.list_tickets_for_booking(
        booking_id, requesting_user_id=principal.user_id, is_privileged=is_privileged
    )
    return [
        TicketResponse(
            id=t.id,
            ticket_reference=t.ticket_reference,
            booking_id=t.booking_id,
            booking_passenger_id=t.booking_passenger_id,
            trip_id=t.trip_id,
            status=t.status,
            issued_at=t.issued_at,
            expires_at=t.expires_at,
            validated_at=t.validated_at,
            qr_token=service.get_qr_token(t),
        )
        for t in tickets
    ]


@router.post(
    "/{booking_id}/rating", response_model=RatingResponse, status_code=status.HTTP_201_CREATED
)
async def rate_booking(
    booking_id: uuid.UUID,
    body: RateBookingRequest,
    principal: CurrentPrincipal,
    service: RatingServiceDep,
) -> RatingResponse:
    """Rates the trip once the booking has completed — see
    ``TripService.end_trip``, the only thing that ever moves a booking to
    ``COMPLETED``. ``score`` is the overall rating; ``safety``,
    ``cleanliness``, ``professionalism`` and ``timeliness`` are optional."""
    rating = await service.rate_booking(
        booking_id,
        passenger_id=principal.user_id,
        score=body.score,
        comment=body.comment,
        categories=body.categories(),
    )
    return RatingResponse.model_validate(rating)


@router.get("/{booking_id}/rating", response_model=RatingResponse)
async def get_booking_rating(
    booking_id: uuid.UUID,
    principal: CurrentPrincipal,
    service: BookingServiceDep,
    ratings: RatingServiceDep,
) -> RatingResponse:
    booking = await service.get_booking(booking_id, requesting_user_id=principal.user_id)
    rating = await ratings.get_rating_for_booking(booking.id)
    if rating is None:
        raise NotFoundError("This booking has not been rated yet.")
    return RatingResponse.model_validate(rating)
