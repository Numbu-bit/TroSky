# ADR-0002: Row-locking (`SELECT ... FOR UPDATE`), not a uniqueness constraint, protects wallet balances

## Status

Accepted (Phase 6).

## Context

ADR-0001 established a partial unique index as the concurrency primitive
for seat reservations — *many rows* (one per seat) contending for
uniqueness within a scope (trip). A wallet balance is a fundamentally
different shape: one row per user, and the correctness requirement isn't
"at most one of these may exist" but "two concurrent mutations of the
*same* row must serialize, never interleave their read-modify-write."
Two concurrent debits against a wallet with just enough balance for one
must result in exactly one succeeding and one failing with
`InsufficientWalletBalanceError` — the same acceptance-criterion shape as
seat booking, but a uniqueness constraint has nothing to attach to here;
there's only one wallet row regardless of how many debits race for it.

## Decision

`WalletRepository.get_or_create_for_update` row-locks the wallet with
`SELECT ... FOR UPDATE` before any balance mutation. A second concurrent
transaction attempting the same lock blocks until the first commits or
rolls back — by the time it acquires the lock, it sees the *post-mutation*
balance and correctly evaluates `InsufficientWalletBalanceError` against
current reality, not stale data. `WalletTransaction`, the append-only
ledger, is written in the same transaction as the balance update, so the
running balance is always reconstructable from the ledger independent of
the cached `wallets.balance_minor_units` column (a second, cross-check
paranoia layer beyond the lock itself).

## Consequences

- Same evidentiary bar as ADR-0001: a genuine two-independent-session
  test (`tests/integration/test_wallet_service.py::TestConcurrentWalletDebit`)
  proves the guarantee rather than asserting it by design intent alone.
- Pessimistic locking means a busy wallet (many concurrent debits/credits
  — unlikely for an individual user's spending wallet, but worth naming)
  serializes strictly, trading throughput for correctness. Acceptable:
  wallet operations are not a high-frequency path, and correctness here
  is non-negotiable (it's real money).
- The same lock-then-ledger shape was reused directly for withdrawal
  approval (Phase 10, debiting at approval time) and trip-earning credits
  (Phase 10, crediting on trip completion) — one primitive, applied
  everywhere money moves through the wallet, rather than a bespoke
  mechanism per call site.
