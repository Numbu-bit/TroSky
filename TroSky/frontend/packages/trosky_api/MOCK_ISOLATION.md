# TroSky — mock code and seed credential isolation

H6 of the 21 Nov 2026 pre-launch audit.

## Threat model

A release build heading for the Play Store or App Store must not
serve the mock backend's seed data to real users. The specific
concerns from the audit:

- `MockBackend` and its seed fixtures (seeded passenger, seeded
  driver, synthetic password `TroSky2026`) live in the published
  `trosky_api` package. They are reachable from the same
  repository switch that selects the live repositories.
- If a release build ever ran with `API_MODE=mock`, users would
  sign in against fake accounts with no real session on the
  server.
- A static scan of the repo for the string `TroSky2026` must be
  able to classify it clearly as a synthetic fixture, not a real
  secret that leaked.

## What H6 enforces

### 1. Compile- and parse-time: the DEPLOY_ENV gate (from C4)

`Env.parse` already refuses `DEPLOY_ENV=prod` with `API_MODE=mock`
or a mock-looking `API_BASE_URL`. That is the primary guard. H6
does not weaken it or duplicate it.

### 2. Runtime belt: the `mockBackend` provider

`packages/trosky_auth/lib/src/providers.dart::mockBackend`
throws a `StateError` immediately if read when
`env.deployEnv == DeployEnv.prod`. A future wiring bug that lets a
prod build reach the provider aborts at the point of damage
instead of silently serving seed fixtures.

### 3. Explicit synthetic-fixture classification

Every seed constant in `mock_backend.dart` carries a comment
saying it is a **synthetic fixture**, not a credential for any
real account. CI greps for the shape of the comment; a future PR
that adds a secret that forgets the comment fails.

### 4. CI reachability check

The frontend workflow's `mock-isolation-check` job asserts:

- `_sensitiveHeaders` of `MockBackend.seedPassword` is referenced
  only from mock files or tests, never from production repository
  switch branches or UI code.
- The mock provider carries the `DeployEnv.prod` throw.
- `Env.parse` still rejects `DEPLOY_ENV=prod + API_MODE=mock`
  (the C4 guard didn't regress).

## Deliberate non-changes

- **No conditional imports.** `conditional-import` would let
  release builds exclude `MockBackend` entirely from the AOT
  snapshot, but Dart's `conditional-import` directive dispatches on
  platform (`dart.io` vs `dart.html`), not on dart-defines. A
  separate entrypoint pair (`main_live.dart` + `main_mock.dart`)
  could, but doing that adds two build targets, two CI matrices,
  and a new source of drift; the benefit over the runtime throw +
  C4 parse guard is small.
- **No `kDebugMode`-only mock registration.** Staging builds still
  need mock mode for owner UX walk-throughs without a running
  server; gating only on `kDebugMode` would break that.

## Is `TroSky2026` a real password?

**No.** It's a synthetic fixture that exists so the in-memory
`MockBackend` can accept the seeded passenger's sign-in. The real
production backend never provisions an account with this
password; this was confirmed by inspecting `../backend/scripts/`
during the H6 audit (it seeds accounts via its own secret-driven
procedure).

If a real TroSky user ever set their own password to `TroSky2026`
on production, that is their choice and the backend will accept
it; H6 makes no claim about that case. The fixture string here
has no privileged meaning to the real backend.

## Handoff for the backend developer

An item has been filed under **B / H6** in
`docs/backend-requests.md` asking the backend owner to confirm:

- No production migration or seed script creates an account with
  password `TroSky2026`, phone `+233241234567`, or phone
  `+233201234567`.
- If any of the three were used during development on the
  production cluster, the corresponding account is rotated or
  deleted.

That is explicitly an owner/backend-developer task, not a
frontend change.
