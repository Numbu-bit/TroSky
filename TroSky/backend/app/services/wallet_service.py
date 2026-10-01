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
from dataclasses import dataclass
from datetime import UTC, date, datetime, time, timedelta
from decimal import Decimal

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import from_minor_units, get_settings, to_minor_units
from app.core.exceptions import InsufficientWalletBalanceError
from app.core.logging import get_logger
from app.models.payments import Wallet, WalletEntryType, WalletReferenceType, WalletTransaction
from app.repositories.wallet_repository import WalletRepository

logger = get_logger(__name__)


@dataclass(frozen=True, slots=True)
class EarningsBucket:
    start: date
    total: Decimal
    trips_count: int


@dataclass(frozen=True, slots=True)
class EarningsSummary:
    period: str
    currency: str
    total: Decimal
    trips_count: int
    pending_withdrawals_total: Decimal
    buckets: list[EarningsBucket]


def period_start(day: date, period: str) -> date:
    """The first day of the day/week (Monday)/month containing ``day``."""
    if period == "week":
        return day - timedelta(days=day.weekday())
    if period == "month":
        return day.replace(day=1)
    return day


def period_starts(period: str, start: date, end: date) -> list[date]:
    """Start of every period overlapping ``start``..``end``, in order."""
    starts = []
    current = period_start(start, period)
    while current <= end:
        starts.append(current)
        if period == "day":
            current += timedelta(days=1)
        elif period == "week":
            current += timedelta(days=7)
        else:
            current = (current.replace(day=28) + timedelta(days=4)).replace(day=1)
    return starts


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
        self,
        user_id: uuid.UUID,
        *,
        reference_type: WalletReferenceType | None = None,
        limit: int,
        offset: int,
    ) -> tuple[list[WalletTransaction], int]:
        wallet = await self._wallets.get_by_user_id(user_id)
        if wallet is None:
            return [], 0
        return await self._wallets.list_transactions(
            wallet.id, reference_type=reference_type, limit=limit, offset=offset
        )

    async def earnings_summary(
        self, user_id: uuid.UUID, *, period: str, start: date, end: date
    ) -> EarningsSummary:
        """Trip earnings from ``start`` to ``end`` (inclusive, UTC dates),
        totalled per day, week (from Monday) or month. Every period in the
        range gets a bucket, empty ones included, so a chart has no gaps."""
        rows = await self._wallets.earnings_by_period_and_trip(
            user_id,
            period=period,
            start=datetime.combine(start, time.min, tzinfo=UTC),
            end=datetime.combine(end + timedelta(days=1), time.min, tzinfo=UTC),
        )
        minor_by_period: dict[date, int] = {}
        trips_by_period: dict[date, set[uuid.UUID]] = {}
        for period_start, trip_id, minor_units in rows:
            day = period_start.date()
            minor_by_period[day] = minor_by_period.get(day, 0) + minor_units
            if trip_id is not None:
                trips_by_period.setdefault(day, set()).add(trip_id)

        buckets = [
            EarningsBucket(
                start=bucket_start,
                total=from_minor_units(minor_by_period.get(bucket_start, 0)),
                trips_count=len(trips_by_period.get(bucket_start, ())),
            )
            for bucket_start in period_starts(period, start, end)
        ]
        all_trips = set().union(*trips_by_period.values()) if trips_by_period else set()
        return EarningsSummary(
            period=period,
            currency=get_settings().PAYMENTS_DEFAULT_CURRENCY,
            total=from_minor_units(sum(minor_by_period.values())),
            trips_count=len(all_trips),
            pending_withdrawals_total=(
                await self._wallets.pending_withdrawals_total(user_id)
            ).quantize(Decimal("0.01")),
            buckets=buckets,
        )
