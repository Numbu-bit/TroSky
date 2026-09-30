# Backend Requests from the Frontend Team

**For:** the TroSky backend developer
**From:** frontend (Flutter mobile app, admin web, fleet web)
**Status as of:** 30 Sep 2026

The frontend is being built now against **mock data that follows the contracts below**. When an endpoint lands in the repo, the frontend switches from mock to live. So the most helpful thing is to **agree the request/response shape early**, even before the code exists. If you want a different shape, change it here (or tell us) before building, and we'll update our mocks.

All proposals follow the existing backend conventions:
- The `{"error": {code, message, details, request_id}}` envelope for errors.
- `PaginatedResponse` (`items`, `total`, `limit`, `offset`) for lists.
- `Decimal` for money.
- `require_roles(...)` for access control.
- `extra="forbid"` on request models.

When you finish one, please:
1. Push to the shared repo.
2. Add a `CHANGELOG.md` line with the gap ID (e.g. "G2 done").
3. Make sure `/openapi.json` shows it. The frontend reads the OpenAPI spec to stay in sync.

---

## P0: blocks the driver app and password reset

### G2 — Driver's assigned trips
The driver app has no way to find out which trips a driver has, so it can't start one. `/drivers/me/assignments` returns vehicles only.

`GET /drivers/me/trips?status=<TripStatus,...>&date=YYYY-MM-DD` · role `driver` · paginated
```json
{ "items": [{
    "trip_id": "uuid", "route_id": "uuid", "route_name": "Madina → Circle",
    "origin_stop_name": "Madina Zongo Junction", "destination_stop_name": "Circle",
    "scheduled_departure_at": "2026-10-01T07:15:00Z", "scheduled_arrival_at": "…",
    "status": "<existing TripStatus value>",
    "vehicle_id": "uuid", "vehicle_registration_number": "GR 1234-24",
    "seats_total": 14, "seats_booked": 9, "boarded_count": 3 }],
  "total": 1, "limit": 20, "offset": 0 }
```

### G3 — Passenger manifest for a trip
The driver's "Passenger List" screen.

`GET /driver-trips/{trip_id}/passengers` · only the driver assigned to that trip (403 otherwise)
```json
[{ "ticket_id": "uuid", "booking_reference": "TS-8KQ2",
   "seat_id": "uuid", "seat_label": "B3",
   "passenger_full_name": "Ama Owusu", "phone_number": "+23324•••4567",
   "pickup_stop_name": "Madina Zongo Junction",
   "boarded": true, "boarded_at": "2026-10-01T07:12:40Z" }]
```
`boarded` should flip to `true` when `POST /driver-trips/{id}/tickets/validate` succeeds.

### G1 — Password reset with a typeable code
Today the reset "code" is a 43-character token, which nobody can type from an SMS.

Proposal: send a 6-digit OTP (`purpose=password_reset`), and let `POST /auth/password/reset` also accept:
```json
{ "target": "+233241234567", "code": "482913", "new_password": "…" }
```
Keep the existing `{token, new_password}` form so nothing else breaks.

---

## P1: needed for full screens (the frontend has workarounds for now)

### G12 — Upcoming / past bookings
`GET /bookings?status=<BookingStatus,...>&upcoming=true|false`, and embed a small trip summary in `BookingResponse`:
```json
"trip": { "scheduled_departure_at": "…", "route_name": "…", "origin_stop_name": "…",
          "destination_stop_name": "…", "status": "…", "vehicle_registration_number": "…" }
```
Without it, the app makes one extra request per booking.

### G7 — Driver earnings summary
`GET /drivers/me/earnings?period=day|week|month&from=&to=` · role `driver`
```json
{ "period": "week", "currency": "GHS", "total": "412.50", "trips_count": 23,
  "pending_withdrawals_total": "150.00",
  "buckets": [{ "start": "2026-09-28", "total": "58.00", "trips_count": 3 }] }
```
Also add `?reference_type=` as a filter on `GET /wallet/transactions`.

### G8 — Trip lists for admin and fleet owners
- `GET /admin/trips?status=&date=&route_id=&driver_id=` (paginated)
- `GET /admin/live-trips`: active trips with their last GPS position, `{trip_id, route_name, vehicle_registration_number, driver_name, status, latitude, longitude, heading, updated_at}`
- `GET /fleets/{fleet_id}/live-trips`: the same, scoped to that fleet

### G10 — Fleet owner finding a driver to assign
- `GET /fleets/{fleet_id}/drivers`: drivers currently assigned to the fleet's vehicles
- `GET /fleets/driver-lookup?phone=`: returns an **approved** driver's `{driver_id, full_name, phone_number (masked), approval_status}`, or 404

---

## P2: nice to have for the MVP

| ID | Request | Proposal |
|---|---|---|
| G4 | Favourite routes (shown on the Home screen) | `GET/POST/DELETE /users/me/favourite-routes` with `{id, origin_stop_id, destination_stop_id, label}`, returning stop names too |
| G5 | Profile photo | `POST /users/me/avatar` (multipart, reuse the document S3 upload) → `UserResponse` |
| G9 | Edit and delete routes and stops | `PATCH/DELETE /admin/stops/{id}`, `PATCH/DELETE /admin/routes/{id}` |
| G16 | Vehicles near me (Home map clusters) | `GET /vehicles/nearby?latitude=&longitude=&radius_m=` → active vehicles with last position, route name and free seats |
| G13 | Rating categories (only if the Figma "Rate Driver" screen shows them) | Optional `safety`, `cleanliness`, `professionalism`, `timeliness` (1–5) on `RateBookingRequest` |

---

## Needs a product decision first (don't build yet)

| ID | The Figma design shows | Backend today |
|---|---|---|
| G18 | Sign up with **phone → OTP only** (no password; email optional) | Requires phone + Gmail address + name + password |
| G14 | **Subscribe your commute** (monthly plan, "save up to 40%") | No subscriptions |
| G15 | **Fare splitting**: price drops as more riders board | One fixed `fare_amount` per trip |
| G17 | Optional Ghana Card verification | Fields exist, but there's no verification endpoint |

Mubarik will confirm these with the team and update this file.

---

## CI

**`TroSky/.github/workflows/ci.yml` has never run.** GitHub only runs workflows from `.github/workflows/` at the repository root. In this repo that folder sits one level down, inside `TroSky/`, so GitHub ignores it and no lint, tests, scans or image builds happen on push or PR. The frontend workflow is at the root (`.github/workflows/frontend.yml`) and does run; it only triggers on `TroSky/frontend/**`, so it won't touch the backend.

To fix it:
1. Move the file to the root: `git mv TroSky/.github/workflows/ci.yml .github/workflows/backend.yml`
2. Paths are then relative to the repo root, so prefix them with `TroSky/`:
   - `defaults.run.working-directory: TroSky/backend`
   - `cache-dependency-path: TroSky/backend/pyproject.toml` (both `setup-python` steps that set it)
   - Trivy `scan-ref: TroSky/backend/requirements.lock.txt`
   - coverage upload `path: TroSky/backend/coverage.xml`
3. Two paths are wrong regardless of the move, because every `run:` step already executes inside the backend folder while `uses:` steps resolve from the repo root:
   - `docker build ... --target runtime backend` should end in `.` (as written it points at `backend/backend`).
   - The image upload should use `path: TroSky/backend/image.tar`, since `docker save -o image.tar` writes it inside the backend folder.
4. Optional: add `paths: ["TroSky/backend/**", ".github/workflows/backend.yml"]` to the `push` and `pull_request` triggers so frontend-only commits don't run the backend pipeline.

Because the workflow has never run, expect the first run to surface a few failures of its own.
