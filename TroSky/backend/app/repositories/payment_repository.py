"""Database access for payments, the inbound-webhook audit/dedupe log, and
refund requests.

``record_webhook_event`` mirrors ``BookingRepository.create_seat_reservation``:
the INSERT runs inside a ``SAVEPOINT`` so a unique-constraint violation (this
exact ``(channel, provider_reference, event_status)`` tuple already exists —
a genuine replayed delivery) can be caught and translated into "this is a
duplicate, don't reprocess it" without poisoning the caller's outer
transaction.
"""

from __future__ import annotations

import secrets
import uuid
from datetime import UTC, datetime
from decimal import Decimal
from typing import Any

from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.payments import (
    Payment,
    PaymentPurpose,
    PaymentStatus,
    PaymentWebhookEvent,
    RefundRequest,
    RefundStatus,
    WithdrawalRequest,
    WithdrawalStatus,
)
from app.providers.payments.base import PaymentChannel


def generate_internal_reference() -> str:
    return f"PAY-{secrets.token_hex(8).upper()}"


class PaymentRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    # ------------------------------------------------------------------
    # Payments
    # ------------------------------------------------------------------
    async def create_payment(
        self,
        *,
        user_id: uuid.UUID,
        booking_id: uuid.UUID | None,
        purpose: PaymentPurpose,
        channel: PaymentChannel,
        amount: Decimal,
        payer_phone_number: str | None,
        internal_reference: str,
        idempotency_key: uuid.UUID | None,
        idempotency_request_hash: str | None,
        status: PaymentStatus = PaymentStatus.PENDING,
    ) -> Payment:
        payment = Payment(
            user_id=user_id,
            booking_id=booking_id,
            purpose=purpose,
            channel=channel,
            amount=amount,
            payer_phone_number=payer_phone_number,
            internal_reference=internal_reference,
            idempotency_key=idempotency_key,
            idempotency_request_hash=idempotency_request_hash,
            status=status,
            initiated_at=datetime.now(UTC),
        )
        self._session.add(payment)
        await self._session.flush()
        return payment

    async def get_by_id(self, payment_id: uuid.UUID) -> Payment | None:
        result = await self._session.execute(select(Payment).where(Payment.id == payment_id))
        return result.scalar_one_or_none()

    async def get_for_update(self, payment_id: uuid.UUID) -> Payment | None:
        result = await self._session.execute(
            select(Payment).where(Payment.id == payment_id).with_for_update()
        )
        return result.scalar_one_or_none()

    async def get_by_internal_reference_for_update(self, reference: str) -> Payment | None:
        result = await self._session.execute(
            select(Payment).where(Payment.internal_reference == reference).with_for_update()
        )
        return result.scalar_one_or_none()

    async def get_by_idempotency_key(
        self, user_id: uuid.UUID, idempotency_key: uuid.UUID
    ) -> Payment | None:
        result = await self._session.execute(
            select(Payment).where(
                Payment.user_id == user_id, Payment.idempotency_key == idempotency_key
            )
        )
        return result.scalar_one_or_none()

    async def list_successful_for_booking(self, booking_id: uuid.UUID) -> list[Payment]:
        result = await self._session.execute(
            select(Payment)
            .where(Payment.booking_id == booking_id, Payment.status == PaymentStatus.SUCCESSFUL)
            .order_by(Payment.completed_at.desc())
        )
        return list(result.scalars().all())

    async def find_stale_processing_payments(
        self, *, older_than: datetime, limit: int
    ) -> list[Payment]:
        """Row-locks (``FOR UPDATE SKIP LOCKED``) a batch of payments still
        ``PENDING``/``PROCESSING`` well past when a webhook should have
        arrived — the reconciliation sweep's candidate set."""
        stmt = (
            select(Payment)
            .where(
                Payment.status.in_([PaymentStatus.PENDING, PaymentStatus.PROCESSING]),
                Payment.created_at < older_than,
                Payment.channel != PaymentChannel.WALLET,
            )
            .limit(limit)
            .with_for_update(skip_locked=True)
        )
        result = await self._session.execute(stmt)
        return list(result.scalars().all())

    async def list_for_user(
        self, user_id: uuid.UUID, *, limit: int, offset: int
    ) -> tuple[list[Payment], int]:
        count_result = await self._session.execute(
            select(Payment.id).where(Payment.user_id == user_id)
        )
        total = len(count_result.scalars().all())
        result = await self._session.execute(
            select(Payment)
            .where(Payment.user_id == user_id)
            .order_by(Payment.created_at.desc())
            .limit(limit)
            .offset(offset)
        )
        return list(result.scalars().all()), total

    async def set_status(
        self,
        payment: Payment,
        *,
        new_status: PaymentStatus,
        failure_reason: str | None = None,
        completed_at: datetime | None = None,
        provider_reference: str | None = None,
    ) -> None:
        payment.status = new_status
        if failure_reason is not None:
            payment.failure_reason = failure_reason
        if completed_at is not None:
            payment.completed_at = completed_at
        if provider_reference is not None:
            payment.provider_reference = provider_reference
        await self._session.flush()

    # ------------------------------------------------------------------
    # Webhook events (idempotent record-or-detect-duplicate)
    # ------------------------------------------------------------------
    async def record_webhook_event(
        self,
        *,
        channel: PaymentChannel,
        provider_reference: str,
        event_status: str,
        signature_valid: bool,
        raw_payload: dict[str, Any],
    ) -> tuple[PaymentWebhookEvent, bool]:
        """Returns ``(event, is_new)``. ``is_new=False`` means this exact
        event was already recorded — the caller must not reprocess it."""
        event = PaymentWebhookEvent(
            channel=channel,
            provider_reference=provider_reference,
            event_status=event_status,
            signature_valid=signature_valid,
            raw_payload=raw_payload,
        )
        try:
            async with self._session.begin_nested():
                self._session.add(event)
                await self._session.flush()
        except IntegrityError:
            result = await self._session.execute(
                select(PaymentWebhookEvent).where(
                    PaymentWebhookEvent.channel == channel,
                    PaymentWebhookEvent.provider_reference == provider_reference,
                    PaymentWebhookEvent.event_status == event_status,
                )
            )
            existing = result.scalar_one()
            return existing, False
        return event, True

    async def mark_webhook_event_processed(
        self, event: PaymentWebhookEvent, *, payment_id: uuid.UUID | None
    ) -> None:
        event.processed_at = datetime.now(UTC)
        event.payment_id = payment_id
        await self._session.flush()

    # ------------------------------------------------------------------
    # Refund requests
    # ------------------------------------------------------------------
    async def create_refund_request(
        self,
        *,
        payment_id: uuid.UUID,
        booking_id: uuid.UUID | None,
        requested_by: uuid.UUID | None,
        amount: Decimal,
        reason: str | None,
    ) -> RefundRequest:
        refund_request = RefundRequest(
            payment_id=payment_id,
            booking_id=booking_id,
            requested_by=requested_by,
            amount=amount,
            reason=reason,
        )
        self._session.add(refund_request)
        await self._session.flush()
        return refund_request

    async def get_refund_request_by_id(self, refund_id: uuid.UUID) -> RefundRequest | None:
        result = await self._session.execute(
            select(RefundRequest).where(RefundRequest.id == refund_id)
        )
        return result.scalar_one_or_none()

    async def get_refund_request_for_update(self, refund_id: uuid.UUID) -> RefundRequest | None:
        result = await self._session.execute(
            select(RefundRequest).where(RefundRequest.id == refund_id).with_for_update()
        )
        return result.scalar_one_or_none()

    async def list_refund_requests_for_payment(self, payment_id: uuid.UUID) -> list[RefundRequest]:
        result = await self._session.execute(
            select(RefundRequest).where(RefundRequest.payment_id == payment_id)
        )
        return list(result.scalars().all())

    async def list_refund_requests(
        self, *, status: RefundStatus | None, limit: int, offset: int
    ) -> tuple[list[RefundRequest], int]:
        stmt = select(RefundRequest)
        if status is not None:
            stmt = stmt.where(RefundRequest.status == status)
        count_result = await self._session.execute(
            select(func.count()).select_from(stmt.subquery())
        )
        total = count_result.scalar_one()
        result = await self._session.execute(
            stmt.order_by(RefundRequest.created_at.desc()).limit(limit).offset(offset)
        )
        return list(result.scalars().all()), total

    # ------------------------------------------------------------------
    # Withdrawal requests
    # ------------------------------------------------------------------
    async def create_withdrawal_request(
        self,
        *,
        user_id: uuid.UUID,
        amount: Decimal,
        channel: PaymentChannel,
        destination_phone_number: str,
    ) -> WithdrawalRequest:
        withdrawal = WithdrawalRequest(
            user_id=user_id,
            amount=amount,
            channel=channel,
            destination_phone_number=destination_phone_number,
        )
        self._session.add(withdrawal)
        await self._session.flush()
        return withdrawal

    async def get_withdrawal_request_by_id(
        self, withdrawal_id: uuid.UUID
    ) -> WithdrawalRequest | None:
        result = await self._session.execute(
            select(WithdrawalRequest).where(WithdrawalRequest.id == withdrawal_id)
        )
        return result.scalar_one_or_none()

    async def get_withdrawal_request_for_update(
        self, withdrawal_id: uuid.UUID
    ) -> WithdrawalRequest | None:
        result = await self._session.execute(
            select(WithdrawalRequest).where(WithdrawalRequest.id == withdrawal_id).with_for_update()
        )
        return result.scalar_one_or_none()

    async def list_withdrawal_requests_for_user(
        self, user_id: uuid.UUID, *, limit: int, offset: int
    ) -> tuple[list[WithdrawalRequest], int]:
        count_result = await self._session.execute(
            select(WithdrawalRequest.id).where(WithdrawalRequest.user_id == user_id)
        )
        total = len(count_result.scalars().all())
        result = await self._session.execute(
            select(WithdrawalRequest)
            .where(WithdrawalRequest.user_id == user_id)
            .order_by(WithdrawalRequest.created_at.desc())
            .limit(limit)
            .offset(offset)
        )
        return list(result.scalars().all()), total

    async def list_all_withdrawal_requests(
        self, *, status: WithdrawalStatus | None, limit: int, offset: int
    ) -> tuple[list[WithdrawalRequest], int]:
        stmt = select(WithdrawalRequest)
        if status is not None:
            stmt = stmt.where(WithdrawalRequest.status == status)
        count_result = await self._session.execute(
            select(func.count()).select_from(stmt.subquery())
        )
        total = count_result.scalar_one()
        result = await self._session.execute(
            stmt.order_by(WithdrawalRequest.created_at.desc()).limit(limit).offset(offset)
        )
        return list(result.scalars().all()), total
