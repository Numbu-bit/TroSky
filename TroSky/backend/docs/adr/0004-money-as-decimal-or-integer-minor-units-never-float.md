# ADR-0004: Money is `Decimal` (or integer minor units), never `float`, at every layer

## Status

Accepted (Phase 1 convention; the wallet ledger's specific integer-minor-units
form decided in Phase 6).

## Context

`float` cannot exactly represent most base-10 decimal fractions (`0.1 +
0.2 != 0.3` in IEEE 754 binary floating point) — a well-known,
well-documented hazard for any system handling currency. This is real
money moving through a real platform (fares, wallet balances, refunds,
driver earnings); a rounding drift that would be an invisible rendering
quirk in most software is an actual accounting discrepancy here, and one
that compounds across thousands of transactions.

## Decision

Two representations are used, chosen per table by how the value is used,
never `float` for either:

1. **`Decimal` (Postgres `NUMERIC`)** for values that are primarily
   *read/displayed/summed* at the GHS-major-unit granularity a person
   thinks in — `bookings.total_amount`, `payments.amount`,
   `trips.fare_amount`, `refund_requests.amount`, `withdrawal_requests.amount`.
   Pydantic schemas type these fields as `Decimal` with explicit
   `max_digits`/`decimal_places`, not `float`.
2. **Integer minor units (pesewas)** for `wallets.balance_minor_units`
   and every `wallet_transactions` amount column — the one place in the
   schema where a ledger's running balance is reconstructed by *summing
   many rows*, and integer arithmetic has zero rounding ambiguity at any
   scale, where even `Decimal` arithmetic (correct, but still
   floating-decimal under the hood) is a strictly weaker guarantee than
   necessary. `app.core.config.to_minor_units` / `from_minor_units`
   convert at the service/API boundary — nothing outside
   `app.services.wallet_service` and `app.repositories.wallet_repository`
   ever handles a raw minor-units integer.

## Consequences

- No currency field anywhere in this codebase's models, schemas, or
  business logic is typed `float` — verified by convention and code
  review at every phase, not by an automated linter rule (a genuine gap;
  a custom ruff/mypy check forbidding `float` in files matching
  `app/models/*.py`/`app/schemas/*.py` would be a reasonable Phase 11+
  hardening addition that wasn't built).
- The two-representation split means a developer adding a new
  money-bearing column must consciously choose which one applies, rather
  than there being one blessed type for "money" everywhere — a small
  extra cognitive step in exchange for the wallet ledger's stronger
  guarantee where it matters most.
- `MoneyAmount` (`app.core.config`) is a reusable Pydantic-annotated type
  alias for the `Decimal` case, keeping the `max_digits`/`decimal_places`
  constraint consistent across every schema that uses it.
