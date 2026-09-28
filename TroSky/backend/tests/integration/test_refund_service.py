"""Integration tests for the refund workflow: a refund-eligible cancellation
opens a PENDING RefundRequest (never moves money by itself), and admin
approval is what actually processes the payout — via the wallet ledger for
wallet-funded payments, or the provider's refund endpoint otherwise."""

from __future__ import annotations

import uuid
from decimal import Decimal

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import InvalidStateTransitionError, RefundNotAllowedError
from app.models.bookings import BookingStatus
from app.models.payments import PaymentStatus, RefundStatus, WalletReferenceType
from app.providers.payments.base import PaymentChannel
from app.providers.payments.sandbox import SandboxPaymentProvider
from app.schemas.booking import BookingCreateRequest, PassengerInput
from app.services.booking_service import BookingService
from app.services.payment_service import PaymentService
from app.services.refund_service import RefundService
from app.services.wallet_service import WalletService
from tests.integration.test_booking_service import _make_bookable_trip

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]


@pytest.fixture(autouse=True)
def _clear_sandbox():
    SandboxPaymentProvider.clear()
    yield
    SandboxPaymentProvider.clear()


async def _make_confirmed_wallet_paid_booking(
    session: AsyncSession, *, passenger_id: uuid.UUID, make_user
) -> tuple[uuid.UUID, uuid.UUID]:
    """Returns ``(booking_id, payment_id)`` for a booking paid in full via
    the wallet (the simplest path to a SUCCESSFUL payment for these tests)."""
    trip_id, seat_ids, _ = await _make_bookable_trip(session, seat_count=1, make_user=make_user)
    booking_service = BookingService(session)
    booking = await booking_service.create_booking(
        passenger_id,
        BookingCreateRequest(
            trip_id=trip_id, passengers=[PassengerInput(seat_id=seat_ids[0], full_name="Passenger")]
        ),
        idempotency_key=None,
    )
    await WalletService(session).credit(
        passenger_id,
        amount=Decimal("100.00"),
        reference_type=WalletReferenceType.WALLET_TOPUP,
        reference_id=None,
        description="Top-up",
    )
    payment_service = PaymentService(session)
    payment = await payment_service.pay_for_booking(
        passenger_id,
        booking.id,
        channel=PaymentChannel.WALLET,
        payer_phone=None,
        idempotency_key=None,
    )
    return booking.id, payment.id


class TestCancellationOpensRefundRequest:
    async def test_cancel_before_trip_start_opens_pending_refund_request(
        self, db_session: AsyncSession, make_user
    ) -> None:
        passenger_id = (await make_user()).id
        booking_id, payment_id = await _make_confirmed_wallet_paid_booking(
            db_session, passenger_id=passenger_id, make_user=make_user
        )
        booking_service = BookingService(db_session)
        booking = await booking_service.cancel_booking(
            booking_id, requesting_user_id=passenger_id, reason="Change of plans"
        )
        assert booking.status == BookingStatus.REFUND_PENDING

        payment_service = PaymentService(db_session)
        refund_request = await payment_service.create_refund_request_for_cancelled_booking(
            booking, requested_by=passenger_id
        )
        assert refund_request is not None
        assert refund_request.status == RefundStatus.PENDING
        assert refund_request.payment_id == payment_id
        # The whole amount paid comes back: the fare plus the platform fee.
        assert refund_request.amount == booking.total_amount

    async def test_creating_refund_request_twice_is_idempotent(
        self, db_session: AsyncSession, make_user
    ) -> None:
        passenger_id = (await make_user()).id
        booking_id, _ = await _make_confirmed_wallet_paid_booking(
            db_session, passenger_id=passenger_id, make_user=make_user
        )
        booking_service = BookingService(db_session)
        booking = await booking_service.cancel_booking(
            booking_id, requesting_user_id=passenger_id, reason=None
        )
        payment_service = PaymentService(db_session)
        first = await payment_service.create_refund_request_for_cancelled_booking(
            booking, requested_by=passenger_id
        )
        second = await payment_service.create_refund_request_for_cancelled_booking(
            booking, requested_by=passenger_id
        )
        assert first is not None
        assert second is not None
        assert first.id == second.id


class TestRefundApproval:
    async def test_approving_a_wallet_funded_refund_credits_the_wallet(
        self, db_session: AsyncSession, make_user
    ) -> None:
        passenger_id = (await make_user()).id
        booking_id, _ = await _make_confirmed_wallet_paid_booking(
            db_session, passenger_id=passenger_id, make_user=make_user
        )
        booking_service = BookingService(db_session)
        booking = await booking_service.cancel_booking(
            booking_id, requesting_user_id=passenger_id, reason=None
        )
        payment_service = PaymentService(db_session)
        refund_request = await payment_service.create_refund_request_for_cancelled_booking(
            booking, requested_by=passenger_id
        )
        assert refund_request is not None

        balance_before = await WalletService(db_session).get_balance(passenger_id)

        reviewer_id = (await make_user()).id
        refund_service = RefundService(db_session)
        approved = await refund_service.approve_and_process(
            refund_request.id, reviewer_id=reviewer_id, notes="Approved"
        )
        assert approved.status == RefundStatus.COMPLETED

        balance_after = await WalletService(db_session).get_balance(passenger_id)
        assert balance_after == balance_before + refund_request.amount

        payment = await payment_service.get_payment(
            refund_request.payment_id, requesting_user_id=passenger_id
        )
        assert payment.status == PaymentStatus.REFUNDED

        refreshed_booking = await booking_service._bookings.get_by_id(booking_id)
        assert refreshed_booking is not None
        assert refreshed_booking.status == BookingStatus.REFUNDED

    async def test_approving_twice_is_idempotent(self, db_session: AsyncSession, make_user) -> None:
        passenger_id = (await make_user()).id
        booking_id, _ = await _make_confirmed_wallet_paid_booking(
            db_session, passenger_id=passenger_id, make_user=make_user
        )
        booking_service = BookingService(db_session)
        booking = await booking_service.cancel_booking(
            booking_id, requesting_user_id=passenger_id, reason=None
        )
        payment_service = PaymentService(db_session)
        refund_request = await payment_service.create_refund_request_for_cancelled_booking(
            booking, requested_by=passenger_id
        )
        assert refund_request is not None

        refund_service = RefundService(db_session)
        reviewer_id = (await make_user()).id
        first = await refund_service.approve_and_process(
            refund_request.id, reviewer_id=reviewer_id, notes=None
        )
        second = await refund_service.approve_and_process(
            refund_request.id, reviewer_id=reviewer_id, notes=None
        )
        assert first.status == second.status == RefundStatus.COMPLETED

        # Topped up 100.00, paid the booking, refunded once: back to 100.00.
        # A second credit would leave 100.00 + refund_request.amount.
        balance = await WalletService(db_session).get_balance(passenger_id)
        assert balance == Decimal("100.00")

    async def test_rejecting_a_refund_request(self, db_session: AsyncSession, make_user) -> None:
        passenger_id = (await make_user()).id
        booking_id, _ = await _make_confirmed_wallet_paid_booking(
            db_session, passenger_id=passenger_id, make_user=make_user
        )
        booking_service = BookingService(db_session)
        booking = await booking_service.cancel_booking(
            booking_id, requesting_user_id=passenger_id, reason=None
        )
        payment_service = PaymentService(db_session)
        refund_request = await payment_service.create_refund_request_for_cancelled_booking(
            booking, requested_by=passenger_id
        )
        assert refund_request is not None

        refund_service = RefundService(db_session)
        rejected = await refund_service.reject(
            refund_request.id, reviewer_id=(await make_user()).id, notes="Policy violation"
        )
        assert rejected.status == RefundStatus.REJECTED

        with pytest.raises(InvalidStateTransitionError):
            await refund_service.approve_and_process(
                refund_request.id, reviewer_id=(await make_user()).id, notes=None
            )

    async def test_cannot_approve_more_than_refundable_balance(
        self, db_session: AsyncSession, make_user
    ) -> None:
        passenger_id = (await make_user()).id
        booking_id, payment_id = await _make_confirmed_wallet_paid_booking(
            db_session, passenger_id=passenger_id, make_user=make_user
        )
        booking_service = BookingService(db_session)
        booking = await booking_service.cancel_booking(
            booking_id, requesting_user_id=passenger_id, reason=None
        )
        payment_service = PaymentService(db_session)
        refund_request = await payment_service.create_refund_request_for_cancelled_booking(
            booking, requested_by=passenger_id
        )
        assert refund_request is not None

        # Simulate the payment having already been (partially) refunded
        # beyond what this request should now be allowed to take.
        payment = await payment_service.get_payment(payment_id, requesting_user_id=passenger_id)
        payment.refunded_amount = payment.amount
        await db_session.flush()

        refund_service = RefundService(db_session)
        with pytest.raises(RefundNotAllowedError):
            await refund_service.approve_and_process(
                refund_request.id, reviewer_id=(await make_user()).id, notes=None
            )
