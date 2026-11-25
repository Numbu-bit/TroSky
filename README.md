# TroSky

Ghanaian shared-transport app: a Flutter mobile app on a FastAPI backend, with a React admin
dashboard and a fare engine and seat allocation service. See `TroSky/frontend/CLAUDE.md` and
`TroSky/backend/README.md` for per-module instructions.

## How to test

Owner-facing walkthrough. Tester APKs live in `Desktop\TroSky staging APK\` and are always
built from `main` (per-PR builds get a `-prNN` suffix and are deleted after the test). Install
with `adb install -r <path>`. Record every phone test with `adb shell screenrecord` into
`Desktop\TroSky test videos\<date>-<what>.mp4`.

### Test accounts (demo + staging seed)

| Account | Identifier | Password | Notes |
|---|---|---|---|
| Demo passenger | `0244 000 001` | `TroSky2026` | Mock-mode seed; on-device without a backend. |
| Staging passenger | `0244 000 101` | `TroSky2026` | Render staging; has booking history + saved routes. |
| Staging driver | `0244 000 201` | `TroSky2026` | Approved driver; has assigned trips. |

OTPs during sign-up go via the backend SMS stub — grab the latest code from
`docker logs trosky-api 2>&1 | grep 'otp='` for a local run, or from the Render staging logs.

### Build command

A full staging build the owner can hand to a tester:

```bash
flutter build apk --release \
  --dart-define-from-file=env/staging.json \
  --dart-define=TESTER_MENU=true \
  --obfuscate --split-debug-info=build/symbols
```

Switch `env/staging.json` for `env/prod.example.json` after it's filled with the real prod API
host — `DEPLOY_ENV=prod` rejects placeholder hosts, `http://`, `ws://` and `TESTER_MENU=true`
at parse time. Env parsing is fail-loud for every deploy (step 21/A2): a missing
`DEPLOY_ENV`, `API_MODE`, `API_BASE_URL`, `WS_BASE_URL` or `HELP_CENTRE_URL` throws at startup
in release builds.

### Install + first-run

1. `adb install -r <path>` from `Desktop\TroSky staging APK\`.
2. Open the app. The splash fades to Welcome (cold start, ~2 s).
3. The app wakes the Render backend automatically — no Retry button. The banner reads
   "Waking up the server… usually under a minute" and clears once the first request lands
   (seed only when the DB is empty; 28 Oct faster-wake change).

### Features — one-line how-to each

- **Sign in / Sign up / Reset password.** Welcome → Sign in. Reset: Sign in → "Forgot
  password?" → enter identifier → backend sends a 6-digit code (same confirmation whether
  the account exists or not — no existence leak) → enter code + new password; backend
  signs every session out.
- **Home + search.** Greeting at the top (7-tap area for the tester menu — see below).
  "Where are you going?" opens the search sheet. The results screen shows today's trips;
  a late-evening search with none left today auto-loads tomorrow's first departures and
  shows a `Tomorrow, EEE d MMM` chip. Subscriptions banner (decision 16) shows in mock
  mode only.
- **Seat selection + Payment.** Pick a seat → MoMo. Sandbox cases: success (any valid
  Ghanaian number), fail with `0000` suffix, timeout with `9999` suffix. Payment polls
  `/payments/{id}/sync`.
- **Trips tab.** Upcoming / Past tabs. Tap a booking → details. Each booking carries its
  own status line ("Confirmed", "Boarding at origin", "Cancelled by you · <reason>",
  etc.).
- **Ticket QR.** Open from a confirmed booking. Swipe between seats, one QR per seat.
  The QR is signed and cached locally so it works offline. Save PNG and Share both
  hit the system sheet. Screenshots are blocked on this screen (FLAG_SECURE / privacy
  cover; H1).
- **Trip Details.** Driver avatar + Call / Message buttons (verified pill when the
  phone is verified). Stops with times. Ride length shown live when the trip starts.
- **Live tracking.** Opens when boarding begins. WS first, falls back to polling every
  5–10 s with the fallback banner. Live-fare tile updates as riders board.
- **Cancel reasons.** Three entry points — Payment "Cancel booking", Payment back →
  "Release seats", Trips → "Cancel" — all open the same reason sheet
  (`showCancelBookingSheet`). Once cancelled: "Cancelled by you · <reason>" or
  "Cancelled by TroSky · <reason>" or "Expired · Not paid in time".
- **Wallet.** Payment methods list, transactions list, Top up. Top-up uses an
  idempotency key so a double-tap can't double-charge; a returning user resumes the
  same request.
- **Safety: SOS.** Reachable within 2 taps during a trip. Hold-to-send (3 s) to avoid
  accidental triggers; releases before the hold completes cancel. Opens Call 191 and
  optionally sends an alert with the latest coordinates. Location is shared only if
  you grant permission — screenshot shows "Location not shared" otherwise.
- **Safety: Report.** Trip Details → "Report issue". Category picker → description
  (≥10 chars). Photo attach is deferred.
- **Safety: Rate.** After a completed trip, 1–5 stars. Submit is disabled until at
  least one star is picked. The "rate on Trips" banner is a deferred follow-up.
- **Account: Profile.** Avatar, name, verified status, Personal info, Reset password,
  Preferences, Delete account, Sign out.
- **Account: Personal info.** First name, last name, email, phone — read-only except
  for name + email (changes rotate the session; phone changes are deferred).
- **Account: Reset password.** Same flow as the Sign-in reset path, but reached via
  Profile when already signed in.
- **Account: Delete account.** Two confirmations, backend soft-deletes, sessions revoked.
- **Notifications.** Inbox + preferences (SMS/email). Unread bell on Home; tapping
  opens the inbox. Mark-read is server-side with optimistic UI. Push via FCM is a
  deferred follow-up.
- **Favourites.** Profile → Favourite routes. Add/edit/delete. The draggable Home
  sheet integration is a deferred follow-up.
- **Tester menu.** Staging / demo only (`TESTER_MENU=true`). On Home, tap the greeting
  7 times within 3 s. Actions: Wake server, Top up wallet ₵100, Show onboarding again,
  Sign out & clear data. The sheet header documents the trigger spot. Release APKs
  tree-shake the entire menu — not present in a production build.

### Security posture (summary)

- Release builds are **R8-shrunk + obfuscated** (`--obfuscate
  --split-debug-info=build/symbols`), symbols archived off-device.
- **FLAG_SECURE** (Android) + an iOS privacy cover on every sensitive screen (Ticket QR,
  OTP entry, password fields, PII edit, MoMo). See `apps/mobile/lib/app/secure_window.dart`.
- **Backup isolation**: `android:allowBackup` on, but the backup rules exclude secrets,
  the Hive encrypted boxes, and the refresh token store. See
  `apps/mobile/android/app/src/main/res/xml/backup_rules.xml` (H5).
- **TLS hardening**: `cleartextTrafficPermitted=false` in `network_security_config.xml`;
  prod builds reject `http://` / `ws://` at parse time (Env strict rules). Cert pinning is
  a deferred follow-up.
- **Secrets**: refresh tokens in flutter_secure_storage (platform Keystore/Keychain);
  other PII in Hive with an AES key stored in secure storage. Sign-out wipes an explicit
  allow-list — never `prefs.clear()`.
- **PII in logs/telemetry**: phone numbers, names, coordinates, tokens are never logged,
  never sent to analytics, never in crash breadcrumbs. Booking ids are hashed.

Runbooks per feature: `docs/` (incident response, release checklist, security posture).

### Known deferrals (tiny follow-up PRs)

- Rate banner on Trips (Step 21).
- Search favourite chips (Step 21).
- Avatar upload on Personal info (Step 21).
- Photo attach on Report (Step 21).
- Push notifications via FCM (Step 21).
- Marker tween on the live-tracking map respecting reduced-motion (Step 21/B D-7).
- Draggable Home sheet for favourites (Step 21).
- H1 Wallet sheet wrap (post-H1).
- H3 app-lock UI (controller shipped, UI deferred).
- Certificate pinning (post-launch).

See `TroSky/frontend/docs/a11y-audit-nov-2026.md` for the full accessibility deferral
list with per-screen notes.
