"""Refund review and payout.

Cancellation eligibility (can this booking be cancelled, and is it
refund-eligible) is decided instantly by ``BookingService`` — but releasing
real money is a separate, explicitly admin-gated step: cancelling a booking
only ever creates a ``RefundRequest`` in ``PENDING`` status
(``PaymentService.create_refund_request_for_cancelled_booking``); actually
moving money happens only here, once a holder of ``Permission.REFUNDS_APPROVE``
approves it.
"""

from __future__ import annotations

import uuid
from datetime import UTC, datetime

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings, get_settings
from app.core.exceptions import (
    InvalidStateTransitionError,
    NotFoundError,
    ProviderError,
    RefundNotAllowedError,
)
from app.core.logging import get_logger
from app.models.bookings import BookingStatus
from app.models.payments import PaymentStatus, RefundRequest, RefundStatus, WalletReferenceType
from app.providers.payments.base import PaymentChannel
from app.providers.payments.factory import get_payment_provider
from app.repositories.booking_repository import BookingRepository
from app.repositories.payment_repository import PaymentRepository
from app.services.wallet_service import WalletService

logger = get_logger(__name__)


class RefundService:
    def __init__(self, session: AsyncSession, settings: Settings | None = None) -> None:
        self._session = session
        self._settings = settings or get_settings()
        self._payments = PaymentRepository(session)
        self._bookings = BookingRepository(session)
        self._wallets = WalletService(session)

    async def get_refund_request(self, refund_id: uuid.UUID) -> RefundRequest:
        refund_request = await self._payments.get_refund_request_by_id(refund_id)
        if refund_request is None:
            raise NotFoundError("Refund request not found.")
        return refund_request

    async def list_refund_requests(
        self, *, status: RefundStatus | None, limit: int, offset: int
    ) -> tuple[list[RefundRequest], int]:
        return await self._payments.list_refund_requests(status=status, limit=limit, offset=offset)

    async def approve_and_process(
        self, refund_id: uuid.UUID, *, reviewer_id: uuid.UUID, notes: str | None
    ) -> RefundRequest:
        refund_request = await self._payments.get_refund_request_for_update(refund_id)
        if refund_request is None:
            raise NotFoundError("Refund request not found.")
        if refund_request.status == RefundStatus.COMPLETED:
            return refund_request  # idempotent: repeat approval of an already-paid refund
        if refund_request.status != RefundStatus.PENDING:
            raise InvalidStateTransitionError(
                f"Cannot approve a refund request in status '{refund_request.status.value}'."
            )

        payment = await self._payments.get_for_update(refund_request.payment_id)
        if payment is None:
            raise NotFoundError("The payment behind this refund request no longer exists.")
        refundable = payment.amount - payment.refunded_amount
        if refund_request.amount > refundable:
            raise RefundNotAllowedError(
                "Refund amount exceeds the payment's refundable balance.",
                details={"refundable": str(refundable), "requested": str(refund_request.amount)},
            )

        refund_request.reviewed_by = reviewer_id
        refund_request.reviewed_at = datetime.now(UTC)
        refund_request.decision_notes = notes
        refund_request.status = RefundStatus.APPROVED

        success: bool
        provider_reference: str | None
        error: str | None
        if payment.channel == PaymentChannel.WALLET:
            await self._wallets.credit(
                payment.user_id,
                amount=refund_request.amount,
                reference_type=WalletReferenceType.REFUND,
                reference_id=refund_request.id,
                description=f"Refund for payment {payment.internal_reference}",
                idempotency_key=str(refund_request.id),
            )
            success, provider_reference, error = True, None, None
        else:
            provider = get_payment_provider(payment.channel, self._settings)
            try:
                result = await provider.refund(
                    provider_reference=payment.provider_reference or payment.internal_reference,
                    amount=refund_request.amount,
                    reason=refund_request.reason or "",
                )
                success, provider_reference, error = (
                    result.success,
                    result.provider_refund_reference,
                    result.error,
                )
            except ProviderError as exc:
                success, provider_reference, error = False, None, str(exc)

        if success:
            refund_request.status = RefundStatus.COMPLETED
            refund_request.provider_refund_reference = provider_reference
            payment.refunded_amount += refund_request.amount
            new_payment_status = (
                PaymentStatus.REFUNDED
                if payment.refunded_amount >= payment.amount
                else PaymentStatus.PARTIALLY_REFUNDED
            )
            await self._payments.set_status(payment, new_status=new_payment_status)
            if refund_request.booking_id is not None:
                booking = await self._bookings.get_for_update(refund_request.booking_id)
                if booking is not None and booking.status == BookingStatus.REFUND_PENDING:
                    await self._bookings.set_status(
                        booking,
                        new_status=BookingStatus.REFUNDED,
                        changed_by=reviewer_id,
                        reason="Refund completed",
                    )
            logger.info(
                "refund_completed",
                refund_request_id=str(refund_request.id),
                amount=str(refund_request.amount),
            )
        else:
            refund_request.status = RefundStatus.FAILED
            refund_request.failure_reason = error
            logger.warning("refund_failed", refund_request_id=str(refund_request.id), error=error)

        await self._session.flush()
        return refund_request

    async def reject(
        self, refund_id: uuid.UUID, *, reviewer_id: uuid.UUID, notes: str | None
    ) -> RefundRequest:
        refund_request = await self._payments.get_refund_request_for_update(refund_id)
        if refund_request is None:
            raise NotFoundError("Refund request not found.")
        if refund_request.status != RefundStatus.PENDING:
            raise InvalidStateTransitionError(
                f"Cannot reject a refund request in status '{refund_request.status.value}'."
            )
        refund_request.status = RefundStatus.REJECTED
        refund_request.reviewed_by = reviewer_id
        refund_request.reviewed_at = datetime.now(UTC)
        refund_request.decision_notes = notes
        await self._session.flush()
        logger.info("refund_rejected", refund_request_id=str(refund_request.id))
        return refund_request
