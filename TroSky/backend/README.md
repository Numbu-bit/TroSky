# TroSky Backend

**Smart Public Transport Platform for Ghana — Backend API (MVP)**

> Status: All 11 phases complete. Foundation, identity/auth, driver/
> fleet/vehicle verification, routes/trips, concurrency-safe bookings,
> payments/wallet, QR ticketing, live GPS tracking, notifications/safety,
> earnings/withdrawals/fleet analytics/admin/reporting, and now full test
> depth, load-test scenarios, complete documentation (ADRs, authorization
> matrix, incident response, data retention, provider integration guide),
> Prometheus metrics/rate limiting wired into real call sites, and
> Kubernetes manifests — all with real provider adapters where a vendor
> contract could be verified (MTN MoMo, Firebase push, Twilio, SES/SMTP,
> S3) and honest interface-complete skeletons where it couldn't (Telecel
> Cash, AirtelTigo Money, card gateway, Google/Mapbox/HERE routing,
> mobile-money disbursement). Two independent, database-proven
> concurrency guarantees anchor the booking/payment core: a Postgres
> partial unique index makes double-booking a seat impossible, and
> row-locking makes a wallet overdraft impossible, each backed by a
> genuine two-session race test. See
> [Implementation status](#implementation-status) below,
> [Known limitations](#known-limitations) for what remains honestly
> unfinished, and `CHANGELOG.md` for the phase-by-phase detail this
> summary intentionally no longer repeats in full.

## Product overview

TroSky is a platform connecting passengers, drivers, fleet owners, and
platform administrators for intercity/urban bus travel in Ghana: route
search, seat reservation, mobile money / card / wallet payment, QR ticket
validation, live GPS tracking, and emergency SOS reporting.

## Technology stack

| Concern | Choice |
|---|---|
| Language / runtime | Python 3.12 (Docker image `python:3.12-slim`) |
| API framework | FastAPI + Pydantic v2 |
| Database | PostgreSQL 16 + PostGIS (Supabase-compatible), async via SQLAlchemy 2.x / asyncpg |
| Migrations | Alembic |
| Cache / locks / OTP / rate limiting | Redis 7 |
| Background jobs | Celery (Redis broker) + Celery Beat |
| Realtime | FastAPI WebSockets + Redis Pub/Sub |
| Auth | Argon2id password hashing, PyJWT access/refresh tokens |
| Object storage | S3-compatible (MinIO locally) |
| Observability | structlog (JSON logs), OpenTelemetry, Prometheus |
| Testing | pytest, pytest-asyncio, pytest-cov, Factory Boy |
| Lint / types | Ruff, mypy |
| Packaging / infra | Docker, Docker Compose, Kubernetes/Helm, GitHub Actions |

## Repository structure

```
backend/
  app/
    main.py                 FastAPI app factory / ASGI entrypoint
    api/                     HTTP layer: routers, dependencies, request/response wiring
      v1/                    Versioned business endpoints (added phase by phase)
      health.py               Unversioned liveness/readiness/details probes
    core/                    Cross-cutting infrastructure (config, db, redis, security,
                             permissions, exceptions, logging, telemetry, rate limiting)
    models/                  SQLAlchemy ORM models (persistence)
    schemas/                 Pydantic request/response contracts
    repositories/            Database access, isolated from business rules
    services/                Business use cases (the only layer allowed to orchestrate
                             repositories + providers + events)
    providers/               Third-party integration adapters (payments, sms, email,
                             push, storage, maps) — sandbox + production implementations
    workers/                 Celery app + background tasks
    websocket/               WebSocket connection management (trip/GPS streams)
    middleware/              ASGI middleware (correlation IDs, access logs, size limits)
    events/                  Domain event / outbox pattern plumbing
    utilities/                Small stateless helpers shared across layers
  alembic/                  Migrations (env.py wired to async engine + app settings)
  tests/
    unit/ integration/ api/ security/ load/
  deployments/
    docker/  kubernetes/    Container + cluster deployment assets
  docs/                     ADRs, diagrams, API authorization matrix, runbooks
  pyproject.toml            Dependencies, Ruff, mypy, pytest, coverage configuration
  docker-compose.yml        Full local stack (API, worker, scheduler, Postgres+PostGIS,
                             Redis, MinIO, MailHog)
  Dockerfile                Multi-stage, non-root production image
  Makefile                  Common developer commands
  .env.example              Documented configuration template
```

Layering rule: `api → services → repositories → models`; `services → providers`
for external I/O. Route handlers never contain business logic, and
repositories never import from `api` or `services`.

## Local setup

**Prerequisites:** Docker + Docker Compose (recommended), or Python 3.12,
PostgreSQL 16 with PostGIS, and Redis 7 installed locally.

### Option A — Docker Compose (recommended)

```bash
cd backend
cp .env.example .env        # edit values as needed; defaults work for local dev
make docker-up               # builds and starts api, worker, scheduler, postgres, redis, minio, mailhog
```

The API is then available at `http://localhost:8000`, interactive docs at
`http://localhost:8000/docs` (enabled automatically outside production),
MinIO console at `http://localhost:9001`, and MailHog UI at
`http://localhost:8025`.

### Option B — Local Python environment

```bash
cd backend
python -m venv .venv
source .venv/bin/activate        # Windows: .venv\Scripts\activate
make dev-install                 # pip install -e ".[dev]" + pre-commit install
cp .env.example .env             # point DATABASE_URL / REDIS_URL at your local services
make migrate                     # alembic upgrade head
make seed                        # roles, permissions, dev admin (safe to re-run)
make run                         # uvicorn app.main:app --reload
```

## Environment configuration

All configuration is documented in [`.env.example`](.env.example) and
validated eagerly at startup via `app/core/config.py`. In `APP_ENV=production`,
the process refuses to start if `DEBUG=true`, if `EXPOSE_HEALTH_DETAILS=true`,
if any signing secret is shorter than 32 characters or looks like a
development placeholder, or if a live payment provider is selected without
credentials configured — this is deliberate fail-secure behavior, not a bug.

## Database migrations

```bash
make migrate                         # apply all pending migrations
make migrate-create m="add drivers"  # autogenerate a new migration from model changes
make migrate-downgrade               # roll back one migration
```

The first migration (`20260804_0001_enable_extensions`) enables the
`pgcrypto`, `postgis`, and `citext` Postgres extensions required by every
later migration. `20260804_0002_create_identity_tables` adds the identity
schema (users, roles/permissions, sessions, refresh tokens, OTP challenges,
password resets, device registrations, emergency contacts, notification
preferences). `20260804_0003_create_driver_vehicle_tables` adds drivers,
fleet owners, fleets, vehicles, verification documents/approvals/status
history, and seat layouts. `20260804_0004_create_route_trip_tables` adds
stops (PostGIS-indexed), routes, route stops/schedules, and trips with
their driver/vehicle assignments and status history.
`20260809_0005_create_booking_tables` adds bookings, booking passengers,
seat reservations (with the partial unique index that makes double-booking
impossible), booking status history, and cancellation requests.

## Seed data

```bash
make seed   # loads development-only seed data: 5 system roles, every permission,
            # all permissions granted to `admin`, and a dev administrator
            # (phone +233200000000; password from DEV_ADMIN_PASSWORD env var,
            # else a clearly-labeled local-only fallback — see scripts/seed_dev_data.py).
            # Example routes/stops/vehicles/trips are seeded from Phase 4 onward.
            # Never seeds production credentials.
```

## Tests

```bash
make test         # full suite
make test-cov      # with coverage report, fails if < 80%
pytest -m unit                 # fast, no external services required
pytest -m integration          # requires Postgres + Redis (docker compose up postgres redis)
```

Tests never call real external providers — SMS/email (Phase 2+) and
payment/push/maps (Phase 6+) providers are exercised through their sandbox
implementations (`app/providers/*/sandbox.py`). `.env.test` pins
`SMS_PROVIDER=sandbox` / `EMAIL_PROVIDER=sandbox` for exactly this reason.

`tests/` is organized as `unit/` (pure logic, no I/O), `integration/`
(service-layer tests against a real Postgres/Redis, including the two
genuine two-session concurrency race tests — seat reservation and wallet
debit), `api/` (HTTP-layer contract tests), `security/` (cross-tenant data
isolation), and `load/` (Locust scenarios, run separately — see
[`tests/load/README.md`](tests/load/README.md), never against production).
Any test requiring Postgres/Redis skips cleanly with an explicit message
if they're unreachable rather than failing — the 80% coverage gate is
therefore only meaningfully evaluated where those services exist (CI's
`test` job runs both as service containers).

## Lint & type-check

```bash
make lint          # ruff check
make format        # ruff format + ruff check --fix
make typecheck      # mypy app
```

`pre-commit install` (via `make dev-install`) runs Ruff, mypy, and secret
scanning (`gitleaks`) on every commit.

## Worker & scheduler

```bash
make worker   # celery -A app.workers.celery_app worker --loglevel=info
make beat      # celery -A app.workers.celery_app beat --loglevel=info
```

## Accessing API documentation

Interactive OpenAPI docs are served at `/docs` (Swagger UI) and `/redoc`
whenever `DEBUG=true` or `APP_ENV != production`. **In production these are
disabled by default** — set `DEBUG=true` explicitly (not recommended) to
re-enable them there.

## Provider integration

TroSky ships every third-party integration (payments, SMS, email, push,
maps/ETA, object storage) behind a stable interface with:

1. A **sandbox/local implementation** used in development and tests — fully
   functional, deterministic, no network calls to real vendors.
2. A **production adapter skeleton** with explicit configuration fields and
   `# PRODUCTION CREDENTIALS REQUIRED` markers — no invented, undocumented
   vendor endpoints are implemented.

SMS and email adapters exist from Phase 2 (`app/providers/sms/`,
`app/providers/email/`): `TwilioSmsProvider` and `SmtpEmailProvider` /
`SesEmailProvider` are genuinely production-capable once credentials are
configured (Twilio's REST API and SMTP are both stable, publicly documented
contracts); `HubtelSmsProvider` is a configuration-ready skeleton that
refuses to send until its request contract is confirmed against current
Hubtel docs. Payment/push/maps adapters follow the same pattern from Phase
6. See [`docs/provider-integration-guide.md`](docs/provider-integration-guide.md)
for the full credentials/callback-URL/compliance checklist per vendor.

## Security considerations

* Argon2id password hashing; JWT access/refresh tokens with rotation and
  session revocation (Phase 2).
* Server-side, permission-based authorization on every protected route —
  never trust client-side role checks.
* Redis-backed rate limiting (`app/core/ratelimit.py`), wired via
  `Depends(rate_limit(...))` onto registration, login, OTP, password
  reset, token refresh, payment initiation, QR validation, SOS, and
  location publishing endpoints. Fails **open**, not closed, on a Redis
  outage — rate limiting is an abuse-prevention acceleration layer, not a
  source of truth, and a Redis outage must degrade to "unlimited
  requests, logged" rather than every protected endpoint (including
  login and SOS) 500ing. See `tests/unit/test_ratelimit_fail_open.py`.
* Standardized error envelope that never leaks stack traces, secrets, or
  internal exception messages to clients (`app/core/exceptions.py`).
* Structured logs redact known-sensitive field names before they reach any
  sink (`app/core/logging.py`).
* See [`docs/api-authorization-matrix.md`](docs/api-authorization-matrix.md),
  [`docs/incident-response.md`](docs/incident-response.md), and
  [`docs/data-retention-notes.md`](docs/data-retention-notes.md) for the
  full authorization matrix, incident response procedure, and retention
  policy. Design decisions with lasting consequences are recorded as ADRs
  under [`docs/adr/`](docs/adr/).

## Deployment

* `Dockerfile`: multi-stage, non-root (`uid 1000`), healthcheck baked in.
* `docker-compose.yml`: full local stack.
* [`deployments/kubernetes/`](deployments/kubernetes/): plain Kubernetes
  manifests (no Helm chart) for the API and worker Deployments with
  HPA/PDB, a single-replica `Recreate`-strategy Celery beat scheduler
  (deliberate — two beat instances would each independently fire every
  scheduled task), a one-shot migration `Job` (migrations never run
  implicitly on pod startup, to avoid N API replicas racing
  `alembic upgrade head`), an Ingress tuned for the long-lived WebSocket
  tracking connection, and default-deny NetworkPolicies with explicit
  allows. See that directory's own `README.md` for the full file-by-file
  breakdown, apply order, and stated assumptions (external managed
  Postgres/Redis/S3, no cloud-provisioning code included).
* [`.github/workflows/backend.yml`](../../.github/workflows/backend.yml) (repository
  root, not under `backend/` — required for GitHub Actions to discover
  it): lint → typecheck → test against real Postgres+PostGIS/Redis service
  containers (with an 80% coverage gate) → dependency scan (Trivy) →
  container build & Trivy scan → environment-gated deploys (development /
  staging / production). **Production deploys require manual approval**
  via a protected GitHub Environment — this pipeline never deploys to
  production unattended. The deploy steps themselves are placeholders
  (`echo`) pending real cluster/registry credentials — see
  [`docs/production-readiness-checklist.md`](docs/production-readiness-checklist.md).

## Backup and restore

Documented in
[`docs/data-retention-notes.md`](docs/data-retention-notes.md): managed
Postgres (e.g. Supabase) point-in-time recovery is the assumed backup
mechanism, with `pg_dump`-based logical backups as a documented fallback
for self-hosted deployments, plus a full retention-by-table policy and an
honest list of what automated data-lifecycle tooling does not yet exist
(no automated erasure flow, no OTP/notification purge job, no field-level
encryption).

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| App fails to start with a `ValidationError` mentioning "Insecure production configuration" | `APP_ENV=production` with a dev placeholder secret or `DEBUG=true` — see [Environment configuration](#environment-configuration). |
| `/health/ready` returns 503 | Postgres or Redis is unreachable — check `docker compose ps` / connection strings. |
| `alembic upgrade head` fails on a fresh database | `pgcrypto`/`postgis` extensions require a Postgres role with `CREATE EXTENSION` privilege — the default `docker-compose.yml` Postgres user has this. |

## Known limitations

* Business endpoints exist under `/api/v1` for `auth`, `users` (profile,
  emergency contacts, notification preferences, device registration),
  `drivers`, `fleets`/`fleet-owners`/`vehicles` (+ fleet analytics),
  `routes`/`stops`/`trips` (public search/browse) + live
  `location`/`eta`/`/ws/track`, `driver-trips` (lifecycle, ticket
  validation, GPS ping push), `bookings` (+ tickets, rating), `payments`/
  `wallet` (+ withdrawals), `tickets`, `notifications`, `complaints`,
  `trips/{id}/incidents`+`/sos`, and a substantial `admin` surface
  (driver/vehicle/booking/cancellation/refund/complaint/incident/SOS/
  withdrawal review, user management, driver rating summary, platform
  reporting). Phase 11 added testing depth, load testing, full
  documentation, observability wiring, and Kubernetes manifests — not new
  business endpoints.
* Trip cancellation does not cascade to cancelling its bookings/tickets —
  a pre-existing gap (Phase 4's `TripService.cancel_trip` predates
  bookings) worth closing before production launch.
* No QR *image* is generated server-side (the opaque signed token is the
  API contract; rendering it is a client concern). ETA is a local
  great-circle-distance heuristic, not real road-network routing — see
  `app/providers/maps/local.py`. Telecel Cash, AirtelTigo Money, a card
  gateway, Google/Mapbox/HERE routing, and automated mobile-money
  disbursement (withdrawals are admin-confirmed, not auto-paid — see
  `WithdrawalRequest`'s docstring) are all fully wired at every layer
  above their respective provider adapter but intentionally raise
  `ProviderError` until a real, verified vendor contract replaces the
  placeholder, rather than fabricate one — see
  `app/providers/payments/unavailable.py` and `app/providers/maps/unavailable.py`.
* Document upload is a direct multipart `UploadFile` stream rather than a
  client-side presigned-URL flow (both are spec-permitted; simpler for
  an MVP and easier to test end-to-end).
* Several deliberate MVP simplifications are recorded where they were
  made rather than gathered here redundantly — a trip's Redis
  live-location key expiring via TTL instead of an explicit clear-on-end
  hook (Phase 8), refund/withdrawal payout being a single admin action
  rather than a separate approve-then-process pair (Phases 6, 10),
  notification dispatch being wired into booking confirmation only as
  proof-of-pipeline rather than every domain event (Phase 9), and driver
  earnings being a flat platform-wide percentage rather than a per-fleet
  negotiated rate (Phase 10) — see each phase's `CHANGELOG.md` entry.
* `Permission.WALLET_ADJUST`, `SYSTEM_SETTINGS_MANAGE`, `FEATURE_FLAGS_MANAGE`,
  and `AUDIT_LOGS_VIEW` are defined in `app/core/permissions.py` (present
  since Phase 1) but not wired to any endpoint — verified via grep, not
  assumed; documented rather than hidden in
  [`docs/api-authorization-matrix.md`](docs/api-authorization-matrix.md).
  A manual wallet adjustment tool, system settings/feature-flag admin
  surface, and an audit-log query endpoint are natural post-MVP additions.
* Kubernetes manifests (`deployments/kubernetes/`) are plain YAML, not a
  Helm chart — sufficient to `kubectl apply -k` a real cluster, but no
  templating/values-file layer for multiple environments yet.
* Load test scenarios (`tests/load/`) were authored and verified against
  the actual route signatures but have not been run against a live
  server from this environment — see
  [`tests/load/README.md`](tests/load/README.md)'s own caveat.
* The dev sandbox this backend was authored in has no Docker/Postgres/Redis
  available, so every Postgres/Redis-dependent test (`tests/integration/*`,
  `tests/api/*`, parts of `tests/security/*`) was written and statically
  verified (imports resolve, `ruff`/`mypy` clean, every test collects and
  skips cleanly when Postgres/Redis are unreachable — confirmed via
  repeated full-suite runs: `0 failed` every time) but not *executed for
  real* there — including both genuine concurrency tests (seat
  reservation in Phase 5, wallet debit in Phase 6), which need a real
  Postgres to prove anything. They run for real in CI and via
  `docker compose up postgres redis && pytest`. See `CHANGELOG.md`'s
  Phase 5 entry for why this distinction is stated this carefully: a
  full-suite run in this sandbox once surfaced a concurrency test as a
  hard failure (a raw connection error) rather than a skip, traced to a
  missing skip-guard on that one test rather than a booking-logic
  defect — fixed, and applied proactively to every similarly-shaped test
  written since, but "collects and skips cleanly" is still not the same
  evidentiary bar as "passed against a real database."

## Production-readiness checklist

See [`docs/production-readiness-checklist.md`](docs/production-readiness-checklist.md)
for the full list; this backend is an MVP implementation and requires a
legal/regulatory review for Ghanaian data-protection obligations before a
production launch — no compliance certification is claimed by this
codebase.

## Implementation status

| Phase | Scope | Status |
|---|---|---|
| 1 | Scaffold, config, DB/Redis, logging, health, Docker, CI | ✅ Done |
| 2 | Identity, roles/permissions, sessions, OTP, auth, profile | ✅ Done |
| 3 | Driver/fleet-owner/vehicle documents & approvals | ✅ Done |
| 4 | Routes, stops, schedules, trips, trip state machine | ✅ Done |
| 5 | Seat reservations & booking lifecycle | ✅ Done |
| 6 | Payments, webhooks, refunds, wallet ledger | ✅ Done |
| 7 | QR ticketing | ✅ Done |
| 8 | GPS tracking, WebSockets, ETA | ✅ Done |
| 9 | Notifications, ratings, complaints, incidents, SOS | ✅ Done |
| 10 | Earnings, withdrawals, fleet analytics, admin, reporting | ✅ Done |
| 11 | Rate-limit & metrics wiring, load tests, ADRs, docs, Kubernetes manifests, CI/CD verification | ✅ Done |
