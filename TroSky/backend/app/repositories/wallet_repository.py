"""Database access for wallets and the append-only wallet-transaction ledger.

``get_or_create_for_update`` is the concurrency-critical operation: it row-
locks (``SELECT ... FOR UPDATE``) the caller's wallet before any balance
mutation, so two concurrent credit/debit operations against the same wallet
serialize at the database rather than racing on a read-modify-write. Unlike
seat reservations (many rows contending via a partial unique index), a
wallet is a single row per user — pessimistic locking is the right tool
here, not a uniqueness constraint.
"""

from __future__ import annotations

import uuid
from datetime import datetime
from decimal import Decimal

from sqlalchemy import func, literal_column, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.bookings import Booking
from app.models.payments import (
    Wallet,
    WalletEntryType,
    WalletReferenceType,
    WalletTransaction,
    WithdrawalRequest,
    WithdrawalStatus,
)


class WalletRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get_or_create_for_update(self, user_id: uuid.UUID) -> Wallet:
        result = await self._session.execute(
            select(Wallet).where(Wallet.user_id == user_id).with_for_update()
        )
        wallet = result.scalar_one_or_none()
        if wallet is not None:
            return wallet

        # Another concurrent request may be creating the wallet at the same
        # instant; the unique constraint on `user_id` is the real guarantee,
        # this SAVEPOINT just lets us recover from losing that race cleanly.
        wallet = Wallet(user_id=user_id)
        try:
            async with self._session.begin_nested():
                self._session.add(wallet)
                await self._session.flush()
        except IntegrityError:
            result = await self._session.execute(
                select(Wallet).where(Wallet.user_id == user_id).with_for_update()
            )
            wallet = result.scalar_one()
        return wallet

    async def get_by_user_id(self, user_id: uuid.UUID) -> Wallet | None:
        result = await self._session.execute(select(Wallet).where(Wallet.user_id == user_id))
        return result.scalar_one_or_none()

    async def get_transaction_by_idempotency_key(
        self, wallet_id: uuid.UUID, idempotency_key: str
    ) -> WalletTransaction | None:
        result = await self._session.execute(
            select(WalletTransaction).where(
                WalletTransaction.wallet_id == wallet_id,
                WalletTransaction.idempotency_key == idempotency_key,
            )
        )
        return result.scalar_one_or_none()

    async def record_transaction(
        self,
        wallet: Wallet,
        *,
        entry_type: WalletEntryType,
        amount_minor_units: int,
        reference_type: WalletReferenceType,
        reference_id: uuid.UUID | None,
        description: str,
        idempotency_key: str | None,
    ) -> WalletTransaction:
        """Applies the balance mutation to the already row-locked ``wallet``
        and appends the corresponding ledger row. Caller is responsible for
        the row lock (``get_or_create_for_update``) and for checking
        sufficient balance before calling this for a debit."""
        if entry_type == WalletEntryType.CREDIT:
            wallet.balance_minor_units += amount_minor_units
        else:
            wallet.balance_minor_units -= amount_minor_units

        transaction = WalletTransaction(
            wallet_id=wallet.id,
            entry_type=entry_type,
            amount_minor_units=amount_minor_units,
            balance_after_minor_units=wallet.balance_minor_units,
            reference_type=reference_type,
            reference_id=reference_id,
            description=description,
            idempotency_key=idempotency_key,
        )
        self._session.add(transaction)
        await self._session.flush()
        return transaction

    async def list_transactions(
        self,
        wallet_id: uuid.UUID,
        *,
        reference_type: WalletReferenceType | None = None,
        limit: int,
        offset: int,
    ) -> tuple[list[WalletTransaction], int]:
        stmt = select(WalletTransaction).where(WalletTransaction.wallet_id == wallet_id)
        if reference_type is not None:
            stmt = stmt.where(WalletTransaction.reference_type == reference_type)
        total = (
            await self._session.execute(select(func.count()).select_from(stmt.subquery()))
        ).scalar_one()
        result = await self._session.execute(
            stmt.order_by(WalletTransaction.created_at.desc()).limit(limit).offset(offset)
        )
        return list(result.scalars().all()), total

    async def earnings_by_period_and_trip(
        self, user_id: uuid.UUID, *, period: str, start: datetime, end: datetime
    ) -> list[tuple[datetime, uuid.UUID | None, int]]:
        """Trip earnings credited to ``user_id`` in ``[start, end)``, summed
        per trip within each ``period`` ("day", "week" or "month"; UTC,
        weeks starting Monday). Returns ``(period_start, trip_id, minor_units)``.
        """
        if period not in ("day", "week", "month"):
            raise ValueError(f"Unsupported period: {period!r}")
        period_start = func.date_trunc(
            period, func.timezone("UTC", WalletTransaction.created_at)
        ).label("period_start")
        result = await self._session.execute(
            select(period_start, Booking.trip_id, func.sum(WalletTransaction.amount_minor_units))
            .select_from(WalletTransaction)
            .join(Wallet, Wallet.id == WalletTransaction.wallet_id)
            # Trip earnings reference the booking they were earned on.
            .outerjoin(Booking, Booking.id == WalletTransaction.reference_id)
            .where(
                Wallet.user_id == user_id,
                WalletTransaction.reference_type == WalletReferenceType.TRIP_EARNING,
                WalletTransaction.entry_type == WalletEntryType.CREDIT,
                WalletTransaction.created_at >= start,
                WalletTransaction.created_at < end,
            )
            # By output name: repeating the expression would bind its
            # arguments afresh, and Postgres would not see them as the same.
            .group_by(literal_column("period_start"), Booking.trip_id)
        )
        return [(row[0], row[1], int(row[2])) for row in result.all()]

    async def pending_withdrawals_total(self, user_id: uuid.UUID) -> Decimal:
        """Withdrawals requested but not yet paid out or turned down."""
        result = await self._session.execute(
            select(func.coalesce(func.sum(WithdrawalRequest.amount), 0)).where(
                WithdrawalRequest.user_id == user_id,
                WithdrawalRequest.status.in_([WithdrawalStatus.PENDING, WithdrawalStatus.APPROVED]),
            )
        )
        return Decimal(result.scalar_one())
