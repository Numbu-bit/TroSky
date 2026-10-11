# Changelog

All notable changes to the TroSky backend are documented in this file.
Format loosely follows [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Phase 1 — Foundation (2026-08-04)

Added:
- Project scaffold matching the modular-monolith layout (`api`, `core`,
  `models`, `schemas`, `repositories`, `services`, `providers`, `workers`,
  `websocket`, `middleware`, `events`, `utilities`).
- `app/core/config.py`: validated `pydantic-settings` configuration with
  fail-secure production checks.
- `app/core/database.py`: async SQLAlchemy engine/session management.
- `app/core/redis.py`: async Redis client, connection pooling, distributed
  lock primitive.
- `app/core/logging.py`: structured JSON logging via structlog with
  automatic sensitive-field redaction and request-correlation binding.
- `app/core/security.py`: Argon2id password hashing, secure OTP/opaque
  token generation, JWT access/refresh token issuance and verification.
- `app/core/permissions.py`: role/permission policy mechanism
  (`Principal`, `require_roles`, `require_permissions`).
- `app/core/exceptions.py`: standardized `{ "error": {...} }` response
  envelope and global exception handlers.
- `app/core/ratelimit.py`: Redis fixed-window rate limiting with per-route
  named rules.
- `app/core/telemetry.py`: Prometheus metrics (`/metrics`) and optional
  OpenTelemetry OTLP tracing.
- `app/middleware/request_context.py`: correlation ID, access logging,
  request-size-limit middleware.
- `app/api/health.py`: `/health/live`, `/health/ready`, `/health/details`.
- `app/models/base.py`: declarative base + UUID/timestamp/soft-delete/audit/
  optimistic-concurrency mixins.
- `app/workers/celery_app.py` + baseline heartbeat task.
- Alembic wired to the async engine; first migration enabling `pgcrypto`,
  `postgis`, `citext`.
- Docker Compose stack (API, worker, scheduler, Postgres+PostGIS, Redis,
  MinIO, MailHog); multi-stage non-root production `Dockerfile`.
- GitHub Actions CI: lint, format check, mypy, tests with coverage gate,
  migration validation, dependency scan, container build & scan,
  environment-gated deploys (production requires manual approval).
- Ruff, mypy, pytest, coverage, pre-commit configuration.
- Unit tests for `core.security` and `core.config`; API tests for
  `/health/*`.

### Phase 2 — Identity, roles/permissions, sessions, OTP, auth, profile (2026-08-04)

Added:
- `app/models/identity.py`: `Role`, `Permission`, `RolePermission`, `User`,
  `UserProfile`, `UserRole`, `UserSession`, `RefreshToken`, `OtpChallenge`,
  `PasswordResetToken`, `DeviceRegistration`, `EmergencyContact`,
  `NotificationPreference` — with unique/check constraints and indexes per
  the spec (unique phone/email, non-negative counters, session/target
  lookups).
- Migration `20260804_0002`: creates all identity tables + `otp_channel`,
  `otp_purpose`, `device_platform` Postgres enums.
- `app/providers/sms/*` and `app/providers/email/*`: provider interface +
  console + sandbox (in-memory, test-safe) implementations for both, plus
  production adapters — `TwilioSmsProvider` (real, documented Twilio REST
  API), `SmtpEmailProvider` (standard SMTP, works against any real relay),
  `SesEmailProvider` (real boto3 SES client). `HubtelSmsProvider` is a
  configuration-ready skeleton that refuses to send until its request
  contract is confirmed against current Hubtel docs — see the module
  docstring.
- `app/utilities/phone.py`: E.164 phone normalization (`phonenumbers`).
- `app/utilities/password_policy.py`: configurable password policy
  (`PASSWORD_MIN_LENGTH`, `PASSWORD_REQUIRE_*` settings).
- `app/repositories/{user,session,otp,profile}_repository.py`: all identity
  database access.
- `app/services/otp_service.py`: OTP issuance (DB is authority; Redis only
  guards the resend cooldown) with HMAC-keyed code hashing
  (`core.security.hash_otp_code`) and attempt-limit enforcement.
- `app/services/auth_service.py`: registration, OTP verification, password
  login, OTP login, refresh-token rotation **with reuse detection** (a
  replayed refresh token revokes the entire session), logout/logout-all,
  session listing/revocation, forgot/reset password (enumeration-safe,
  revokes all sessions on reset).
- `app/services/user_service.py`: profile update, account deletion
  (password-confirmed, soft delete), emergency contacts CRUD, notification
  preferences.
- `app/api/dependencies.py`: real `get_current_principal` — validates the
  JWT, confirms the referenced session hasn't been revoked, and loads
  *current* roles/permissions from the database on every request; wired in
  via `app.dependency_overrides` (see `app/main.py`) so
  `core.permissions.require_roles`/`require_permissions` stay free of
  database imports.
- `app/api/v1/auth.py`: `/register`, `/verify-otp`, `/resend-otp`,
  `/login`, `/otp-login`, `/refresh`, `/logout`, `/logout-all`,
  `/password/forgot`, `/password/reset`, `/sessions`,
  `/sessions/{id}` (DELETE) — every state-changing/enumerable endpoint
  rate-limited.
- `app/api/v1/users.py`: `/users/me` (GET/PATCH/DELETE),
  `/users/me/notification-preferences` (GET/PATCH),
  `/users/me/emergency-contacts` (full CRUD).
- `scripts/seed_dev_data.py`: idempotent seed for the 5 system roles, every
  `Permission` enum value, all permissions granted to `admin`, and a dev
  administrator (no production credentials; password from
  `DEV_ADMIN_PASSWORD` env var or a clearly-labeled local fallback).
- Tests: `tests/unit/{test_password_policy,test_phone_utilities}.py`
  (pure logic); `tests/integration/test_auth_service.py` (registration,
  OTP verify, password login, lockout, refresh rotation + reuse detection,
  logout, suspended-account block); `tests/api/test_auth_api.py`
  (full HTTP registration→verify→login→refresh→reuse-rejected→logout
  flow, mass-assignment rejection, standardized 401 error body);
  `tests/security/test_data_isolation.py` (a passenger cannot read/modify
  another passenger's emergency contacts; a revoked session's access token
  is rejected immediately, not just on next refresh).

Assumptions recorded:
- Added a `super_admin` role beyond the spec's four named roles, as an
  internal break-glass concept (bypasses granular permission checks). Not
  seeded for any user by default.
- `notification_preferences` persistence lands in Phase 2 (API inventory
  places its endpoints under "Profile"); actual notification *delivery*
  (push/SMS/email dispatch, templates, retries) is still Phase 9.
- Login is not gated on phone/email verification (registration sends an
  OTP, but an unverified account can still log in); `phone_verified` /
  `email_verified` are exposed on the profile response so clients can
  prompt. Configurable/tightenable later via a feature flag if the product
  decision is to require verification before login.
- Public registration never creates an `admin` account; the only path to
  an initial administrator is `scripts/seed_dev_data.py`. An
  authenticated admin-invite endpoint is planned for Phase 10.

Known limitation of this session: this sandbox has no Docker/Postgres/Redis
available, so `tests/integration/*` and `tests/api/*` (and the DB-touching
parts of `tests/security/*`) could not be *executed* here — they correctly
collect and skip via the `require_postgres`/`require_redis` fixtures. They
are designed to run in CI (`.github/workflows/ci.yml` provisions real
Postgres + Redis services) and via `docker compose up postgres redis &&
pytest` locally. Everything that *could* run in this sandbox did: `ruff
check`/`ruff format --check`/`mypy app scripts` are clean, all 64
non-DB-dependent tests pass, and both Alembic migrations were validated via
`alembic upgrade head --sql` / `alembic downgrade head:base --sql` (valid
SQL, clean round trip, enum types created exactly once).

### Phase 3 — Driver, fleet-owner, vehicle, document, and approval workflows (2026-08-08)

Added:
- `app/models/drivers.py`: `Driver`, `DriverDocument`, `DriverApproval`,
  `DriverStatusHistory`, `DriverAssignment` (non-trip driver↔vehicle
  authorization), plus the shared `ApprovalStatus` / `DocumentType` /
  `DocumentStatus` / `ApprovalDecision` enums reused by vehicles.
- `app/models/vehicles.py`: `FleetOwner`, `Fleet`, `Vehicle`,
  `VehicleDocument`, `VehicleApproval`, `VehicleStatusHistory`,
  `VehicleSeatLayout`, `VehicleSeat`.
- Migration `20260804_0003`: all 13 tables above + `approval_status`,
  `document_type`, `document_status`, `approval_decision`, `vehicle_type`,
  `seat_type` Postgres enums. Verified upgrade and full downgrade
  (`0003→0002→0001→base`) via `alembic ... --sql`.
- `app/providers/storage/{base,s3,sandbox,malware_scan,factory}.py`: a real
  boto3 S3-compatible adapter (works against MinIO in dev/CI and AWS S3 in
  production — same adapter), an in-memory sandbox for tests, and a
  malware-scan integration point (`NoOpMalwareScanner` — a documented
  extension point, not a production control by itself).
- `app/utilities/file_validation.py`: size/MIME/extension allowlist
  validation applied before any upload is scanned or stored.
- `app/services/document_service.py`: shared validate → scan → store
  pipeline used by both driver and vehicle document uploads.
- `app/services/driver_service.py` / `app/services/fleet_service.py`:
  registration, profile update, document upload/download-URL issuance
  (audit-logged), seat-layout definition (capacity-checked), non-trip
  driver↔vehicle assignment (requires an *approved* driver), and admin
  approve/reject with full status-history + approval-decision trails.
  **Fleet-owner tenant isolation** is enforced on every fleet/vehicle
  lookup — another owner's resource reports `404`, never `403`, so its
  existence isn't leaked.
- `app/api/v1/drivers.py` (role-gated `driver`), `app/api/v1/fleets.py`
  (role-gated `fleet_owner`; flat `/fleet-owners`, `/fleets`, `/vehicles`
  paths per the spec's endpoint list), `app/api/v1/admin.py` (new router;
  driver/vehicle pending-list + approve/reject, permission-gated on
  `drivers:approve` / `vehicles:approve`).
- Multipart document upload (`UploadFile`) rather than presigned
  client-side upload URLs — simpler for an MVP and still satisfies "secure
  streamed upload" from the spec; presigned uploads are a documented future
  option.
- Tests: `tests/unit/test_file_validation.py` (pure logic);
  `tests/integration/test_driver_service.py` and `test_fleet_service.py`
  (registration, license/registration-number uniqueness, document
  upload/download, capacity-checked seat layouts, approved-driver-only
  assignment, admin approve/reject including double-approve rejection, and
  fleet-owner tenant isolation); `tests/api/test_driver_fleet_api.py`
  (full HTTP driver profile + document upload flow, role-gate rejection for
  a passenger hitting driver endpoints, full HTTP fleet/vehicle/seat-layout
  flow, cross-owner `404`).

Assumptions recorded:
- `driver_assignments` (spec's "Driver and verification" table) is modeled
  as a fleet owner authorizing a driver to operate a specific vehicle —
  distinct from the trip-specific `trip_driver_assignments` introduced in
  Phase 4. `GET /drivers/me/assignments` currently returns these non-trip
  assignments; it gains trip data once trips exist.
- Fleet-owner verification uses only the `fleet_owners.status` field (no
  dedicated `fleet_owner_documents` table) since the spec's explicit entity
  list only names driver and vehicle documents.
- Seat layout is one-active-layout-per-vehicle (replace, not version);
  `PUT` fully replaces the layout rather than patching individual seats.
- Same "sandbox provider, no real vendor in tests" policy extended to
  storage: `SandboxStorageProvider` stands in for the real
  boto3/S3-compatible adapter in every test.

Known limitation of this session (unchanged from Phase 2): no
Docker/Postgres/Redis in this sandbox, so `tests/integration/*`,
`tests/api/*`, and the DB-touching parts of `tests/security/*` could not be
*executed* here — 71 non-DB-dependent tests pass, 42 DB-dependent tests
correctly skip via `require_postgres`, and all of Phase 3 collects cleanly
alongside Phases 1–2 (113 tests total). `ruff check`, `ruff format --check`,
and `mypy app scripts` are clean across 85 source files.

### Phase 4 — Routes, stops, schedules, trips, trip state machine (2026-08-09)

Added:
- `app/models/routes.py`: `Stop` (PostGIS `Geography(POINT, 4326)`, GIST
  index), `Route`, `RouteStop` (ordered, unique per route+sequence and
  route+stop), `RouteSchedule` (recurring departure pattern: time of day +
  `days_of_week` array + fare).
- `app/models/trips.py`: `Trip` (optimistic-concurrency `version` column),
  `TripDriverAssignment` / `TripVehicleAssignment` (partial unique index —
  at most one *active* assignment per trip, enforced at the database level,
  not just in application code), `TripStatusHistory`, `TripEvent` (generic
  domain-event log consumed by later phases).
- Migration `20260804_0004`: all 9 tables above + `day_of_week`,
  `trip_status`, `trip_event_type` Postgres enums. Verified upgrade and
  full downgrade (`0004→...→base`) via `alembic ... --sql`; fixed a
  duplicate-GIST-index bug caught by the same dry-run process (GeoAlchemy2
  auto-creates a spatial index by default — disabled via
  `spatial_index=False` so the explicitly declared index is the only one).
- `app/utilities/geo.py`: lat/lng ⇄ WKT/WKB conversion helpers plus a
  haversine fallback distance calculator.
- `app/services/trip_service.py`: the trip state machine
  (`TRIP_TRANSITIONS`) — `SCHEDULED → BOARDING/IN_PROGRESS/CANCELLED`,
  `BOARDING → IN_PROGRESS/CANCELLED`, `IN_PROGRESS →
  PAUSED/COMPLETED/CANCELLED`, `PAUSED → IN_PROGRESS/CANCELLED`,
  `COMPLETED`/`CANCELLED` terminal. Every transition takes a
  `SELECT ... FOR UPDATE` row lock before checking/changing status.
  `start_trip`/`end_trip` are idempotent (repeat calls from the same driver
  return the already-reached state instead of erroring) per the spec's
  explicit requirement. `start_trip` verifies: caller has a driver profile,
  is the trip's *actively assigned* driver, the assigned vehicle is
  approved, and there is no conflicting active trip for that driver
  (`DRIVER_HAS_CONFLICTING_TRIP`).
- `app/services/route_service.py`: stop/route/schedule CRUD, trip search
  (indexed query + short-TTL Redis cache keyed by the exact search
  parameters), and trip-seat lookup (full vehicle seat layout, every seat
  reported available — Phase 5 subtracts reservations).
- `app/api/v1/routes.py` (public, unauthenticated): `/stops`, `/routes`,
  `/routes/{id}`, `/trips/search`, `/trips/{id}`, `/trips/{id}/seats`.
- `app/api/v1/driver_trips.py` (role-gated `driver`):
  `/driver-trips/{id}/{start,pause,resume,end}`.
- `app/api/v1/admin.py` extended (permission-gated `routes:manage` /
  `trips:manage`): stop/route/schedule creation, manual trip creation,
  schedule-based trip creation, driver/vehicle assignment, cancellation.
- `scripts/seed_dev_data.py` extended: 4 example stops (Accra Circle,
  Accra Kaneshie, Kumasi Kejetia, Takoradi Market Circle) and 2 example
  routes with schedules — idempotent, no example drivers/vehicles/trips
  (those need a believable approval trail, not placeholder data).
- Tests: `tests/unit/test_trip_state_machine.py` (pure logic — the full
  transition table plus every rejected/allowed transition, no database);
  `tests/integration/test_trip_service.py` (assignment requires an approved
  driver, start requires the actively-assigned driver, idempotent
  start/end, conflicting-active-trip rejection, pause/resume, cancel-from-
  scheduled, cannot-cancel-completed); `tests/integration/test_route_service.py`
  (stop/route/intermediate-stop creation, search within/outside the stop
  filter, seat lookup with/without a vehicle assignment);
  `tests/api/test_routes_trips_api.py` (public route listing/detail,
  search validation, role-gate rejection for non-drivers and drivers
  without an active assignment).

Assumptions recorded:
- `trip_locations` (high-volume GPS ingestion) is deferred to Phase 8,
  where its retention/archival strategy is designed alongside the ingestion
  pipeline that writes to it — creating the table now with no writer would
  be premature.
- The passenger seat-booking manifest endpoint needs Phase 5's
  `booking_passengers` table and is deferred there; `GET
  /driver-trips/{id}/manifest` is not yet implemented (no fake data is
  returned in its place).
- Trip-end's downstream effects that depend on later phases (marking
  tickets/bookings, earnings/settlement calculation, passenger
  notifications, rating eligibility, analytics) are not yet wired; a
  `TripEvent(TRIP_COMPLETED)` row is recorded as the hook those phases'
  consumers will subscribe to.
- Search and per-search caching target the MVP's expected query patterns
  (indexed columns, 60s TTL); documented as a first point to revisit if
  result-set sizes grow well beyond the pilot scale.

Known limitation of this session (unchanged from Phases 2–3): no
Docker/Postgres/Redis in this sandbox, so `tests/integration/*`,
`tests/api/*` could not be *executed* here — everything collects cleanly
(144 tests total) and the DB-dependent ones correctly skip via
`require_postgres`. `ruff check`, `ruff format --check`, and `mypy app
scripts` are clean across 97 source files.

### Phase 5 — Seat layouts, reservation locking, booking lifecycle (2026-08-09)

Added:
- `app/models/bookings.py`: `Booking` (optimistic-concurrency `version`
  column, unique `booking_reference`, per-passenger-scoped unique
  `idempotency_key`), `BookingPassenger`, `SeatReservation` — the
  concurrency-critical table — `BookingStatusHistory`, `CancellationRequest`.
- **The core correctness guarantee**: `seat_reservations` carries a
  **partial unique index** on `(trip_id, seat_id)` for rows whose status is
  `held` or `confirmed`. Postgres itself rejects a second active
  reservation for the same seat on the same trip — not application-level
  locking, not "only" a Redis lock. Redis is used solely to short-circuit
  an obviously-taken seat before a database round trip (`sismember` on a
  per-trip held-seats set); a Redis outage degrades performance, never
  correctness.
- Migration `20260809_0005`: all 5 tables above + `booking_status`,
  `reservation_status`, `cancellation_status` Postgres enums, including the
  partial unique index. Verified upgrade/downgrade via `alembic ... --sql`.
- `app/repositories/booking_repository.py`: `create_seat_reservation`
  attempts its INSERT inside a `SAVEPOINT` (`session.begin_nested()`) so a
  unique-violation from a losing race is caught and translated to
  `SeatNotAvailableError` without poisoning the rest of a (possibly
  multi-seat) booking transaction — the whole booking then rolls back
  all-or-nothing. `find_expirable_bookings` uses
  `SELECT ... FOR UPDATE SKIP LOCKED` so multiple sweep workers never
  double-process the same booking.
- `app/services/booking_service.py`: idempotent booking creation (a
  replayed `Idempotency-Key` with an identical payload returns the
  existing booking; a different payload raises `IdempotencyConflictError`,
  409), the seat-hold → confirm → cancel/expire lifecycle, and a simple MVP
  cancellation policy — auto-approved (refund-eligible if already paid)
  while the trip hasn't started, queued for admin review afterward.
  `confirm_booking` exists as a service method only, with **no API route**
  — a client can never self-report "payment succeeded"; Phase 6's payment
  webhook handler is the only caller.
- `app/workers/tasks/bookings.py` + a 30-second Celery beat schedule:
  the reservation-expiry sweep.
- `RouteService.get_trip_seats` / `get_available_seats_count` (Phase 4)
  now reflect real availability — configured seat-layout total minus
  currently held/confirmed reservations — closing the loop promised in
  Phase 4's changelog entry.
- `app/api/v1/bookings.py`: `POST /bookings` (Idempotency-Key supported),
  `GET /bookings`, `GET /bookings/{id}`, `POST /bookings/{id}/cancel`.
  `app/api/v1/admin.py` extended with read-only `GET /admin/bookings`
  (permission-gated `bookings:view_any`).
- Tests: `tests/integration/test_booking_service.py` — seat holds, seat/
  vehicle/trip-state validation, idempotent replay, idempotency-key
  conflict, auto-approved cancellation before trip start, double-cancel
  rejection, cross-passenger cancellation rejection, confirm (+ idempotent
  confirm), the expiry sweep, and **the concurrency test**: two
  independent, genuinely concurrent database sessions racing
  `asyncio.gather` for the same single seat — asserts exactly one wins and
  the other receives `SeatNotAvailableError`, proving the database
  constraint (not application logic) is what prevents overselling.
  `tests/api/test_bookings_api.py` covers what's specific to the HTTP
  layer (auth required, validation, cross-passenger 404).

Assumptions recorded:
- `refund_requests` (spec's "Booking and ticketing" entity list) is
  deferred to Phase 6 — a refund is only meaningful once a real payment
  exists, and Phase 6 is where `payments`/`refunds` land.
- Cancellation policy is intentionally simple for the MVP: auto-approved
  refund-eligible before trip start, admin-reviewed afterward. Documented
  as a policy to revisit with product/legal input, not a hidden default.
- The passenger-facing "confirm payment" step is deliberately **not** an
  API endpoint in this phase — only a service method Phase 6's trusted,
  server-verified payment-webhook handler will call, per the spec's "never
  trust a client-submitted payment-successful flag" requirement.

Known limitation of this session (unchanged from Phases 2–4): no
Docker/Postgres/Redis in this sandbox, so the concurrency test itself
has not actually been *executed against a real Postgres* here (it needs
one to prove the race condition is actually resolved by the database) —
it collects and, when Postgres is unreachable, skips cleanly alongside
the rest of the suite (161 tests total), and is designed to run, and
matter most, in CI. `ruff check`, `ruff format --check`, and `mypy app
scripts` are clean across 103 source files.

Post-write correction: a full-suite run in this session surfaced this
test as a hard `FAILED` (a raw asyncpg `ConnectionRefusedError`) rather
than the expected `SKIPPED`. Root cause was a test-hygiene bug, not a
concurrency-logic bug: every other Postgres-dependent test in this
project depends on the `db_session` fixture (which itself depends on
`require_postgres` and calls `pytest.skip(...)` when unreachable), but
`test_only_one_of_two_concurrent_attempts_succeeds` needs two
independently-committing sessions to observe real cross-session
contention, so it bypassed `db_session` and called
`get_session_factory()` directly — skipping the reachability guard
along with it. Fixed by adding `require_postgres` as an explicit
fixture dependency on the test itself, so it now skips exactly like
every other integration test when no Postgres is available, and re-ran
clean (`ruff`/`mypy`/skip-not-fail confirmed). The underlying
correctness claim — that the partial unique index on
`seat_reservations (trip_id, seat_id) WHERE status IN ('held',
'confirmed')` is what actually prevents overselling under concurrent
demand — still awaits execution against a real Postgres (CI, or a local
`docker compose up postgres`); it has not regressed, but it has also
never yet been *proven* by a green run, which is worth stating plainly
rather than implying more confidence than the evidence supports.

## [0.6.0] - 2026-08-11 - Phase 6: payments, webhooks, refunds, wallet ledger

Adds the payment domain end to end: five new tables (`payments`,
`payment_webhook_events`, `refund_requests`, `wallets`,
`wallet_transactions`), a channel-agnostic `PaymentProvider` interface,
idempotent signature-verified webhook processing, admin-gated refund
payouts, and a double-entry-style in-app wallet — and gives
`BookingService.confirm_booking` (built in Phase 5 with no caller) its
first real one.

Added:
- `app/models/payments.py`: `Payment` (idempotent-create pattern mirroring
  `Booking`, optimistic-concurrency `version` column, `internal_reference`
  as the correlation key for inbound webhooks), `PaymentWebhookEvent` (the
  replay-protection/audit table — unique on `(channel, provider_reference,
  event_status)`), `RefundRequest`, `Wallet`, `WalletTransaction` (an
  append-only ledger storing integer minor units, never `Decimal`/`float`,
  via the `to_minor_units`/`from_minor_units` helpers `app.core.config`
  had carried unused since Phase 1 for exactly this).
- `alembic/versions/20260809_0006_create_payment_wallet_tables.py`: all
  five tables + six new enums. Full `upgrade`/`downgrade --sql` validated
  clean, chained after Phase 5's migration.
- `app/providers/payments/`: `base.py` (the `PaymentProvider` Protocol —
  `initialize_payment` / `query_payment` / `refund` /
  `verify_webhook_signature` / `parse_webhook_event` — plus the
  `PaymentChannel` enum: `mtn_momo`, `telecel_cash`, `airteltigo_money`,
  `card`, `wallet`); `sandbox.py` (deterministic, controllable outcomes —
  a magic phone-number suffix simulates a decline, and
  `simulate_webhook_payload` lets tests exercise the full initiate →
  webhook → confirm/credit pipeline without a network call, mirroring
  `SandboxSmsProvider`'s in-memory-outbox pattern); `mtn_momo.py` (a real,
  fully implemented adapter against MTN's publicly documented MoMo
  Collections API — OAuth-style token exchange, Request-to-Pay, status
  polling; refunds correctly raise `ProviderError` since Collections has
  no refund endpoint of its own, a real refund needs the separate
  Disbursements product); `unavailable.py` (the same
  configuration-ready-skeleton policy Phase 2's `HubtelSmsProvider` set:
  Telecel Cash, AirtelTigo Money, and a generic card gateway have no
  stable public merchant-collection contract this codebase has verified,
  so their adapters raise `ProviderError` with a clear pointer rather than
  fabricating request/response shapes — the domain model, migration,
  repositories, services, routes, and webhook pipeline are all fully
  implemented and channel-agnostic regardless); `factory.py` (per-channel
  resolution — `PAYMENTS_ACTIVE_PROVIDER=sandbox`, the default, forces
  every channel through the sandbox regardless of which one is requested).
- `app/repositories/payment_repository.py`, `wallet_repository.py`:
  `PaymentRepository.record_webhook_event` reuses the exact
  SAVEPOINT-and-catch-`IntegrityError` pattern
  `BookingRepository.create_seat_reservation` established in Phase 5 to
  turn a literal duplicate webhook delivery into a database-enforced
  no-op; `WalletRepository.get_or_create_for_update` row-locks
  (`SELECT ... FOR UPDATE`) the wallet before every balance mutation —
  pessimistic locking rather than a uniqueness constraint, since a wallet
  is a single contended row per user rather than many rows racing for one
  of several slots (the seat-reservation shape).
- `app/services/payment_service.py`: `pay_for_booking` (wallet channel
  debits and confirms synchronously — no external party to wait on, so no
  `PROCESSING` state and no webhook for it; every other channel goes
  `PENDING` → `PROCESSING` and is only ever moved to `SUCCESSFUL` by
  `process_webhook` or `sync_payment_status`, never by any client-facing
  response — the spec's "never trust a client-submitted
  payment-successful flag" requirement enforced structurally, not just by
  convention), `initiate_wallet_topup`, `process_webhook` (idempotent —
  a duplicate delivery is recorded but not reprocessed),
  `sync_payment_status` / `reconcile_pending_payments` (the fallback for
  a lost or delayed webhook — both funnel through the same
  `_apply_provider_status` the webhook path uses, so the outcome is
  identical regardless of which one observes success first).
  `app/services/wallet_service.py`: `credit`/`debit`, both idempotency-key
  aware and both row-locking before mutating.
  `app/services/refund_service.py`: `approve_and_process` /`reject` — a
  cancellation only ever opens a `PENDING` `RefundRequest`
  (`PaymentService.create_refund_request_for_cancelled_booking`, called
  from the API layer right after `BookingService.cancel_booking` or the
  new `review_cancellation_request`); actually releasing money is a
  separate, explicit step gated on `Permission.REFUNDS_APPROVE`.
- `app/services/booking_service.py`: `review_cancellation_request` — the
  admin-decision endpoint Phase 5's post-boarding
  (`auto_decide=False`) cancellation path was missing; without it, a
  `CancellationRequest` left `PENDING` had no way to ever be resolved.
- `app/api/v1/payments.py`: `POST /payments/webhooks/{channel}`
  (deliberately unauthenticated — reads the raw body directly so signature
  verification runs against the exact bytes the provider signed, before
  any of it is trusted or parsed as JSON), `GET /payments`,
  `GET /payments/{id}`, `POST /payments/{id}/sync`, `POST /wallet/topups`,
  `GET /wallet`, `GET /wallet/transactions`.
  `app/api/v1/bookings.py`: `POST /bookings/{id}/pay`; `cancel_booking`
  now also calls `create_refund_request_for_cancelled_booking`.
  `app/api/v1/admin.py`: `GET /admin/cancellation-requests`,
  `POST /admin/cancellation-requests/{id}/review`,
  `GET /admin/refund-requests`,
  `POST /admin/refund-requests/{id}/approve`,
  `POST /admin/refund-requests/{id}/reject` — all gated on the
  `Permission.REFUNDS_APPROVE` / `PAYMENTS_REVIEW` slugs `app.core.permissions`
  had already defined since Phase 1.
- `app/workers/tasks/payments.py` + a 120-second Celery beat schedule:
  `reconcile_pending_payments`, the reconciliation sweep.
- Tests: `tests/unit/test_payment_providers.py` (sandbox determinism, MTN
  MoMo signature verification and status mapping, factory channel
  resolution — no network, no database);
  `tests/integration/test_wallet_service.py` (credit/debit,
  insufficient-balance rejection, idempotent replay, ledger balance
  tracking, and — mirroring Phase 5's seat-reservation race test exactly —
  **a genuine concurrency test**: two independent sessions racing to
  debit the same wallet when the balance covers only one, asserting
  exactly one wins);
  `tests/integration/test_payment_service.py` (wallet and provider-channel
  booking payment, webhook-driven confirmation, the failed-payment →
  booking-returns-to-`PENDING`-for-retry transition, webhook replay
  protection, payment idempotency, wallet top-up, reconciliation);
  `tests/integration/test_refund_service.py` (refund-request creation,
  approval crediting the wallet and marking the payment `REFUNDED`,
  idempotent re-approval, rejection, over-refund rejection);
  `tests/api/test_payments_api.py` (auth, validation, and the webhook
  route's deliberate lack of authentication).

Lesson applied from Phase 5's concurrency-test incident (see that
entry above): both new tests that need two genuinely independent,
separately-committing sessions (`TestConcurrentWalletDebit` here, and the
webhook API test that performs a real DB write with no auth check ahead of
it) were written from the start with an explicit `require_postgres`
dependency, so they skip — rather than fail with a raw connection error —
in this sandbox. Verified directly: a full run here produced
`0 failed` with every Postgres-dependent test (Phases 2–6 combined)
skipping cleanly, and separately confirmed that `ruff check`,
`ruff format --check`, and `mypy app scripts` are clean, `configure_mappers()`
succeeds across all 45 mapped tables, and the full Alembic
`upgrade`/`downgrade --sql` chain (six migrations) validates end to end.

Assumptions recorded:
- MTN MoMo is the one real, fully-implemented provider adapter for this
  phase — it is the one Ghanaian mobile-money channel with genuinely
  stable, public API documentation this codebase could verify against
  (https://momodeveloper.mtn.com), the same bar Phase 2 applied when it
  built a real Twilio adapter but left Hubtel as a skeleton. Telecel Cash,
  AirtelTigo Money, and a card gateway are fully wired at every layer
  above the provider adapter (model, migration, repository, service,
  routes, webhook pipeline) but their concrete adapters intentionally
  raise `ProviderError` until a real vendor contract is verified —
  choosing not to fabricate a plausible-looking integration was judged
  more valuable than checking a box.
- Refund payout is a single admin action (`approve` = process
  immediately), not a separate approve-then-process pair, matching the
  MVP-simplicity precedent Phase 5 set for cancellation policy.
- A failed payment returns its booking from `PAYMENT_PENDING` to
  `PENDING` (seat hold retained) so the passenger can immediately retry —
  a different channel or the same one — rather than waiting out the full
  reservation hold on a payment that has already definitively failed.
- Wallet balances are integer minor units (pesewas) end to end at
  storage, converted to/from `Decimal` GHS only at service/API
  boundaries — the strictest possible reading of the spec's "never float"
  requirement, applied to the one table where a rounding bug would be
  worst.

Known limitation of this session (unchanged from Phases 2–5): no
Docker/Postgres/Redis in this sandbox, so the wallet-debit concurrency
test and every other Postgres-dependent test in this phase have not been
*executed against a real Postgres* here — same caveat as Phase 5's
concurrency test, stated with the same care this time given what that
entry had to walk back.

## [0.7.0] - 2026-08-11 - Phase 7: QR ticket issuance & validation

Adds a `tickets` table and a QR-based boarding pass per booked seat, issued
automatically the moment a booking is confirmed and validated by the
trip's assigned driver at boarding.

Added:
- `app/models/tickets.py`: `Ticket` (one row per `BookingPassenger`,
  `TicketStatus`: `issued` → `validated` | `expired` | `revoked`). The QR
  code's signature is deliberately **not** persisted — it's fully
  derivable from `(id, expires_at)` plus `TICKET_QR_SIGNING_SECRET` (the
  same secret `app.core.config` has required since Phase 1, previously
  unused), so there's no second, driftable copy of the same fact to keep
  in sync, and rotating the signing secret correctly invalidates every
  outstanding QR code at once.
- `alembic/versions/20260811_0007_create_ticket_table.py`. Full
  `upgrade`/`downgrade --sql` validated clean, chained after Phase 6.
- `app/utilities/ticket_qr.py`: `encode_qr_token` / `decode_qr_token` — a
  compact `base64url(ticket_id | expires_at | HMAC-SHA256(...))` token.
  `decode_qr_token` never raises on malformed input (a forged or garbled
  scan is an expected input, not an exceptional one) — it returns `None`,
  which `TicketService.validate_qr` turns into a client-facing
  `TicketValidationError`.
- `app/repositories/ticket_repository.py`,
  `app/services/ticket_service.py`: `issue_tickets_for_booking` (idempotent
  — a no-op if tickets already exist for the booking, since it's called
  from `BookingService.confirm_booking`, itself idempotent and reachable
  from more than one caller — a retried webhook, a reconciliation poll
  racing a webhook that already landed); `validate_qr` (row-locks the
  ticket before checking/changing its status, so two conductors scanning
  the same physical ticket at once can't both admit the same passenger;
  checks the token's signature, that it matches *this* trip, and that the
  ticket is still `ISSUED` and unexpired — a correctly-signed token only
  proves it wasn't forged, never that boarding should be allowed);
  `revoke_tickets_for_booking` (only touches still-`ISSUED` tickets — a
  passenger who already boarded keeps their boarding history intact even
  if the booking is cancelled afterward).
- `app/services/booking_service.py`: `BookingService` now composes
  `TicketService` (the same "always composed, never optional" pattern
  `AuthService` uses for `OtpService`) — `confirm_booking` issues tickets,
  `cancel_booking`'s auto-approved path and `review_cancellation_request`'s
  approved path both revoke them.
- `app/services/trip_service.py`: `assert_is_assigned_driver` — a public
  wrapper around the existing `_resolve_assigned_driver_id` guard, reused
  by ticket validation so "is this caller actually running this trip"
  isn't duplicated.
- `app/api/v1/tickets.py`: `GET /tickets/{id}`.
  `app/api/v1/bookings.py`: `GET /bookings/{id}/tickets`.
  `app/api/v1/driver_trips.py`: `POST
  /driver-trips/{trip_id}/tickets/validate` — driver-only, restricted to
  the trip's actively assigned driver via `assert_is_assigned_driver`,
  same guard as start/pause/resume/end.
- Tests: `tests/unit/test_ticket_qr.py` (roundtrip, tampered token, wrong
  secret, garbage input — no network, no database);
  `tests/integration/test_ticket_service.py` (one ticket issued per
  passenger, idempotent re-confirmation, valid scan, repeat-scan
  rejection, wrong-trip rejection, tampered-token rejection, and
  cancellation revoking still-issued tickets while leaving an
  already-validated one untouched); `tests/api/test_tickets_api.py`
  (auth-required checks for all three routes).

Assumptions recorded:
- A ticket's validity window defaults to the trip's scheduled arrival
  time, or scheduled departure + 6 hours if no arrival time is set — an
  MVP default, not a configurable policy yet.
- No QR *image* is generated server-side — `TicketResponse.qr_token` is
  the opaque signed string; rendering it into a scannable QR image is a
  client-side (mobile app) concern, the standard split for this pattern
  and one that avoids adding an image-generation dependency to the
  backend for a purely presentational step.
- Trip cancellation does not yet cascade to cancelling its bookings and
  revoking their tickets — that cascade did not exist before this phase
  either (Phase 4's `TripService.cancel_trip` predates bookings entirely)
  and is being named here explicitly rather than silently left
  undocumented. Worth closing before production launch; out of scope for
  "QR ticket issuance & validation" specifically.

Known limitation of this session (unchanged from Phases 2–6): no
Docker/Postgres/Redis in this sandbox, so every Postgres-dependent test in
this phase has not been *executed against a real Postgres* here. `ruff
check`, `ruff format --check`, and `mypy app scripts` are clean;
`configure_mappers()` succeeds across all 46 mapped tables; the full
Alembic `upgrade`/`downgrade --sql` chain (seven migrations) validates end
to end; a full test-suite run produced `0 failed` with every new test
skipping cleanly (verified via `require_postgres`/`db_session`, not a raw
connection error).

## [0.8.0] - 2026-08-11 - Phase 8: GPS ingestion, Redis geo state, WebSockets, ETA

Adds live GPS tracking: a durable raw-ping log, Redis as the live-read
path (with pub/sub fan-out to WebSocket subscribers), a local
straight-line ETA heuristic, and the authorization rule that ties
watching a trip's location to actually having a reason to.

Added:
- `app/models/tracking.py`: `TripLocation` — the durable, replayable raw
  GPS ping log (retained for `GPS_RAW_RETENTION_DAYS`, purged by a daily
  Celery beat task). Deliberately **not** the live-tracking read path —
  see the service below.
- `alembic/versions/20260811_0008_create_trip_location_table.py`. Full
  `upgrade`/`downgrade --sql` validated clean, chained after Phase 7.
- `app/providers/maps/`: `base.py` (`MapsProvider` Protocol, `EtaResult`);
  `local.py` (`LocalMapsProvider` — great-circle distance × a fixed
  road-winding correction factor, divided by the vehicle's current
  measured speed or a fixed average-speed fallback; an explicit MVP
  heuristic, not real road-network routing); `unavailable.py` (Google/
  Mapbox/HERE skeletons — unlike the payment channels, these vendors'
  routing APIs *are* well documented; the blocker is simply no API key/
  billing account in this environment, so fabricating a response shape
  for an unconfigured paid API would be the fake implementation, not the
  honest skeleton); `factory.py`.
- `app/repositories/tracking_repository.py`,
  `app/services/tracking_service.py`: `record_location` — validates the
  trip is `IN_PROGRESS`, sanity-checks the new position against the
  previous one (an implied speed above `GPS_MAX_PLAUSIBLE_SPEED_KMH` is
  rejected as a spoofed/corrupted reading), updates the Redis live-state
  hash and `GEOADD`s it into a geo set, publishes the update to a
  per-trip pub/sub channel for WebSocket subscribers — but only persists
  a `trip_locations` row when at least `GPS_UPDATE_MIN_INTERVAL_SECONDS`
  has passed since the last one, so a high-frequency GPS stream doesn't
  translate 1:1 into row-volume while live tracking itself stays fully
  responsive. `get_live_location` reads Redis first and falls back to the
  durable log on a cache miss (restart, evicted key) — Postgres is the
  fallback, never the primary read path, for the same latency reasons
  Redis backs seat-hold acceleration rather than the other way around.
  `can_watch_trip` — the trip's assigned driver, a passenger with an
  active booking on it, or a `Permission.TRIPS_MONITOR_LIVE` holder; no
  one else.
- `app/services/trip_service.py`: `assert_is_assigned_driver` — a public
  wrapper around the existing driver-assignment guard, reused here again.
- `app/api/v1/driver_trips.py`: `POST /driver-trips/{trip_id}/location` —
  the driver's own ping-push endpoint, same assigned-driver guard as
  start/pause/resume/end/validate.
  `app/api/v1/tracking.py`: `GET /trips/{trip_id}/location`,
  `GET /trips/{trip_id}/eta`, and `WS /ws/trips/{trip_id}/track` — a
  WebSocket streaming live-location updates as they're published. Browsers
  can't attach an `Authorization` header to a WebSocket handshake, so the
  access token travels as `?token=...` instead (the standard fallback for
  this transport); the same `can_watch_trip` check runs before `accept()`.
- `app/workers/tasks/tracking.py` + a daily (03:00) Celery beat schedule:
  `purge_old_trip_locations`, batched per-transaction so a purge spanning
  a large table never holds one long-running transaction against it.
- Tests: `tests/unit/test_geo.py` (the `haversine_distance_km` helper
  Phase 1 shipped unused until now — roundtrip against a known
  Accra–Kumasi distance); `tests/unit/test_maps_provider.py` (the local
  heuristic's speed-fallback behavior, the routing-factor inflation, the
  unconfigured-real-provider skeleton); `tests/integration/test_tracking_service.py`
  (ingestion caches and is readable, rejects pings for a non-in-progress
  trip, rejects an implausible jump, accepts a plausible nearby update,
  ETA returns a positive estimate, and all three `can_watch_trip` branches
  — driver/unrelated-user/booked-passenger); `tests/api/test_tracking_api.py`
  (REST auth-required checks, and the WebSocket handshake rejecting both a
  missing and a garbage token — using Starlette's sync `TestClient`, since
  `httpx`/the project's usual async `client` fixture has no WebSocket
  support).

Assumptions recorded:
- The live-location Redis hash carries a generous TTL
  (`GPS_STALE_THRESHOLD_SECONDS × 20`) purely as a garbage-collection
  safety net for abandoned trips — "is this reading stale" is always
  computed from `recorded_at` at read time, never from whether the key
  still exists.
- Trip completion/cancellation does not explicitly clear its Redis
  live-state key — it's left to expire via the TTL above. Simple and
  sufficient for the MVP; an explicit clear on `TripService.end_trip`
  would be a small, cheap addition if immediate cleanup ever matters.
- The WebSocket route builds a minimal `Principal` directly from the
  decoded JWT rather than running the full `get_current_principal`
  session-revocation/role-refresh lookup (documented inline in
  `app.api.v1.tracking`) — acceptable for a read-only stream that
  independently re-checks booking/driver ownership against the database
  on every connection via `can_watch_trip`.

Known limitation of this session (unchanged from Phases 2–7): no
Docker/Postgres/Redis in this sandbox, so every Postgres/Redis-dependent
test in this phase has not been *executed against real infrastructure*
here. `ruff check`, `ruff format --check`, and `mypy app scripts` are
clean; `configure_mappers()` succeeds across all 47 mapped tables; the
full Alembic `upgrade`/`downgrade --sql` chain (eight migrations)
validates end to end; a full test-suite run produced `0 failed` with
every new test skipping cleanly via `require_postgres`/`require_redis`.

## [0.9.0] - 2026-08-11 - Phase 9: notifications, ratings, complaints, incidents, SOS

Adds a preference-aware notification pipeline (in-app inbox + push/SMS/
email fan-out, with transactional/safety categories that always bypass
opt-outs), post-trip ratings, complaint filing, and the safety-review
loop: incident reports and SOS distress alerts that SMS every registered
emergency contact immediately, unconditionally.

Also closes a gap the Phase 4 changelog entry explicitly flagged at the
time: `TripService.end_trip` now moves every `CONFIRMED` booking on that
trip to `COMPLETED` — without it, `BookingStatus.COMPLETED` was declared
but never reachable, which would have made "rate your completed trip"
impossible to gate correctly.

Added:
- `app/models/notifications.py`: `Notification` — one row per logical
  notification event, always written (the in-app inbox) regardless of
  channel preferences, with `channel_results` recording each channel's
  independent outcome (`sent` / `skipped_opted_out` / `skipped_no_device`
  / `failed`). `category` (`transactional` / `safety` / `promotional`)
  decides whether `NotificationPreference` opt-outs even apply — only
  `promotional` respects them, cashing in the bypass rule
  `NotificationPreference`'s own Phase 2 docstring already promised.
  `app/models/feedback.py`: `Rating` (one per booking, unique constraint +
  the same SAVEPOINT-and-catch-`IntegrityError` pattern seat reservations
  and payment webhooks use), `Complaint`. `app/models/safety.py`:
  `Incident`, `SosAlert`.
- `alembic/versions/20260811_0009_create_notification_feedback_safety_tables.py`.
  Full `upgrade`/`downgrade --sql` validated clean, chained after Phase 8.
- `app/providers/push/`: `base.py` (`PushProvider` Protocol);
  `firebase.py` (a real adapter against the official `firebase-admin` SDK
  and Google's publicly documented FCM API — genuinely production-ready
  once a real service-account credential is supplied, same bar as the
  MTN MoMo/Twilio adapters; `firebase-admin` and `FIREBASE_ENABLED`/
  `FIREBASE_CREDENTIALS_JSON`/`FIREBASE_CREDENTIALS_PATH` had sat unused
  in this codebase since Phase 1 for exactly this); `sandbox.py` (the
  same in-memory-outbox pattern as `SandboxSmsProvider`); `factory.py`.
- `app/services/notification_service.py`: `notify` (writes the inbox
  record first, then attempts push/SMS/email independently — one
  channel's failure never blocks another or the in-app record),
  `list_notifications`, `mark_read` (ownership-scoped).
  `app/services/rating_service.py`: `rate_booking` — only a `COMPLETED`
  booking can be rated, by its own passenger, once.
  `app/services/complaint_service.py`: file/list/resolve/dismiss, with a
  terminal-state guard against re-deciding an already-resolved complaint.
  `app/services/safety_service.py`: `report_incident`/`trigger_sos`, both
  gated by a shared `_assert_trip_participant` check (the trip's assigned
  driver, or a passenger with an active booking on it — reusing the same
  authorization shape `TrackingService.can_watch_trip` established in
  Phase 8); `trigger_sos` immediately SMSes every one of the triggering
  user's registered emergency contacts, calling `SmsProvider` directly
  rather than going through `NotificationService` — a safety-critical
  alert to a non-platform-user contact must never be shaped by preference
  opt-outs that exist for an entirely different purpose.
- `app/services/trip_service.py`: `end_trip` now calls
  `BookingRepository.list_confirmed_for_trip` and transitions each to
  `COMPLETED` — the fix described above.
  `app/services/user_service.py`: `register_device` (push-token
  registration), composing the `DeviceRepository` Phase 2 already built.
- `app/api/v1/notifications.py`: `GET /notifications`,
  `POST /notifications/{id}/read`. `app/api/v1/users.py`:
  `POST /users/me/devices`. `app/api/v1/bookings.py`:
  `POST /bookings/{id}/rating`, `GET /bookings/{id}/rating`.
  `app/api/v1/complaints.py`: file/list/get. `app/api/v1/safety.py`:
  `POST /trips/{id}/incidents`, `GET /incidents/{id}`,
  `POST /trips/{id}/sos`, `GET /sos/{id}`. `app/api/v1/admin.py`:
  complaint/incident/SOS-alert review queues and decisions (all gated on
  the `Permission.COMPLAINTS_MANAGE`/`INCIDENTS_MANAGE`/`SOS_REVIEW`
  slugs `app.core.permissions` had already defined since Phase 1), plus a
  driver rating-summary endpoint.
- `app/services/booking_service.py`: `confirm_booking` now also sends a
  real `TRANSACTIONAL` "booking confirmed" notification — the one
  concrete trigger wired in this phase to prove the pipeline works
  end-to-end, rather than shipping the infrastructure unused.
- Tests: `tests/unit/test_push_provider.py` (sandbox outbox, factory
  default); `tests/integration/test_notification_service.py` (in-app
  record always written, transactional bypasses opt-out, promotional
  respects it, push reaches a registered device, push is skipped
  cleanly with none registered, mark-read is ownership-scoped);
  `tests/integration/test_rating_service.py` (rate a completed booking,
  reject a second rating, reject a non-owner, driver average);
  `tests/integration/test_complaint_service.py` (file, ownership-scoped
  reads, resolve/dismiss, terminal-state guard);
  `tests/integration/test_safety_service.py` (participant-gated incident
  reporting and SOS triggering, emergency-contact SMS fan-out, SOS
  acknowledge → resolve, rejecting a decision on an already-resolved
  alert); `tests/api/test_notifications_complaints_safety_api.py`
  (auth-required checks across all three routers).

Assumptions recorded:
- SOS/incident location capture is optional (`latitude`/`longitude` may
  be omitted) rather than always pulled from `TrackingService`'s live
  state — simpler for the MVP; wiring an automatic live-location snapshot
  in is a natural follow-up once this phase's plumbing and Phase 8's are
  both in place.
- Admin awareness of a new incident/SOS alert is poll-based (the
  `GET /admin/incidents` / `GET /admin/sos-alerts` review queues), not a
  real-time push to on-duty ops staff — that would need a
  push-to-admin-role mechanism out of scope for this phase.
- Notification dispatch triggers are not wired into every domain event
  (payment received, trip started/delayed, ticket validated, etc.) — only
  booking confirmation, as the concrete proof the pipeline is real and
  not merely scaffolding. Wiring the rest is mechanical (one `notify()`
  call per event) and left for whichever phase most naturally owns each
  trigger, rather than bolted on speculatively here.

Known limitation of this session (unchanged from Phases 2–8): no
Docker/Postgres/Redis in this sandbox, so every Postgres/Redis-dependent
test in this phase has not been *executed against real infrastructure*
here. `ruff check`, `ruff format --check`, and `mypy app scripts` are
clean; `configure_mappers()` succeeds across all 52 mapped tables; the
full Alembic `upgrade`/`downgrade --sql` chain (nine migrations) validates
end to end.

## [0.10.0] - 2026-08-11 - Phase 10: earnings, withdrawals, fleet analytics, admin, reports

Adds driver revenue-share earnings credited automatically on trip
completion, wallet-to-mobile-money withdrawal requests with an
honestly-scoped admin-confirmed payout (see below), fleet-owner analytics
scoped to their own fleet, admin user management, and a platform-overview
report.

Also closes a second gap the Phase 4 changelog entry flagged at the time
alongside booking completion: `USERS_MANAGE`/`USERS_SUSPEND` had been
scaffolded since Phase 1 and `User.is_suspended`/`suspended_reason`/
`suspended_at` had existed since Phase 2, but nothing could ever actually
set them — an admin had no way to suspend an account before this phase.

Added:
- `app/models/payments.py`: `WithdrawalRequest` (`WalletReferenceType`
  gains `trip_earning`/`withdrawal`, added via `ALTER TYPE ... ADD VALUE`
  rather than a type rebuild). The wallet is debited at **approval**, not
  request or completion time — a pending request doesn't tie up funds
  before it's even reviewed, and a driver can't spend money that's
  already been approved for payout. No automated mobile-money
  disbursement is wired up (MTN MoMo Collections has no payout endpoint
  of its own — see the Phase 6 entry on Disbursements needing separate
  credentials this codebase doesn't have), so completion is an explicit
  admin confirmation that a payout was sent by some other means, and a
  failed payout reverses the debit by crediting the same amount back.
  This is a deliberately honest MVP scope, not a shortcut: automating the
  disbursement call itself would require exactly the fabricated-response
  problem this codebase has refused to ship since Phase 6.
- `alembic/versions/20260811_0010_create_withdrawal_requests_table.py`.
  Full `upgrade`/`downgrade --sql` validated clean, chained after Phase 9.
- `app/core/config.py`: `DRIVER_EARNINGS_SHARE_PERCENT` (default 80%),
  `MIN_WITHDRAWAL_AMOUNT_GHS`.
- `app/services/trip_service.py`: `end_trip` now credits the assigned
  driver's own wallet with their configured share of each completed
  booking's fare, referenced back to the booking for audit — the driver
  identity was already verified by `_resolve_assigned_driver_id` earlier
  in the same call, so no extra lookup is needed to know whose wallet to
  credit.
- `app/services/withdrawal_service.py`: request (validates the mobile-
  money-only channel, the configured minimum, and current balance),
  approve/reject/complete/fail — the same approve-then-process shape
  `RefundService` established in Phase 6, reused because the underlying
  problem (admin-gated money movement with a reversible failure path) is
  the same one.
- `app/repositories/analytics_repository.py`,
  `app/services/analytics_service.py`: `get_fleet_summary` (vehicle
  count, trip counts, completed-booking revenue, average rating — scoped
  to the fleet via `FleetService.get_own_fleet`'s existing tenant-
  isolation check, so a fleet owner can never see another's numbers);
  `get_platform_overview` (user counts by role, booking counts, total
  successful-payment revenue, active trips, open complaints, active SOS
  alerts) — deliberately a single dashboard-shaped endpoint rather than a
  general reporting/export system, appropriately scoped for this MVP.
- `app/repositories/user_repository.py`: `list_users` (search by phone/
  email), `suspend`/`reactivate`, `count_by_role`.
  `app/services/admin_service.py`: `AdminService` — suspending a user
  also revokes every one of their outstanding sessions immediately (a
  suspended account must not keep using a token minted before the
  suspension).
- `app/api/v1/payments.py`: `POST /wallet/withdrawals`,
  `GET /wallet/withdrawals`, `GET /wallet/withdrawals/{id}`.
  `app/api/v1/fleets.py`: `GET /fleets/{id}/analytics`.
  `app/api/v1/admin.py`: `GET /admin/users`,
  `POST /admin/users/{id}/suspend`, `POST /admin/users/{id}/reactivate`,
  the withdrawal-review queue (list/approve/reject/complete/fail), and
  `GET /admin/reports/overview` — all gated on the
  `Permission.USERS_MANAGE`/`USERS_SUSPEND`/`WITHDRAWALS_REVIEW`/
  `REPORTS_VIEW` slugs `app.core.permissions` had already defined since
  Phase 1.
- Tests: `tests/integration/test_withdrawal_service.py` (minimum-amount
  and balance-sufficiency validation, channel restriction, the wallet
  being untouched until approval, approve/reject/complete/fail including
  the reversal-on-failure credit, a terminal-state guard);
  `tests/integration/test_analytics_service.py` (a fleet summary
  reflecting real completed-trip revenue and rating data, tenant
  isolation rejecting another owner, platform-overview counts moving
  with seeded data); `tests/integration/test_admin_service.py` (search,
  suspend revoking sessions, reactivate clearing the flag);
  `tests/integration/test_trip_earnings.py` (the driver wallet credited
  with exactly the configured share on trip completion);
  `tests/api/test_phase10_api.py` (auth-required checks across all new
  routes).

Assumptions recorded:
- Driver earnings are a flat, platform-wide percentage
  (`DRIVER_EARNINGS_SHARE_PERCENT`), not a per-fleet or per-route
  negotiated rate, and nothing is credited to the fleet owner separately
  — an MVP simplification; a real revenue-share model would need a rates
  table and is a natural Phase 11+/post-MVP extension.
- Fleet analytics is a single summary snapshot, not a time-series/
  date-ranged report — sufficient for "how is my fleet doing," not yet a
  full BI-style reporting surface.
- Admin user management does not yet expose bulk actions, audit-log
  querying, or non-suspension moderation tools (warnings, rate-limiting a
  specific account, etc.) — suspend/reactivate covers the one action the
  spec's permission scaffolding named explicitly.

Known limitation of this session (unchanged from Phases 2–9): no
Docker/Postgres/Redis in this sandbox, so every Postgres/Redis-dependent
test in this phase has not been *executed against real infrastructure*
here. `ruff check`, `ruff format --check`, and `mypy app scripts` are
clean; `configure_mappers()` succeeds across all 53 mapped tables; the
full Alembic `upgrade`/`downgrade --sql` chain (ten migrations) validates
end to end.

## [0.11.0] - 2026-08-12 - Phase 11: observability wiring, rate limiting, load tests, docs, Kubernetes, final hardening

The final phase. No new business endpoints — this phase closes gaps
between what earlier phases *documented/scaffolded* and what was actually
*wired up*, adds the deployment/documentation surface a real launch would
need, and gives the whole codebase a final honest look for anything left
unfinished.

Added:
- `app/core/telemetry.py`'s Prometheus counters/histogram
  (`PAYMENT_EVENTS_TOTAL`, `WEBHOOK_EVENTS_TOTAL`, `BOOKING_EVENTS_TOTAL`,
  `RESERVATION_EXPIRATIONS_TOTAL`, `GPS_INGEST_TOTAL`,
  `ACTIVE_WEBSOCKET_CONNECTIONS`, `NOTIFICATION_DELIVERY_TOTAL`,
  `SOS_EVENTS_TOTAL`) had existed since Phase 1 but were never
  incremented anywhere — discovered via
  `grep -rn "METRIC_NAME" app/ | grep -v telemetry.py` returning zero
  hits for every one of them. Wired `.inc()` calls into the real service
  call sites (`payment_service`, `booking_service`, `tracking_service`,
  `notification_service`, `safety_service`) and the tracking WebSocket
  handler; verified every `.labels(...)` call site's keyword arguments
  match each metric's declared `labelnames` exactly (a mismatch would
  only surface as a runtime `ValueError` once Postgres/Redis exist, i.e.
  in CI, not in this sandbox — checked by hand since it isn't something
  `mypy`/`ruff` can catch).
- `app/core/ratelimit.py`'s `DEFAULT_RULES` (`payments:initiate`,
  `tickets:validate`, `sos:trigger`, `tracking:location_publish`) had
  existed since Phase 1 but were never applied via `Depends()` to any
  route — same discovery pattern as the metrics gap. Wired
  `Depends(rate_limit(...))` onto `POST /bookings/{id}/pay`,
  `POST /payments/wallet/topups`, `POST /driver-trips/{id}/location`,
  `POST /driver-trips/{id}/tickets/validate`, and
  `POST /trips/{id}/sos`.
- **Bug found and fixed by the above wiring**: applying the rate-limit
  dependency surfaced 3 new auth-check test failures
  (`test_trigger_sos_requires_authentication`,
  `test_topup_requires_authentication`,
  `test_pay_for_booking_requires_authentication`) — a Redis outage made
  `RateLimiter.hit` raise `redis.exceptions.ConnectionError` unhandled
  out of the dependency, producing a 500 instead of the auth
  dependency's 401. Root cause: FastAPI resolves route-level
  `dependencies=[...]` in the same graph as the endpoint's own
  parameter dependencies with no guaranteed auth-first ordering, and a
  hard-failing rate limiter violates this codebase's own restated
  principle that Redis is an acceleration layer, never load-bearing for
  correctness or availability (see `app/core/redis.py`'s module
  docstring, and every prior phase's Redis-as-cache-not-source-of-truth
  decisions). Fixed by wrapping `limiter.hit(...)` in
  `try/except RedisError` and failing **open** — log a warning, let the
  request through to the real checks below it — rather than failing
  closed. New regression coverage:
  `tests/unit/test_ratelimit_fail_open.py` (mocks `RateLimiter.hit`
  directly, since `fakeredis` — this project's only in-memory Redis
  substitute — doesn't support `EVAL`/Lua scripting without the
  optional `lupa` C-extension, which isn't installed; the fixed-window
  counter's own correctness is exercised against real Redis via the
  pre-existing `tests/unit/test_ratelimit_rules.py` and
  `require_redis`-gated integration coverage).
- `docs/adr/0001` through `0005` (+ `docs/adr/README.md` index): the five
  concurrency/money/provider/test-isolation decisions this codebase has
  carried since Phases 5–6 finally written down as ADRs, each with
  Status/Context/Decision/Consequences — including ADR-0005 narrating
  the Phase 5 concurrency-test incident (a raw `ConnectionRefusedError`
  instead of a clean skip, from a missing `require_postgres` guard) that
  motivated this project's SAVEPOINT-vs-real-session test-isolation
  pattern.
- `docs/api-authorization-matrix.md`: every route's auth requirement,
  verified against actual decorators/dependencies via grep before
  writing (not just described from memory) — including an explicit
  section naming the four `Permission.*` slugs defined since Phase 1
  that are still wired to zero endpoints (`WALLET_ADJUST`,
  `SYSTEM_SETTINGS_MANAGE`, `FEATURE_FLAGS_MANAGE`, `AUDIT_LOGS_VIEW`).
- `docs/incident-response.md`, `docs/data-retention-notes.md`,
  `docs/production-readiness-checklist.md`,
  `docs/provider-integration-guide.md`: operational runbook material,
  backup/restore + retention-by-table policy, an honest
  done/deferred/owed breakdown for an actual production launch, and a
  per-vendor credentials/callback-URL checklist distinguishing the
  production-capable adapters from the configuration-ready skeletons.
- `deployments/kubernetes/`: plain manifests (no Helm) for the API and
  worker Deployments (HPA 3–12 replicas, PDB, non-root, read-only root
  filesystem, startup/liveness/readiness probes), a single-replica
  `Recreate`-strategy Celery beat scheduler (deliberately never scaled
  beyond 1 — two beat instances would each independently fire every
  scheduled task), a one-shot migration `Job`
  (`restartPolicy: Never`, migrations never run implicitly on pod
  startup, to avoid N API replicas racing `alembic upgrade head`), an
  Ingress with `proxy-read-timeout`/`proxy-send-timeout: "3600"` for the
  long-lived WebSocket tracking connection, and default-deny
  NetworkPolicies with explicit allows (ingress-nginx, DNS, external
  managed Postgres/Redis/S3 on 443/5432/6379, OTel collector). All YAML
  validated via `yaml.safe_load_all`. See that directory's own
  `README.md`.
- `scripts/seed_load_test_data.py` + `tests/load/locustfile.py`: a pool
  of 50 pre-verified passenger accounts and one fully bookable trip, and
  three weighted Locust user classes (anonymous browsing, authenticated
  passenger search/booking — including an explicit note that a `409` on
  booking contention is the *correct* expected outcome under concurrent
  load per ADR-0001, not a bug — and a narrowly-scoped driver GPS-ping
  throughput check). Authored and verified against actual route
  signatures; not executed against a live server from this sandbox — see
  `tests/load/README.md`'s own caveat.
- Confirmed the already-complete `.github/workflows/ci.yml` at the
  **repository root** (`TroSky/.github/workflows/ci.yml`, required
  location for GitHub Actions to discover it — not `backend/.github/`,
  where an earlier draft of this phase mistakenly placed a duplicate
  before this was caught and removed) was already correct: lint →
  typecheck → test against real Postgres+PostGIS/Redis service
  containers with an 80%-coverage gate → dependency scan (`pip-audit`) →
  container build & Trivy scan → environment-gated deploys (production
  requires manual GitHub Environment approval). Left untouched rather
  than "improved" — it was already solid.

Verified (this session, this sandbox):
- `ruff check .` — all checks passed. `ruff format --check .` — 215
  files already formatted. `mypy app scripts` — success, 161 source
  files, no issues.
- `pytest --cov=app --cov-report=term-missing`: **144 passed, 166
  skipped, 0 failed** — the skips are the same "Postgres is not
  reachable" sandbox limitation as every prior phase; the three
  previously-failing auth tests above are confirmed passing (no longer
  in the failure list). Local coverage is 55.43%, below the 80% gate —
  expected and unchanged from every prior phase's caveat, since the 166
  skipped tests (including both genuine two-session concurrency races)
  need real Postgres/Redis to run at all; the gate is only meaningfully
  evaluated in CI.
- All eight `.labels(...)` metric call sites cross-checked by hand
  against their metric's declared `labelnames` — no mismatches.

Known limitation of this session (unchanged from Phases 2–10): no
Docker/Postgres/Redis in this sandbox, so this phase's own new
integration-shaped behavior (the metrics call sites, the rate-limit
enforcement path beyond the fail-open unit test) has been statically
verified and exercised indirectly through the existing service-layer
integration tests it lives inside, but not executed against real
infrastructure here. Runs for real in CI and via
`docker compose up postgres redis && pytest`.

This is the final phase. See `README.md#known-limitations` for the
consolidated, still-honest list of what remains unfinished after all 11
phases, and `docs/production-readiness-checklist.md` for what's owed
before an actual production launch.

## [0.12.0] - 2026-10-01 - Frontend requests (mobile app, admin web, fleet web)

The gaps in "Backend Requests from the Frontend Team" (30 Sep 2026), built to
the shapes the frontend mocks against. All are listed in `/openapi.json`.

- **G1 done** — `POST /auth/password/forgot` now sends a 6-digit code (by
  email or SMS, as other codes). `POST /auth/password/reset` takes
  `{target, code, new_password}`; the older `{token, new_password}` is still
  accepted.
- **G2 done** — `GET /drivers/me/trips?status=a,b&date=YYYY-MM-DD`
  (paginated): route, end stops, times, status, vehicle, `seats_total`,
  `seats_booked` (paid seats, i.e. the manifest), `boarded_count`.
- **G3 done** — `GET /driver-trips/{trip_id}/passengers`: the manifest for
  the assigned driver only (403 otherwise), in pickup order, phones masked
  (`+23324•••4567`); `boarded`/`boarded_at` follow ticket scans.
- **G4 done** — `GET/POST/DELETE /users/me/favourite-routes`, returning stop
  names; 409 `FAVOURITE_ROUTE_EXISTS` / `FAVOURITE_ROUTES_LIMIT` (20).
- **G5 done** — `POST /users/me/avatar` (multipart `file`, JPEG/PNG ≤ 5 MB)
  → `UserResponse`; `avatar_url` is a signed link valid for an hour.
- **G7 done** — `GET /drivers/me/earnings?period=day|week|month&from=&to=`
  with a bucket for every period (weeks start Monday); `?reference_type=` on
  `GET /wallet/transactions`.
- **G8 done** — `GET /admin/trips` (paginated; filters `status`, `date`,
  `route_id`, `driver_id`), `GET /admin/live-trips`,
  `GET /fleets/{fleet_id}/live-trips`.
- **G9 done** — `PATCH/DELETE /admin/stops/{id}` and
  `PATCH/DELETE /admin/routes/{id}`. DELETE deactivates (history is kept);
  409 `STOP_IN_USE` / `ROUTE_HAS_ACTIVE_TRIPS` while still in use. Moving a
  stop or changing a route's length re-measures the distances that price
  partial rides.
- **G10 done** — `GET /fleets/{fleet_id}/drivers`,
  `GET /fleets/driver-lookup?phone=` (approved drivers only, else 404).
- **G12 done** — `GET /bookings?status=a,b&upcoming=true|false`; every
  `BookingResponse` now embeds `trip {scheduled_departure_at, route_name,
  origin_stop_name, destination_stop_name, status,
  vehicle_registration_number}`, plus `boarding_stop_name` /
  `alighting_stop_name` (the booking's own stops, which differ from the
  route's for a partial ride).
- **G13 done** — optional `safety`, `cleanliness`, `professionalism`,
  `timeliness` (1–5) on `RateBookingRequest` and `RatingResponse`; averages
  in the admin driver rating summary.
- **G16 done** — `GET /vehicles/nearby?latitude=&longitude=&radius_m=`:
  vehicles out on trips near the point, from GPS pings at most 5 minutes
  old, with route and free seats.
- **G14, G15, G17, G18** — not built: awaiting the product decisions the
  request lists. Note for G15: fares are already shared by distance — each
  new booking pays its distance's share of the trip fare, so the price
  falls as seats fill (see `app/services/fare_service.py`).

Also changed this cycle (affects the app's sign-up and sign-in screens):

- Verification codes go by **email** while no SMS provider is paid for
  (`OTP_DELIVERY_CHANNEL=email`), sent after the response returns.
- Registration requires a **Gmail** address (`EMAIL_REQUIRED`,
  `EMAIL_DOMAIN_NOT_ALLOWED`; `REGISTRATION_EMAIL_DOMAINS`).
- Password login and booking require a **verified** account
  (`ACCOUNT_NOT_VERIFIED`, with `details.target` to send a new code to);
  logging in with an emailed code verifies the account.

Migration `20260930_0013`: `favourite_routes`, `user_profiles.avatar_storage_key`,
and the four optional rating columns — additive only.

## [0.13.0] - 2026-10-02 - Frontend requests, round 2

Everything from the second request list that needed no product decision.
All of it is in `/openapi.json`.

### Bugs

- **B1 fixed** — the login lockout, the one-time-code attempt limit and
  "sign out every session when a refresh token is reused" now stick. They
  were written and then rolled back with the failing request. A safeguard
  now marks its write as one to keep (`keep_writes_on_failure`), and
  `get_db` commits that write before reporting the error. Covered by HTTP
  tests that failed before the fix.
- **B2 fixed** — a fresh database registers users without `make seed`.
  Roles and permissions are reference data, added by
  `python -m scripts.seed_reference_data` (`make seed-reference`). It runs
  after `alembic upgrade head` in docker-compose, the container entrypoint
  and the Kubernetes migration Job, and creates no users, so it is safe in
  production.
- **B3 fixed** — the backend workflow is now `.github/workflows/backend.yml`
  at the repository root, with paths prefixed `TroSky/backend` and the
  build context fixed. It runs on pushes to `main`, `develop` and
  `backend`, and on pull requests to `main` and `develop`, only when
  backend files change. It also runs the reference seed after migrations.
  Its lint and test jobs were rehearsed in Linux containers matching the
  runner, which turned up four problems that would have failed the first
  run, all now fixed:
  - `.env.test` was gitignored, although the tests load it and it holds
    only placeholders. It is now committed.
  - Alembic and the seed load the app's settings, so the job now loads
    `.env.test` into its environment, not just the database URL.
  - SQLAlchemy 2.1 was released and the version range allowed it. CI (and
    the Docker image) would have run an untested version whose stricter
    typing fails mypy. It is now capped below 2.1, and those two queries are
    typed to pass on either version.
  - A new test file's imports were out of order.

  It also showed that local test runs were quietly reading the developer's
  `.env` for any setting `.env.test` leaves out, and so passing on dev
  values: higher rate limits, the Gmail SMTP host. Tests now ignore `.env`
  entirely, and `.env.test` sets its own rate limits.
- Rejected requests no longer echo passwords, codes or tokens: a 422's
  `details.errors[].input` is `"***REDACTED***"` for those fields, and the
  same goes for the logs.

### Demo data and tools

- **D1 done** — `make seed-demo` (`python -m scripts.seed_demo_data`).
  It adds:
  - 10 Accra stops: Madina, Circle, Legon, Osu, Achimota, Tema, Kaneshie,
    Lapaz, Airport and 37.
  - 6 routes that stop along the way.
  - 12 approved vehicles with seat layouts: Hiace minibuses, Sprinter
    shuttles and a Yutong bus.
  - A trip every 30 minutes from 05:30 to 21:00, from now to 7 days ahead.
  - A verified passenger with GHS 200 in the wallet, 3 past trips (one
    rated) and 1 upcoming paid booking.

  Re-running tops the timetable up. Logins (password `TroSkyDemo!2026`):

  | Account | Phone |
  |---|---|
  | Passenger, Ama Serwaa | 0245550201 |
  | Fleet owner, Kwesi Appiah | 0245550202 |
  | Driver Kofi Mensah, Madina → Circle | 0245550211 |
  | Driver Abena Owusu, Tema → Circle | 0245550212 |
  | Driver Yaw Boateng, Achimota → Osu | 0245550213 |

  The script refuses to run when `APP_ENV=production`.
- **D2 done** — `make simulate-gps` (`python -m scripts.simulate_gps
  [--trip-id] [--driver-phone] [--speedup 3] [--end]`). It logs in as a
  driver, starts their current or next trip, and sends a ping every 5 s
  along the route's stops. Live tracking, nearby vehicles, search ETAs and
  shared links then show real movement. `--end` completes the trip.
- **D3, D4** — not done here: a hosted server and the Firebase project need
  accounts and billing that only the project owner can set up.

### Passenger app

- **G19 done** — `POST /sos {latitude, longitude}` with no trip. Emergency
  contacts are texted as for a trip SOS. `SosAlertResponse.trip_id` is now
  nullable.
- **G20 done** — every `/trips/search` result has
  `fare {current, solo, minimum, platform_fee, total, currency,
  riders_count, seats}` for the searched pickup and drop-off.
  `GET /trips/{id}/fare-quote?origin_stop_id=&destination_stop_id=&seats=`
  returns the same plus the stops. `current` excludes TroSky's fee, and
  `total` is exactly what `POST /bookings` then charges, because they share
  one code path. `minimum` is the price if every free seat filled.
  - **Answer to the G20 question:** a passenger's fare is **fixed when
    they book**. Later riders lower the price for people who book after
    them; nobody already booked is refunded or re-billed. So "Drops to
    ₵x as more riders join" describes the price of booking later, not a
    refund.
  - Also fixed: a booking with a drop-off but no pickup used to be priced
    as the whole route. It now pays from the route's start to that stop.
- **G21 done** — trips already on the road are now in search results, since
  a trotro picks people up along its route. Each result has:
  - `vehicle_eta_to_pickup_minutes`: from the latest GPS ping, null for
    trips that haven't set off.
  - `has_passed_pickup`: once true, the trip can't be booked from that
    stop. `POST /bookings` answers 409 `PICKUP_ALREADY_PASSED`, also for a
    moving trip booked from its first stop.
  - `ride_minutes` for the searched segment.

  Search also takes `?sort=departure|cheapest|fastest` (trips that have
  passed the pickup always come last), `?vehicle_type=` and `?seats=` (the
  number of seats to price). It now makes a handful of queries in total,
  instead of three per result.
- **G22 done** — `GET /trips/{id}` adds `route_name`, origin and
  destination stop ids and names, `vehicle {registration_number, type,
  make_model, capacity}`, `driver {id, full_name, avatar_url,
  average_rating, rating_count}`, `riders_count`, `seats_total` and
  `available_seats`.
- **G24 done** — `POST /bookings/{id}/share` → `{url, token, expires_at}`,
  for a paid booking only (409 `BOOKING_NOT_SHAREABLE` otherwise). Anyone
  with the link can open it without an account:
  - `GET /shared-trips/{token}`: trip status, stops, vehicle, first names,
    the vehicle's position while moving, and `minutes_to_dropoff`.
  - `GET /share/{token}`: a small page showing the same, for people
    without the app.

  Links last 12 hours; an expired or cancelled one answers 410
  `SHARE_LINK_GONE`. `TRIP_SHARE_BASE_URL` points links at your own page
  instead.
- **G25 done** — `GET /bookings/summary?month=YYYY-MM` →
  `{month, currency, trips_count, total_spent, average_fare,
  total_saved}`. It counts paid trips departing that month. Saved is the
  unshared price minus the fare paid, recorded from today on, so older
  bookings count as no saving.
- **G26 done** — `FavouriteRouteResponse.next_trip {trip_id,
  scheduled_departure_at, available_seats, fare, currency}`: the soonest
  trip in the next 7 days with a free seat, or null.
- **G27 done** — `GET /notifications/unread-count` → `{unread_count}`;
  `POST /notifications/read-all` → `{marked_read}`.
- **G28 done** — `GET/POST /users/me/payment-methods`, plus
  `PATCH/DELETE /users/me/payment-methods/{id}` (rename, make default).
  `{id, channel, masked_number, label, is_default, created_at}`:
  - Only mobile money numbers can be saved (`mtn_momo`, `telecel_cash`,
    `airteltigo_money`); cards need a card processor first.
  - The first number saved is the default, and deleting the default
    promotes the newest one left.
  - Pay with a saved method by sending `payment_method_id` instead of
    `channel` to `POST /bookings/{id}/pay` and `POST /wallet/topups`.

### Driver app

- **G29 done** — `GET /drivers/me/rating-summary`: overall and the four
  categories.
- **G30 done** — `/drivers/me/assignments` items carry `vehicle {id,
  registration_number, vehicle_type, make_model, capacity, status}`.
  `DriverResponse` now has `full_name` and `phone_number`, including on the
  admin driver screens.
- **G31 done** — `GET /driver-trips/{trip_id}/payments` →
  `{total_collected, fare_per_seat, by_channel[{channel, passengers,
  amount}], receipts[{passenger_name, seat_label, amount, channel, paid_at,
  booking_reference}]}`. It's for the assigned driver only. Amounts are
  fares, the platform fee excluded, the same base driver earnings are a
  share of. `fare_per_seat` is the trip's listed whole-route fare.
- **G32 done** — incident types `passenger_issue` and `road_hazard`.
  `severity` is optional and follows the type when left out: accident and
  safety_concern are high; breakdown, passenger_issue and road_hazard
  medium; delay and other low. `POST /incidents/{id}/photo` attaches one
  JPEG/PNG of up to 8 MB (uploading again replaces it). `IncidentResponse`
  has a signed `photo_url`, including in admin lists.
- **G33 done** — manifest entries have `dropoff_stop_name`.

### Decisions (from section E)

1. Boarding: the **driver scans the passenger's ticket**, as built.
2. Driver trips: **scheduled by admins and fleet owners**, as built. Go
   Online/Offline is an availability toggle, with no ride requests.
3. Subscriptions (G14): out of the MVP.
4. Ghana Card verification (G17): out of the MVP.
5. Wallet "Send" and driver chat: out of the MVP.
6. Withdrawals stay **paid after admin approval**.

Migration `20261002_0014`:
- `payment_methods`
- `sos_alerts.trip_id` becomes nullable
- `incident_type` gains two values
- `incidents.photo_storage_key`
- `bookings.solo_fare_amount`

Everything is additive except the nullable `trip_id`, and the migration has
a full downgrade.

## [0.14.0] - 2026-10-03 - Admin dashboard, steps 1-2

The first two build steps of "TroSky Admin: Missing Backend Endpoints". All
of it is in `/openapi.json`. The document suggested permission names; these
endpoints reuse the existing ones instead:

| Endpoints | Needs any one of |
|---|---|
| Vehicles | `vehicles:approve`, `trips:monitor_live` |
| Drivers | `drivers:approve`, `trips:monitor_live` |
| Fleets | `vehicles:approve`, `reports:view` |
| Payments, revenue | `payments:review`, `refunds:approve`, `reports:view` |
| User growth, funnel | `reports:view` |
| Driver performance | `reports:view`, `drivers:approve` |

### Changes to existing endpoints

- **Trip cancel** (`POST /admin/trips/{id}/cancel`) now cancels every booking
  still holding seats on the trip, in the same transaction:
  - Paid bookings become `refund_pending`, each with a refund request
    awaiting approval at `/admin/refund-requests`. Unpaid ones are cancelled.
  - Every passenger is notified, and the response adds `bookings_cancelled`,
    `refunds_queued` and `refund_amount`.
  - A mobile money payment that succeeds after its booking was cancelled or
    expired is now queued for a refund. Before, the webhook failed and the
    provider retried it forever, with the money never returned.
- **Overview** (`GET /admin/reports/overview`) takes `from`, `to` (inclusive
  Ghana dates, default the last 30 days) and `city`. It adds `period` and
  `figures`. Each figure has `value`, `previous` (the same number of days
  just before), `change_percent` and a daily `series`. The figures are:
  - `new_users`, `new_passengers`, `new_drivers`
  - `paid_bookings`, `completed_trips`, `booking_payments`
  - `complaints`, `sos_alerts`

  The all-time totals are unchanged. With `city`, sign-up figures are null,
  since users have no city.
- **CSV export**: `?format=csv` on `/admin/trips`, `/admin/bookings`,
  `/admin/complaints`, `/admin/incidents` and `/admin/withdrawals` (and every
  new list). It returns every matching row, up to 10,000, with nested fields
  as dotted columns.

### New endpoints

- **Section 2 done**: `GET /admin/vehicles`, `/admin/vehicles/{id}`,
  `/admin/drivers`, `/admin/drivers/{id}`, `/admin/fleets` and
  `/admin/fleets/{id}`.
  - **Live status:** `on_trip` (boarding, under way or paused), `idle` (a
    trip still to run today) or `offline`.
  - **Vehicles:** insurance and roadworthiness expiry come from approved
    documents.
  - **Filters:** approval status, live status, fleet, city (a trip starting
    there in the last 30 or next 7 days), `expiring_within_days`, and a
    search.
  - **Fleets:** size, vehicles on a trip now, 7-day utilization (share of
    approved vehicles that completed a trip), 30-day revenue and average
    rating.
  - **Details:** a vehicle's details add documents, 30-day activity and
    recent incidents; a fleet's add all its vehicles and drivers.
- **Section 5 done**:
  - `GET /admin/payments`: every payment with its booking, payer, method,
    fee and refunds. Filters: dates, method, status, purpose, city, route,
    fleet and a reference search.
  - `GET /admin/analytics/revenue`:
    - figures: gross, refunds, net, platform fees, paid bookings, average
      fare and failed-payment rate
    - a daily series per payment method
    - totals by route, fleet and hour
    - pending withdrawals
- **Section 6 done**:
  - `GET /admin/analytics/users`:
    - sign-ups per day by role, and cumulative users
    - daily, weekly and monthly active users ("active" = signed in or
      booked)
    - activation: a paid booking within 7 days of signing up
    - weekly retention cohorts, and passengers by city
  - `GET /admin/analytics/funnel`: searches → reserved → paid → boarded
    (ticket scanned), with conversion between stages.
- **Section 3 done**: `GET /admin/drivers/performance` and
  `/admin/drivers/{id}/performance`.
  - **Measures, per period:** rating, on-time starts (within 5 minutes),
    cancellation rate over finished trips, complaints per 100 trips, and
    QR scan rate.
  - **Score:** 0–100, weighted rating 35%, on time 25%, reliability 15%,
    complaints 15%, QR 10%. A part with no data is left out rather than
    counted as zero.
  - **At risk:** flagged with reasons, but only once there is enough data.
  - **Detail view:** adds a daily trend, rating spread, recent reviews, and
    earnings today, this week and this month, with pending withdrawals.

### Search logging

The funnel, and the demand heat maps in a later step, need searches.
Migration `20261003_0015` adds `search_events`, one row per trip search,
including searches far from any stop that fail. It stores the stops, the
counts found and bookable, and only a ~550 m grid cell for GPS searches,
never the passenger's position. Searches are counted from this release on.

Also: the `seed_identity_data` test fixture now grants the admin role every
permission, as the reference seed does in every real environment.

## [0.15.0] - 2026-10-03 - Admin dashboard, step 3: audit log, settings, flags, wallets

Section 1 of "TroSky Admin: Missing Backend Endpoints". Migration
`20261003_0016` adds `audit_logs`, `system_settings` and `feature_flags`.
The endpoints reuse existing permissions:

| Endpoints | Needs |
|---|---|
| Audit log | `audit_logs:view` |
| Settings | `system_settings:manage` |
| Feature flags | `feature_flags:manage` |
| Wallets | `wallet:adjust` |

### Audit trail

Every admin request that changes something is recorded automatically. No
endpoint has to remember to do it, so new admin endpoints are covered too.
The request adds one row for each database row it inserts, changes or
deletes, holding:

- who, which endpoint (its name, method and path), and which row (table and
  id)
- the columns that changed, before and after (an insert has only "after", a
  delete only "before")
- the reason from the request body (`reason`, `rejection_reason`, `notes`,
  `decision_notes` or `resolution_notes`), the IP address, user agent and
  request id

A request that changed nothing still gets one row (`entity_type` is
`request`). Not recorded:

- reads
- failed requests, which are rolled back together with their audit rows
- password, code and token hashes
- `updated_at` and `version`
- the status-history tables, which repeat a change already on the row
- rows changed by a bulk `UPDATE` or `DELETE` statement, which are not
  listed one by one; the request is still on record

`GET /admin/audit-logs` lists the trail, newest first. It filters by
`actor_id`, `action`, `entity_type`, `entity_id`, `from` and `to`, and
supports `?format=csv`. `GET /admin/audit-logs/{id}` returns one entry.

### Settings

`GET /admin/settings` lists each setting with its value and whether an
admin changed it. `PATCH /admin/settings` changes any of them at once:

- Platform fee per seat and percent, and the driver's share of the fare.
- Payment hold, 60–3600 s.
- Live position interval, 2–60 s.
- Complaint resolution time for each priority, in hours.
- Approval target, in hours.
- SOS escalation contacts.
- Enabled cities.

Each setting defaults to the environment value. An admin's change is stored
and takes precedence; `null` puts the default back. All the changes in one
request are checked together, and if any is invalid none are saved (422).
If a stored value stops being valid (because the limits changed later), it
is ignored and an error is logged. Its default applies until an admin saves
a new value, and it never blocks changes to other settings.

The fees, the payment hold, the driver's share and the position interval
apply to new quotes, bookings and trips. They take effect at once on the
server that made the change, and within 30 seconds on the others. The
complaint times, approval target and escalation contacts are stored for
step 4. Enabled cities are stored but not enforced yet.

### Feature flags

`GET /admin/feature-flags` and `PATCH /admin/feature-flags/{key}` (body
`enabled`, `rollout_percent`):

- `fare_sharing` turns fare sharing between a trip's riders on or off.
- `book_moving_trips` controls trips already under way: shown in search and
  bookable from stops ahead. This is the new setting
  `BOOK_MOVING_TRIPS_ENABLED`, on by default as before.
- `trip_share_links` can go to a share of passengers, the same passengers
  each time. When it is off for a passenger, sharing answers 403
  `FEATURE_DISABLED`.

A flag that switches a platform-wide setting is on or off for everyone, so a
partial rollout of one is refused (422).

### Wallets

- `GET /admin/wallets/{user_id}` returns a user's balance, money held for
  withdrawals, and transactions, newest first.
- `POST /admin/wallets/{user_id}/adjustments` credits or debits a wallet by
  hand. It needs a reason, which the user sees as the transaction's
  description, and takes an optional reference. A debit may not take the
  balance below zero (402). Send an `Idempotency-Key` so a retry does not
  adjust twice.

## [0.16.0] - 2026-10-03 - Admin dashboard, step 4: complaints, alerts, search, live stream

Sections 4 and 10 of "TroSky Admin: Missing Backend Endpoints". Migration
`20261003_0017` adds:

- complaint priority, assignment and first-response time
- `complaint_notes`
- `sos_escalations`

| Endpoints | Needs |
|---|---|
| Complaints (all of them) | `complaints:manage` |
| SOS details, escalations | `sos:review` |
| Trip replay | `trips:monitor_live` or `trips:manage` |
| Alerts, search, live stream | any permission behind something they show; each admin sees only that part |

### Complaints

Every complaint now has a **priority**: low, medium, high or urgent. Safety
complaints start high and the rest medium, and existing safety complaints
were moved to high.

A complaint is **due** after its priority's resolution time from filing.
These times come from the `complaint_sla_hours` setting: 72, 48, 24 and 4
hours by default. It is **overdue** while still open or in review after
that.

Endpoints:

- **List.** `GET /admin/complaints` now also returns:
  - the priority
  - who filed it, with name and phone
  - the assignee
  - the first-response time
  - `due_at` and `is_overdue`

  New filters: `priority`, `category`, `assigned_to`, `unassigned` and
  `overdue`, and `complaint_status` now takes several values. `sort` takes
  `created_at`, `due_at` or `priority`.
- **One complaint.** `GET /admin/complaints/{id}` returns the complaint with
  its notes and messages, oldest first.
- **Change.** `PATCH /admin/complaints/{id}` can:
  - assign it (`assigned_to`; `null` unassigns). Only an active admin who
    handles complaints can be assigned.
  - set the `priority`
  - move it to `in_review`

  A resolved or dismissed complaint cannot be changed (409).
- **Notes and messages.** `POST /admin/complaints/{id}/notes` takes a
  `kind`. An `internal` note is for the team only. A `message` goes to the
  passenger as a notification and shows in the app.
- **Figures.** `GET /admin/complaints/stats` takes `from`, `to` and `city`
  like the other analytics, and returns:
  - what is open now, by priority, with how many are overdue or unassigned
  - for the period against the one before:
    - complaints filed, with a daily series
    - complaints per 1,000 completed trips
    - average hours to a first response and to a decision
    - complaints filed by category
- **Passenger app.** `GET /complaints/{id}/messages` lists support's
  messages on the passenger's own complaint.

The **first response** is the first thing the passenger saw: a message, the
move to review, or the decision. Complaints decided before this release
count their decision.

The resolve and dismiss routes moved into the new complaints module. Their
URLs are unchanged, and their responses now use the admin shape, which
includes every field they returned before.

### SOS

- `GET /admin/sos-alerts/{id}` returns what an admin needs to act:
  - where the alert was raised, and who raised it (name and phone)
  - the trip: vehicle, driver and fleet owner with their phone numbers, and
    the vehicle's last recorded position
  - the escalations so far
  - who to call, from the `sos_escalation_contacts` setting
- `POST /admin/sos-alerts/{id}/escalations` records who was contacted, with
  name, number, time (default now) and notes. The contact is one of police,
  ambulance, fire service, fleet owner, emergency contact or other. An alert
  nobody has picked up yet is acknowledged by the same admin. The document
  proposed `/admin/sos/{sosId}/escalations`; this path keeps the existing
  `/admin/sos-alerts` naming.

### Alerts feed

`GET /admin/alerts` is one list, most severe first, then oldest:

| Type | Severity | What it means |
|---|---|---|
| `sos_active` | critical | An SOS alert nobody has picked up. |
| `complaint_overdue` | high, medium or low | High for urgent and high-priority complaints, otherwise the complaint's own priority. |
| `document_expiring` | high, medium or low | An approved driver's or vehicle's latest approved copy of a document: low if it expires within 30 days, medium within 7 days, high if already expired. An approved renewal clears it. |
| `approval_waiting` | medium | A driver or vehicle waiting longer than the `approval_target_hours` setting (48 h by default). |

Each type needs its own permission, and `counts` gives the total of each.
High-risk fraud flags join the feed in step 6.

### Search

`GET /admin/search?q=` needs at least 2 characters. It returns up to `limit`
results (default 5) of each kind:

- users, by name, phone number in any format, or email
- drivers, by name, phone number or licence number
- vehicles, by plate, ignoring spaces and dashes
- trips, by route name, or by id or its first characters
- bookings, by reference
- payments, by TroSky or provider reference

An id finds any kind. `searched` lists the kinds the caller's permissions
cover.

### Trip replay

`GET /admin/trips/{id}/track` returns the positions recorded during a trip,
oldest first, with the distance they cover and the top speed. It returns up
to 20,000 points; `truncated` says there were more, and `since` / `until`
narrow the range. `?format=csv` exports the points. Positions are kept for
`GPS_RAW_RETENTION_DAYS`.

### Live stream

`GET /admin/stream` sends Server-Sent Events, in place of polling.

| Event | Sent when |
|---|---|
| `sos.created`, `sos.updated` | An SOS is raised, or acknowledged, escalated or resolved. |
| `complaint.created`, `complaint.updated` | A complaint is filed, or changed. |
| `approval.requested`, `approval.document_uploaded` | A driver or vehicle (`kind`) applies or uploads a document. |
| `position` | A bus moved; at most every 5 seconds per trip. |
| `end` | Access was withdrawn; the stream then closes. |

- **Format.** `data` is JSON: `{"type", "at", "data"}`, where `data` holds
  the ids involved. Fetch the details from the endpoints above.
- **Signing in.** Send `Authorization: Bearer`, or `?token=` for
  `EventSource`, which cannot send headers.
- **Topics.** `topics=sos,complaints,approvals,positions` narrows the
  stream. By default it carries every topic the caller's permissions allow:
  `sos:review`, `complaints:manage`, `drivers:approve` / `vehicles:approve`,
  and `trips:monitor_live` for positions.
- **No lost events.** An event is sent only after its change is committed.
  Every event except `position` has an id. When `EventSource` reconnects it
  sends `Last-Event-ID`, and the stream replays what was missed from the
  last 1,000 events.
- **Staying signed in.** Access is re-checked every
  `WS_AUTH_RECHECK_SECONDS`, so a logout, a suspension or a removed
  permission ends the stream.
- **Connections.** A comment line every 15 seconds keeps idle connections
  open. Each server process takes at most 20 streams (503 beyond that).
  Behind a proxy, turn off response buffering for this path. The response
  sets `X-Accel-Buffering: no` for nginx.

The audit trail covers every change above, including assignments, notes
and escalations.

## [0.17.0] - 2026-10-03 - Admin dashboard, step 5: demand heat maps

Section 8 of "TroSky Admin: Missing Backend Endpoints". There is no
migration: this reads the search log added in 0.14.0, and bookings.

`GET /admin/analytics/demand` needs `reports:view`.

- **`type`** chooses the demand to show:
  - `searches` (the default): every trip search
  - `unmet`: searches that found no bus with a free seat to catch
  - `bookings`: paid bookings, counted in seats
- **Filters:**
  - `from`, `to` and `city`, as for the other analytics. The city is where
    the pickup stop is.
  - `days`, such as `mon,tue,wed,thu,fri`
  - `hour_from` and `hour_to`, in Ghana time and inclusive. `22` to `5`
    wraps past midnight.
- **Returns:**
  - `total`, `previous_total` (the same number of days just before) and
    `change_percent`
  - `cells`: the weight in each ~550 m grid cell, heaviest first, up to
    2,000. `cell_degrees` gives the cell size.
  - `top_origins` and `top_pairs`: the 10 busiest pickup stops and
    journeys
  - `by_day_and_hour`: Monday to Sunday, 24 hourly values each
  - `supply_gaps`: the pickup stops where searches most often found no bus
    with a free seat, with `searches`, `unmet` and `unmet_share`

Privacy: the response holds only totals, never a position. A GPS search was
only ever stored as its grid cell. A search by stop, and a booking, are
placed at the pickup stop, a public place. A cell with fewer than 3
searches is withheld, so no one person's searches can be picked out;
`withheld` says how many searches that left out. Searches are counted from
0.14.0 on.

## [0.18.0] - 2026-10-03 - Admin dashboard, step 6: fraud detection

Section 7 of "TroSky Admin: Missing Backend Endpoints". Migration
`20261003_0018` adds:

- `fraud_rules`, `fraud_flags` and `fraud_flag_events`
- `blocked_devices`
- `ticket_scan_attempts`
- a freeze on `wallets`

Two new permissions, `fraud:view` and `fraud:manage`, are added by the
reference seed and granted to the admin role. Reading flags and figures
needs either one; changing anything needs `fraud:manage`.

### Detection

A scheduled job runs every 15 minutes (`app.workers.tasks.fraud`).
`POST /admin/fraud/scan` runs one at once, and answers 409 while another run
is going. Each rule has a threshold, a time window and a severity:

| Rule | Looks for | Default |
|---|---|---|
| `ticket_reused` | A ticket shown again after boarding, or on another trip | 1 refused scan in 24 h |
| `payment_failures` | Repeated failed payments | 5 in 1 h |
| `shared_device` | Several accounts signing in on one device | 3 accounts in 30 days |
| `shared_momo_number` | Several accounts paying with one mobile money number | 3 accounts in 30 days |
| `expired_reservations` | Reservations left to expire unpaid | 5 in 7 days |
| `refund_share` | A high share of a passenger's paid bookings refunded | half, of at least 4, in 30 days |
| `stationary_trip` | A completed trip whose vehicle barely moved (5+ positions) | 0.2 km at most, trips ended in 24 h |
| `impossible_speed` | A jump between recorded positions faster than a bus can go | 150 km/h, in 24 h |
| `low_scan_compliance` | A driver scanning few paid passengers' tickets (10+ passengers) | half or fewer, in 7 days |
| `unusual_topups` | Large wallet top-ups | GHS 2,000 in 24 h |

A finding becomes a **flag**. Each flag has:

- the rule, severity and a **risk score** (0–100): the severity's base (low
  25, medium 50, high 70, critical 90), plus up to 20 for how far past the
  threshold the finding is
- what it is about (a user, ticket, trip, driver, device or phone number)
  and the account mainly concerned
- a summary and the money at risk
- its evidence, with links to the users, trips, bookings and payments
  involved

Each flag names its incident, such as a particular ticket, or a user on a
particular day, so later runs never raise it twice:

- **Getting worse.** A flag still open is updated when its finding grows,
  for example more failures. Its timeline records "detected again" and its
  risk score rises with it.
- **Closed.** A flag confirmed or judged a false positive stays as it is.

To support `ticket_reused`, a ticket refused at boarding because it was
used already, or because it is for another trip, is now recorded, even
though the scan itself fails.

### Endpoints

- **List.** `GET /admin/fraud/flags` lists flags, riskiest first. It
  filters by status, rule, severity, `min_risk`, assignee or `unassigned`,
  the account concerned, and `from`/`to`, and supports CSV.
- **One flag.** `GET /admin/fraud/flags/{id}` returns the evidence, the
  timeline (detected, detected again, assigned, status changes, actions),
  and the linked users (suspended? wallet frozen?), trips, bookings and
  payments.
- **Review.** `PATCH /admin/fraud/flags/{id}` sets the status
  (`investigating`, `confirmed`, `false_positive`, or back to `open`) and
  the assignee. The assignee must review fraud. Confirming a flag or calling
  it a false positive needs a `reason`.
- **Actions.** `POST /admin/fraud/flags/{id}/actions` takes a reason, and
  moves an open flag to investigating. The account defaults to the flag's
  account, and the device to the flag's device. The actions:
  - `suspend_account` suspends the account and signs it out everywhere.
    `/admin/users/{id}/reactivate` undoes it.
  - `freeze_wallet` / `unfreeze_wallet`. No payments or payouts leave a
    frozen wallet: debits, withdrawal requests and completing a payout all
    answer 403 `WALLET_FROZEN`. An admin's wallet adjustment can still take
    money back. `GET /admin/wallets/{id}` shows `frozen_at` and
    `frozen_reason`.
  - `block_device` / `unblock_device`. Every session on the device ends,
    and signing in from it answers 403 `DEVICE_BLOCKED`.
- **Figures.** `GET /admin/fraud/stats` returns open and high-risk flags
  (risk 70+) and the money at risk now. For the period it adds flags raised
  per day, against the previous period; confirmed and false positives; the
  precision (confirmed out of all reviewed); and counts per rule.
- **Rules.** `GET /admin/fraud/rules` lists the rules. `PATCH
  /admin/fraud/rules/{rule}` changes a threshold, time window (5 minutes to
  90 days) or severity, or turns a rule off; the change applies from the
  next run.

Open flags with a risk score of 70 or more appear in `/admin/alerts`
(`fraud_high_risk`). The live stream has a `fraud` topic with
`fraud.flagged` and `fraud.updated` events.

## [0.19.0] - 2026-10-03 - Admin dashboard, step 7: reports, people and the admin team

Sections 9 and 11 of "TroSky Admin: Missing Backend Endpoints". This
completes the 49 endpoints the document asked for, and a test now checks
every one of them is in `/openapi.json`. The optional
`POST /admin/reports/schedules` (emailed reports) is not built: the email
provider has no attachments yet.

Migration `20261003_0019` adds `user_permissions`. The reference seed adds
the `staff` role and the `admins:manage` permission, which the admin role
gets like every other.

### Reports

`GET /admin/reports/{report}` needs `reports:view`. It returns JSON with
`columns` (key, label and kind), `rows`, `totals` and `notes`, or CSV with
`?format=csv`. The dashboard makes PDF and XLSX from either. It takes:

- `from` and `to`, up to a year
- `city` (where trips start), `route` and `fleet`
- `granularity`: `day`, `week` (from Monday) or `month`

The reports:

| Report | One row per | Columns |
|---|---|---|
| `daily_rides` | period | trips completed and cancelled, seats offered and booked, occupancy, passengers boarded |
| `revenue` | period | paid bookings, gross, refunds, net, platform fees, average fare |
| `peak_hours` | hour of the day (Ghana time) | trips departing, seats booked, passengers boarded, bookings made, searches |
| `route_popularity` | route, busiest first | trips, seats offered and booked, occupancy, boardings, fares, cancelled bookings |
| `passenger_growth` | period | new, total, active (made a paid booking) and first-time passengers |
| `cancellation_rates` | period | bookings made, cancelled by passengers, cancelled with their trip, expired unpaid, trips scheduled and cancelled, and both rates |

The time series use the dashboard analytics' own definitions, so the two
always agree. A figure that cannot be tied to a city, route or fleet, such
as sign-ups or searches, is null when one is chosen, with a note saying so.
`/admin/reports/overview` is unchanged.

### Users

- **List.** `GET /admin/users` now browses as well as searches. It filters
  by role, `status` (active, suspended, inactive), `city` (booked a trip
  from there) and sign-up date, sorts, and supports CSV. Each user adds
  their name, roles and last sign-in. `search` works as before.
- **One user.** `GET /admin/users/{id}` returns:
  - profile and roles
  - saved mobile money numbers, masked (`+23324•••0201`)
  - the 3 most-booked routes
  - booking and complaint counts
  - wallet balance, and whether it is frozen
  - active sessions, driver and fleet owner ids, and open fraud flags
- **Devices.** `GET /admin/users/{id}/sessions` lists a user's signed-in
  devices, and `DELETE /admin/users/{id}/sessions/{session_id}` signs one
  out.

Viewing needs `users:manage` or `users:suspend`; devices need
`users:manage`.

### The admin team

Needs `admins:manage`. The team is everyone with the `super_admin`, `admin`
or `staff` role:

- an admin holds every permission
- a member of staff holds only the permissions granted to them, which
  count wherever permissions are checked

The endpoints:

- `GET /admin/admins` lists the team with each member's role, permissions
  (and which were granted directly), status and last sign-in.
- `POST /admin/admins` invites `{full_name, phone_number, email, role,
  permissions}`. An existing account with that number or email joins the
  team as it is. Otherwise a new account is created and sent a code to set
  its password, the same code as "forgot password", so give an email while
  codes go by email.
- `PATCH /admin/admins/{id}` changes a member's role or permissions.
  `active: false` takes them off the team: their team roles and permissions
  go, and they are signed out everywhere.

No one can raise anyone above themselves:

- no changing your own access
- no changing someone with a role above yours
- no giving a role above your own
- no granting a permission you do not hold

`GET /admin/me/sessions` and `DELETE /admin/me/sessions/{session_id}` let
any team member see and end their own sessions.

### Approvals

- `POST /admin/drivers/{id}/request-info` and
  `POST /admin/vehicles/{id}/request-info` take
  `{document_types, note}`. They ask for documents again instead of
  rejecting the application:
  - those documents are marked rejected with the note, and the app already
    lets them be uploaded again
  - the request goes in the status history, which restarts the
    approval-waiting clock
  - the driver or fleet owner is notified
- `GET /admin/documents/{id}` returns a driver's or vehicle's document with
  a link valid for five minutes. A driver's document needs
  `drivers:approve`, and a vehicle's needs `vehicles:approve`.

### Tests

API tests now share one application per run instead of building it for
each test. Building it registers every route, now about 230, so this makes
an API test about three times faster.

## [0.19.1] - 2026-10-03 - Verification codes arrive faster

A new account's code used to reach the mail server about 4 seconds after
the request arrived, before Gmail had even delivered it. It now takes about
1.4 seconds, so the code is usually in the inbox 3 to 5 seconds after the
person taps Register. Two changes:

- **The mail server connection is kept open.** Opening one (connect,
  STARTTLS, login) took 1.7 s to Gmail from Accra, and every message paid
  for it. Logged-in connections are now reused, and sending on one takes
  about 0.5 s:
  - the app opens one at start-up
  - it checks idle ones with NOOP every `EMAIL_SMTP_KEEPALIVE_SECONDS`
    (default 40; 0 turns this off)
  - a connection the server has closed is replaced on the spot, and the
    message is sent once more
- **The code goes out earlier in registration.** Twelve database round
  trips, at about 0.14 s each to the hosted database, used to come before
  the send; now there are about four:
  - the phone and email checks are one query
  - the account is inserted without a savepoint
  - the role and notification preferences are set after the send
  - every code (registration, login, password reset) starts on its way
    before it is stored

  A test fails if the code is pushed back behind more database work.

## [0.20.0] - 2026-10-03 - Drivers accept trips and bookings; seats free up when passengers get off

Database migration `20261003_0020`. Run `alembic upgrade head` before
starting this version.

### Trips

- An assigned driver now accepts or declines the trip:
  `POST /driver-trips/{trip_id}/accept` and `/decline` (with a reason).
  Declining takes them off the trip, which then needs another driver.
- Starting the trip, or accepting a booking on it, also counts as accepting
  the trip. A trip already on the road cannot be declined.
- The driver is notified when a trip is assigned to them. Trip lists
  (`/drivers/me/trips`, `/admin/trips`) show the answer as
  `driver_response`.
- Trips assigned before this version count as accepted.

### Bookings

- A new booking now waits for the trip's driver, or an admin, to accept it
  (`awaiting_acceptance`). The seats are held, but the passenger cannot pay
  yet. `expires_at` is the deadline for an answer.
- Once accepted, the booking is `pending`. The passenger is told to pay
  within `SEAT_RESERVATION_HOLD_SECONDS`, as before.
- Drivers see their waiting bookings at `GET /driver-trips/booking-requests`
  and answer them at
  `POST /driver-trips/{trip_id}/bookings/{booking_id}/accept` or `/decline`.
- If the driver declines, or does not answer within
  `BOOKING_ACCEPT_TIMEOUT_SECONDS` (default 120), the booking moves to
  another vehicle. That vehicle must:
  - go from the same pickup to the same destination
  - have a driver and enough free seats
  - not have passed the pickup yet
  - leave within `BOOKING_MOVE_WINDOW_MINUTES` (default 60)
- A moved booking keeps its passengers and its price, gets seats on the new
  vehicle, and waits for that driver. The passenger is told each time.
- A booking moves at most `BOOKING_MAX_MOVES` times (default 3). With no
  other vehicle, or after the last move, it ends uncharged and the passenger
  is told to search again.
- A worker job checks for unanswered bookings every 15 seconds.
- A passenger can cancel a booking that is waiting for an answer at any
  time; no admin review is needed.
- `BOOKING_ACCEPTANCE_REQUIRED=false` turns all of this off: bookings go
  straight to payment, as before.

### Getting off

- A passenger's seat is now free for the rest of the route once they get
  off. Before, it stayed taken until the end of the trip.
- A passenger is off when:
  - the driver marks them off at
    `POST /driver-trips/{trip_id}/passengers/{booking_passenger_id}/alight`,
    with an optional `stop_id` (otherwise the stop nearest the vehicle)
  - or the vehicle's GPS reaches the stop they booked to
- The passenger list shows `booking_passenger_id` and `alighted_at` for
  each passenger.
- When everyone on a booking is off and it is paid for, the booking is
  completed there and then. The driver's share of the fare is credited at
  that point, not again at the end of the trip.
- The passenger gets a notification offering vehicles leaving from where
  they got off. The same happens at the end of a trip.
  `GET /bookings/{booking_id}/onward-trips` lists those vehicles: ones
  leaving within `ONWARD_TRIPS_WINDOW_MINUTES` (default 120) that have not
  passed the stop and have a seat free.
- A passenger who gets off early gets no money back for the part they did
  not ride: the fare is fixed at booking.

### Operations team

New admin endpoints:

- `GET /admin/booking-requests`: every booking waiting for an answer.
- `POST /admin/bookings/{id}/accept` and `/decline`: answer a booking for
  the driver. Declining has `move_to_another_trip` (default true); set it
  to false to end the booking. An admin can also decline a booking that was
  accepted but not yet paid for.
- `POST /admin/bookings/{id}/move`: put an unpaid booking on a trip of the
  admin's choice.
- `POST /admin/trips/{id}/accept-for-driver` and `/decline-for-driver`:
  answer a trip for the driver, who is notified.
- `POST /admin/trips/{trip_id}/passengers/{booking_passenger_id}/alight`:
  mark a passenger off for the driver.
- `GET /admin/driver-actions`: a log of everything drivers did, newest
  first, also as CSV. It covers trips and bookings accepted or declined,
  trips started, paused, resumed and ended, tickets scanned, and passengers
  marked off. `acted_as` says whether it was the driver, an admin acting
  for them, or the system.

Viewing needs `trips:manage` or `trips:monitor_live`; acting needs
`trips:manage`. These events are announced for the live admin stream:
`booking.awaiting_acceptance`, `booking.accepted`, `booking.moved`,
`booking.not_accepted`, `trip.accepted`, `trip.declined` and
`passenger.alighted` (the stream delivers them from 0.20.2).

### Tests

`.env.test` turns acceptance off, so existing tests still book straight to
payment. The new tests turn it on:

- `tests/integration/test_booking_acceptance.py`: 26 tests
- `tests/api/test_booking_acceptance_api.py`: 8 tests


## [0.20.1] - 2026-10-04 - The dashboard can ask what an admin may do

- `GET /admin/me` returns the signed-in admin's role (`super_admin`,
  `admin` or `staff`) and every permission they hold, so the admin
  dashboard shows only the screens and actions open to them. A super admin
  holds every permission; staff hold only what was granted to them. Anyone
  else gets 403.
- The access token still carries roles only.

## [0.20.2] - 2026-10-04 - Timetables can be listed; the stream carries drivers' answers

- `GET /admin/routes/{route_id}/schedules` lists a route's active timetable
  entries, earliest departure first. Needs `routes:manage` or
  `trips:manage`. Before this, entries could be added but never read back,
  so a trip could only be created from a timetable entry whose id was
  already known.
- The admin stream (`GET /admin/stream`) has a new topic, `dispatch`, for
  `trips:manage` or `trips:monitor_live`. It carries the `booking.*`,
  `trip.*` and `passenger.*` events added in 0.20.0, which the stream used
  to drop: the 0.20.0 notes wrongly said it delivered them.

## [0.21.0] - 2026-10-08 - Passengers sign up from Ghana

- Registering as a passenger now needs the phone's location
  (`latitude`/`longitude` on `POST /auth/register`), and it must be in
  Ghana. Without one the answer is 422 `LOCATION_REQUIRED`; from elsewhere,
  422 `LOCATION_NOT_SERVED`. The location is only checked, never stored.
  New setting `PASSENGER_SIGNUP_COUNTRIES` (default `GH`; empty switches
  the check off). The outline of Ghana is approximate: about 15 km of
  margin keeps border towns such as Aflao and Paga in, and lets places
  just across the border (Lomé) in too.
- Unchanged: a passenger still verifies their email with the code sent to
  it before signing in or booking (`REQUIRE_VERIFIED_ACCOUNT`), and needs no
  admin approval.
- **The passenger app must send its location when it registers:** until
  it does, passenger sign-up is refused (or set
  `PASSENGER_SIGNUP_COUNTRIES` empty until the app is updated).

## [0.22.0] - 2026-10-08 - Trips change status on their own

A trip's status now follows what its vehicle is doing, and the clock,
without the driver pressing anything (`app/services/trip_autopilot.py`):

- **Boarding** when the first ticket is scanned, or when the vehicle is at
  the first stop in the 30 minutes before departure.
- **In progress** when, having been at the first stop, it leaves it along the
  route (300 m). Driving off sideways (to fill up, say) does not count. A
  vehicle first heard from at a later stop after the departure time is
  under way too.
- **Paused** after 20 minutes standing still (within 50 m) away from any
  stop; waiting at a stop is not a pause. **In progress** again as soon as it
  moves further than that, whoever paused it.
- **Completed** after 3 minutes at the last stop, or when its GPS goes quiet
  there for 10. Passengers still aboard arrive and the driver is paid, as
  when the driver ends the trip.
- **Not started**: 15 minutes after the departure time, a `trip_not_started`
  alert (severity high, `entity_type: trip`) for admins with
  `trips:manage` or `trips:monitor_live`; its `details.cancels_at` says when
  it will be cancelled. After 2 hours a trip still **scheduled**, whose
  vehicle has not been heard from for 30 minutes, is **cancelled**:
  passengers are told, paid ones get a refund request for an admin to
  approve, and the driver is told. A boarding trip is never cancelled on its
  own (its vehicle is there): the alert stays until the team acts. Trips
  that should have left more than a day ago are left alone.

Every automatic change goes through the same code as the driver's buttons,
is recorded in the trip's history with `changed_by: null` and its reason,
and in driver actions as `acted_as: system`. The driver can still start,
pause, resume and end trips by hand, and admins cancel as before.

- `POST /driver-trips/{id}/location` now also takes positions while a trip
  is paused, and from 30 minutes before departure while it is scheduled or
  boarding (only positions on the road are kept in the trip's recorded
  path). Its response has `trip_status`. A position the system cannot act
  on (the driver has another trip still going, say) is still accepted.
  Positions with no time zone are taken as UTC.
- Passengers are no longer marked as arrived by positions sent before the
  trip is on the road (a vehicle passing their stop on its way to the
  first).
- New admin stream event `trip.status_changed` (`trip_id`, `previous`,
  `status`, `by`: driver, admin or system, `reason`) for every status
  change, by anyone.
- New worker task `app.workers.tasks.trips.apply_trip_timeouts`, every
  minute.
- Migration `20261008_0021`: trip event type `boarding_started`.
- Settings (all in `.env.example`): `TRIP_AUTO_STATUS_ENABLED` (default on;
  off restores the old behaviour), `TRIP_AUTO_WINDOW_MINUTES`,
  `TRIP_AT_STOP_METERS`, `TRIP_LEFT_STOP_METERS`, `TRIP_AUTO_PAUSE_MINUTES`,
  `TRIP_STILL_METERS`, `TRIP_ARRIVAL_MINUTES`,
  `TRIP_ARRIVAL_SILENCE_MINUTES`, `TRIP_NOT_STARTED_ALERT_MINUTES`,
  `TRIP_NOT_STARTED_CANCEL_MINUTES` (0: never cancel).
- **The driver app should send positions from 30 minutes before departure
  until the trip ends, paused included, and keep sending while standing
  still.** Until it does, boarding still comes from ticket scans, and the
  driver starts the trip by hand; everything after that follows on its own.

## [0.22.1] - 2026-10-11 - Fixes for the staging server

- **Signing in no longer holds up the server.** Hashing and checking a
  password (Argon2id, 64 MiB) ran in the event loop: on Render's free CPU a
  sign-in took 17 s, during which no other request, health checks included,
  was answered. It now runs in a thread pool of its own, at most
  `PASSWORD_HASH_CONCURRENCY` (new setting, default 2) at a time per
  process, so a burst of sign-ins waits its turn rather than running a
  512 MB server out of memory. The hash itself is unchanged: existing
  passwords keep working.
- **Background tasks no longer fail every other run.** Each Celery task ran
  in an event loop of its own, closed when it finished, while the database
  and Redis connection pools are shared by the whole worker process: the
  next task took a connection from the closed loop and failed ("attached to
  a different loop", `'NoneType' object has no attribute 'send'`). Seat-hold
  sweeps, moving unanswered bookings and the trip-status check were all hit.
  Tasks now share one loop per worker process (`app/workers/loop.py`), and
  the pools are closed on it when the process stops. Running Celery with
  `--max-tasks-per-child 1` to work around it is no longer needed.
- **`scripts.seed_demo_data` works with booking acceptance on.** Since
  0.20.0 it confirmed the demo passenger's upcoming booking while it was
  still waiting for the driver, and stopped there. The driver now accepts it
  first, as in the app. Seeding no longer needs
  `BOOKING_ACCEPTANCE_REQUIRED=false`.
