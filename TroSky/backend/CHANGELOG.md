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
