# Contributing to TroSky Backend

## Workflow

1. Branch from `main` (never commit directly to `main`).
2. Make focused, reviewable commits.
3. Run the full local gate before opening a PR:
   ```bash
   make format
   make lint
   make typecheck
   make test-cov
   ```
4. Open a PR against `main`. CI must pass (lint, typecheck, tests ≥ 80%
   coverage, migration validation, dependency scan, container build/scan)
   before merge.
5. Production deploys require a manual approval gate on the `production`
   GitHub Environment — no direct/automatic production deploys are
   supported by design.

## Code organization rules

- **API routes** (`app/api/`) handle HTTP concerns only: request parsing,
  response shaping, calling into `services`. No business logic, no direct
  database queries.
- **Services** (`app/services/`) contain business use cases and orchestrate
  `repositories` + `providers` + `events`. All financial/booking mutations
  happen inside an explicit transaction boundary here.
- **Repositories** (`app/repositories/`) contain database access only —
  no business rules, no HTTP concerns.
- **Models** (`app/models/`) define persistence (SQLAlchemy ORM) — no
  business logic beyond simple derived properties.
- **Schemas** (`app/schemas/`) define the public API contract (Pydantic).
  Never pass ORM models directly to a route's response — map explicitly to
  a schema (this also prevents mass-assignment and accidental data
  exposure).
- **Providers** (`app/providers/`) isolate every third-party integration
  behind an interface with a sandbox implementation for local dev/tests and
  a production adapter for real credentials.

## Style

- Python 3.12, fully typed (`mypy --strict`), formatted and linted with
  Ruff (`make format`, `make lint`).
- Async I/O throughout the request path — no blocking calls in an `async
  def` route or service method.
- No bare `except Exception: pass`. Catch specific exceptions, log with
  context via `structlog`, and translate to an `AppError` subclass at the
  service/API boundary — never let a raw internal exception reach a client
  response.
- Money is always `Decimal` or integer minor units (GHS pesewas) — never
  `float`.
- All timestamps are stored and processed in UTC; convert to
  `Africa/Accra` only when presenting to a human.

## Tests

- New business logic requires unit tests (`tests/unit/`) and, where it
  touches the database or an external boundary, integration/API tests
  (`tests/integration/`, `tests/api/`).
- Never call a real external provider (payment gateway, SMS, email, push,
  maps) from a test — use the provider's sandbox implementation.
- Security-sensitive changes (auth, permissions, payments, ticket
  validation) require a corresponding test in `tests/security/`.

## Commit messages

Use a short imperative summary line, optionally followed by a body
explaining *why*. Reference the relevant implementation phase where useful,
e.g. `Phase 5: add row-locked seat hold creation`.

## Secrets

Never commit real credentials. `.env` is gitignored; `.env.example` and
`.env.test` contain placeholder values only. `gitleaks` runs as a
pre-commit hook and in CI to catch accidental secret commits.
