# TroSky Frontend Inventory

This is built from a direct read of `backend/app/api/v1/*`, `schemas/*`, `core/exceptions.py` and `core/permissions.py`. It was **re-verified on 30 Sep 2026 against the current backend** (the first draft was read from an older copy of the backend on the Desktop).

**Status keys:** ✅ backend ready · ⚠️ works with a client-side workaround · ❌ backend gap (listed in §6)

---

## 1. What we are building

| # | Product | Tech | Who | Notes |
|---|---|---|---|---|
| 1 | **TroSky mobile app** | Flutter (Android + iOS) | Passenger **and** Driver | One app. The user picks *Passenger* or *Driver* at entry and gets a completely separate interface for each. |
| 2 | **Admin web app** | React, in `TroSky/admin-dashboard` (Maahir) | `admin`, `super_admin` | Not part of this Flutter workspace (`design-decisions.md`, 26) |
| 3 | **Fleet owner web app** | Flutter Web | `fleet_owner` | Its own deployable app and URL |

**Visual design:** every color, font, spacing value, radius, icon and illustration comes from the **Figma Make file**. Nothing is invented. Until the Figma values are extracted into `docs/design-tokens.md`, no screen gets built.

---

## 2. Proposed structure

```
TroSky/
├── backend/                      (exists, untouched)
├── .github/workflows/
│   ├── ci.yml                    (exists, backend)
│   └── frontend.yml              (new)
└── frontend/
    ├── CLAUDE.md                 rules for Claude Code
    ├── design/                   Figma screenshots + Make code, by screen ID (e.g. design/S-04/)
    ├── docs/
    │   ├── frontend-inventory.md (this file)
    │   ├── design-tokens.md      extracted from Figma Make, the single source for visuals
    │   └── backend-gaps.md
    ├── apps/
    │   ├── mobile/               passenger + driver
    │   │   └── lib/
    │   │       ├── entry/        splash, onboarding, role chooser, auth
    │   │       ├── passenger/    passenger shell + features
    │   │       └── driver/       driver shell + features
    │   └── fleet_web/
    └── packages/
        ├── trosky_ui/            theme + widgets built from Figma tokens
        ├── trosky_core/          errors, money (Decimal), phone, dates, env, l10n
        ├── trosky_api/           Dio client, DTOs, repositories, mocks, WebSocket tracking
        └── trosky_auth/          session, token storage, role/mode guards
```

The shared packages mean login, error handling, the API client and design widgets are written once and reused by all three apps.

### How the Passenger/Driver switch works (mapped to the backend)

The backend already supports this. `POST /auth/register` takes `role: passenger | driver | fleet_owner`, and `GET /users/me` returns `roles: []`.

1. The **role chooser** sets `mode = passenger | driver` and remembers it on the device.
2. **Sign up** sends that `role` to `/auth/register`.
3. **Sign in** is the same `/auth/login` for both. Afterwards the app checks `/users/me.roles`:
   - If the role matches the mode, the app opens that shell.
   - If it doesn't (for example, a passenger account tries Driver mode), the app offers **"Become a driver"**. That goes straight to D-01, where `POST /drivers/me` adds the driver role to the same account with no re-login (`role_service.py`). It must **not** send the user back to sign-up: the same phone would fail with `PHONE_ALREADY_REGISTERED`.
4. After signing up, a **driver** goes through onboarding (`POST /drivers/me`, then document uploads), then an **"awaiting approval"** screen, until an admin approves them. Only then does the driver dashboard unlock.
5. The next launch skips the chooser and opens the remembered mode. The chooser is still reachable from settings or sign-out.

✅ One account can hold several roles. `POST /drivers/me` and `POST /fleet-owners/me` are open to any signed-in account and add the role.

---

## 3. Backend facts the frontend must respect

| Topic | What the backend does | Frontend rule |
|---|---|---|
| Base path | `/api/v1`, health checks at `/health/*` | Base URL comes from env |
| Errors | `{"error": {code, message, details, request_id}}` | Map `code` to a typed failure (`SEAT_NOT_AVAILABLE`, `INVALID_CREDENTIALS`, `ACCOUNT_SUSPENDED`, `RATE_LIMIT_EXCEEDED`…) and show `message` |
| Validation | 422 `VALIDATION_ERROR`, field info in `details` | Show errors inline on the right field |
| Tokens | `access_token`, `refresh_token`, `expires_in`, `session_id`. Refresh **rotates** | Refresh one request at a time: concurrent 401s wait for a single refresh |
| Money | Pydantic `Decimal`, which arrives as a string such as `"12.50"`. Currency `GHS` | Parse with Dart `decimal`. Never `double` |
| Phone | The server normalizes `024…`, `24…` and `+233…` | Accept all three; the server has the final say |
| Seat hold | `SEAT_RESERVATION_HOLD_SECONDS = 600`; bookings carry `expires_at` | Show a countdown from `expires_at`; on expiry, go back to seat selection |
| Payment channels | `mtn_momo`, `telecel_cash`, `airteltigo_money`, `card`, `wallet` | Only **MTN MoMo and Wallet actually work** today (the others raise `ProviderError`). Show them as "Coming soon" or hide them |
| Payment status | `pending → processing → successful / failed / cancelled / refunded / partially_refunded` | Poll `POST /payments/{id}/sync` while the "Approve on your phone" screen is showing |
| Live tracking | WebSocket `/api/v1/ws/trips/{trip_id}/track?token=<access>` | Reconnect with backoff; fall back to polling `GET /trips/{id}/location` + `/eta` every 5–10 s |
| Pagination | `{items, total, limit, offset}` | One shared paginated-list widget |
| Tickets | The API returns an opaque signed token; **the client draws the QR** | Render with `qr_flutter`. Store confirmed tickets locally so they work **offline** |
| Sign-up then OTP | `/auth/verify-otp` returns only a message, no tokens | After a successful OTP, silently call `/auth/login` with the credentials just entered |
| **Email at sign-up** | Required. `REGISTRATION_EMAIL_DOMAINS` defaults to `gmail.com,googlemail.com` (`config.py:228`). Errors: `EMAIL_REQUIRED`, `EMAIL_DOMAIN_NOT_ALLOWED` | S-06 needs an email field with an inline message explaining the rule |
| **Where the code goes** | `OTP_DELIVERY_CHANNEL` can send codes by email instead of SMS. The register response includes `otp_sent_to` | S-07 verifies against `otp_sent_to` and shows it ("Code sent to k•••@gmail.com"). Same for forgot password |
| **GPS pickup** | `/trips/search` and `POST /bookings` accept `pickup_latitude` and `pickup_longitude`. Results include `pickup_stop_name`, `pickup_distance_m` and `pickup_source` (`gps` or `manual`). Error `NO_PICKUP_NEARBY` | P-02 and P-03 are built around "pick up near me". Show the pickup stop and walking distance on each result |
| Stops | `GET /stops?q=` searches by name (≥ 2 characters). `GET /stops/nearby?latitude=&longitude=` returns stops nearest first | Use the server search; no client-side filtering |
| Rating | `RateBookingRequest` = one `score` (1–5) + optional `comment` | P-14 uses a single score (see G13) |
| Admin login | `/auth/login` doesn't check role | The admin dashboard and the fleet app must check `/users/me.roles` after login and reject other roles |

---

## 4. Screen inventory, mobile app

Use the **Screen ID** as the screenshot filename (e.g. `S-04.png`). "Figma" is the screenshot I need from you.

### 4a. Entry (shared)
| ID | Screen | Endpoints | API |
|---|---|---|---|
| S-01 | Splash | `GET /users/me` (if a token is stored) | ✅ |
| S-02 | Onboarding slides | none | ✅ |
| ~~S-03~~ | ~~Role chooser~~: none, replaced by the Welcome screen's driver link (decision 7) | — | — |
| S-04 | **Welcome** (phone; P4 Sign Up). Built 1 Oct 2026 | none (checked on the device) | ✅ |
| S-05 | **Sign in**: phone or email + password, plus "Sign in with a code" (decision 10). Built 1 Oct 2026 | `POST /auth/login`, `POST /auth/resend-otp` (purpose `login`) → `POST /auth/otp-login`, then `GET /users/me` | ✅ |
| S-06 | **Your details**: name, Gmail, password (not in Figma; decision 6). Built 1 Oct 2026 | `POST /auth/register` (role from the app mode) | ✅ |
| S-07 | **Code verification** (target = `otp_sent_to`). Built 1 Oct 2026 | `POST /auth/verify-otp`, `POST /auth/resend-otp`, then a silent `POST /auth/login` | ✅ |
| S-08 | Forgot password | `POST /auth/password/forgot` | ✅ |
| S-09 | Reset password | `POST /auth/password/reset` | ❌ G1 |
| S-10 | Wrong-role sheet with "Become a driver", which leads to D-01 | `POST /drivers/me` | ✅ |

### 4b. Passenger
| ID | Screen | Endpoints | API |
|---|---|---|---|
| P-01 | **Home** (P5: map, favourite routes, subscribe banner, SOS) in the passenger tab bar (decision 12). Built 1 Oct 2026. P5 has no upcoming-trip card, so `GET /bookings` isn't used yet | `GET /stops/nearby`, `GET /users/me/favourite-routes` (G4), `GET /vehicles/nearby` (G16) | ✅ banner behind `subscriptions` (G14); SOS needs G19 |
| P-02 | **Search** (from, to, when; not in Figma, decision 19). Built 2 Oct 2026: Current location or a chosen stop, stop search, nearby stops, favourites, last 5 searches | `GET /stops?q=`, `GET /stops/nearby`, `GET /users/me/favourite-routes` | ✅ |
| P-03 | **Search results** (P6). Built 2 Oct 2026: filter pills (decision 22, sorted and filtered by the backend since 10 Oct), pages, save route. Since 10 Oct 2026 live shows the full design: the passenger's fare with the saving (G20), vehicles approaching or passed (G21) | `GET /trips/search` (+ `pickup_latitude` / `pickup_longitude`, `sort`, `vehicle_type`), `POST /users/me/favourite-routes` | ✅ |
| P-04 | Trip details | `GET /trips/{id}`, `GET /routes/{id}` | ✅ |
| P-05 | **Seat selection** (P7). Built 2 Oct 2026: the map drawn from the seat rows and columns (decision 25), refreshed every 10 s, up to 10 seats; the fare from the backend's quote for the stops and seats (since 10 Oct 2026); Reserve holds the seats (passengers per decision 23) | `GET /trips/{id}/seats`, `GET /trips/{id}/fare-quote`, `POST /bookings` (`Idempotency-Key`) | ✅ |
| P-06 | Passenger details + booking review. Not built: decision 23 names the passengers without asking, and Payment shows the review | `POST /bookings` | ✅ |
| P-07 | Payment method. **Placeholder** since 2 Oct 2026: the held booking (reference, seats, fare, fee, total), a countdown to `expires_at`, Cancel booking; Home reopens an unpaid hold after a restart | `POST /bookings/{id}/pay`, `GET /wallet`; the placeholder uses `POST /bookings/{id}/cancel`, `GET /bookings?status=pending,payment_pending&upcoming=true` | ✅ |
| P-08 | Approve on your phone (MoMo pending) | `POST /payments/{id}/sync` (poll) | ✅ |
| P-09 | Payment success / failed | `GET /bookings/{id}` | ✅ |
| P-10 | Ticket (QR) | `GET /bookings/{id}/tickets`, `GET /tickets/{id}` | ✅ |
| P-11 | Live bus tracking (map + ETA) | WS track, `GET /trips/{id}/location`, `/eta` | ✅ |
| P-12 | SOS (confirm + sent) | `POST /trips/{id}/sos`, `GET /sos/{id}` | ✅ |
| P-13 | Report incident | `POST /trips/{id}/incidents` | ✅ |
| P-14 | Rate driver (single 1–5 score + comment) | `POST /bookings/{id}/rating` | ✅ (categories = G13) |
| P-15 | Trip history (upcoming / past) | `GET /bookings` + one `GET /trips/{id}` per booking | ⚠️ G12 |
| P-16 | Booking details + cancel | `GET /bookings/{id}`, `POST /bookings/{id}/cancel` | ✅ |
| P-17 | Wallet | `GET /wallet`, `GET /wallet/transactions` | ✅ |
| P-18 | Top up wallet | `POST /wallet/topups` → P-08 | ✅ |
| P-19 | Payment history | `GET /payments` | ✅ |
| P-20 | Notifications | `GET /notifications`, `POST /notifications/{id}/read` | ✅ |
| P-21 | Profile | `GET/PATCH /users/me` | ⚠️ G5 (photo) |
| P-22 | Emergency contacts | `/users/me/emergency-contacts` (CRUD) | ✅ |
| P-23 | Notification settings | `GET/PATCH /users/me/notification-preferences` | ✅ |
| P-24 | Complaints (file + list) | `POST/GET /complaints` | ✅ |
| P-25 | Settings (sessions, sign out, delete account, switch mode) | `/auth/sessions`, `/auth/logout`, `DELETE /users/me` | ✅ |
| P-26 | Favourite routes | `GET/POST/DELETE /users/me/favourite-routes` | ✅ (G4 done in backend 0.12.0) |
| P-27 | Subscribe (recurring commute) | none | ❌ G14 |

### 4c. Driver
| ID | Screen | Endpoints | API |
|---|---|---|---|
| D-01 | Driver onboarding (licence details) | `POST /drivers/me` | ✅ |
| D-02 | Upload documents (licence, insurance, photo…) | `POST/GET /drivers/me/documents` | ✅ |
| D-03 | Awaiting approval / rejected | `GET /drivers/me` (approval status) | ✅ |
| D-04 | Driver dashboard (today's trips) | none that lists the driver's trips | ❌ G2 |
| D-05 | Active trip (start / pause / resume / end + map) | `/driver-trips/{id}/start, pause, resume, end`, `/location` (GPS every 5–10 s) | ✅ |
| D-06 | Passenger list (manifest) | none | ❌ G3 |
| D-07 | QR scanner + result | `POST /driver-trips/{id}/tickets/validate` | ✅ |
| D-08 | Earnings (daily / weekly / monthly) | `GET /wallet/transactions`, filtered in the app on `reference_type == "trip_earning"` (no server filter, so the app pages through everything) | ⚠️ G7 |
| D-09 | Wallet + withdraw | `GET /wallet`, `POST/GET /wallet/withdrawals` | ✅ |
| D-10 | Driver profile + vehicle | `GET/PATCH /drivers/me`, `GET /drivers/me/assignments` | ✅ |
| D-11 | Driver SOS / incident | `POST /trips/{id}/sos`, `/incidents` | ✅ |
| D-12 | Driver settings / notifications | same as P-20, P-23, P-25 | ✅ |

---

## 5. Screen inventory, web apps

### 5a. Admin web
Not built in Flutter. The admin web app is the React dashboard in `TroSky/admin-dashboard`
(Maahir), with its own screens, tests and CI: see its README. The Flutter `admin_web` placeholder
and its planned screens A-01 to A-14 were removed (`design-decisions.md`, 26).

### 5b. Fleet owner web (`fleet_web`)
| ID | Screen | Endpoints | API |
|---|---|---|---|
| F-01 | Fleet owner sign up / login | `POST /auth/register` (role `fleet_owner`), `/auth/login` | ✅ |
| F-02 | Company profile setup | `POST/GET /fleet-owners/me` | ✅ |
| F-03 | Fleets (create / list / edit) | `POST/GET/PATCH /fleets` | ✅ |
| F-04 | Fleet dashboard (revenue, trips, ratings) | `GET /fleets/{id}/analytics` | ✅ |
| F-05 | Vehicles (list, add, edit) | `/fleets/{id}/vehicles`, `/vehicles/{id}` | ✅ |
| F-06 | Vehicle documents | `/vehicles/{id}/documents` | ✅ |
| F-07 | Seat layout editor | `PUT/GET /vehicles/{id}/seat-layout` | ✅ |
| F-08 | Assign / unassign driver | `/vehicles/{id}/assign-driver` (needs a `driver_id`) | ❌ G10 |
| F-09 | Live fleet status | none | ❌ G8 |

---

## 6. Backend gaps

Ranked by how badly each blocks the frontend. Most are small additions to routers that already exist.

**Backend 0.12.0 (1 Oct 2026) built G1, G2, G3, G4, G5, G7, G8, G9, G10, G12, G13 and G16**, to the shapes in `backend-requests.md`. G11 and the design gaps below remain; G19 is new.

| ID | Gap | Blocks | Suggested fix |
|---|---|---|---|
| **G2** | **A driver can't list their assigned trips.** `/drivers/me/assignments` returns vehicles only, so the driver app has no `trip_id` to start | D-04, D-05, the whole driver flow | `GET /drivers/me/trips?status=&date=` |
| **G3** | **No passenger manifest** for a trip | D-06 | `GET /driver-trips/{trip_id}/passengers` (seat, name, boarded yes/no) |
| **G1** | Password reset needs a ≥20-character `token`, which can't be typed from an SMS | S-09 | Accept a 6-digit OTP (`purpose=password_reset`), or have `verify-otp` return a reset token |
| G8 | No list of active trips / live positions for admin and fleet owners, and no admin trip list | Admin trips and live map, F-09 | `GET /admin/trips?status=`, `GET /admin/live-trips`, fleet-scoped equivalent |
| G10 | A fleet owner can't search for or invite drivers to get a `driver_id` | F-08 | `GET /fleets/{id}/drivers` + search by phone |
| G7 | No earnings summary endpoint (SRS FR-010) | D-08 (works with app-side totals) | `GET /drivers/me/earnings?period=day\|week\|month` |
| G5 | No profile photo upload (only `avatar_url`) | P-21 | `POST /users/me/avatar` (reuse the S3 upload used for documents) |
| G4 | No favourite routes (SRS FR-003) | P-26 | `/users/me/favourite-routes` CRUD |
| G9 | Routes and stops can be created but not edited or deleted | Admin stops and routes | PATCH/DELETE for both |
| G11 | Telecel, AirtelTigo and card payments are placeholders | P-07 | Already known; the UI shows "Coming soon" |
| G12 | `GET /bookings` has no status or date filter, and bookings don't include departure time | P-01, P-15 (the app makes one extra request per booking) | `?status=&upcoming=true` and embed a trip summary |
| G13 | The rating is a single score. The SRS asked for safety, cleanliness, professionalism and timeliness | P-14 (only if the Figma "Rate Driver" screen shows categories) | Optional category scores |
| G19 (done, 0.13.0) | An SOS needs a trip (`POST /trips/{trip_id}/sos`), but Home shows SOS at all times | P-01's SOS button, P-12 outside a trip | `POST /sos` with an optional `trip_id` (decision 18) |

### Gaps the Figma design creates (it shows features the backend doesn't have)
| ID | Design shows | Backend today | Decision needed |
|---|---|---|---|
| **G14** | **Subscribe your commute**: onboarding 3, the Home banner and a Subscribe screen ("save up to 40% with a monthly plan") | No subscription model or endpoints | Build the backend feature, or hide it for the MVP |
| **G15** | **Fare splitting**: onboarding 2 says "as more passengers board, the cost splits", with per-seat prices changing | Each trip has one fixed `fare_amount` | Is the fare dynamic? If yes, this is a pricing change in the backend |
| G16 | Home map with **nearby vehicle clusters** (badges 5, 2) | Only per-trip location (`/trips/{id}/location`) | Add a "vehicles near me" endpoint, or show nearby **stops** (which exist) instead |
| G17 | Sign-up card: "Optionally verify your Ghana Card" | `ghana_card_number` and `ghana_card_verified` fields exist, but no verification endpoint | Hide the card for the MVP, or add an endpoint |
| **G18** | **Sign up is phone → Send OTP only** (passwordless) with a "Continue with Email" option | Register requires phone + **Gmail** email + name + password, *then* the OTP | Decided 1 Oct 2026: keep the backend; see design-decisions.md, decision 6 |

---

## 7. Screenshot request order

I'll ask for these one batch at a time. Each batch is built, tested and committed before the next.

| Batch | Screens | What I need |
|---|---|---|
| 0 — Design tokens | none | ✅ Received (`globals.css`), captured in `docs/design-tokens.md` |
| 1 | S-01, S-02 | ✅ Screenshots received. Built by `prompts/01-foundation-splash-onboarding.md`. The role chooser (S-03) is waiting on Q5 |
| 2 | S-04 → S-10 | Sign in, OTP sign in, sign up, OTP, forgot/reset password, wrong-role message |
| 3 | P-01 → P-04 | Passenger home, search, results, trip details |
| 4 | P-05 → P-10 | Seats, review, payment, MoMo pending, success, ticket |
| 5 | P-11 → P-14 | Tracking, SOS, incident, rating |
| 6 | P-15 → P-26 | Trips, wallet, profile, settings… |
| 7 | D-01 → D-12 | Driver app (after G2 and G3 are fixed) |
| 8 | — | Admin web: the React app in `TroSky/admin-dashboard` (`design-decisions.md`, 26) |
| 9 | F-01 → F-09 | Fleet owner web |

---

## 8. Open questions

- ~~Q1. Can one person be both passenger and driver?~~ **Answered: yes.** See §2.
- **Q2.** Should drivers see the onboarding slides, or go straight from the role chooser to sign in?
- **Q3.** Do the admin and fleet owner web apps have their own Figma screens in the Make file, or only the mobile app?
- **Q4. Sign-up flow (G18).** *Answered 1 Oct 2026: (a). The "Your details" step is built from existing components (design-decisions.md, decision 6).* The design is phone → OTP. The backend needs phone, email, name and password. Options:
  - (a) Keep the backend. The design's first screen stays as it is, and a second "Your details" step collects name, email and password before the code is sent. This needs a design for that step.
  - (b) Change the backend to phone-OTP sign-up (no password, email optional), which matches the design.
- **Q5.** Is there a **role chooser** (Passenger / Driver) screen in Figma? It isn't in the Passenger App list. Without one we would have to invent it, which the rules forbid. *Answered 1 Oct 2026: there is no chooser. The Welcome screen has a "Driving for TroSky? Sign up as a driver" link (design-decisions.md, decision 7).*
- **Q6.** G14 subscriptions and G15 fare-split: MVP features or not?
