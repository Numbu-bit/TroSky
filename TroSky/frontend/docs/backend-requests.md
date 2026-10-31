# Backend Requests from the Frontend Team

**For:** the TroSky backend developer
**From:** frontend (Flutter mobile app, admin web, fleet web)
**Status as of:** 10 Oct 2026 (first written 30 Sep 2026)

**Update 1 Oct 2026 (backend 0.12.0, `6bcfd43`):** G1, G2, G3, G4, G5, G7, G8, G9, G10, G12, G13 and G16 are **done** (see the backend `CHANGELOG.md`). G14, G15, G17 and G18 wait for product decisions. B1 and B2 are still open. G19 is new; G20 and G21 were added on 2 Oct 2026, B3 the same day.

**Update 10 Oct 2026 (backend 0.13.0 on main, `d425891`):** status of the second request list, from the backend `CHANGELOG.md` (0.13.0), the `app/api` and `app/schemas` diff, and tests against a local stack built from main. The second list itself (D1–D4, G22–G33, section E) was sent outside this file; its items are listed here as the changelog names them.

| ID | Request | Status | Delivered by |
|---|---|---|---|
| B1 | Lockout, code attempt limit, sign-out on token reuse | **Done**, re-tested live 10 Oct (all three pass) | Safeguard writes kept on failure (`keep_writes_on_failure`) |
| B2 | Register on a fresh database | **Done** (not re-tested on an empty database) | `scripts.seed_reference_data` after `alembic upgrade head` (compose, image entrypoint, k8s job) |
| B3 | An expired seat hold keeps its seats until the sweeper runs | **Done** (0.22.1, 11 Oct; merged 20 Oct) | `app/repositories/seat_holds.py`: a hold past `expires_at` is free at once |
| B4 | A search with an unknown stop answers 500 | **New** (29 Oct) | See B4 below |
| CI | Backend workflow never ran (the backend changelog calls this "B3") | **Done** | `.github/workflows/backend.yml` at the repository root |
| D1 | Demo data | **Done** (in use; replaces the frontend's `tool/seed_local_trips.dart`) | `make seed-demo` / `python -m scripts.seed_demo_data` |
| D2 | GPS simulator | **Done** (in use) | `make simulate-gps` / `python -m scripts.simulate_gps` |
| D3 | Hosted server | **Not started**: needs the project owner's accounts and billing | — |
| D4 | Firebase project (push) | **Not started**: same reason | — |
| G19 | SOS without a trip | **Done** | `POST /sos {latitude, longitude}`; `SosAlertResponse.trip_id` nullable |
| G20 | The passenger's fare | **Done**, in its own shape (in use on P-03 and P-05) | `fare {current, solo, minimum, platform_fee, total, currency, riders_count, seats}` on `/trips/search`; `GET /trips/{id}/fare-quote` |
| G21 | Vehicles approaching or past the stop | **Done** (in use on P-03) | Trips on the road in search; `vehicle_eta_to_pickup_minutes`, `has_passed_pickup`, `ride_minutes`; `?sort=`, `?vehicle_type=`, `?seats=`; `PICKUP_ALREADY_PASSED` on booking |
| G22 | Trip details | **Done** | `GET /trips/{id}`: route, stops, `vehicle {…}`, `driver {…}`, `riders_count`, `seats_total`, `available_seats` |
| G23 | (not in the changelog or the code) | **Unknown**: the second list isn't in the repo, so what it asked can't be checked | — |
| G24 | Share a live trip | **Done** | `POST /bookings/{id}/share`; `GET /shared-trips/{token}`; `GET /share/{token}` page |
| G25 | Monthly trip summary | **Done** | `GET /bookings/summary?month=YYYY-MM` |
| G26 | A favourite route's next trip | **Done** | `FavouriteRouteResponse.next_trip {trip_id, scheduled_departure_at, available_seats, fare, currency}` |
| G27 | Notification count, read all | **Done** | `GET /notifications/unread-count`; `POST /notifications/read-all` |
| G28 | Saved payment methods | **Partly**: mobile money numbers only; cards need a card processor | `GET/POST /users/me/payment-methods`, `PATCH/DELETE …/{id}`; pay with `payment_method_id` |
| G29 | Driver rating summary | **Done** | `GET /drivers/me/rating-summary` |
| G30 | Vehicles on assignments, driver names | **Done** | `/drivers/me/assignments` items carry `vehicle {…}`; `DriverResponse.full_name`, `phone_number` |
| G31 | Payments on a driver's trip | **Done** | `GET /driver-trips/{trip_id}/payments` |
| G32 | Incident types and a photo | **Done** | Types `passenger_issue`, `road_hazard`; optional `severity`; `POST /incidents/{id}/photo` |
| G33 | Drop-off on the manifest | **Done** | `dropoff_stop_name` on manifest entries |
| G34 | Booking acceptance details | **New** (21 Oct) | See G34 below |
| G35 | Cancels and refunds a passenger can see | **New** (28 Oct) | See G35 below |
| G36 | Payments that can't be retried | **New** (29 Oct) | See G36 below |
| E1 | Boarding | **Decided**: the driver scans the passenger's ticket | As built |
| E2 | Driver trips | **Decided**: scheduled by admins and fleet owners; Go Online/Offline is availability only, no ride requests | As built |
| E3 | Subscriptions (G14) | **Decided**: out of the MVP | — |
| E4 | Ghana Card verification (G17) | **Decided**: out of the MVP | — |
| E5 | Wallet "Send", driver chat | **Decided**: out of the MVP | — |
| E6 | Withdrawals | **Decided**: paid after admin approval | As built |

**Since 10 Oct 2026, 17:14 UTC, main has backend 0.14.0 to 0.22.0 (PR #9).** Two of its changes break screens the app already has; the app is not adapted yet:
- **0.20.0, booking acceptance:** `POST /bookings` answers `awaiting_acceptance`; `expires_at` is the driver's answer deadline (`BOOKING_ACCEPT_TIMEOUT_SECONDS`, 120 s). Payment is possible only once accepted (`pending`, then the 600 s hold). Unanswered or declined, the booking moves to another trip (up to 3 times) or ends uncharged. Affects P-05 → P-07 and Home's restore of a held booking. `BOOKING_ACCEPTANCE_REQUIRED=false` restores the old flow.
- **0.21.0, Ghana-only sign-up:** `POST /auth/register` as a passenger needs `latitude`/`longitude` (422 `LOCATION_REQUIRED`, or `LOCATION_NOT_SERVED` outside Ghana). S-06 sends none, so passenger sign-up fails. `PASSENGER_SIGNUP_COUNTRIES=` (empty) switches the check off.

Also settled by 0.13.0: G15 (fare splitting) is built as the fare sharing behind G20, and **a passenger's fare is fixed when they book**; later riders lower the price only for people who book after them.

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

## Bugs found while connecting the app

### B1: three security safeguards never take effect (rollback on error)

**Fixed in 0.13.0**, re-tested on 10 Oct 2026 with `live_smoke_test.dart`, which now asserts all three: a reused refresh token answers `REFRESH_TOKEN_REUSE_DETECTED` and the other session then gets 401; the 6th wrong code answers `OTP_ATTEMPTS_EXCEEDED`; after 5 wrong passwords the right one answers `ACCOUNT_LOCKED`. What follows is the original report.

`get_db` (app/core/database.py) rolls back the request's transaction on any exception. Three safeguards write to the database and then raise an `AppError`, so their writes are rolled back:

| Safeguard | Write that is lost | What happens instead |
|---|---|---|
| Login lockout (`login_password`) | `record_login_failure` increments `failed_login_attempts` / sets `locked_until` | `ACCOUNT_LOCKED` never happens; passwords can be guessed at the rate limit (10 per 5 minutes per IP) |
| OTP attempt limit (`OtpService.verify_otp`) | `increment_attempts` | `OTP_ATTEMPTS_EXCEEDED` never happens; codes can be guessed at the rate limit |
| Refresh-token reuse (`refresh_tokens`) | `revoke_all_sessions_for_user` | `REFRESH_TOKEN_REUSE_DETECTED` is returned, but every other session stays valid |

**Seen on the local docker stack on 1 Oct 2026** (frontend `packages/trosky_api/test/live/live_smoke_test.dart`, run with `TROSKY_LIVE_API=http://localhost:8000/api/v1`):
- After 5 wrong passwords, the right one still signs in.
- Six wrong codes all return `OTP_INVALID`.
- After a reused refresh token, another session's access token still gets 200 from `GET /users/me`.

**Suggested fix:** commit these writes even though the request fails. For example, do the write in its own session or transaction that commits before raising. Another option is to let `get_db` commit for errors that carry intentional side effects. The integration tests skip without Postgres, which is probably why this went unnoticed.

**Frontend impact:** none. The app already handles `ACCOUNT_LOCKED`, `OTP_ATTEMPTS_EXCEEDED` and `REFRESH_TOKEN_REUSE_DETECTED`, and the mock follows the intended behaviour.

### B2: registration answers 500 until roles are seeded

**Fixed in 0.13.0:** `scripts.seed_reference_data` runs after the migrations.

On a fresh database, `POST /auth/register` fails with `500 INTERNAL_SERVER_ERROR` (`RuntimeError: Role 'passenger' is not seeded`). `make seed` fixes it. Consider running the seed from the docker-compose `api` command after `alembic upgrade head`, so a fresh stack works on its own.

### B4: a search with an unknown stop answers 500

**Seen on 29 Oct 2026** on the local stack (backend 0.22.8 plus #53): the app's recent searches still
held stop IDs from staging, and `GET /trips/search` with one of them answered
`500 INTERNAL_SERVER_ERROR`. The log shows `ForeignKeyViolationError` on `search_events`
(`fk_search_events_origin_stop_id_stops`): the search is recorded for the demand funnel before anyone
checks that the stops exist.

**Suggested fix:** answer 404 `NOT_FOUND` (or 422) for an `origin_stop_id` or `destination_stop_id`
that isn't a stop, before recording the search; or record it without the stop IDs.

**Frontend impact:** small. The app shows "Something went wrong. Try again." and choosing the stops
again works. It can happen to anyone whose saved searches or favourites point at a stop that was
removed.

## P0: blocks the driver app and password reset

### G2 — Driver's assigned trips (done in 0.12.0)
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

### G3 — Passenger manifest for a trip (done in 0.12.0)
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

### G1 — Password reset with a typeable code (done in 0.12.0)
Today the reset "code" is a 43-character token, which nobody can type from an SMS.

Proposal: send a 6-digit OTP (`purpose=password_reset`), and let `POST /auth/password/reset` also accept:
```json
{ "target": "+233241234567", "code": "482913", "new_password": "…" }
```
Keep the existing `{token, new_password}` form so nothing else breaks.

---

## P1: needed for full screens (the frontend has workarounds for now)

### G12 — Upcoming / past bookings (done in 0.12.0)
`GET /bookings?status=<BookingStatus,...>&upcoming=true|false`, and embed a small trip summary in `BookingResponse`:
```json
"trip": { "scheduled_departure_at": "…", "route_name": "…", "origin_stop_name": "…",
          "destination_stop_name": "…", "status": "…", "vehicle_registration_number": "…" }
```
Without it, the app makes one extra request per booking.

### G7 — Driver earnings summary (done in 0.12.0)
`GET /drivers/me/earnings?period=day|week|month&from=&to=` · role `driver`
```json
{ "period": "week", "currency": "GHS", "total": "412.50", "trips_count": 23,
  "pending_withdrawals_total": "150.00",
  "buckets": [{ "start": "2026-09-28", "total": "58.00", "trips_count": 3 }] }
```
Also add `?reference_type=` as a filter on `GET /wallet/transactions`.

### G8 — Trip lists for admin and fleet owners (done in 0.12.0)
- `GET /admin/trips?status=&date=&route_id=&driver_id=` (paginated)
- `GET /admin/live-trips`: active trips with their last GPS position, `{trip_id, route_name, vehicle_registration_number, driver_name, status, latitude, longitude, heading, updated_at}`
- `GET /fleets/{fleet_id}/live-trips`: the same, scoped to that fleet

### G10 — Fleet owner finding a driver to assign (done in 0.12.0)
- `GET /fleets/{fleet_id}/drivers`: drivers currently assigned to the fleet's vehicles
- `GET /fleets/driver-lookup?phone=`: returns an **approved** driver's `{driver_id, full_name, phone_number (masked), approval_status}`, or 404

---

## P2: nice to have for the MVP

| ID | Request | Proposal |
|---|---|---|
| G4 (done) | Favourite routes (shown on the Home screen) | `GET/POST/DELETE /users/me/favourite-routes` with `{id, origin_stop_id, destination_stop_id, label}`, returning stop names too |
| G5 (done) | Profile photo | `POST /users/me/avatar` (multipart, reuse the document S3 upload) → `UserResponse` |
| G9 (done) | Edit and delete routes and stops | `PATCH/DELETE /admin/stops/{id}`, `PATCH/DELETE /admin/routes/{id}` |
| G16 (done) | Vehicles near me (Home map clusters) | `GET /vehicles/nearby?latitude=&longitude=&radius_m=` → active vehicles with last position, route name and free seats |
| G13 (done) | Rating categories (only if the Figma "Rate Driver" screen shows them) | Optional `safety`, `cleanliness`, `professionalism`, `timeliness` (1–5) on `RateBookingRequest` |

---

## Needs a product decision first (don't build yet)

| ID | The Figma design shows | Backend today |
|---|---|---|
| G18 | Sign up with **phone → OTP only** (no password; email optional) | Requires phone + Gmail address + name + password. **Decided 1 Oct 2026: the backend stays as it is.** The app adds a "Your details" screen for name, email and password (frontend `docs/design-decisions.md`, decision 6) |
| G14 | **Subscribe your commute** (monthly plan, "save up to 40%") | No subscriptions. **Decided: out of the MVP** (E3) |
| G15 | **Fare splitting**: price drops as more riders board | **Built** (0.13.0): fare sharing, the fare fixed at booking |
| G17 | Optional Ghana Card verification | Fields exist, but there's no verification endpoint. **Decided: out of the MVP** (E4) |

Mubarik will confirm these with the team and update this file.

---

## New requests

### G19 — SOS without an active trip
> **Done in 0.13.0:** `POST /sos {latitude, longitude}`. The app uses it when the SOS screen is built.

The Home screen (P5) shows an SOS button at all times, also when the passenger is not on a trip. Today an SOS needs a trip: `POST /trips/{trip_id}/sos`. Until this exists, SOS on Home opens the SOS screen but can't raise an alert outside a trip (frontend `docs/design-decisions.md`, decision 18).

Proposal: `POST /sos` · any signed-in user
```json
{ "latitude": 5.6037, "longitude": -0.1870, "trip_id": null, "note": null }
```
→ `SosAlertResponse` with `trip_id` nullable. Admins see it in the existing SOS queue (`GET /admin/sos-alerts`). `trip_id` stays optional, so the app can send it when there is an active trip.

---

## CI

> **Done in 0.13.0** (the backend changelog calls it "B3"): `.github/workflows/backend.yml` at the repository root.

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

### G20 — The passenger's fare in search results
> **Done (backend 0.13.0, on main since PR #6), in use since 10 Oct 2026** (decisions 20 and 24 ended). The backend answers this in its own shape: a `fare` object on each search result (`current`, `solo`, `minimum`, `platform_fee`, `total`, `currency`, `riders_count`, `seats`) and `GET /trips/{id}/fare-quote?origin_stop_id&destination_stop_id&seats`. That covers the seat-screen fields below too (`current` = shared, `solo`, `minimum` = floor). Search Results show `fare`; Seat Selection asks `fare-quote` for its stops and seats.

`GET /trips/search` returns the trip's `fare_amount`: the **whole route's** fare. A booking then charges only the stretch ridden, shared with everyone aboard (`app/services/fare_service.py`). So a Madina → Legon search on the Madina – Circle route shows the full fare, but the booking costs less. The design also shows the saving from sharing ("~~₵38~~ ₵14 · Save 63%").

`FareService.quote()` already computes both numbers. Proposal: add them to every `TripSearchResultResponse`, for the searched pickup → destination:
```json
{ "solo_fare_amount": "38.00", "shared_fare_amount": "14.00" }
```
`solo_fare_amount` = the stretch alone (`solo_segment_fare`); `shared_fare_amount` = what a seat costs if booked now (`per_seat_fare`). Both `null` when unknown. The app computes "Save X%" from the two (frontend `docs/design-decisions.md`, decision 20).

The seat screen (P-05) needs the same for the passenger's stretch on `GET /trips/{id}/seats` (with `origin_stop_id` / `destination_stop_id` as query parameters), plus the lowest the shared fare can go, for "↓ Drops to ₵6.00":
```json
{ "solo_fare_amount": "38.00", "shared_fare_amount": "14.00", "floor_fare_amount": "6.00" }
```
`floor_fare_amount` = `FARE_SHARING_MIN_RATIO` × the solo fare. Until then the seat screen shows an estimate (decision 24).

### G21 — Vehicles approaching or past the passenger's stop
> **Done in 0.13.0**, as `vehicle_eta_to_pickup_minutes`, `has_passed_pickup` and `ride_minutes` on each result, with trips already on the road included. In use on Search Results since 10 Oct 2026 (decision 21 ended).

The results design shows, for each vehicle, how far it is from the passenger's stop ("~3 min away · approaching your stop") and greys out the ones that already passed it. The backend has the live positions (G16) but search doesn't use them, and it only returns trips that **depart the route's first stop** after the requested time, so a vehicle already on its way to a stop further along is missing.

Proposal, per result, when the trip is running:
```json
{ "pickup_eta_minutes": 3, "passed_pickup": false }
```
And for `Now` searches, include trips that already left the first stop but haven't reached the pickup yet. Until then the app shows "Board at <stop> · <distance> away" in that slot (decision 21).

### B3: an expired seat hold keeps its seats until the sweeper runs

> **Done in 0.22.1** (merged to main 20 Oct 2026): `GET /trips/{id}/seats`, search and booking treat a hold past `expires_at` as free (`app/repositories/seat_holds.py`).

> **Still open in 0.13.0** (the backend changelog's "B3" is the CI workflow). Re-tested on 10 Oct 2026: a hold that expired at 17:36:03 still had its seat taken at 17:36:46 (`pending`, reservation `held`) with no Celery worker running. With the worker and beat started, the next sweep (17:38:16) set it `expired` and freed the seat. So with beat running, a lapsed hold is freed within one sweep interval (30 s).

`GET /trips/{id}/seats` and booking both treat a `HELD` reservation as taken until `expire_stale_bookings` (Celery beat, every 30 s) marks it expired. They don't look at `expires_at`. With the worker down (or in a stack without Celery, like the local `trosky-api-local`), seats from a lapsed hold stay taken indefinitely.

Suggested fix: `list_active_seat_ids_for_trip` (and the reservation check) treat `HELD` rows with `expires_at <= now()` as free. The sweeper then only tidies up.

### G34 — How long a driver has, and why a booking moved

**Needed by:** Payment (P-07), built 21 Oct 2026 (frontend decision 28).

Payment shows "2-minute response window" under the driver's countdown, and after a move "The driver
didn't respond" or "The driver couldn't take your booking". `BookingResponse` has neither fact, so
the app works them out:

- the window from a new booking's `expires_at − created_at` (wrong for a booking that already moved,
  so a booking reopened from Home shows no window);
- the reason from when the move is seen: before the old deadline means declined, after it means
  nobody answered (an admin's move reads as "declined").

Suggested, on `BookingResponse` while `awaiting_acceptance` (all optional, so nothing breaks):

```json
{
  "accept_timeout_seconds": 120,
  "moves": 1,
  "last_move_reason": "unanswered"
}
```

`last_move_reason`: `unanswered`, `declined` or `admin` (from the status history reason the service
already writes: "Moved to another vehicle: …").

### G35 — Cancels and refunds a passenger can see

**Needed by:** Trip History (P-15) and Booking details (P-16), built 28 Oct 2026 (frontend
decision 30).

1. **A cancel waiting for review is invisible.** Once a trip has started,
   `POST /bookings/{id}/cancel` files a `CancellationRequest` (pending) and returns the booking
   unchanged. No passenger endpoint returns the request, so after the first answer the app can't
   tell the passenger it is waiting, and a second tap files a second request (nothing stops
   duplicates). Suggested on `BookingResponse`: `cancellation: {status, created_at,
   refund_eligible} | null`, and a 409 for a second pending request.
2. **Where a refund goes.** The design says "₵16.00 refunded to wallet", but `RefundService` pays
   back the way the booking was paid (wallet, or MoMo through the provider), and the booking
   doesn't say which. `GET /payments` has no `booking_id` filter. Suggested: `payment_channel` on
   `BookingResponse` (null until paid). Until then the app says "₵16.00 refunded" and "Refund of
   ₵16.00 requested", and leaves out the design's "PAID WITH".
3. **"Past" takes two queries.** `upcoming` looks only at the trip, so a booking cancelled for
   tomorrow counts as upcoming. The app filters by status instead: Upcoming is
   `status=awaiting_acceptance,pending,payment_pending,confirmed&upcoming=true`, Past is
   `status=completed,cancelled,expired,refund_pending,refunded`. An open booking whose trip ended
   without its passenger getting off is in neither. Suggested: `?history=true` (ended, or trip
   behind), most recent trip first.
4. **A `refund_pending` booking can be cancelled again**, and then becomes `cancelled`
   (`_TERMINAL_BOOKING_STATUSES` doesn't include it). The app never offers it; the refund request
   itself stays. Suggested: refuse it with 409 like the other ended statuses.

### G36 — Payments that can't be retried

**Needed by:** Approve on your phone (P-08) and the payment result (P-09), built 29 Oct 2026
(frontend decision 32).

1. **A mobile money payment can't be given up.** While it is `processing` the booking is
   `payment_pending`, and `POST /bookings/{id}/pay` answers 409 `BOOKING_NOT_PAYABLE`. When no
   prompt reaches the phone (a wrong number, the phone off), the passenger can only wait until MTN
   fails the request and the backend hears of it (a sync, the webhook, or the reconciliation after
   5 minutes), or until the hold runs out. So "I didn't get a prompt" offers Check again, not
   "try again" or "pay another way". Suggested: `POST /payments/{id}/cancel` for the payer: the
   payment `cancelled`, the booking back to `pending`; a success arriving later refunded as after
   an expired hold.
2. **A failure when starting leaves the booking stuck.** In `PaymentService.pay_for_booking`, when
   `initialize_payment` answers `FAILED` or raises `ProviderError` (502), the payment fails but the
   booking stays `payment_pending` (not put back to `pending` as `_apply_provider_status` does).
   The passenger can't pay again until the hold runs out. (Noted on PR #53, which changes only the
   sandbox.)
3. **`GET /payments` has no booking filter.** To find a booking's payment (the cancel sheet's
   refund wording, reopening P-08) the app reads the latest 50 and matches `booking_id`.
   Suggested: `?booking_id=`, or `payment_channel` on `BookingResponse` (G35, 2).
4. **The payer's number isn't on `PaymentResponse`.** Reopened, P-08 says "your MTN MoMo number"
   instead of the number. Suggested: `payer_number_masked`.
