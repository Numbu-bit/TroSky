"""In-app wallet: double-entry-style ledger over an internal GHS balance.

Every mutation goes through :meth:`WalletService.credit` /
:meth:`WalletService.debit`, both of which row-lock the wallet
(``WalletRepository.get_or_create_for_update``) before mutating it and
always append an immutable ``wallet_transactions`` row — the wallet is
never adjusted without a corresponding ledger entry recording why.

Amounts are accepted/returned as ``Decimal`` GHS at this service's boundary
(matching the rest of the codebase) and converted to/from integer minor
units (pesewas) only for storage, via ``app.core.config``'s helpers.
"""

from __future__ import annotations

import uuid
from decimal import Decimal

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import from_minor_units, to_minor_units
from app.core.exceptions import InsufficientWalletBalanceError
from app.core.logging import get_logger
from app.models.payments import Wallet, WalletEntryType, WalletReferenceType, WalletTransaction
from app.repositories.wallet_repository import WalletRepository

logger = get_logger(__name__)


class WalletService:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session
        self._wallets = WalletRepository(session)

    async def get_or_create_wallet(self, user_id: uuid.UUID) -> Wallet:
        return await self._wallets.get_or_create_for_update(user_id)

    async def get_balance(self, user_id: uuid.UUID) -> Decimal:
        wallet = await self._wallets.get_by_user_id(user_id)
        if wallet is None:
            return Decimal("0.00")
        return from_minor_units(wallet.balance_minor_units)

    async def credit(
        self,
        user_id: uuid.UUID,
        *,
        amount: Decimal,
        reference_type: WalletReferenceType,
        reference_id: uuid.UUID | None,
        description: str,
        idempotency_key: str | None = None,
    ) -> WalletTransaction:
        wallet = await self._wallets.get_or_create_for_update(user_id)

        if idempotency_key is not None:
            existing = await self._wallets.get_transaction_by_idempotency_key(
                wallet.id, idempotency_key
            )
            if existing is not None:
                return existing

        transaction = await self._wallets.record_transaction(
            wallet,
            entry_type=WalletEntryType.CREDIT,
            amount_minor_units=to_minor_units(amount),
            reference_type=reference_type,
            reference_id=reference_id,
            description=description,
            idempotency_key=idempotency_key,
        )
        logger.info(
            "wallet_credited",
            user_id=str(user_id),
            amount=str(amount),
            reference_type=reference_type.value,
        )
        return transaction

    async def debit(
        self,
        user_id: uuid.UUID,
        *,
        amount: Decimal,
        reference_type: WalletReferenceType,
        reference_id: uuid.UUID | None,
        description: str,
        idempotency_key: str | None = None,
    ) -> WalletTransaction:
        wallet = await self._wallets.get_or_create_for_update(user_id)

        if idempotency_key is not None:
            existing = await self._wallets.get_transaction_by_idempotency_key(
                wallet.id, idempotency_key
            )
            if existing is not None:
                return existing

        amount_minor = to_minor_units(amount)
        if wallet.balance_minor_units < amount_minor:
            raise InsufficientWalletBalanceError(
                details={
                    "available": str(from_minor_units(wallet.balance_minor_units)),
                    "requested": str(amount),
                }
            )

        transaction = await self._wallets.record_transaction(
            wallet,
            entry_type=WalletEntryType.DEBIT,
            amount_minor_units=amount_minor,
            reference_type=reference_type,
            reference_id=reference_id,
            description=description,
            idempotency_key=idempotency_key,
        )
        logger.info(
            "wallet_debited",
            user_id=str(user_id),
            amount=str(amount),
            reference_type=reference_type.value,
        )
        return transaction

    async def list_transactions(
        self, user_id: uuid.UUID, *, limit: int, offset: int
    ) -> tuple[list[WalletTransaction], int]:
        wallet = await self._wallets.get_by_user_id(user_id)
        if wallet is None:
            return [], 0
        return await self._wallets.list_transactions(wallet.id, limit=limit, offset=offset)
