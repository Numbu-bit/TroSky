"""Cancelling a trip cancels its bookings and queues refunds (admin gap fix).

Uses the Madina -> Legon -> Circle scenario: GHS 8.00 a seat, 4 seats.
"""

from __future__ import annotations

import json
import uuid
from datetime import UTC, datetime, timedelta
from decimal import Decimal

import pytest
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.bookings import Booking, BookingStatus, ReservationStatus, SeatReservation
from app.models.notifications import Notification
from app.models.payments import RefundRequest, RefundStatus, WalletReferenceType
from app.models.tickets import Ticket, TicketStatus
from app.providers.payments.base import PaymentChannel, PaymentProviderStatus
from app.providers.payments.sandbox import SandboxPaymentProvider
from app.services.booking_service import BookingService
from app.services.payment_service import PaymentService
from app.services.trip_service import TripService
from app.services.wallet_service import WalletService
from tests.integration.scenarios import TripScenario, book, build_trip_scenario

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]


async def _scenario(session: AsyncSession, make_user) -> TripScenario:
    departure = datetime.now(UTC) + timedelta(hours=3)
    return await build_trip_scenario(session, make_user, departure=departure)


async def _paid_from_wallet(session: AsyncSession, make_user, scenario: TripScenario, seat: int):
    passenger = await make_user()
    booking = await book(session, passenger.id, scenario, seat=seat, confirm=False)
    await WalletService(session).credit(
        passenger.id,
        amount=Decimal("20.00"),
        reference_type=WalletReferenceType.WALLET_TOPUP,
        reference_id=None,
        description="Test top-up",
    )
    await PaymentService(session).pay_for_booking(
        passenger.id,
        booking.id,
        channel=PaymentChannel.WALLET,
        payer_phone=None,
        idempotency_key=None,
    )
    return passenger, booking


async def _cancel(session: AsyncSession, scenario: TripScenario, admin_id: uuid.UUID):
    """What POST /admin/trips/{id}/cancel does, in one transaction."""
    await TripService(session).cancel_trip(
        scenario.trip_id, cancelled_by=admin_id, reason="Vehicle broke down"
    )
    cancelled = await BookingService(session).cancel_all_for_trip(
        scenario.trip_id, cancelled_by=admin_id, reason="Vehicle broke down"
    )
    refunds = await PaymentService(session).queue_refunds(cancelled, requested_by=admin_id)
    return cancelled, refunds


class TestCancellingATrip:
    async def test_paid_bookings_await_refunds_and_unpaid_ones_are_cancelled(
        self, db_session: AsyncSession, make_user
    ) -> None:
        scenario = await _scenario(db_session, make_user)
        paid_passenger, paid = await _paid_from_wallet(db_session, make_user, scenario, seat=0)
        unpaid = await book(db_session, (await make_user()).id, scenario, seat=1, confirm=False)
        admin = await make_user()

        cancelled, refunds = await _cancel(db_session, scenario, admin.id)

        assert {b.id for b in cancelled} == {paid.id, unpaid.id}
        assert paid.status == BookingStatus.REFUND_PENDING
        assert unpaid.status == BookingStatus.CANCELLED
        [refund] = refunds
        assert refund.booking_id == paid.id
        assert refund.status == RefundStatus.PENDING
        assert refund.amount == paid.total_amount

        reservations = (
            await db_session.scalars(
                select(SeatReservation.status).where(SeatReservation.trip_id == scenario.trip_id)
            )
        ).all()
        assert set(reservations) == {ReservationStatus.RELEASED}
        tickets = (
            await db_session.scalars(select(Ticket.status).where(Ticket.booking_id == paid.id))
        ).all()
        assert tickets
        assert set(tickets) == {TicketStatus.REVOKED}
        told = (
            await db_session.scalars(
                select(Notification.body).where(Notification.user_id == paid_passenger.id)
            )
        ).all()
        assert any("refunded" in body for body in told)

    async def test_finished_bookings_are_left_alone_and_nothing_is_refunded_twice(
        self, db_session: AsyncSession, make_user
    ) -> None:
        scenario = await _scenario(db_session, make_user)
        _, paid = await _paid_from_wallet(db_session, make_user, scenario, seat=0)
        own_cancel = await BookingService(db_session).cancel_booking(
            paid.id, requesting_user_id=paid.passenger_id, reason=None
        )
        await PaymentService(db_session).create_refund_request_for_cancelled_booking(
            own_cancel, requested_by=paid.passenger_id
        )

        cancelled, refunds = await _cancel(db_session, scenario, (await make_user()).id)

        assert cancelled == []
        assert refunds == []
        requests = (
            await db_session.scalars(
                select(RefundRequest).where(RefundRequest.booking_id == paid.id)
            )
        ).all()
        assert len(requests) == 1


class TestPaymentArrivingAfterCancellation:
    async def test_a_late_mobile_money_payment_is_refunded_not_lost(
        self, db_session: AsyncSession, make_user
    ) -> None:
        scenario = await _scenario(db_session, make_user)
        passenger = await make_user()
        booking = await book(db_session, passenger.id, scenario, seat=0, confirm=False)
        payments = PaymentService(db_session)
        payment = await payments.pay_for_booking(
            passenger.id,
            booking.id,
            channel=PaymentChannel.MTN_MOMO,
            payer_phone="0244000001",
            idempotency_key=None,
        )
        await _cancel(db_session, scenario, (await make_user()).id)
        assert booking.status == BookingStatus.CANCELLED

        payload = SandboxPaymentProvider.simulate_webhook_payload(
            payment.internal_reference, PaymentProviderStatus.SUCCESSFUL
        )
        await payments.process_webhook(PaymentChannel.MTN_MOMO, {}, json.dumps(payload).encode())

        refreshed = await db_session.get(Booking, booking.id)
        assert refreshed is not None
        assert refreshed.status == BookingStatus.REFUND_PENDING
        requests = (
            await db_session.scalars(
                select(RefundRequest).where(RefundRequest.booking_id == booking.id)
            )
        ).all()
        assert [r.amount for r in requests] == [payment.amount]
