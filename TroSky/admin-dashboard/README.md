# TroSky Admin Dashboard

The web dashboard TroSky's operations team uses to run the platform: watch buses live, handle SOS
alerts, run trips, the route network and approvals, settle bookings, refunds and payouts, support
passengers, and read the business's figures. It is a single-page React app over the TroSky
backend's admin API, and it can also run fully offline on realistic demo data.

## Contents

- [Quick start](#quick-start)
- [Scripts](#scripts)
- [Environment variables](#environment-variables)
- [Architecture](#architecture)
- [Permissions and screens](#permissions-and-screens)
- [Feature switches](#feature-switches)
- [Demo mode](#demo-mode)
- [Testing](#testing)
- [Deployment](#deployment)
- [Continuous integration](#continuous-integration)
- [Assumptions](#assumptions)
- [SRS traceability](#srs-traceability)

## Quick start

Requires Node.js 20.19+ (22 LTS recommended).

```bash
npm install

# Against a running backend (default http://127.0.0.1:8000, proxied as /api)
npm run dev                      # http://localhost:5173

# Fully offline, on demo data
npm run dev:demo
```

Sign in with an account on the admin team (super admin, admin or staff). In demo mode, the sign-in
page lists the demo accounts.

To point the dev server at another API, copy `.env.example` to `.env.local` and change
`VITE_API_PROXY_TARGET`.

## Scripts

| Script                                     | What it does                                                            |
| ------------------------------------------ | ----------------------------------------------------------------------- |
| `npm run dev` / `dev:demo`                 | Dev server, against the API / on demo data                              |
| `npm run build`                            | Typecheck, then a production build in `dist/` (refuses demo mode)       |
| `npm run build:demo`                       | A demo build (demo data in the browser), for a demo deployment          |
| `npm run check:build`                      | Checks `dist/`: no demo data, initial JavaScript ≤ 250 KB gzipped       |
| `npm run preview`                          | Serves `dist/` locally                                                  |
| `npm run lint` / `format` / `format:check` | ESLint (zero warnings) / Prettier                                       |
| `npm run typecheck`                        | TypeScript, strict                                                      |
| `npm test` / `test:watch` / `coverage`     | Unit and screen tests (Vitest); `coverage` fails below 80 % of lines    |
| `npm run e2e`                              | Playwright end-to-end and accessibility tests, on a demo build          |
| `npm run api:pull` / `api:types`           | Fetch the backend's OpenAPI document / regenerate `src/api/schema.d.ts` |

## Environment variables

Vite reads these at build time (they are baked into the bundle). Examples per environment:
`.env.example` (development), `.env.staging.example`, `.env.production.example`, and `.env.demo`
for demo builds.

| Variable                    | Default                 | Meaning                                                                                                                                                        |
| --------------------------- | ----------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `VITE_API_BASE_URL`         | `/api/v1`               | The API's base URL. Same-origin `/api/v1` in development (proxied) or behind a reverse proxy; otherwise the full URL, e.g. `https://api.trosky.africa/api/v1`. |
| `VITE_API_PROXY_TARGET`     | `http://127.0.0.1:8000` | Development only: where the dev server proxies `/api`.                                                                                                         |
| `VITE_DEMO_MODE`            | `false`                 | `true` answers every request in the browser with demo data. Only demo builds may turn it on.                                                                   |
| `VITE_ENABLED_MODULES`      | every module            | The feature-switched modules to show (comma-separated keys, see [Feature switches](#feature-switches)).                                                        |
| `VITE_LIVE_REFRESH_SECONDS` | `8`                     | How often live data refreshes when polling, clamped to 5–10 s (SRS FR-006).                                                                                    |

At run time, the Docker image takes one variable:

| Variable     | Default | Meaning                                                                                                                                  |
| ------------ | ------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| `API_ORIGIN` | empty   | The API's origin when it isn't this site's own (e.g. `https://api.trosky.africa`), added to the Content-Security-Policy's `connect-src`. |

## Architecture

**Stack:** React 19, React Router 7, TypeScript (strict), Vite 8, Tailwind CSS 4 with shadcn/ui
(Radix), TanStack Query and Table, React Hook Form with Zod, Recharts, MapLibre GL (via
react-map-gl) on CARTO basemaps, openapi-typescript with openapi-fetch, Mock Service Worker for
demo mode, Vitest with Testing Library, and Playwright with axe-core.

```
src/
  app/          router, providers, layout (sidebar, top bar, SOS banner), auth and permission
                guards, live updates
  api/          generated OpenAPI types, the typed client, errors, tokens; demo/ holds the demo
                API (handlers, seeded data, accounts)
  features/     one folder per module: its pages, components and query hooks
  components/   ui (shadcn), data table, charts, map, confirmations, pickers, feedback states
  lib/          formatters, permissions, feature switches, URL state, storage, xlsx
e2e/            Playwright flows and the accessibility sweep
nginx/          the production web server's config
scripts/        OpenAPI download, build check
```

**API.** Types come from the backend's OpenAPI document (`openapi/openapi.json` →
`src/api/schema.d.ts`), so every request and response is typed, and a change on the backend shows up
as a compile error here. `src/api/client.ts` adds the access token, renews it once on a 401, and
turns the API's error envelope into `ApiError` (field errors map onto forms). Money arrives as decimal
strings and is only ever formatted, never calculated in floating point.

**State.** Server data lives in TanStack Query. View state worth sharing (filters, tabs, the page,
an open record) lives in the URL, as ids and codes only, never phone numbers, emails or names.
What an admin types into a search box stays in the component.

**Sessions.** The backend returns tokens in the response body (no httpOnly cookie), so the access
token stays in memory and the refresh token in `sessionStorage`. A reload keeps the admin signed
in, closing the tab ends the session, and nothing goes to `localStorage` except per-browser
preferences (theme, data saver, SOS sound).

**Live data.** The admin's event stream (`GET /admin/stream`, server-sent events) pushes SOS,
complaint, approval, fraud and dispatch events, and each event refreshes only what it affects. While
the stream is unreachable, live data polls every `VITE_LIVE_REFRESH_SECONDS`, backing off and
reconnecting, and the top bar says which mode it is in. Polling pauses in background tabs, and the
data saver mode slows it to 30 s without map animation.

**Permissions.** After sign-in, `GET /admin/me` returns the admin's role and effective permissions.
Screens, menu items, buttons and table actions appear only when the admin holds the permission
(hidden, not disabled), and a 403 is still handled. Destructive and money-moving actions go through a
confirmation that can't be submitted twice, with a reason wherever the API accepts one.

**Resilience.** Every lazy route has a Suspense fallback, and every widget has its own error
boundary with a retry, so one failing call never blanks a page. Lists have loading skeletons, empty
states, error states and server-side pagination.

**Performance.** Each screen is its own chunk, and the map and chart libraries load only with the
screens that use them. The JavaScript loaded up front is about 193 KB gzipped (budget 250 KB,
checked in CI by `npm run check:build`).

## Permissions and screens

A screen opens for an admin holding any one of its permissions (super admins hold all of them).
Screens marked with a module also need that module switched on.

| Screen                              | Path                  | Opens with any of                                                                                      | Module               |
| ----------------------------------- | --------------------- | ------------------------------------------------------------------------------------------------------ | -------------------- |
| Overview                            | `/overview`           | any admin                                                                                              |                      |
| Live map                            | `/live`               | `trips:monitor_live`, `trips:manage`                                                                   |                      |
| Alerts                              | `/alerts`             | `sos:review`, `complaints:manage`, `drivers:approve`, `vehicles:approve`, `fraud:view`, `fraud:manage` | `alerts`             |
| Safety (SOS, incidents)             | `/safety`             | `sos:review`, `incidents:manage`                                                                       |                      |
| Trips                               | `/trips`              | `trips:manage`, `trips:monitor_live`                                                                   |                      |
| Dispatch                            | `/dispatch`           | `trips:manage`, `trips:monitor_live`                                                                   | `dispatch`           |
| Network (stops, routes, timetables) | `/network`            | `routes:manage`                                                                                        |                      |
| Approvals                           | `/approvals`          | `drivers:approve`, `vehicles:approve`                                                                  |                      |
| Fleet                               | `/fleet`              | `vehicles:approve`, `drivers:approve`, `trips:monitor_live`, `reports:view`                            | `fleet`              |
| Bookings & refunds                  | `/bookings`           | `bookings:view_any`, `refunds:approve`                                                                 |                      |
| Payouts                             | `/payouts`            | `withdrawals:review`                                                                                   |                      |
| Revenue                             | `/revenue`            | `payments:review`, `refunds:approve`, `reports:view`                                                   | `revenue`            |
| Wallets                             | `/wallets`            | `wallet:adjust`                                                                                        | `wallets`            |
| Complaints                          | `/complaints`         | `complaints:manage`                                                                                    |                      |
| Accounts                            | `/accounts`           | `users:manage`, `users:suspend`                                                                        |                      |
| Driver ratings                      | `/driver-ratings`     | `drivers:approve`                                                                                      |                      |
| Driver performance                  | `/driver-performance` | `reports:view`, `drivers:approve`                                                                      | `driver-performance` |
| User growth                         | `/user-growth`        | `reports:view`                                                                                         | `user-growth`        |
| Demand map                          | `/demand`             | `reports:view`                                                                                         | `demand`             |
| Reports                             | `/reports`            | `reports:view`                                                                                         | `reports`            |
| Fraud & risk                        | `/fraud`              | `fraud:view`, `fraud:manage`                                                                           | `fraud`              |
| Admin team                          | `/team`               | `admins:manage`                                                                                        | `team`               |
| Audit log                           | `/audit-log`          | `audit_logs:view`                                                                                      | `audit-log`          |
| Settings                            | `/settings`           | `system_settings:manage`, `feature_flags:manage`                                                       | `settings`           |
| My sessions                         | `/me/sessions`        | any admin                                                                                              |                      |

Inside a screen, actions need their own permissions. For example, refunds are only for
`refunds:approve`, suspending only for `users:suspend`, the fraud rules tab only for `fraud:manage`,
and a fleet's page only for `vehicles:approve` or `reports:view`. The source of truth is
`src/app/screens.ts` and each screen's `can(...)` checks.

## Feature switches

The spec's planned modules (section 7) sit behind `VITE_ENABLED_MODULES`. All of them have backend
endpoints today, so the examples switch every one on. Leave a key out to hide that module. Demo mode
switches everything on.

| Key                   | What it adds                                                                      |
| --------------------- | --------------------------------------------------------------------------------- |
| `dispatch`            | Dispatch: drivers' answers to trips and bookings, and answering for them          |
| `driver-performance`  | Driver performance leaderboard, at-risk drivers, per-driver page                  |
| `fleet`               | Fleet: every vehicle, driver and fleet, with live status and expiring documents   |
| `revenue`             | Revenue: money in and out, by method, hour, route and fleet; every payment        |
| `user-growth`         | User growth: sign-ups, activity, the booking funnel, retention cohorts            |
| `complaints-insights` | On Complaints: SLA figures, assignment and internal notes                         |
| `fraud`               | Fraud & risk: flags, review, actions on accounts, rules                           |
| `demand`              | Demand map: heat map, day and hour patterns, supply gaps                          |
| `reports`             | Reports: the SRS §17 reports with CSV, Excel and PDF                              |
| `audit-log`           | Audit log, with values before and after                                           |
| `settings`            | Settings and feature flags                                                        |
| `wallets`             | Wallets: balances, transactions, adjustments                                      |
| `alerts`              | The Alerts page and the global search (otherwise the search covers accounts only) |
| `team`                | Admin team: add people, change their access, remove them                          |

## Demo mode

`npm run dev:demo` (or a `build:demo` deployment) runs every screen offline. Mock Service Worker
answers each request in the browser from a seeded platform shaped exactly like the real API: the same
generated types, and the backend's rules and refusals (page sizes, validation, state checks).

- **The data:** 90 days of Accra-heavy operations, deterministic from a fixed seed, with dates
  relative to today. It covers routes such as Circle ⇄ Madina and Kaneshie ⇄ Kasoa, Ghana-format
  plates, GH₵ fares with a MoMo-heavy payment mix, fictitious `+233 24 000 xxxx` numbers and
  `@trosky.test` emails.
- **Accounts** (password `TroSky-demo-2026`, also listed on the sign-in page):
  - Abena Owusu (super admin)
  - Kwame Mensah (admin)
  - Esi Quaye (staff: bookings, complaints, reports, SOS)
- **Live behaviour:** buses move along their routes. The **DEMO DATA** menu in the top bar raises an
  SOS, files a complaint, adds a driver or vehicle application, makes every request fail (to see the
  error states), or starts the demo again.
- **Behaviour:** responses take 200–600 ms. Everything happens in the browser tab: a reload starts
  again from the seed.
- **Safety:** a production or staging build refuses demo mode, the demo code is dropped from such
  builds as dead code, `npm run check:build` fails if any demo data reaches `dist/`, and the
  **DEMO DATA** badge is on every demo page.

## Testing

- **Unit and screen tests** (`npm test`, `npm run coverage`): Vitest and Testing Library render
  whole screens on the demo API in Node, and drive them the way an admin would (roles, labels,
  keyboard). There are about 200 tests, covering at least 80 % of lines (enforced). They live next to
  what they test (`*.test.ts[x]`).
- **End-to-end** (`npm run e2e`): Playwright builds the demo, serves it and runs the spec's flows in
  Chromium:
  - sign in and out
  - approve and reject a driver
  - create a trip from the timetable and assign an approved driver and vehicle
  - refuse to retire a route in use
  - cancel a trip and work through its refunds
  - approve a refund
  - approve a payout, then mark it failed
  - acknowledge and resolve an SOS
  - resolve a complaint
  - suspend and reactivate an account
  - a missing permission hides a module
- **Accessibility:** `e2e/a11y.spec.ts` runs axe (WCAG 2.2 A and AA) on the sign-in page, every screen
  and tab, record pages, drawers and dialogs, and six screens in dark mode, and fails on any serious or
  critical violation. Run `npx playwright install chromium` once before the first run.

## Deployment

### On Vercel (staging, against the Render backend)

`vercel.json` holds the build, the SPA fallback to `index.html`, long caching for hashed assets, and
the same security headers as the nginx image below. Make two Vercel projects from this repository,
both with **Root Directory** `TroSky/admin-dashboard`:

| Project                             | Build command                        | Environment variables                                                                                                  |
| ----------------------------------- | ------------------------------------ | ---------------------------------------------------------------------------------------------------------------------- |
| `trosky-admin`, the live dashboard  | `npm run build` (from `vercel.json`) | `VITE_API_BASE_URL=https://trosky-api.onrender.com/api/v1`, and `VITE_ENABLED_MODULES` as in `.env.production.example` |
| `trosky-admin-demo`, demo data only | override it: `npm run build:demo`    | none (`.env.demo` has them)                                                                                            |

The live dashboard calls the API on Render directly, so the backend must allow its address:
`CORS_ALLOWED_ORIGINS` in the repository's `render.yaml` lists `https://trosky-admin.vercel.app`. If
Vercel gives the project another address, or it gets a custom domain, change it there
(comma-separated for several) and let Render redeploy. The API's address is also in the
`connect-src` of the `Content-Security-Policy` in `vercel.json`.

Sign in with an administrator account of the Render backend (see its `docs/deploy-render.md`, "The
administrator account"). Render's free plan sleeps after 15 minutes without requests: the first
sign-in then waits up to a minute while it starts, and the sign-in page says so.

The demo project never talks to a server: `build:demo` is the only build allowed to carry demo mode
(a production build with `VITE_DEMO_MODE=true` is refused).

### With Docker

The `Dockerfile` builds the app with Node and serves it from nginx on Alpine (the unprivileged image:
non-root, port 8080). The API's address and the modules are build arguments, so build one image per
environment:

```bash
docker build -t trosky-admin-dashboard \
  --build-arg VITE_API_BASE_URL=https://api.trosky.africa/api/v1 .
docker run -p 8080:8080 -e API_ORIGIN=https://api.trosky.africa trosky-admin-dashboard
```

When the API is served under `/api` on the dashboard's own domain (a reverse proxy in front of both),
keep the default `/api/v1` and leave `API_ORIGIN` empty.

`nginx/default.conf.template` provides:

- SPA fallback to `index.html`, which is never cached so a release takes effect on the next load
- hashed assets cached for a year, gzip, a `/healthz` endpoint, and source maps not served
- the hosting headers from spec section 11:
  - `Content-Security-Policy`:
    - scripts only from the site (no inline scripts)
    - inline styles (Radix positioning, map markers, toasts)
    - images also from `data:`/`https:`
    - connections to the site, `API_ORIGIN` and CARTO's basemaps
    - map workers from `blob:`
    - no framing
  - `Strict-Transport-Security`, `X-Frame-Options: DENY`, `X-Content-Type-Options: nosniff`,
    `Referrer-Policy`, `Permissions-Policy` and `Cross-Origin-Opener-Policy`

## Continuous integration

`.github/workflows/admin-dashboard.yml`, at the repository root, runs on pushes and pull requests
that touch the dashboard:

1. **Checks:** install, lint, format check, typecheck, then unit tests with coverage (fails below 80 %).
2. **Build:** production build, `check:build` (no demo data, initial JavaScript in budget), and a
   check that a production build with demo mode on is refused.
3. **End-to-end:** Playwright flows and the axe sweep on a demo build. The report is uploaded as an
   artifact.
4. **Docker:** builds the image, then smoke-tests the SPA fallback, `/healthz` and the security
   headers.

## Assumptions

Decisions the spec left open, and how the dashboard works around gaps in the API.

**Design and behaviour**

- Pages sit on the light grey `#F5F5F5` with white cards, the usual dashboard arrangement. The
  brand colours are otherwise as specified.
- Buttons and links use `#007A52`, a slightly deeper emerald than Emerald 700. `#00855A` text is only
  4.3:1 on `#F5F5F5`, short of WCAG AA's 4.5:1; `#007A52` is 4.9:1 there and 5.4:1 on white.
- In dark mode, danger fills behind white text use `#C62828` (5.6:1); danger text keeps a light red.
  Text links are underlined, so they are never told apart by colour alone.
- Times are shown in Africa/Accra (UTC+0 all year). Dates in the URL are Accra calendar days.
- The reports API offers CSV only, so Excel files are built in the browser, and PDF uses the
  browser's print to PDF (the print layout hides the navigation).
- The global search (Ctrl+K) uses `/admin/search` when the `alerts` module is on. Otherwise it finds
  accounts by phone, email or name. A payment it finds opens Revenue with that reference filled in,
  and the period moves to the payment's day when the admin may read the payment.
- Live-map markers close together can overlap. WCAG 2.5.8 allows this because the same buses, with
  full-size targets, are listed beside the map.
- The Docker image uses the unprivileged build of nginx on Alpine (non-root, port 8080) rather than
  the stock `nginx:alpine`.

**API gaps the UI works around**

- The admin bookings list can't filter by trip, so the trip page shows counts and links instead of a
  passenger list. After cancelling a trip, its refunds are found in the refund queue by the
  cancellation's reason.
- Timetable entries can be added but not edited or removed, and a route's stops can't change once
  it is created. The UI offers neither.
- A payout's history is built from its own timestamps and notes (there is no history endpoint).
- Rejecting a refund leaves the booking as it was (refund pending), and a failed refund can't be
  retried from the dashboard. Both are backend behaviour, shown as they are.
- Assigning complaints or fraud flags to someone else needs the team list, which needs
  `admins:manage`. Without it, an admin can take an item or give it back.
- Approved backend additions (asked for while building): `GET /admin/me`,
  `GET /admin/routes/{route_id}/schedules`, and booking, trip and passenger events on the admin
  stream (`dispatch` topic).

## SRS traceability

Requirement → screen → tests. Unit tests are under `src/`; end-to-end tests are under `e2e/`.

| Requirement                                                                        | Screen                      | Tests                                                                                                                         |
| ---------------------------------------------------------------------------------- | --------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| Platform overview figures; alerts list, SOS first (§13, spec 6.1)                  | Overview                    | `features/overview/OverviewPage.test.tsx`, `api/demo/handlers/overview.test.ts`                                               |
| Live map refreshes every 5–10 s, pauses when hidden (FR-006, §15)                  | Live map                    | `features/live-map/LiveMapPage.test.tsx`, `e2e/a11y.spec.ts`                                                                  |
| SOS acknowledge and resolve; banner on every page; escalation log (spec 6.3, A10)  | Safety                      | `features/safety/SafetyPage.test.tsx`, `e2e/safety.spec.ts`                                                                   |
| Incidents resolved with a note (spec 6.3)                                          | Safety                      | `features/safety/SafetyPage.test.tsx`                                                                                         |
| Trips: create, from timetable, assign, cancel then bookings (spec 6.4, rule 3.3.5) | Trips                       | `features/trips/TripsScreen.test.tsx`, `e2e/trips.spec.ts`                                                                    |
| Trip replay (A10)                                                                  | Trip page                   | `features/trips/replay.test.ts`, `features/trips/TripsScreen.test.tsx`                                                        |
| Drivers accept trips and bookings; admins answer for them (product decision)       | Dispatch, Trip page         | `features/dispatch/DispatchPage.test.tsx`, `features/trips/TripsScreen.test.tsx`                                              |
| Stops, routes, timetables; "still in use" refusals (spec 6.5, rule 3.3.2)          | Network                     | `features/network/NetworkScreen.test.tsx`, `e2e/network.spec.ts`                                                              |
| Approvals with documents and checklist (FR-004, spec 6.6, A11)                     | Approvals                   | `features/approvals/ApprovalsScreen.test.tsx`, `e2e/approvals.spec.ts`                                                        |
| Bookings, cancellations and refunds (spec 6.7, rule 3.3.4)                         | Bookings & refunds          | `features/bookings/BookingsScreen.test.tsx`, `e2e/money.spec.ts`                                                              |
| Payouts: approve, sent, failed, reject (spec 6.8)                                  | Payouts                     | `features/payouts/PayoutsPage.test.tsx`, `e2e/money.spec.ts`                                                                  |
| Complaints, SLA, assignment, notes (spec 6.9, A4)                                  | Complaints                  | `features/complaints/ComplaintsScreen.test.tsx`, `e2e/support-desk.spec.ts`                                                   |
| Accounts: find, suspend, reactivate, devices (spec 6.10, A11)                      | Accounts                    | `features/accounts/AccountsScreen.test.tsx`, `e2e/support-desk.spec.ts`                                                       |
| Driver ratings by category (FR-011, spec 6.11)                                     | Driver ratings              | `features/driver-ratings/DriverRatingsPage.test.tsx`                                                                          |
| Driver performance and at-risk drivers (FR-010, A3)                                | Driver performance          | `features/driver-performance/DriverPerformance.test.tsx`                                                                      |
| All vehicles, drivers and fleets; expiring documents (A2)                          | Fleet                       | `features/fleet/FleetScreen.test.tsx`                                                                                         |
| Revenue and transactions (A5)                                                      | Revenue                     | `features/revenue/RevenuePage.test.tsx`                                                                                       |
| User growth, funnel, cohorts (A6)                                                  | User growth                 | `features/user-growth/UserGrowthPage.test.tsx`                                                                                |
| Fraud flags, review, actions, rules (A7)                                           | Fraud & risk                | `features/fraud/FraudScreen.test.tsx`                                                                                         |
| Demand heat map and supply gaps (A8)                                               | Demand map                  | `features/demand/DemandPage.test.tsx`                                                                                         |
| The §17 reports with CSV, XLSX and PDF (A9)                                        | Reports, Driver performance | `features/reports/ReportsPage.test.tsx`, `lib/xlsx.test.ts`                                                                   |
| Audit log with before/after (A1)                                                   | Audit log                   | `features/audit-log/AuditLogScreen.test.tsx`                                                                                  |
| Platform settings incl. seat hold (FR-007) and feature flags (A1)                  | Settings                    | `features/settings/SettingsPage.test.tsx`                                                                                     |
| Wallets and adjustments (A1)                                                       | Wallets                     | `features/wallets/WalletsPage.test.tsx`                                                                                       |
| One alerts feed and global search (A10)                                            | Alerts, top bar             | `features/alerts/AlertsPage.test.tsx`, `app/layout/TopBar.test.tsx`                                                           |
| Admin team and own sessions (A11)                                                  | Admin team, My sessions     | `features/team/TeamPage.test.tsx`, `features/team/MySessionsPage.test.tsx`                                                    |
| Sign-in, sessions, permission-driven UI (spec 11)                                  | All                         | `app/auth/auth.test.tsx`, `app/access.test.ts`, `api/client.test.ts`, `e2e/auth.spec.ts`                                      |
| No personal data in URLs (spec 11)                                                 | Accounts, Wallets, Revenue  | `features/accounts/AccountsScreen.test.tsx`, `features/wallets/WalletsPage.test.tsx`, `features/revenue/RevenuePage.test.tsx` |
| WCAG 2.2 AA (spec 9)                                                               | Every screen                | `e2e/a11y.spec.ts`                                                                                                            |
| Initial JavaScript ≤ 250 KB, code-split (spec 10, §7)                              | All                         | `scripts/check-build.mjs` (CI)                                                                                                |
| Demo mode off by default, labelled, never in production (spec 8)                   | All                         | `app/access.test.ts`, `api/demo/db/build.test.ts`, `api/demo/http.test.ts`, CI build job                                      |
| Tests ≥ 80 %, CI (§20), Docker with hosting headers (§19)                          | —                           | `vite.config.ts` coverage threshold, `.github/workflows/admin-dashboard.yml`                                                  |
