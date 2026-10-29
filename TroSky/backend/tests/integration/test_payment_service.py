"""Integration tests for PaymentService: booking payment via wallet and via
a provider channel, idempotent creation, webhook-driven confirmation
(including replay protection), the auto-retry-on-failure booking state
transition, wallet top-ups, and the reconciliation sweep — against a real
Postgres."""

from __future__ import annotations

import json
import uuid
from datetime import UTC, datetime, timedelta
from decimal import Decimal

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.exceptions import ConflictError, InsufficientWalletBalanceError
from app.models.bookings import BookingStatus
from app.models.payments import Payment, PaymentStatus, WalletReferenceType
from app.providers.payments.base import PaymentChannel, PaymentProviderStatus
from app.providers.payments.sandbox import SandboxPaymentProvider
from app.schemas.booking import BookingCreateRequest, PassengerInput
from app.services.booking_service import BookingService
from app.services.payment_service import PaymentService
from app.services.wallet_service import WalletService
from tests.integration.test_booking_service import _make_bookable_trip

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]


@pytest.fixture(autouse=True)
def _clear_sandbox():
    SandboxPaymentProvider.clear()
    yield
    SandboxPaymentProvider.clear()


async def _make_pending_booking(
    session: AsyncSession, *, passenger_id: uuid.UUID, make_user
) -> uuid.UUID:
    trip_id, seat_ids, _ = await _make_bookable_trip(session, seat_count=1, make_user=make_user)
    booking_service = BookingService(session)
    booking = await booking_service.create_booking(
        passenger_id,
        BookingCreateRequest(
            trip_id=trip_id, passengers=[PassengerInput(seat_id=seat_ids[0], full_name="Passenger")]
        ),
        idempotency_key=None,
    )
    return booking.id


class TestBookingPaymentViaWallet:
    async def test_pay_with_sufficient_balance_confirms_booking(
        self, db_session: AsyncSession, make_user
    ) -> None:
        passenger_id = (await make_user()).id
        booking_id = await _make_pending_booking(
            db_session, passenger_id=passenger_id, make_user=make_user
        )
        await WalletService(db_session).credit(
            passenger_id,
            amount=Decimal("100.00"),
            reference_type=WalletReferenceType.WALLET_TOPUP,
            reference_id=None,
            description="Top-up",
        )

        service = PaymentService(db_session)
        payment = await service.pay_for_booking(
            passenger_id,
            booking_id,
            channel=PaymentChannel.WALLET,
            payer_phone=None,
            idempotency_key=None,
        )
        assert payment.status == PaymentStatus.SUCCESSFUL

        booking = await BookingService(db_session)._bookings.get_by_id(booking_id)
        assert booking is not None
        assert booking.status == BookingStatus.CONFIRMED

    async def test_pay_with_insufficient_balance_raises_and_booking_stays_pending(
        self, db_session: AsyncSession, make_user
    ) -> None:
        passenger_id = (await make_user()).id
        booking_id = await _make_pending_booking(
            db_session, passenger_id=passenger_id, make_user=make_user
        )
        service = PaymentService(db_session)
        with pytest.raises(InsufficientWalletBalanceError):
            await service.pay_for_booking(
                passenger_id,
                booking_id,
                channel=PaymentChannel.WALLET,
                payer_phone=None,
                idempotency_key=None,
            )


class TestBookingPaymentViaProvider:
    async def test_pending_payment_confirmed_by_webhook(
        self, db_session: AsyncSession, make_user
    ) -> None:
        passenger_id = (await make_user()).id
        booking_id = await _make_pending_booking(
            db_session, passenger_id=passenger_id, make_user=make_user
        )
        service = PaymentService(db_session)

        payment = await service.pay_for_booking(
            passenger_id,
            booking_id,
            channel=PaymentChannel.MTN_MOMO,
            payer_phone="0244000001",
            idempotency_key=None,
        )
        assert payment.status == PaymentStatus.PROCESSING

        booking_repo = BookingService(db_session)._bookings
        booking = await booking_repo.get_by_id(booking_id)
        assert booking is not None
        assert booking.status == BookingStatus.PAYMENT_PENDING

        payload = SandboxPaymentProvider.simulate_webhook_payload(
            payment.internal_reference, PaymentProviderStatus.SUCCESSFUL
        )

        await service.process_webhook(PaymentChannel.MTN_MOMO, {}, json.dumps(payload).encode())

        refreshed = await service.get_payment(payment.id, requesting_user_id=passenger_id)
        assert refreshed.status == PaymentStatus.SUCCESSFUL
        booking = await booking_repo.get_by_id(booking_id)
        assert booking is not None
        assert booking.status == BookingStatus.CONFIRMED

    async def test_failed_webhook_returns_booking_to_pending_for_retry(
        self, db_session: AsyncSession, make_user
    ) -> None:
        passenger_id = (await make_user()).id
        booking_id = await _make_pending_booking(
            db_session, passenger_id=passenger_id, make_user=make_user
        )
        service = PaymentService(db_session)

        payment = await service.pay_for_booking(
            passenger_id,
            booking_id,
            channel=PaymentChannel.MTN_MOMO,
            payer_phone="0244000001",
            idempotency_key=None,
        )

        payload = SandboxPaymentProvider.simulate_webhook_payload(
            payment.internal_reference, PaymentProviderStatus.FAILED, failure_reason="Declined"
        )
        await service.process_webhook(PaymentChannel.MTN_MOMO, {}, json.dumps(payload).encode())

        refreshed = await service.get_payment(payment.id, requesting_user_id=passenger_id)
        assert refreshed.status == PaymentStatus.FAILED

        booking = await BookingService(db_session)._bookings.get_by_id(booking_id)
        assert booking is not None
        assert booking.status == BookingStatus.PENDING  # free to retry

    async def test_duplicate_webhook_delivery_is_a_no_op(
        self, db_session: AsyncSession, make_user
    ) -> None:
        passenger_id = (await make_user()).id
        booking_id = await _make_pending_booking(
            db_session, passenger_id=passenger_id, make_user=make_user
        )
        service = PaymentService(db_session)
        payment = await service.pay_for_booking(
            passenger_id,
            booking_id,
            channel=PaymentChannel.MTN_MOMO,
            payer_phone="0244000001",
            idempotency_key=None,
        )

        payload = SandboxPaymentProvider.simulate_webhook_payload(
            payment.internal_reference, PaymentProviderStatus.SUCCESSFUL
        )
        raw = json.dumps(payload).encode()
        await service.process_webhook(PaymentChannel.MTN_MOMO, {}, raw)
        await service.process_webhook(PaymentChannel.MTN_MOMO, {}, raw)  # replay

        refreshed = await service.get_payment(payment.id, requesting_user_id=passenger_id)
        assert refreshed.status == PaymentStatus.SUCCESSFUL  # unchanged, not double-processed

    async def test_idempotent_pay_replay_returns_same_payment(
        self, db_session: AsyncSession, make_user
    ) -> None:
        passenger_id = (await make_user()).id
        booking_id = await _make_pending_booking(
            db_session, passenger_id=passenger_id, make_user=make_user
        )
        service = PaymentService(db_session)
        key = uuid.uuid4()
        first = await service.pay_for_booking(
            passenger_id,
            booking_id,
            channel=PaymentChannel.MTN_MOMO,
            payer_phone="0244000001",
            idempotency_key=key,
        )
        second = await service.pay_for_booking(
            passenger_id,
            booking_id,
            channel=PaymentChannel.MTN_MOMO,
            payer_phone="0244000001",
            idempotency_key=key,
        )
        assert first.id == second.id

    async def test_cannot_pay_for_a_non_pending_booking(
        self, db_session: AsyncSession, make_user
    ) -> None:
        passenger_id = (await make_user()).id
        booking_id = await _make_pending_booking(
            db_session, passenger_id=passenger_id, make_user=make_user
        )
        service = PaymentService(db_session)
        await service.pay_for_booking(
            passenger_id,
            booking_id,
            channel=PaymentChannel.MTN_MOMO,
            payer_phone="0244000001",
            idempotency_key=None,
        )
        # Booking is now PAYMENT_PENDING — a second, non-idempotent attempt
        # must be rejected rather than opening a second concurrent payment.
        with pytest.raises(ConflictError):
            await service.pay_for_booking(
                passenger_id,
                booking_id,
                channel=PaymentChannel.MTN_MOMO,
                payer_phone="0244000002",
                idempotency_key=None,
            )


class TestWalletTopup:
    async def test_topup_confirmed_by_webhook_credits_wallet(
        self, db_session: AsyncSession, make_user
    ) -> None:
        user_id = (await make_user()).id
        service = PaymentService(db_session)
        payment = await service.initiate_wallet_topup(
            user_id,
            amount=Decimal("30.00"),
            channel=PaymentChannel.MTN_MOMO,
            payer_phone="0244000001",
            idempotency_key=None,
        )

        payload = SandboxPaymentProvider.simulate_webhook_payload(
            payment.internal_reference, PaymentProviderStatus.SUCCESSFUL
        )
        await service.process_webhook(PaymentChannel.MTN_MOMO, {}, json.dumps(payload).encode())

        balance = await WalletService(db_session).get_balance(user_id)
        assert balance == Decimal("30.00")

    async def test_cannot_top_up_wallet_with_wallet_channel(self, db_session: AsyncSession) -> None:
        service = PaymentService(db_session)
        with pytest.raises(ConflictError):
            await service.initiate_wallet_topup(
                uuid.uuid4(),
                amount=Decimal("10.00"),
                channel=PaymentChannel.WALLET,
                payer_phone=None,
                idempotency_key=None,
            )


class TestReconciliation:
    async def test_reconcile_picks_up_stale_processing_payment(
        self, db_session: AsyncSession, make_user
    ) -> None:
        passenger_id = (await make_user()).id
        booking_id = await _make_pending_booking(
            db_session, passenger_id=passenger_id, make_user=make_user
        )
        service = PaymentService(db_session)
        payment = await service.pay_for_booking(
            passenger_id,
            booking_id,
            channel=PaymentChannel.MTN_MOMO,
            payer_phone="0244000001",
            idempotency_key=None,
        )
        # Force it to look old enough for the sweep to consider it, and
        # resolve the sandbox's side so the poll finds a terminal status.
        stored = await service.get_payment(payment.id, requesting_user_id=passenger_id)
        assert isinstance(stored, Payment)
        stored.created_at = datetime.now(UTC) - timedelta(seconds=600)
        await db_session.flush()
        SandboxPaymentProvider.resolve(payment.internal_reference, PaymentProviderStatus.SUCCESSFUL)

        # The sweep is platform-wide, so other stale payments may be swept
        # too; what matters is that this one was.
        reconciled_count = await service.reconcile_pending_payments(older_than_seconds=300)
        assert reconciled_count >= 1

        refreshed = await service.get_payment(payment.id, requesting_user_id=passenger_id)
        assert refreshed.status == PaymentStatus.SUCCESSFUL


class TestSandboxAutoApprove:
    """PAYMENTS_SANDBOX_AUTO_APPROVE_SECONDS on staging: a MoMo payment
    completes on its own, in whichever process asks next."""

    @staticmethod
    def _service(session: AsyncSession, seconds: int = 0) -> PaymentService:
        settings = get_settings().model_copy(
            update={"PAYMENTS_SANDBOX_AUTO_APPROVE_SECONDS": seconds}
        )
        return PaymentService(session, settings=settings)

    async def test_the_passengers_sync_confirms_the_booking(
        self, db_session: AsyncSession, make_user
    ) -> None:
        passenger_id = (await make_user()).id
        booking_id = await _make_pending_booking(
            db_session, passenger_id=passenger_id, make_user=make_user
        )
        service = self._service(db_session)
        payment = await service.pay_for_booking(
            passenger_id,
            booking_id,
            channel=PaymentChannel.MTN_MOMO,
            payer_phone="0244000001",
            idempotency_key=None,
        )
        assert payment.status == PaymentStatus.PROCESSING
        # The API process that started it is gone (a sleeping server).
        SandboxPaymentProvider.clear()

        synced = await service.sync_payment_status(payment.id)
        assert synced.status == PaymentStatus.SUCCESSFUL
        booking = await BookingService(db_session)._bookings.get_by_id(booking_id)
        assert booking is not None
        assert booking.status == BookingStatus.CONFIRMED

    async def test_the_celery_sweep_approves_it_too(
        self, db_session: AsyncSession, make_user
    ) -> None:
        passenger_id = (await make_user()).id
        booking_id = await _make_pending_booking(
            db_session, passenger_id=passenger_id, make_user=make_user
        )
        service = self._service(db_session)
        payment = await service.pay_for_booking(
            passenger_id,
            booking_id,
            channel=PaymentChannel.MTN_MOMO,
            payer_phone="0244000001",
            idempotency_key=None,
        )
        stored = await service.get_payment(payment.id, requesting_user_id=passenger_id)
        stored.created_at = datetime.now(UTC) - timedelta(seconds=600)
        await db_session.flush()
        # The worker is another process: it never saw this payment start.
        SandboxPaymentProvider.clear()

        assert await service.reconcile_pending_payments(older_than_seconds=300) >= 1
        refreshed = await service.get_payment(payment.id, requesting_user_id=passenger_id)
        assert refreshed.status == PaymentStatus.SUCCESSFUL

    async def test_a_number_that_never_answers_stays_processing(
        self, db_session: AsyncSession, make_user
    ) -> None:
        passenger_id = (await make_user()).id
        booking_id = await _make_pending_booking(
            db_session, passenger_id=passenger_id, make_user=make_user
        )
        service = self._service(db_session)
        payment = await service.pay_for_booking(
            passenger_id,
            booking_id,
            channel=PaymentChannel.MTN_MOMO,
            payer_phone="0249999999",
            idempotency_key=None,
        )
        SandboxPaymentProvider.clear()
        synced = await service.sync_payment_status(payment.id)
        assert synced.status == PaymentStatus.PROCESSING
        booking = await BookingService(db_session)._bookings.get_by_id(booking_id)
        assert booking is not None
        assert booking.status == BookingStatus.PAYMENT_PENDING

    async def test_a_declined_number_lets_the_passenger_try_again(
        self, db_session: AsyncSession, make_user
    ) -> None:
        passenger_id = (await make_user()).id
        booking_id = await _make_pending_booking(
            db_session, passenger_id=passenger_id, make_user=make_user
        )
        service = self._service(db_session)
        payment = await service.pay_for_booking(
            passenger_id,
            booking_id,
            channel=PaymentChannel.MTN_MOMO,
            payer_phone="0240000000",
            idempotency_key=None,
        )
        synced = await service.sync_payment_status(payment.id)
        assert synced.status == PaymentStatus.FAILED
        assert synced.failure_reason == "Customer declined the payment prompt."
        booking = await BookingService(db_session)._bookings.get_by_id(booking_id)
        assert booking is not None
        assert booking.status == BookingStatus.PENDING

    async def test_a_wallet_top_up_is_credited_the_same_way(
        self, db_session: AsyncSession, make_user
    ) -> None:
        passenger_id = (await make_user()).id
        service = self._service(db_session)
        payment = await service.initiate_wallet_topup(
            passenger_id,
            amount=Decimal("50.00"),
            channel=PaymentChannel.MTN_MOMO,
            payer_phone="0244000001",
            idempotency_key=None,
        )
        assert payment.status == PaymentStatus.PROCESSING
        SandboxPaymentProvider.clear()

        synced = await service.sync_payment_status(payment.id)
        assert synced.status == PaymentStatus.SUCCESSFUL
        assert await WalletService(db_session).get_balance(passenger_id) == Decimal("50.00")
