# ADR-0005: SAVEPOINT-based test isolation, with a real-commit escape hatch for genuine concurrency tests

## Status

Accepted (Phase 1 `db_session` fixture; the escape hatch formalized
across Phases 5–10 as each phase's own concurrency test needed it).

## Context

Integration tests need a real Postgres to mean anything (see every phase
CHANGELOG entry's "known limitation" note on this exact point) and need
each test to start from a clean, isolated database state without the
cost of recreating the schema per test. The standard technique — wrap
each test in an outer transaction and roll it back at teardown — works
for almost everything, but breaks down for exactly one class of test:
proving a *cross-session* concurrency guarantee (ADR-0001, ADR-0002)
requires two genuinely independent database connections racing each
other, and a single outer transaction shared by the whole test can't
provide that.

## Decision

Two fixtures, used for two different purposes:

1. **`db_session`** (the default, used by nearly every integration test):
   binds an `AsyncSession` to a connection with
   `join_transaction_mode="create_savepoint"` inside an outer transaction
   that's always rolled back at teardown — the service layer under test
   can `flush()`/`commit()`-as-if-real without any of it surviving the
   test. Depends on `require_postgres`, which skips (not fails) the test
   when Postgres is unreachable.
2. **Real, independently-committing sessions** (`get_session_factory()`
   directly), used *only* by the small number of tests proving a genuine
   concurrency guarantee — `TestConcurrentSeatReservation` (Phase 5),
   `TestConcurrentWalletDebit` (Phase 6) — via `asyncio.gather` racing two
   coroutines, each opening its own session/connection. These tests
   depend on `require_postgres` *directly* (not via `db_session`, which
   they can't use — a SAVEPOINT-isolated session isn't a second,
   independent connection) so they skip cleanly rather than fail with a
   raw connection error when Postgres is unreachable.

The second bullet's parenthetical isn't hypothetical: exactly this
mistake happened once, live, in this project. The original
`TestConcurrentSeatReservation` test didn't request `require_postgres`
(only the fixtures it *could* use would have gated it), so in an
environment without Postgres it failed with a raw `ConnectionRefusedError`
instead of skipping — surfacing as the single test failure in an
otherwise-clean full-suite run. The fix, and the lesson written up in
`CHANGELOG.md`'s Phase 5 entry, is exactly this ADR's second bullet;
every concurrency test written since (Phase 6's wallet-debit race test)
applied it from the start.

## Consequences

- The overwhelming majority of integration tests get fast, fully-isolated
  runs with zero cross-test state leakage, at the cost of not being able
  to observe genuine cross-session behavior — acceptable, because only a
  small, deliberately-identified set of tests actually need to.
- The two fixture types must be reached for correctly at the point a new
  test is written, not fixed up after the fact — the failure mode when
  they're mismatched (a concurrency test using `db_session`, or a normal
  test forgetting `require_postgres`) is a real, previously-observed bug
  in this exact codebase, not a theoretical one.
