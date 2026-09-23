# Load tests

Locust scenarios (`locustfile.py`) against a disposable environment —
**never production**. `locust` is already a dev dependency
(`pyproject.toml`).

## Running

```bash
# 1. Point at a real, disposable Postgres+Redis (e.g. `docker compose up postgres redis`)
#    and run the app against it (`make run`, or the `api` service in docker-compose.yml).

# 2. Seed a pool of pre-verified passenger accounts + one bookable trip —
#    see scripts/seed_load_test_data.py's docstring for why this is a
#    separate, load-test-only script rather than reusing `make seed`.
python -m scripts.seed_load_test_data

# 3. Run Locust, headless or with its web UI:
locust -f tests/load/locustfile.py --host http://localhost:8000
# headless, e.g. 200 users ramping over 30s for 5 minutes:
locust -f tests/load/locustfile.py --host http://localhost:8000 \
  --headless --users 200 --spawn-rate 10 --run-time 5m --csv reports/load
```

## What this has and hasn't validated

This session authored the scenarios and the seed script and confirmed
they're internally consistent (endpoints, payload shapes, and query
parameters match the actual route signatures as of Phase 11) — but, per
every other "no Postgres/Redis in this sandbox" caveat throughout
`CHANGELOG.md`, **they have not been run against a live server from this
authoring environment**. Treat a first real run as validation of the
scenarios themselves, not just of the backend's performance — watch for
schema drift (a response shape the scenario assumes has since changed)
before trusting the numbers it reports.

## What the three user classes exercise

- **`BrowsingUser`** (weight 5): anonymous trip search/stop listing — the
  bulk of real-world traffic to a public transport search product.
- **`PassengerUser`** (weight 3): logs in once, then repeatedly searches,
  checks seat availability, and attempts bookings — the concurrency-
  sensitive path `docs/adr/0001-...md` documents. A `409` on
  `attempt_booking` is not a bug; it's the exact expected outcome when
  two simulated passengers race for the same seat and the database
  constraint correctly lets only one through. Watch the *rate* of 409s
  as a proxy for real-world contention under this load profile, not as
  an error to eliminate.
- **`DriverGpsUser`** (weight 1): exercises the GPS-ping endpoint's
  throughput/rate-limiting behavior at the auth boundary — see the
  class's own docstring for the specific (and deliberate) scope
  limitation versus a full authenticated driver session.

## Suggested pass/fail bar (not yet validated against a real run)

No numbers below are empirically derived from this codebase — they're a
starting point to tune once a real run exists, not a claim about actual
measured performance:

- p95 latency on `/trips/search` and `/trips/[id]/seats` under 500ms at
  the target concurrent-user count.
- `/bookings [create]` p95 under 1s (it does more work: seat validation,
  a row-locked insert attempt, notification dispatch).
- Zero 5xx responses at any load level tested — a 409 on booking
  contention or a 429 on rate-limiting are both *correct* non-2xx
  responses, not failures.
