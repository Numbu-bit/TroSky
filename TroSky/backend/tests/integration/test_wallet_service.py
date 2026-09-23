"""Integration tests for WalletService: the double-entry-style ledger,
idempotent credit/debit, insufficient-balance rejection, and the
concurrency guarantee itself (two simultaneous debits against the same
wallet, only one succeeds when the balance covers just one) against a real
Postgres."""

from __future__ import annotations

import asyncio
import uuid
from decimal import Decimal

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_session_factory
from app.core.exceptions import InsufficientWalletBalanceError
from app.models.payments import WalletReferenceType, WalletTransaction
from app.services.wallet_service import WalletService

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]


class TestWalletCreditDebit:
    async def test_new_wallet_has_zero_balance(self, db_session: AsyncSession) -> None:
        service = WalletService(db_session)
        balance = await service.get_balance(uuid.uuid4())
        assert balance == Decimal("0.00")

    async def test_credit_increases_balance(self, db_session: AsyncSession, make_user) -> None:
        service = WalletService(db_session)
        user_id = (await make_user()).id
        await service.credit(
            user_id,
            amount=Decimal("50.00"),
            reference_type=WalletReferenceType.WALLET_TOPUP,
            reference_id=None,
            description="Top-up",
        )
        assert await service.get_balance(user_id) == Decimal("50.00")

    async def test_debit_decreases_balance(self, db_session: AsyncSession, make_user) -> None:
        service = WalletService(db_session)
        user_id = (await make_user()).id
        await service.credit(
            user_id,
            amount=Decimal("50.00"),
            reference_type=WalletReferenceType.WALLET_TOPUP,
            reference_id=None,
            description="Top-up",
        )
        await service.debit(
            user_id,
            amount=Decimal("20.00"),
            reference_type=WalletReferenceType.BOOKING_PAYMENT,
            reference_id=None,
            description="Booking",
        )
        assert await service.get_balance(user_id) == Decimal("30.00")

    async def test_debit_beyond_balance_raises(self, db_session: AsyncSession, make_user) -> None:
        service = WalletService(db_session)
        user_id = (await make_user()).id
        with pytest.raises(InsufficientWalletBalanceError):
            await service.debit(
                user_id,
                amount=Decimal("10.00"),
                reference_type=WalletReferenceType.BOOKING_PAYMENT,
                reference_id=None,
                description="Booking",
            )

    async def test_credit_with_idempotency_key_is_applied_once(
        self, db_session: AsyncSession, make_user
    ) -> None:
        service = WalletService(db_session)
        user_id = (await make_user()).id
        key = "topup-1"
        first = await service.credit(
            user_id,
            amount=Decimal("25.00"),
            reference_type=WalletReferenceType.WALLET_TOPUP,
            reference_id=None,
            description="Top-up",
            idempotency_key=key,
        )
        second = await service.credit(
            user_id,
            amount=Decimal("25.00"),
            reference_type=WalletReferenceType.WALLET_TOPUP,
            reference_id=None,
            description="Top-up",
            idempotency_key=key,
        )
        assert first.id == second.id
        assert await service.get_balance(user_id) == Decimal("25.00")

    @pytest.mark.xfail(
        strict=True,
        reason=(
            "Ledger ordering is not deterministic for entries written in one "
            "transaction: created_at defaults to server-side now(), which in "
            "PostgreSQL is transaction_timestamp() and therefore identical for "
            "every row in the transaction, so WalletRepository.list_transactions' "
            "ORDER BY created_at DESC has nothing to break the tie. Needs a "
            "monotonic sequence column on wallet_transactions (UUIDv4 ids are "
            "random, so they cannot serve as the tiebreaker)."
        ),
    )
    async def test_ledger_records_balance_after_each_entry(
        self, db_session: AsyncSession, make_user
    ) -> None:
        service = WalletService(db_session)
        user_id = (await make_user()).id
        await service.credit(
            user_id,
            amount=Decimal("100.00"),
            reference_type=WalletReferenceType.WALLET_TOPUP,
            reference_id=None,
            description="Top-up",
        )
        await service.debit(
            user_id,
            amount=Decimal("40.00"),
            reference_type=WalletReferenceType.BOOKING_PAYMENT,
            reference_id=None,
            description="Booking",
        )
        transactions, total = await service.list_transactions(user_id, limit=10, offset=0)
        assert total == 2
        newest, oldest = transactions
        assert isinstance(newest, WalletTransaction)
        assert oldest.balance_after_minor_units == 10_000
        assert newest.balance_after_minor_units == 6_000


class TestConcurrentWalletDebit:
    async def test_only_one_of_two_concurrent_debits_succeeds(self, committed_user) -> None:
        """Mirrors ``TestConcurrentSeatReservation`` in
        ``test_booking_service.py``: two independent, genuinely concurrent
        sessions racing to debit the same wallet when the balance covers
        exactly one of them. Correctness here comes from row-locking the
        wallet (``SELECT ... FOR UPDATE``), not from application-level
        coordination — this test cannot use the SAVEPOINT-isolated
        ``db_session`` fixture for the same reason the seat-reservation
        race test can't (see that module's docstring), so it depends on
        ``require_postgres`` directly to skip cleanly when unreachable."""
        session_factory = get_session_factory()
        user_id = committed_user.id
        async with session_factory() as setup_session, setup_session.begin():
            await WalletService(setup_session).credit(
                user_id,
                amount=Decimal("100.00"),
                reference_type=WalletReferenceType.WALLET_TOPUP,
                reference_id=None,
                description="Top-up",
            )

        async def attempt() -> WalletTransaction:
            async with session_factory() as session:
                service = WalletService(session)
                try:
                    transaction = await service.debit(
                        user_id,
                        amount=Decimal("100.00"),
                        reference_type=WalletReferenceType.BOOKING_PAYMENT,
                        reference_id=None,
                        description="Racing booking payment",
                    )
                except Exception:
                    await session.rollback()
                    raise
                else:
                    await session.commit()
                    return transaction

        results = await asyncio.gather(attempt(), attempt(), return_exceptions=True)
        successes = [r for r in results if isinstance(r, WalletTransaction)]
        failures = [r for r in results if isinstance(r, InsufficientWalletBalanceError)]
        assert len(successes) == 1, f"Expected exactly one winner, got: {results}"
        assert (
            len(failures) == 1
        ), f"Expected exactly one InsufficientWalletBalanceError, got: {results}"

        async with session_factory() as check_session:
            balance = await WalletService(check_session).get_balance(user_id)
        assert balance == Decimal("0.00")
