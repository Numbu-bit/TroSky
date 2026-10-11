# Staging check, 11 Oct 2026

The first end-to-end run against the live Render server, `https://trosky-api.onrender.com`
(Blueprint-managed, backend from `main`).

- **App:** a release APK built from `main` at `1f95a5d` with `env/staging.example.json`
  (`API_MODE=live`). Universal (arm64-v8a, armeabi-v7a, x86_64), 60.2 MB, signed with the debug key.
- **Phone:** TECNO BG6 on **mobile data**. Its Wi-Fi was off (in hotspot mode), and there was no adb
  reverse.
- **Test accounts:** made-up Gmail addresses (`REGISTRATION_EMAIL_DOMAINS`). The console email
  provider never sends mail; the codes were read from Render's log.

## The app, step by step

| # | Step | Screenshot | Result |
|---|---|---|---|
| 1 | Splash | [01](01-splash.png) | ✅ |
| 2 | Onboarding → Skip | [02](02-onboarding.png) | ✅ |
| 3 | Welcome, phone number | [03](03-welcome.png), [04](04-phone-entered.png) | ✅ |
| 4 | Your details → Create account | [05](05-details.png) | ✅ Registered with **no location** (sign-up check off on staging) |
| 5 | Enter the code (from Render's log) | [06](06-code-screen.png), [07](07-code-typed.png) | ✅ Verified and signed in |
| 6 | Home ("Not now" to location, so the map is on Accra) | [08](08-home-location-prompt.png), [09](09-home.png) | ✅ "Good evening, Phone Test Rider" |
| 7 | Search Accra Madina → Accra Circle | [10](10-search-madina-circle.png), [11](11-results.png) | ✅ 4 demo minibuses (19:30–21:00) |
| 8 | Seat Selection | [12](12-seat-selection.png), [13](13-seat-chosen.png) | ✅ Live fare quote: ₵8.00 now, drops to ₵2.00 |
| 9 | Reserve seat B2 | [14](14-reserved-payment.png) | ⚠️ Booked (TRK-N27NROS6, ₵8.50 with fee), but **awaiting acceptance**: see below |
| 10 | Cancel booking | [15](15-cancelled.png) | ✅ "Booking cancelled. Your seats are free again." The server says `cancelled` |

**Finding:** the booking was `awaiting_acceptance`, with `expires_at` 2 minutes after creation, so
`BOOKING_ACCEPTANCE_REQUIRED` was still **true** on Render although it was meant to be `false`. The
app doesn't know that state yet. Its Payment screen shows the driver's 2-minute window as "Seats
held for 02:00", where acceptance off would give 10 minutes to pay. Check the start log line
`booking acceptance by the driver: …`. Changes made in the dashboard to a Blueprint-managed
variable are overwritten whenever `render.yaml` changes and the Blueprint syncs (it sets `"true"`).

## API smoke test (from a PC, timed)

| Call | Status | Time |
|---|---|---|
| `GET /health/live`, first request (server waking) | 200 | **26.1 s** |
| `POST /auth/register`, no latitude/longitude | 201 | 4.06 s |
| `POST /auth/verify-otp` (code from the log) | 200 | 1.03 s |
| `POST /auth/login` | 200 | 2.12 s |
| `GET /users/me` | 200 (passenger) | 0.88 s |
| `POST /auth/refresh` | 200 | 0.60 s |
| `POST /auth/logout` | 204 | 0.73 s |
| `POST /auth/refresh` after logout | 401 (rejected) | 0.90 s |

- **Earlier cold start:** while the service was restarting, one `/health/live` request timed out
  after 120 s; the next one answered in 4.7 s.
- **Demo data:** the demo passenger (0245550201) signs in, and the demo stops and timetable are
  there.

## Rate limits (`TroSky/backend/docs/deploy-render.md`)

1. **Proxy address:** Render's health checks come from `10.231.24.45`, inside `10.0.0.0/8`. Still
   to read: the `client_ip` of an outside request in the log.
2. **Each client its own limit:** not shown. The PC was on the phone's hotspot, so both had one
   public IP, and the phone's sign-in after the PC's 11th try was refused too ("Too many tries"),
   as expected for one address. Repeat with a second phone on another network.
3. **Can't choose its own address:** ✅ The 11th wrong login gave 429, and with
   `X-Forwarded-For: 203.0.113.7` it was still 429.
