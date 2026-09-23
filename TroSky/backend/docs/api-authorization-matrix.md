# API authorization matrix

Every protected route enforces its rule server-side via
`app.core.permissions.require_roles` / `require_permissions`, or an
in-service ownership check (`app.api.v1.bookings`'s "another passenger's
booking is 404, never 403" pattern, repeated for payments, tickets,
complaints, withdrawals, ...) — never a client-trusted role claim. This
document is a map of what's already in the code, grouped by router, not a
second source of truth; if it and the code ever disagree, the code wins —
open an issue/PR to reconcile.

**Roles** (`SystemRole`): `passenger`, `driver`, `fleet_owner`, `admin`,
`super_admin`. `super_admin` implicitly holds every permission
(`Principal.has_permission` short-circuits on it) — it is not listed
per-row below for that reason, not because it's excluded.

## Public (no authentication)

| Route | Notes |
|---|---|
| `GET /health/live`, `GET /health/ready`, `GET /health/details` | Liveness/readiness; `details` gated by `EXPOSE_HEALTH_DETAILS` (false in production). |
| `GET /metrics` | Prometheus scrape endpoint. |
| `POST /auth/register`, `/auth/login`, `/auth/login/otp/request`, `/auth/login/otp/verify`, `/auth/verify-otp`, `/auth/refresh`, `/auth/password-reset/request`, `/auth/password-reset/confirm` | Rate-limited (see `docs/production-readiness-checklist.md`). |
| `GET /routes`, `/stops`, `/routes/{id}`, `/trips/search`, `/trips/{id}`, `/trips/{id}/seats` | Deliberately public — browsing doesn't require an account (`app.api.v1.routes`'s module docstring). |
| `POST /payments/webhooks/{channel}` | Provider-to-server, not user-to-server — signature-verified instead of bearer-authenticated (see `app.api.v1.payments`'s module docstring). |

## Authenticated, no specific role (any logged-in user)

| Route | Ownership scoping |
|---|---|
| `GET/PATCH/DELETE /users/me`, `/users/me/notification-preferences`, `/users/me/emergency-contacts*`, `POST /users/me/devices` | Always the caller's own record — there is no "get other user's profile" route. |
| `POST /auth/logout`, `/auth/logout-all`, `GET /auth/sessions`, `DELETE /auth/sessions/{id}` | Caller's own sessions only. |
| `POST /bookings`, `GET /bookings`, `GET /bookings/{id}`, `POST /bookings/{id}/cancel`, `POST /bookings/{id}/pay`, `GET /bookings/{id}/tickets`, `POST/GET /bookings/{id}/rating` | 404 (not 403) on another passenger's booking, unless the caller also holds `bookings:view_any`. `pay` rate-limited (`payments:initiate`). |
| `GET/POST /payments*`, `GET/POST /wallet*`, `GET/POST /wallet/withdrawals*` | Caller's own payments/wallet only, unless `payments:review` / `withdrawals:review`. Wallet topup rate-limited (`payments:initiate`). |
| `GET /tickets/{id}` | 404 on another passenger's ticket unless `bookings:view_any`. |
| `GET /trips/{id}/location`, `/eta`, `WS /ws/trips/{id}/track` | Gated by `TrackingService.can_watch_trip` — the trip's assigned driver, a passenger with an active booking on it, or `trips:monitor_live`. Not a role/permission decorator; an in-service check (Phase 8). |
| `GET/POST /notifications*` | Caller's own inbox only. |
| `POST/GET /complaints*` | 404 on another user's complaint unless `complaints:manage`. |
| `POST /trips/{id}/incidents`, `/sos`, `GET /incidents/{id}`, `/sos/{id}` | `SafetyService._assert_trip_participant` — the trip's assigned driver or a passenger with an active booking on it; reads 404 for non-owners unless `incidents:manage`/`sos:review`. SOS trigger rate-limited (`sos:trigger`). |

## `driver` role required (router-level, `app/api/v1/drivers.py` + `app/api/v1/driver_trips.py`)

All of `POST/GET/PATCH /drivers/me`, `/drivers/me/documents*`,
`/drivers/me/assignments`, and every `driver-trips/*` route
(`start`/`pause`/`resume`/`end`/`location`/`tickets/validate`) additionally
require the caller to be *this specific trip's* actively assigned driver
(`TripService.assert_is_assigned_driver` / `_resolve_assigned_driver_id`)
— the role alone is necessary but not sufficient. `location` rate-limited
(`tracking:location_publish`), `tickets/validate` rate-limited
(`tickets:validate`).

## `fleet_owner` role required (router-level, `app/api/v1/fleets.py`)

All of `POST/GET /fleet-owners/me`, `/fleets*`, `/vehicles*` additionally
require the fleet/vehicle to belong to *this specific* fleet owner
(`FleetService.get_own_fleet` / `get_own_vehicle`) — tenant isolation, not
just role membership. Includes `GET /fleets/{id}/analytics`.

## Permission-gated (mostly admin surface, `app/api/v1/admin.py`)

| Permission | Routes |
|---|---|
| `drivers:approve` | `GET /admin/drivers/pending`, `POST /admin/drivers/{id}/approve`, `/reject`, `GET /admin/drivers/{id}/rating-summary` |
| `vehicles:approve` | `GET /admin/vehicles/pending`, `POST /admin/vehicles/{id}/approve`, `/reject` |
| `routes:manage` | `POST /admin/stops`, `/admin/routes`, `/admin/routes/{id}/schedules` |
| `trips:manage` | `POST /admin/trips`, `/admin/trips/from-schedule`, `/admin/trips/{id}/assign-driver`, `/assign-vehicle`, `/cancel` |
| `bookings:view_any` | `GET /admin/bookings`, plus the read-bypass on every passenger-owned booking/ticket/payment route above |
| `refunds:approve` | `GET /admin/refund-requests`, `POST /admin/refund-requests/{id}/approve`, `/reject`; `GET /admin/cancellation-requests`, `POST /admin/cancellation-requests/{id}/review` |
| `complaints:manage` | `GET /admin/complaints`, `POST /admin/complaints/{id}/resolve`, `/dismiss` |
| `incidents:manage` | `GET /admin/incidents`, `POST /admin/incidents/{id}/resolve` |
| `sos:review` | `GET /admin/sos-alerts`, `POST /admin/sos-alerts/{id}/acknowledge`, `/resolve` |
| `users:manage` | `GET /admin/users` |
| `users:suspend` | `POST /admin/users/{id}/suspend`, `/reactivate` |
| `withdrawals:review` | `GET /admin/withdrawals`, `POST /admin/withdrawals/{id}/approve`, `/reject`, `/complete`, `/fail` |
| `reports:view` | `GET /admin/reports/overview` |
| `payments:review` | Read-bypass only (no dedicated admin payment-list route yet — `GET /payments` as an authenticated user plus this permission would need a small addition to list *any* user's payments; today it only unlocks reading a specific payment by id if you already have it). |
| `trips:monitor_live` | Read-bypass only, on the live-tracking routes above. |

## Defined but not yet wired to any route

`Permission.WALLET_ADJUST`, `SYSTEM_SETTINGS_MANAGE`,
`FEATURE_FLAGS_MANAGE`, and `AUDIT_LOGS_VIEW` have existed in
`app.core.permissions.Permission` since Phase 1 (scaffolded ahead of the
features that would use them) but no endpoint checks any of them yet —
there is no manual wallet-adjustment endpoint, no system-settings store,
no feature-flag store, and no structured audit-log table in this
codebase. Documented here rather than silently omitted; each would need
its own domain model before a route enforcing the permission would mean
anything.
