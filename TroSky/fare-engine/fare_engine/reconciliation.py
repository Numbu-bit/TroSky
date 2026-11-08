"""Daily reconciliation: match MoMo's statement to our payment attempts and trips.

Inputs are our PaymentAttempt records and the day's MoMo transaction report
(matched on the reference we send MTN with each request). Field names in MTN's
report are assumptions: VERIFY BEFORE LAUNCH against MTN's current documentation.
"""

from __future__ import annotations

from collections import defaultdict
from dataclasses import dataclass, field
from decimal import Decimal


@dataclass(frozen=True)
class PaymentAttempt:
    reference: str  # our idempotency key, sent to MTN as the request reference
    trip_id: str | None
    kind: str  # collection | disbursement
    amount: Decimal
    status: str  # succeeded | failed | pending | timed_out


@dataclass(frozen=True)
class MomoLine:
    reference: str
    financial_transaction_id: str
    kind: str
    amount: Decimal
    status: str  # SUCCESSFUL | FAILED | PENDING


@dataclass
class ReconciliationReport:
    matched: list[str] = field(default_factory=list)
    missing_at_momo: list[str] = field(default_factory=list)  # we say succeeded, MoMo has no success
    unexpected_at_momo: list[str] = field(default_factory=list)  # MoMo success we did not record (late approval)
    amount_mismatches: list[str] = field(default_factory=list)
    duplicate_charges: list[str] = field(default_factory=list)  # two successes for one reference or trip
    trips_without_payment: list[str] = field(default_factory=list)
    checked: int = 0

    @property
    def problems(self) -> int:
        return sum(
            len(x)
            for x in (
                self.missing_at_momo,
                self.unexpected_at_momo,
                self.amount_mismatches,
                self.duplicate_charges,
                self.trips_without_payment,
            )
        )

    @property
    def mismatch_rate(self) -> Decimal:
        return Decimal(self.problems) / Decimal(max(self.checked, 1))


def reconcile(
    attempts: list[PaymentAttempt], statement: list[MomoLine], completed_digital_trips: list[str]
) -> ReconciliationReport:
    report = ReconciliationReport()
    successes: dict[str, list[MomoLine]] = defaultdict(list)
    for line in statement:
        if line.status == "SUCCESSFUL":
            successes[line.reference].append(line)
    by_reference = {a.reference: a for a in attempts}

    for reference, lines in successes.items():
        if len(lines) > 1:
            report.duplicate_charges.append(reference)

    paid_trips: dict[str, int] = defaultdict(int)
    for attempt in attempts:
        report.checked += 1
        momo = successes.get(attempt.reference, [])
        if attempt.status == "succeeded":
            if not momo:
                report.missing_at_momo.append(attempt.reference)
            elif momo[0].amount != attempt.amount:
                report.amount_mismatches.append(attempt.reference)
            else:
                report.matched.append(attempt.reference)
                if attempt.kind == "collection" and attempt.trip_id:
                    paid_trips[attempt.trip_id] += 1
        elif momo:
            # Timed out or pending on our side, approved at MTN: honour it if the trip
            # is unpaid, otherwise refund it.
            report.unexpected_at_momo.append(attempt.reference)

    for reference in successes:
        if reference not in by_reference:
            report.unexpected_at_momo.append(reference)

    for trip_id in completed_digital_trips:
        count = paid_trips.get(trip_id, 0)
        if count == 0:
            report.trips_without_payment.append(trip_id)
        elif count > 1:
            report.duplicate_charges.append(f"trip:{trip_id}")
    return report
