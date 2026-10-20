"""Payment lifecycle: booking payments, wallet top-ups, and idempotent,
signature-verified webhook processing.

Confirmation model — the spec's "never trust a client-submitted
payment-successful flag" requirement, enforced structurally: a booking
payment only ever reaches ``PaymentStatus.SUCCESSFUL`` via
:meth:`PaymentService.process_webhook` (a server-verified inbound
notification) or :meth:`PaymentService.sync_payment_status` (a server-
initiated poll against the provider) — never via any client-facing
endpoint setting a status directly. Both paths funnel through the same
``_apply_provider_status`` so the outcome is identical regardless of which
one actually observes success first (whichever arrives first wins; the
other is a no-op against an already-terminal payment).

The wallet channel bypasses the provider abstraction entirely: a wallet
payment is a synchronous, immediately-final debit — there is no external
party to wait on, so there is no PROCESSING state and no webhook for it.
"""

from __future__ import annotations

import hashlib
import json
import uuid
from collections.abc import Mapping
from datetime import UTC, datetime, timedelta
from decimal import Decimal

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings, get_settings
from app.core.exceptions import (
    ConflictError,
    IdempotencyConflictError,
    InvalidWebhookSignatureError,
    NotFoundError,
    ProviderError,
)
from app.core.logging import get_logger
from app.core.telemetry import PAYMENT_EVENTS_TOTAL, WEBHOOK_EVENTS_TOTAL
from app.models.bookings import Booking, BookingStatus
from app.models.payments import (
    Payment,
    PaymentPurpose,
    PaymentStatus,
    RefundRequest,
    RefundStatus,
    WalletReferenceType,
)
from app.providers.payments.base import PaymentChannel, PaymentProviderStatus
from app.providers.payments.factory import get_payment_provider
from app.repositories.booking_repository import BookingRepository
from app.repositories.payment_repository import PaymentRepository, generate_internal_reference
from app.services.booking_service import BookingService
from app.services.wallet_service import WalletService

logger = get_logger(__name__)

_PENDING_OR_PROCESSING = (PaymentStatus.PENDING, PaymentStatus.PROCESSING)


class PaymentService:
    def __init__(self, session: AsyncSession, settings: Settings | None = None) -> None:
        self._session = session
        self._settings = settings or get_settings()
        self._payments = PaymentRepository(session)
        self._bookings = BookingRepository(session)
        self._wallets = WalletService(session)
        self._booking_service = BookingService(session, settings=self._settings)

    @staticmethod
    def _hash_request(
        *, booking_id: uuid.UUID | None, channel: PaymentChannel, amount: Decimal
    ) -> str:
        raw = f"{booking_id}:{channel.value}:{amount}"
        return hashlib.sha256(raw.encode("utf-8")).hexdigest()

    async def _get_or_create_payment(
        self,
        *,
        user_id: uuid.UUID,
        booking_id: uuid.UUID | None,
        purpose: PaymentPurpose,
        channel: PaymentChannel,
        amount: Decimal,
        payer_phone: str | None,
        idempotency_key: uuid.UUID | None,
    ) -> tuple[Payment, bool]:
        """Returns ``(payment, is_new)``."""
        request_hash = self._hash_request(booking_id=booking_id, channel=channel, amount=amount)
        if idempotency_key is not None:
            existing = await self._payments.get_by_idempotency_key(user_id, idempotency_key)
            if existing is not None:
                if existing.idempotency_request_hash != request_hash:
                    raise IdempotencyConflictError()
                return existing, False

        payment = await self._payments.create_payment(
            user_id=user_id,
            booking_id=booking_id,
            purpose=purpose,
            channel=channel,
            amount=amount,
            payer_phone_number=payer_phone,
            internal_reference=generate_internal_reference(),
            idempotency_key=idempotency_key,
            idempotency_request_hash=request_hash,
        )
        return payment, True

    # ------------------------------------------------------------------
    # Booking payment
    # ------------------------------------------------------------------
    async def pay_for_booking(
        self,
        user_id: uuid.UUID,
        booking_id: uuid.UUID,
        *,
        channel: PaymentChannel,
        payer_phone: str | None,
        idempotency_key: uuid.UUID | None,
    ) -> Payment:
        booking = await self._bookings.get_for_update(booking_id)
        if booking is None or booking.passenger_id != user_id:
            raise NotFoundError("Booking not found.")
        # A retry of a payment already made for this booking has, by
        # definition, moved the booking past PENDING — it must still get its
        # original payment back rather than a conflict.
        replay = (
            await self._payments.get_by_idempotency_key(user_id, idempotency_key)
            if idempotency_key is not None
            else None
        )
        is_replay = replay is not None and replay.booking_id == booking.id
        if booking.status != BookingStatus.PENDING and not is_replay:
            raise ConflictError(
                f"Booking is not awaiting payment (status: {booking.status.value}).",
                code="BOOKING_NOT_PAYABLE",
            )

        payment, is_new = await self._get_or_create_payment(
            user_id=user_id,
            booking_id=booking.id,
            purpose=PaymentPurpose.BOOKING_PAYMENT,
            channel=channel,
            amount=booking.total_amount,
            payer_phone=payer_phone,
            idempotency_key=idempotency_key,
        )
        if not is_new:
            return payment

        if channel == PaymentChannel.WALLET:
            await self._wallets.debit(
                user_id,
                amount=payment.amount,
                reference_type=WalletReferenceType.BOOKING_PAYMENT,
                reference_id=payment.id,
                description=f"Booking {booking.booking_reference}",
                idempotency_key=str(payment.id),
            )
            await self._payments.set_status(
                payment,
                new_status=PaymentStatus.SUCCESSFUL,
                completed_at=datetime.now(UTC),
            )
            await self._booking_service.confirm_booking(booking.id)
            logger.info("booking_paid_via_wallet", booking_id=str(booking.id))
            return payment

        provider = get_payment_provider(channel, self._settings)
        await self._bookings.set_status(
            booking,
            new_status=BookingStatus.PAYMENT_PENDING,
            changed_by=user_id,
            reason="Payment initiated",
        )
        try:
            result = await provider.initialize_payment(
                reference=payment.internal_reference,
                amount=payment.amount,
                currency=payment.currency,
                payer_phone=payer_phone,
                narration=f"TroSky booking {booking.booking_reference}",
            )
        except ProviderError:
            await self._payments.set_status(
                payment, new_status=PaymentStatus.FAILED, failure_reason="Provider unreachable"
            )
            raise

        new_status = (
            PaymentStatus.SUCCESSFUL
            if result.status == PaymentProviderStatus.SUCCESSFUL
            else PaymentStatus.PROCESSING
            if result.status == PaymentProviderStatus.PENDING
            else PaymentStatus.FAILED
        )
        await self._payments.set_status(
            payment, new_status=new_status, provider_reference=result.provider_reference
        )
        logger.info(
            "booking_payment_initiated",
            booking_id=str(booking.id),
            payment_id=str(payment.id),
            channel=channel.value,
        )
        return payment

    # ------------------------------------------------------------------
    # Wallet top-up
    # ------------------------------------------------------------------
    async def initiate_wallet_topup(
        self,
        user_id: uuid.UUID,
        *,
        amount: Decimal,
        channel: PaymentChannel,
        payer_phone: str | None,
        idempotency_key: uuid.UUID | None,
    ) -> Payment:
        if channel == PaymentChannel.WALLET:
            raise ConflictError("Cannot top up the wallet using the wallet itself.")

        payment, is_new = await self._get_or_create_payment(
            user_id=user_id,
            booking_id=None,
            purpose=PaymentPurpose.WALLET_TOPUP,
            channel=channel,
            amount=amount,
            payer_phone=payer_phone,
            idempotency_key=idempotency_key,
        )
        if not is_new:
            return payment

        provider = get_payment_provider(channel, self._settings)
        try:
            result = await provider.initialize_payment(
                reference=payment.internal_reference,
                amount=payment.amount,
                currency=payment.currency,
                payer_phone=payer_phone,
                narration="TroSky wallet top-up",
            )
        except ProviderError:
            await self._payments.set_status(
                payment, new_status=PaymentStatus.FAILED, failure_reason="Provider unreachable"
            )
            raise

        new_status = (
            PaymentStatus.SUCCESSFUL
            if result.status == PaymentProviderStatus.SUCCESSFUL
            else PaymentStatus.PROCESSING
        )
        await self._payments.set_status(
            payment, new_status=new_status, provider_reference=result.provider_reference
        )
        if new_status == PaymentStatus.SUCCESSFUL:
            await self._credit_wallet_for_payment(payment)
        return payment

    async def _credit_wallet_for_payment(self, payment: Payment) -> None:
        await self._wallets.credit(
            payment.user_id,
            amount=payment.amount,
            reference_type=WalletReferenceType.WALLET_TOPUP,
            reference_id=payment.id,
            description="Wallet top-up",
            idempotency_key=str(payment.id),
        )

    async def _settle_booking_payment(self, booking_id: uuid.UUID) -> None:
        """Confirm the booking a payment was for -- unless it was cancelled or
        expired while the payment was in flight (a trip cancelled by the
        operator, a hold that ran out). The money has arrived either way, so
        it is then queued for a refund rather than rejected, which would
        leave the provider retrying a webhook nobody can accept."""
        booking = await self._bookings.get_for_update(booking_id)
        if booking is not None and booking.status in (
            BookingStatus.CANCELLED,
            BookingStatus.EXPIRED,
        ):
            await self._bookings.set_status(
                booking,
                new_status=BookingStatus.REFUND_PENDING,
                changed_by=None,
                reason="Paid after the booking was cancelled or expired",
            )
            await self.create_refund_request_for_cancelled_booking(booking, requested_by=None)
            logger.warning("late_payment_queued_for_refund", booking_id=str(booking_id))
            return
        await self._booking_service.confirm_booking(booking_id)

    async def queue_refunds(
        self, bookings: list[Booking], *, requested_by: uuid.UUID | None
    ) -> list[RefundRequest]:
        """A refund request for each ``refund_pending`` booking; each still
        needs an admin's approval to pay out."""
        queued = []
        for booking in bookings:
            refund = await self.create_refund_request_for_cancelled_booking(
                booking, requested_by=requested_by
            )
            if refund is not None:
                queued.append(refund)
        return queued

    # ------------------------------------------------------------------
    # Status transition — shared by webhook processing and reconciliation
    # ------------------------------------------------------------------
    async def _apply_provider_status(
        self,
        payment: Payment,
        *,
        status: PaymentProviderStatus,
        failure_reason: str | None,
    ) -> None:
        if payment.status not in _PENDING_OR_PROCESSING:
            return  # already terminal — idempotent no-op, regardless of what arrives now

        if status == PaymentProviderStatus.SUCCESSFUL:
            await self._payments.set_status(
                payment, new_status=PaymentStatus.SUCCESSFUL, completed_at=datetime.now(UTC)
            )
            if payment.purpose == PaymentPurpose.BOOKING_PAYMENT and payment.booking_id is not None:
                await self._settle_booking_payment(payment.booking_id)
            elif payment.purpose == PaymentPurpose.WALLET_TOPUP:
                await self._credit_wallet_for_payment(payment)
            PAYMENT_EVENTS_TOTAL.labels(provider=payment.channel.value, outcome="successful").inc()
            logger.info("payment_succeeded", payment_id=str(payment.id))
        elif status == PaymentProviderStatus.FAILED:
            await self._payments.set_status(
                payment, new_status=PaymentStatus.FAILED, failure_reason=failure_reason
            )
            PAYMENT_EVENTS_TOTAL.labels(provider=payment.channel.value, outcome="failed").inc()
            if payment.purpose == PaymentPurpose.BOOKING_PAYMENT and payment.booking_id is not None:
                booking = await self._bookings.get_for_update(payment.booking_id)
                if booking is not None and booking.status == BookingStatus.PAYMENT_PENDING:
                    # Let the passenger retry (a different channel, or the
                    # same one again) rather than waiting out the full
                    # reservation hold on a payment that has already failed.
                    await self._bookings.set_status(
                        booking,
                        new_status=BookingStatus.PENDING,
                        changed_by=None,
                        reason="Payment failed; seat hold retained for retry",
                    )
            logger.info("payment_failed", payment_id=str(payment.id), reason=failure_reason)
        # PENDING: nothing to do — already PROCESSING.

    async def process_webhook(
        self, channel: PaymentChannel, headers: Mapping[str, str], raw_body: bytes
    ) -> None:
        provider = get_payment_provider(channel, self._settings)
        signature_valid = provider.verify_webhook_signature(headers, raw_body)
        if not signature_valid:
            raise InvalidWebhookSignatureError()

        payload = json.loads(raw_body)
        event = provider.parse_webhook_event(headers, payload)

        webhook_event, is_new = await self._payments.record_webhook_event(
            channel=channel,
            provider_reference=event.provider_reference,
            event_status=event.status.value,
            signature_valid=signature_valid,
            raw_payload=payload,
        )
        # A repeat of a callback whose content is believed changes nothing.
        # One that only names a payment to check (MTN MoMo) is checked again
        # while the payment is open: an earlier, forged copy saying the same
        # must not make the real one be ignored.
        trusted = getattr(provider, "trusts_webhook_status", True)
        if not is_new and trusted:
            WEBHOOK_EVENTS_TOTAL.labels(provider=channel.value, result="duplicate").inc()
            logger.info(
                "payment_webhook_duplicate_ignored",
                channel=channel.value,
                reference=event.provider_reference,
            )
            return

        payment = await self._payments.get_by_internal_reference_for_update(
            event.provider_reference
        )
        if payment is None:
            WEBHOOK_EVENTS_TOTAL.labels(provider=channel.value, result="unmatched").inc()
            logger.warning(
                "payment_webhook_unmatched",
                channel=channel.value,
                reference=event.provider_reference,
            )
            await self._payments.mark_webhook_event_processed(webhook_event, payment_id=None)
            return

        WEBHOOK_EVENTS_TOTAL.labels(provider=channel.value, result="processed").inc()
        status, failure_reason = event.status, event.failure_reason
        if not trusted and payment.status in _PENDING_OR_PROCESSING:
            # An unsigned callback (MTN MoMo) only says which payment to
            # check: what the provider itself answers is what counts.
            result = await provider.query_payment(
                payment.provider_reference or payment.internal_reference
            )
            status, failure_reason = result.status, result.failure_reason
        await self._apply_provider_status(payment, status=status, failure_reason=failure_reason)
        await self._payments.mark_webhook_event_processed(webhook_event, payment_id=payment.id)

    async def sync_payment_status(self, payment_id: uuid.UUID) -> Payment:
        """Polls the provider directly — the reconciliation fallback for a
        lost or delayed webhook (used by the Celery beat task and available
        for on-demand admin use)."""
        payment = await self._payments.get_for_update(payment_id)
        if payment is None:
            raise NotFoundError("Payment not found.")
        if payment.status not in _PENDING_OR_PROCESSING or payment.channel == PaymentChannel.WALLET:
            return payment

        provider = get_payment_provider(payment.channel, self._settings)
        reference = payment.provider_reference or payment.internal_reference
        result = await provider.query_payment(reference)
        await self._apply_provider_status(
            payment, status=result.status, failure_reason=result.failure_reason
        )
        return payment

    # ------------------------------------------------------------------
    # Reconciliation sweep (Celery beat) — the safety net for a webhook
    # that never arrives or was lost in transit.
    # ------------------------------------------------------------------
    async def reconcile_pending_payments(
        self, *, older_than_seconds: int = 300, batch_size: int = 50
    ) -> int:
        cutoff = datetime.now(UTC) - timedelta(seconds=older_than_seconds)
        candidates = await self._payments.find_stale_processing_payments(
            older_than=cutoff, limit=batch_size
        )
        reconciled = 0
        for payment in candidates:
            provider = get_payment_provider(payment.channel, self._settings)
            reference = payment.provider_reference or payment.internal_reference
            try:
                result = await provider.query_payment(reference)
            except ProviderError:
                logger.warning(
                    "payment_reconciliation_provider_unreachable", payment_id=str(payment.id)
                )
                continue
            if result.status != PaymentProviderStatus.PENDING:
                await self._apply_provider_status(
                    payment, status=result.status, failure_reason=result.failure_reason
                )
                reconciled += 1
        if reconciled:
            logger.info("payments_reconciled", count=reconciled)
        return reconciled

    # ------------------------------------------------------------------
    # Reads
    # ------------------------------------------------------------------
    async def get_payment(
        self, payment_id: uuid.UUID, *, requesting_user_id: uuid.UUID, is_privileged: bool = False
    ) -> Payment:
        payment = await self._payments.get_by_id(payment_id)
        if payment is None:
            raise NotFoundError("Payment not found.")
        if not is_privileged and payment.user_id != requesting_user_id:
            raise NotFoundError("Payment not found.")
        return payment

    async def list_own_payments(
        self, user_id: uuid.UUID, *, limit: int, offset: int
    ) -> tuple[list[Payment], int]:
        return await self._payments.list_for_user(user_id, limit=limit, offset=offset)

    # ------------------------------------------------------------------
    # Cross-domain orchestration hook — called by the API layer right
    # after a booking cancellation/cancellation-review leaves a booking in
    # REFUND_PENDING, so the refund payout itself still goes through an
    # explicit admin approval gate rather than happening automatically.
    # ------------------------------------------------------------------
    async def create_refund_request_for_cancelled_booking(
        self, booking: Booking, *, requested_by: uuid.UUID | None
    ) -> RefundRequest | None:
        if booking.status != BookingStatus.REFUND_PENDING:
            return None

        successful_payments = await self._payments.list_successful_for_booking(booking.id)
        if not successful_payments:
            logger.error(
                "refund_pending_booking_has_no_successful_payment", booking_id=str(booking.id)
            )
            return None
        payment = successful_payments[0]

        existing = await self._payments.list_refund_requests_for_payment(payment.id)
        for candidate in existing:
            if candidate.status in (RefundStatus.PENDING, RefundStatus.APPROVED):
                return candidate  # idempotent: don't create a second request

        refundable = payment.amount - payment.refunded_amount
        return await self._payments.create_refund_request(
            payment_id=payment.id,
            booking_id=booking.id,
            requested_by=requested_by,
            amount=refundable,
            reason="Booking cancelled before departure.",
        )
