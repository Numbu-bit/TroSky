"""Wallet withdrawals: a driver/fleet-owner cashing out to mobile money.

The wallet is debited at *approval*, not at request time (see
``app.models.payments.WithdrawalRequest`` for the reasoning) — so a
request that's later rejected never touched the balance at all, and one
that's approved-but-fails is reversed by crediting the same amount back
rather than leaving the requester's funds in limbo.
"""

from __future__ import annotations

import uuid
from datetime import UTC, datetime
from decimal import Decimal

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings, get_settings
from app.core.exceptions import ConflictError, InvalidStateTransitionError, NotFoundError
from app.core.logging import get_logger
from app.models.payments import WalletReferenceType, WithdrawalRequest, WithdrawalStatus
from app.providers.payments.base import PaymentChannel
from app.repositories.payment_repository import PaymentRepository
from app.services.wallet_service import WalletService

logger = get_logger(__name__)

_WITHDRAWABLE_CHANNELS = frozenset(
    {PaymentChannel.MTN_MOMO, PaymentChannel.TELECEL_CASH, PaymentChannel.AIRTELTIGO_MONEY}
)


class WithdrawalService:
    def __init__(self, session: AsyncSession, settings: Settings | None = None) -> None:
        self._session = session
        self._settings = settings or get_settings()
        self._withdrawals = PaymentRepository(session)
        self._wallets = WalletService(session)

    async def request_withdrawal(
        self,
        user_id: uuid.UUID,
        *,
        amount: Decimal,
        channel: PaymentChannel,
        destination_phone_number: str,
    ) -> WithdrawalRequest:
        if channel not in _WITHDRAWABLE_CHANNELS:
            raise ConflictError(
                "Withdrawals must go to a mobile money channel.",
                code="INVALID_WITHDRAWAL_CHANNEL",
            )
        if amount < self._settings.MIN_WITHDRAWAL_AMOUNT_GHS:
            raise ConflictError(
                f"Minimum withdrawal amount is GHS {self._settings.MIN_WITHDRAWAL_AMOUNT_GHS}.",
                code="WITHDRAWAL_BELOW_MINIMUM",
            )
        balance = await self._wallets.get_balance(user_id)
        if amount > balance:
            raise ConflictError(
                "Requested amount exceeds the current wallet balance.",
                code="WITHDRAWAL_EXCEEDS_BALANCE",
                details={"balance": str(balance), "requested": str(amount)},
            )

        withdrawal = await self._withdrawals.create_withdrawal_request(
            user_id=user_id,
            amount=amount,
            channel=channel,
            destination_phone_number=destination_phone_number,
        )
        logger.info("withdrawal_requested", withdrawal_id=str(withdrawal.id), amount=str(amount))
        return withdrawal

    async def get_withdrawal(
        self,
        withdrawal_id: uuid.UUID,
        *,
        requesting_user_id: uuid.UUID,
        is_privileged: bool = False,
    ) -> WithdrawalRequest:
        withdrawal = await self._withdrawals.get_withdrawal_request_by_id(withdrawal_id)
        if withdrawal is None:
            raise NotFoundError("Withdrawal request not found.")
        if not is_privileged and withdrawal.user_id != requesting_user_id:
            raise NotFoundError("Withdrawal request not found.")
        return withdrawal

    async def list_own_withdrawals(
        self, user_id: uuid.UUID, *, limit: int, offset: int
    ) -> tuple[list[WithdrawalRequest], int]:
        return await self._withdrawals.list_withdrawal_requests_for_user(
            user_id, limit=limit, offset=offset
        )

    async def list_all_withdrawals(
        self, *, status: WithdrawalStatus | None, limit: int, offset: int
    ) -> tuple[list[WithdrawalRequest], int]:
        return await self._withdrawals.list_all_withdrawal_requests(
            status=status, limit=limit, offset=offset
        )

    async def approve(
        self, withdrawal_id: uuid.UUID, *, reviewer_id: uuid.UUID, notes: str | None
    ) -> WithdrawalRequest:
        withdrawal = await self._withdrawals.get_withdrawal_request_for_update(withdrawal_id)
        if withdrawal is None:
            raise NotFoundError("Withdrawal request not found.")
        if withdrawal.status != WithdrawalStatus.PENDING:
            raise InvalidStateTransitionError(
                f"Cannot approve a withdrawal request in status '{withdrawal.status.value}'."
            )

        await self._wallets.debit(
            withdrawal.user_id,
            amount=withdrawal.amount,
            reference_type=WalletReferenceType.WITHDRAWAL,
            reference_id=withdrawal.id,
            description=f"Withdrawal to {withdrawal.destination_phone_number}",
            idempotency_key=str(withdrawal.id),
        )
        withdrawal.status = WithdrawalStatus.APPROVED
        withdrawal.reviewed_by = reviewer_id
        withdrawal.reviewed_at = datetime.now(UTC)
        withdrawal.decision_notes = notes
        await self._session.flush()
        logger.info("withdrawal_approved", withdrawal_id=str(withdrawal_id))
        return withdrawal

    async def reject(
        self, withdrawal_id: uuid.UUID, *, reviewer_id: uuid.UUID, notes: str | None
    ) -> WithdrawalRequest:
        withdrawal = await self._withdrawals.get_withdrawal_request_for_update(withdrawal_id)
        if withdrawal is None:
            raise NotFoundError("Withdrawal request not found.")
        if withdrawal.status != WithdrawalStatus.PENDING:
            raise InvalidStateTransitionError(
                f"Cannot reject a withdrawal request in status '{withdrawal.status.value}'."
            )
        withdrawal.status = WithdrawalStatus.REJECTED
        withdrawal.reviewed_by = reviewer_id
        withdrawal.reviewed_at = datetime.now(UTC)
        withdrawal.decision_notes = notes
        await self._session.flush()
        logger.info("withdrawal_rejected", withdrawal_id=str(withdrawal_id))
        return withdrawal

    async def complete(
        self, withdrawal_id: uuid.UUID, *, reviewer_id: uuid.UUID, provider_reference: str | None
    ) -> WithdrawalRequest:
        """Marks the payout as actually sent — an explicit admin
        confirmation, not an automated disbursement (see the model
        docstring)."""
        withdrawal = await self._withdrawals.get_withdrawal_request_for_update(withdrawal_id)
        if withdrawal is None:
            raise NotFoundError("Withdrawal request not found.")
        if withdrawal.status == WithdrawalStatus.COMPLETED:
            return withdrawal  # idempotent
        if withdrawal.status != WithdrawalStatus.APPROVED:
            raise InvalidStateTransitionError(
                f"Cannot complete a withdrawal request in status '{withdrawal.status.value}'."
            )
        withdrawal.status = WithdrawalStatus.COMPLETED
        withdrawal.provider_reference = provider_reference
        await self._session.flush()
        logger.info("withdrawal_completed", withdrawal_id=str(withdrawal_id))
        return withdrawal

    async def mark_failed(
        self, withdrawal_id: uuid.UUID, *, reviewer_id: uuid.UUID, reason: str
    ) -> WithdrawalRequest:
        """The payout could not be completed after approval — reverses the
        debit by crediting the same amount back."""
        withdrawal = await self._withdrawals.get_withdrawal_request_for_update(withdrawal_id)
        if withdrawal is None:
            raise NotFoundError("Withdrawal request not found.")
        if withdrawal.status != WithdrawalStatus.APPROVED:
            raise InvalidStateTransitionError(
                f"Cannot fail a withdrawal request in status '{withdrawal.status.value}'."
            )
        await self._wallets.credit(
            withdrawal.user_id,
            amount=withdrawal.amount,
            reference_type=WalletReferenceType.WITHDRAWAL,
            reference_id=withdrawal.id,
            description=f"Withdrawal reversal: {reason}",
            idempotency_key=f"{withdrawal.id}-reversal",
        )
        withdrawal.status = WithdrawalStatus.FAILED
        withdrawal.failure_reason = reason
        await self._session.flush()
        logger.info("withdrawal_failed", withdrawal_id=str(withdrawal_id), reason=reason)
        return withdrawal
