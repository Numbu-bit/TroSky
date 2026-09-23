# ADR-0001: A Postgres partial unique index, not application-level locking, prevents double-booking

## Status

Accepted (Phase 5), reused for the same class of problem in Phase 6
(wallet balance) and implicitly for every other concurrency-sensitive
write since (payment webhook replay, ticket validation).

## Context

The spec's explicit, named acceptance criterion: "Concurrent users cannot
reserve the same seat successfully." Two passengers hitting `POST
/bookings` for the same seat on the same trip within milliseconds of each
other must result in exactly one booking succeeding — not "usually," not
"unless the app crashes at the wrong moment," but *always*, because a
distributed lock, a Redis `SETNX`, or an application-level
check-then-insert can all be defeated by a sufficiently unlucky
interleaving, a crashed process holding a lock, or a second app
instance/pod that never saw the in-memory state the first one used to
decide.

## Decision

`seat_reservations` carries a partial unique index:

```sql
CREATE UNIQUE INDEX uq_seat_reservations_active_trip_seat
ON seat_reservations (trip_id, seat_id)
WHERE status IN ('held', 'confirmed');
```

The database itself rejects a second active reservation for the same
seat on the same trip — full stop, regardless of how many app instances,
threads, or retried requests race to insert one. The application's job
is only to *catch* that rejection (a `SAVEPOINT`-wrapped insert,
`IntegrityError` → `SeatAlreadyReservedError` → the client-facing
`SeatNotAvailableError`; see `BookingRepository.create_seat_reservation`)
and translate it into a normal, expected 409 response — not to prevent
the race in the first place.

Redis (`trip:{id}:held_seats`) exists purely as a pre-check to
short-circuit an *obviously* taken seat before a database round trip
under load — a performance optimization. A Redis outage degrades
performance, never correctness, because every write still goes through
the constraint above regardless of what Redis said.

## Consequences

- Correctness is provable by a genuine two-independent-session
  concurrency test (`asyncio.gather` racing two real, separately
  committing sessions against the same seat) rather than by code review
  alone — and that test exists and passes
  (`tests/integration/test_booking_service.py::TestConcurrentSeatReservation`).
- The same shape (partial unique index + SAVEPOINT-catch) was reused
  directly for `payment_webhook_events`' replay protection (Phase 6) and
  is the template `TestConcurrentWalletDebit` (Phase 6, via row-locking
  instead — see ADR-0002 for why that one differs) followed for proving
  its own guarantee.
- The cost: every seat-reservation insert is a real database round trip
  with a SAVEPOINT, not a lock-free write. For this workload (seat
  reservations, not high-frequency trading) that cost is negligible next
  to the correctness guarantee it buys.
