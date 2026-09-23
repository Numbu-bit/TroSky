# Architecture Decision Records

Short records of significant, hard-to-reverse decisions made while
building this backend — not a changelog (`CHANGELOG.md` is that) and not
exhaustive (most day-to-day choices don't rise to "ADR-worthy"; these are
the handful that shaped multiple later phases or would be expensive to
get wrong).

| ADR | Decision |
|---|---|
| [0001](0001-postgres-constraint-over-app-locking-for-seat-concurrency.md) | A Postgres partial unique index, not application-level locking, prevents double-booking a seat. |
| [0002](0002-row-locking-for-wallet-balance-not-partial-index.md) | Row-locking (`SELECT ... FOR UPDATE`), not a uniqueness constraint, protects wallet balances. |
| [0003](0003-sandbox-first-providers-honest-unavailable-skeletons.md) | Sandbox-first provider adapters; unverified vendor integrations raise, never fabricate. |
| [0004](0004-money-as-decimal-or-integer-minor-units-never-float.md) | Money is `Decimal` (or integer minor units), never `float`, at every layer. |
| [0005](0005-savepoint-test-isolation-with-real-session-escape-hatch.md) | SAVEPOINT-based test isolation, with a real-commit escape hatch for genuine concurrency tests. |
