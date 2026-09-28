"""Integration tests for WithdrawalService: requesting (minimum amount,
balance sufficiency, channel validation), approval debiting the wallet at
approval time (not request time), rejection never touching the balance,
completion, and a failed payout reversing the debit — against a real
Postgres."""

from __future__ import annotations

import uuid
from decimal import Decimal

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ConflictError, InvalidStateTransitionError
from app.models.payments import WalletReferenceType, WithdrawalStatus
from app.providers.payments.base import PaymentChannel
from app.services.wallet_service import WalletService
from app.services.withdrawal_service import WithdrawalService

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]


async def _funded_user(
    session: AsyncSession, make_user, *, amount: Decimal = Decimal("100.00")
) -> uuid.UUID:
    # wallets.user_id is a foreign key to users.id, so the owner must exist.
    user_id = (await make_user()).id
    await WalletService(session).credit(
        user_id,
        amount=amount,
        reference_type=WalletReferenceType.WALLET_TOPUP,
        reference_id=None,
        description="Top-up",
    )
    return user_id


class TestRequestWithdrawal:
    async def test_request_within_balance_succeeds(
        self, db_session: AsyncSession, make_user
    ) -> None:
        user_id = await _funded_user(db_session, make_user)
        service = WithdrawalService(db_session)
        withdrawal = await service.request_withdrawal(
            user_id,
            amount=Decimal("50.00"),
            channel=PaymentChannel.MTN_MOMO,
            destination_phone_number="0244000001",
        )
        assert withdrawal.status == WithdrawalStatus.PENDING

    async def test_request_does_not_touch_balance_yet(
        self, db_session: AsyncSession, make_user
    ) -> None:
        user_id = await _funded_user(db_session, make_user)
        service = WithdrawalService(db_session)
        await service.request_withdrawal(
            user_id,
            amount=Decimal("50.00"),
            channel=PaymentChannel.MTN_MOMO,
            destination_phone_number="0244000001",
        )
        balance = await WalletService(db_session).get_balance(user_id)
        assert balance == Decimal("100.00")  # unchanged until approval

    async def test_request_exceeding_balance_rejected(
        self, db_session: AsyncSession, make_user
    ) -> None:
        user_id = await _funded_user(db_session, make_user, amount=Decimal("10.00"))
        service = WithdrawalService(db_session)
        with pytest.raises(ConflictError):
            await service.request_withdrawal(
                user_id,
                amount=Decimal("50.00"),
                channel=PaymentChannel.MTN_MOMO,
                destination_phone_number="0244000001",
            )

    async def test_request_below_minimum_rejected(
        self, db_session: AsyncSession, make_user
    ) -> None:
        user_id = await _funded_user(db_session, make_user)
        service = WithdrawalService(db_session)
        with pytest.raises(ConflictError):
            await service.request_withdrawal(
                user_id,
                amount=Decimal("1.00"),
                channel=PaymentChannel.MTN_MOMO,
                destination_phone_number="0244000001",
            )

    async def test_wallet_channel_rejected(self, db_session: AsyncSession, make_user) -> None:
        user_id = await _funded_user(db_session, make_user)
        service = WithdrawalService(db_session)
        with pytest.raises(ConflictError):
            await service.request_withdrawal(
                user_id,
                amount=Decimal("50.00"),
                channel=PaymentChannel.WALLET,
                destination_phone_number="0244000001",
            )


class TestWithdrawalDecisions:
    async def test_approve_debits_wallet(self, db_session: AsyncSession, make_user) -> None:
        user_id = await _funded_user(db_session, make_user)
        service = WithdrawalService(db_session)
        withdrawal = await service.request_withdrawal(
            user_id,
            amount=Decimal("50.00"),
            channel=PaymentChannel.MTN_MOMO,
            destination_phone_number="0244000001",
        )
        approved = await service.approve(
            withdrawal.id, reviewer_id=(await make_user()).id, notes="OK"
        )
        assert approved.status == WithdrawalStatus.APPROVED

        balance = await WalletService(db_session).get_balance(user_id)
        assert balance == Decimal("50.00")

    async def test_reject_never_touches_balance(self, db_session: AsyncSession, make_user) -> None:
        user_id = await _funded_user(db_session, make_user)
        service = WithdrawalService(db_session)
        withdrawal = await service.request_withdrawal(
            user_id,
            amount=Decimal("50.00"),
            channel=PaymentChannel.MTN_MOMO,
            destination_phone_number="0244000001",
        )
        rejected = await service.reject(
            withdrawal.id, reviewer_id=(await make_user()).id, notes="No"
        )
        assert rejected.status == WithdrawalStatus.REJECTED

        balance = await WalletService(db_session).get_balance(user_id)
        assert balance == Decimal("100.00")

    async def test_complete_after_approval(self, db_session: AsyncSession, make_user) -> None:
        user_id = await _funded_user(db_session, make_user)
        service = WithdrawalService(db_session)
        withdrawal = await service.request_withdrawal(
            user_id,
            amount=Decimal("50.00"),
            channel=PaymentChannel.MTN_MOMO,
            destination_phone_number="0244000001",
        )
        await service.approve(withdrawal.id, reviewer_id=(await make_user()).id, notes=None)
        completed = await service.complete(
            withdrawal.id, reviewer_id=(await make_user()).id, provider_reference="manual-txn-1"
        )
        assert completed.status == WithdrawalStatus.COMPLETED
        assert completed.provider_reference == "manual-txn-1"

    async def test_fail_after_approval_reverses_debit(
        self, db_session: AsyncSession, make_user
    ) -> None:
        user_id = await _funded_user(db_session, make_user)
        service = WithdrawalService(db_session)
        withdrawal = await service.request_withdrawal(
            user_id,
            amount=Decimal("50.00"),
            channel=PaymentChannel.MTN_MOMO,
            destination_phone_number="0244000001",
        )
        await service.approve(withdrawal.id, reviewer_id=(await make_user()).id, notes=None)
        failed = await service.mark_failed(
            withdrawal.id, reviewer_id=(await make_user()).id, reason="Wrong number"
        )
        assert failed.status == WithdrawalStatus.FAILED

        balance = await WalletService(db_session).get_balance(user_id)
        assert balance == Decimal("100.00")  # reversed

    async def test_cannot_approve_a_rejected_withdrawal(
        self, db_session: AsyncSession, make_user
    ) -> None:
        user_id = await _funded_user(db_session, make_user)
        service = WithdrawalService(db_session)
        withdrawal = await service.request_withdrawal(
            user_id,
            amount=Decimal("50.00"),
            channel=PaymentChannel.MTN_MOMO,
            destination_phone_number="0244000001",
        )
        await service.reject(withdrawal.id, reviewer_id=(await make_user()).id, notes=None)
        with pytest.raises(InvalidStateTransitionError):
            await service.approve(withdrawal.id, reviewer_id=(await make_user()).id, notes=None)
