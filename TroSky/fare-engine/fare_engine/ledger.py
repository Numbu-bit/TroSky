"""Double-entry ledger with immutable entries and idempotency keys.

Accounts are named ``<type>:<name>[:<owner>]``; the type decides the normal side:

    asset:momo_clearing                 money in our MoMo merchant wallet
    asset:driver_receivable:<driver>    fees (and clawbacks) a driver owes us
    liability:rider:<rider>             money a rider has paid ahead of a trip (negative = rider owes)
    liability:driver_payable:<driver>   earnings we owe a driver
    liability:payouts_in_flight         payouts sent to MoMo, not yet confirmed
    liability:vat_payable               VAT carved out of the fee (zero until verified)
    income:service_fees                 the platform fee, net of VAT
    expense:rider_promotions            platform-funded rider discounts
    expense:driver_incentives           bonuses paid to drivers
    expense:refunds                     refunds the platform absorbs

Every transaction balances (debits == credits), amounts are whole pesewas, and
nothing is ever updated or deleted: a correction is a new, reversing transaction.
Posting the same idempotency key twice returns the first transaction; reusing a
key for different lines is refused.
"""

from __future__ import annotations

from collections import defaultdict
from dataclasses import dataclass, field
from datetime import datetime
from decimal import Decimal
from typing import Any, Iterable

from .money import CENT, ZERO
from .settlement import TripSettlement

NORMAL_DEBIT = {"asset", "expense"}
NORMAL_CREDIT = {"liability", "income"}

MOMO = "asset:momo_clearing"
IN_FLIGHT = "liability:payouts_in_flight"
FEES = "income:service_fees"
VAT = "liability:vat_payable"
PROMOS = "expense:rider_promotions"
INCENTIVES = "expense:driver_incentives"
REFUNDS = "expense:refunds"


def rider(rider_id: str) -> str:
    return f"liability:rider:{rider_id}"


def payable(driver_id: str) -> str:
    return f"liability:driver_payable:{driver_id}"


def receivable(driver_id: str) -> str:
    return f"asset:driver_receivable:{driver_id}"


class LedgerError(ValueError):
    """A transaction was refused."""


class IdempotencyConflict(LedgerError):
    """An idempotency key was reused for a different transaction."""


@dataclass(frozen=True)
class Line:
    account: str
    debit: Decimal = ZERO
    credit: Decimal = ZERO

    @staticmethod
    def dr(account: str, amount: Decimal) -> "Line":
        return Line(account, debit=amount)

    @staticmethod
    def cr(account: str, amount: Decimal) -> "Line":
        return Line(account, credit=amount)


@dataclass(frozen=True)
class Transaction:
    seq: int
    idempotency_key: str
    kind: str
    lines: tuple[Line, ...]
    at: datetime | None
    meta: tuple[tuple[str, Any], ...] = field(default=())

    def fingerprint(self) -> tuple:
        return (self.kind, tuple(sorted((l.account, l.debit, l.credit) for l in self.lines)))

    def meta_dict(self) -> dict[str, Any]:
        return dict(self.meta)


class Ledger:
    """Append-only, in-memory reference ledger. Production uses the PostgreSQL schema in schema.sql."""

    def __init__(self) -> None:
        self._transactions: list[Transaction] = []
        self._by_key: dict[str, Transaction] = {}
        self._debits: dict[str, Decimal] = defaultdict(lambda: ZERO)
        self._credits: dict[str, Decimal] = defaultdict(lambda: ZERO)

    @property
    def transactions(self) -> tuple[Transaction, ...]:
        return tuple(self._transactions)

    def find(self, idempotency_key: str) -> Transaction | None:
        return self._by_key.get(idempotency_key)

    def post(
        self,
        idempotency_key: str,
        kind: str,
        lines: Iterable[Line],
        *,
        at: datetime | None = None,
        meta: dict[str, Any] | None = None,
    ) -> Transaction:
        kept = tuple(l for l in lines if l.debit or l.credit)  # drop zero lines
        candidate = Transaction(len(self._transactions) + 1, idempotency_key, kind, kept, at, tuple(sorted((meta or {}).items())))
        existing = self._by_key.get(idempotency_key)
        if existing is not None:
            if existing.fingerprint() != candidate.fingerprint():
                raise IdempotencyConflict(f"key {idempotency_key!r} was already used for different lines")
            return existing
        self._check(candidate)
        self._transactions.append(candidate)
        self._by_key[idempotency_key] = candidate
        for l in kept:
            self._debits[l.account] += l.debit
            self._credits[l.account] += l.credit
        return candidate

    @staticmethod
    def _check(txn: Transaction) -> None:
        if len(txn.lines) < 2:
            raise LedgerError("a transaction needs at least two non-zero lines")
        for l in txn.lines:
            kind = l.account.split(":", 1)[0]
            if kind not in NORMAL_DEBIT | NORMAL_CREDIT:
                raise LedgerError(f"unknown account type in {l.account!r}")
            if l.debit < 0 or l.credit < 0 or (l.debit and l.credit):
                raise LedgerError("each line is a positive debit or a positive credit, never both")
            for amount in (l.debit, l.credit):
                if amount != amount.quantize(CENT):
                    raise LedgerError("ledger amounts must be whole pesewas")
        if sum(l.debit for l in txn.lines) != sum(l.credit for l in txn.lines):
            raise LedgerError(f"transaction {txn.idempotency_key!r} does not balance")

    def balance(self, account: str) -> Decimal:
        """Balance on the account's normal side (assets and expenses: debits minus credits)."""
        dr, cr = self._debits[account], self._credits[account]
        return dr - cr if account.split(":", 1)[0] in NORMAL_DEBIT else cr - dr

    def accounts(self) -> list[str]:
        return sorted(set(self._debits) | set(self._credits))

    def trial_balance(self) -> Decimal:
        """Total debits minus total credits across the whole ledger: always zero."""
        return sum(self._debits.values(), ZERO) - sum(self._credits.values(), ZERO)

    def reverse(self, idempotency_key: str, original_key: str, *, at: datetime | None = None) -> Transaction:
        original = self._by_key.get(original_key)
        if original is None:
            raise LedgerError(f"no transaction with key {original_key!r}")
        flipped = [Line(l.account, debit=l.credit, credit=l.debit) for l in original.lines]
        return self.post(idempotency_key, f"reversal:{original.kind}", flipped, at=at, meta={"reverses": original_key})


# ------------------------------------------------------------------ postings


def record_collection(ledger: Ledger, *, rider_id: str, amount: Decimal, reference: str, at: datetime | None = None) -> Transaction:
    """A MoMo request-to-pay succeeded: the money is in our wallet, held for the rider."""
    if amount <= 0:
        raise LedgerError("nothing to collect: a fully discounted trip needs no MoMo request")
    return ledger.post(
        f"collection:{reference}",
        "momo_collection",
        [Line.dr(MOMO, amount), Line.cr(rider(rider_id), amount)],
        at=at,
        meta={"reference": reference},
    )


def settle_trip(
    ledger: Ledger,
    *,
    trip_id: str,
    rider_id: str,
    driver_id: str,
    settlement: TripSettlement,
    payment: str,
    at: datetime | None = None,
) -> Transaction:
    """Post a completed trip. Digital: take the rider's payment and owe the driver the net.
    Cash: the driver already holds the fare, so the fee becomes a receivable from the driver."""
    s = settlement
    if payment == "digital":
        lines = [
            Line.dr(rider(rider_id), s.rider_pays),
            Line.dr(PROMOS, s.promo),
            Line.dr(INCENTIVES, s.incentives),
            Line.cr(FEES, s.platform_revenue_ex_vat),
            Line.cr(VAT, s.vat_on_fee),
            Line.cr(payable(driver_id), s.driver_payout),
        ]
    elif payment == "cash":
        # Cash tolls and tips stay with the driver and never touch the platform.
        lines = [
            Line.dr(receivable(driver_id), s.platform_fee),
            Line.cr(FEES, s.platform_revenue_ex_vat),
            Line.cr(VAT, s.vat_on_fee),
            Line.dr(PROMOS, s.promo),
            Line.dr(INCENTIVES, s.incentives),
            Line.cr(payable(driver_id), s.promo + s.incentives),
        ]
    else:
        raise LedgerError("payment must be 'digital' or 'cash'")
    return ledger.post(f"trip:{trip_id}:settle", f"trip_{payment}", lines, at=at, meta={"trip_id": trip_id})


@dataclass(frozen=True)
class Payout:
    payout_id: str
    driver_id: str
    payable_before: Decimal
    fees_netted: Decimal
    amount: Decimal
    status: str  # pending | succeeded | failed | below_minimum | nothing_due


def start_payout(
    ledger: Ledger, *, driver_id: str, run_id: str, minimum_payout: Decimal, at: datetime | None = None
) -> Payout:
    """Net fees owed against earnings, then send what is left if it reaches the minimum."""
    payout_id = f"payout:{run_id}:{driver_id}"
    done = ledger.find(payout_id)
    if done is not None:
        return Payout(**done.meta_dict()["payout"])
    owed_to_driver = ledger.balance(payable(driver_id))
    owed_by_driver = ledger.balance(receivable(driver_id))
    netted = min(owed_to_driver, owed_by_driver) if owed_to_driver > 0 and owed_by_driver > 0 else ZERO
    if netted:
        ledger.post(
            f"{payout_id}:netting",
            "fee_netting",
            [Line.dr(payable(driver_id), netted), Line.cr(receivable(driver_id), netted)],
            at=at,
        )
    amount = owed_to_driver - netted
    if amount <= 0:
        return Payout(payout_id, driver_id, owed_to_driver, netted, ZERO, "nothing_due")
    if amount < minimum_payout:
        return Payout(payout_id, driver_id, owed_to_driver, netted, ZERO, "below_minimum")
    payout = Payout(payout_id, driver_id, owed_to_driver, netted, amount, "pending")
    ledger.post(
        payout_id,
        "payout_started",
        [Line.dr(payable(driver_id), amount), Line.cr(IN_FLIGHT, amount)],
        at=at,
        meta={"payout": payout.__dict__},
    )
    return payout


def finish_payout(ledger: Ledger, payout: Payout, *, succeeded: bool, at: datetime | None = None) -> Payout:
    """MoMo confirmed the disbursement, or it failed and the money goes back to the driver's balance."""
    if payout.status != "pending":
        raise LedgerError("only a pending payout can finish")
    if succeeded:
        lines = [Line.dr(IN_FLIGHT, payout.amount), Line.cr(MOMO, payout.amount)]
    else:
        lines = [Line.dr(IN_FLIGHT, payout.amount), Line.cr(payable(payout.driver_id), payout.amount)]
    ledger.post(f"{payout.payout_id}:finished", "payout_succeeded" if succeeded else "payout_failed", lines, at=at)
    return Payout(**{**payout.__dict__, "status": "succeeded" if succeeded else "failed"})


def settle_fee_arrears(
    ledger: Ledger, *, driver_id: str, amount: Decimal, reference: str, at: datetime | None = None
) -> Transaction:
    """The driver paid fees they owe through a MoMo collection."""
    key = f"fee_settlement:{reference}"
    existing = ledger.find(key)
    if existing is not None:
        return existing
    owed = ledger.balance(receivable(driver_id))
    if amount <= 0 or amount > owed:
        raise LedgerError(f"payment of {amount} does not fit fees owed of {owed}")
    return ledger.post(
        key, "fee_settlement", [Line.dr(MOMO, amount), Line.cr(receivable(driver_id), amount)], at=at, meta={"reference": reference}
    )


def refund_rider(
    ledger: Ledger,
    *,
    trip_id: str,
    amount: Decimal,
    reference: str,
    charged_to: str = "platform",
    driver_id: str | None = None,
    at: datetime | None = None,
) -> Transaction:
    """Refund a rider through MoMo. The platform absorbs it, or, after a dispute ruled
    against the driver, it is recovered from the driver's next payout."""
    if charged_to == "platform":
        debit = REFUNDS
    elif charged_to == "driver" and driver_id:
        debit = receivable(driver_id)
    else:
        raise LedgerError("charged_to must be 'platform', or 'driver' with a driver_id")
    return ledger.post(
        f"refund:{reference}", "refund", [Line.dr(debit, amount), Line.cr(MOMO, amount)], at=at, meta={"trip_id": trip_id}
    )
