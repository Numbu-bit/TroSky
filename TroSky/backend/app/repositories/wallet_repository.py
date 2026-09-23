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

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.payments import Wallet, WalletEntryType, WalletReferenceType, WalletTransaction


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
        self, wallet_id: uuid.UUID, *, limit: int, offset: int
    ) -> tuple[list[WalletTransaction], int]:
        count_result = await self._session.execute(
            select(WalletTransaction.id).where(WalletTransaction.wallet_id == wallet_id)
        )
        total = len(count_result.scalars().all())
        result = await self._session.execute(
            select(WalletTransaction)
            .where(WalletTransaction.wallet_id == wallet_id)
            .order_by(WalletTransaction.created_at.desc())
            .limit(limit)
            .offset(offset)
        )
        return list(result.scalars().all()), total
