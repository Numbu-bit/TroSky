"""When a seat counts as taken, and a booking as aboard: in one place, for the
seat map, search, fares and booking.

A hold (a booking waiting for its driver's answer, or for payment) keeps its
seats until its ``expires_at``. Past that it frees them at once, whether or
not the background sweep has yet been round to mark it expired: on a small
server the worker may be asleep. Booking a seat whose hold has lapsed
resolves that hold first (``BookingService.create_booking``).
"""

from __future__ import annotations

from datetime import datetime

from sqlalchemy import ColumnElement, and_, or_

from app.models.bookings import Booking, BookingStatus, ReservationStatus, SeatReservation

# Bookings holding seats until their ``expires_at``.
HOLDING_STATUSES = (
    BookingStatus.AWAITING_ACCEPTANCE,
    BookingStatus.PENDING,
    BookingStatus.PAYMENT_PENDING,
)


def seat_taken(now: datetime) -> ColumnElement[bool]:
    """A reservation keeping its seat from anyone else at ``now``: paid
    for, or held and not yet lapsed."""
    return or_(
        SeatReservation.status == ReservationStatus.CONFIRMED,
        and_(
            SeatReservation.status == ReservationStatus.HELD,
            or_(SeatReservation.expires_at.is_(None), SeatReservation.expires_at > now),
        ),
    )


def lapsed_hold(now: datetime) -> ColumnElement[bool]:
    """A reservation still marked held whose hold ran out by ``now``."""
    return and_(
        SeatReservation.status == ReservationStatus.HELD,
        SeatReservation.expires_at.is_not(None),
        SeatReservation.expires_at <= now,
    )


def booking_aboard(now: datetime) -> ColumnElement[bool]:
    """A booking sharing its trip's seats and fare at ``now``: paid for or
    travelled, or holding seats with its hold not yet lapsed. Cancelled,
    expired and refunded bookings freed their seats."""
    return or_(
        Booking.status.in_((BookingStatus.CONFIRMED, BookingStatus.COMPLETED)),
        and_(
            Booking.status.in_(HOLDING_STATUSES),
            or_(Booking.expires_at.is_(None), Booking.expires_at > now),
        ),
    )
