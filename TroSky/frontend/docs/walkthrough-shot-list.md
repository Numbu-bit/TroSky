# Walkthrough video — shot list (Nov 2026)

One-page script the owner follows on their own phone. Target total
length ≤ 4 min. Each scene has a target duration and the expected
behaviour so the owner knows what "correct" looks like before pressing
record.

- **Phone**: TECNO BG6 (reference device) over `adb shell screenrecord`.
- **Build**: latest `Desktop\TroSky staging APK\<file>.apk` from `main`.
- **Backend**: Render staging. Wake it 60 s before filming by opening
  the app once; the first launch triggers the wake banner for ~1 min.
- **Save to**: `Desktop\TroSky test videos\2026-11-walkthrough.mp4`.

## Scenes (in order)

### 1 · Cold start + wake banner — 15 s
- Account: n/a (not signed in yet).
- Open the app from cold. Splash fades to Welcome.
- Expected: "Waking up the server… usually under a minute" banner
  appears at the top, then clears within ~60 s. The banner does not
  have a Retry button.

### 2 · Sign in + Home with bell + tester menu — 25 s
- Account: **staging passenger** (`0244 000 101` / `TroSky2026`).
- Sign in → land on Home. Point at the bell top-right; if it has a
  red dot, briefly tap through the inbox and back.
- Tap the greeting 7 times within 3 seconds. Expected: tester-menu
  bottom sheet opens. Close it.
- Expected: the greeting is a precise 48dp tap area — if the app
  doesn't open the menu after 7 taps, keep each tap on the greeting
  text, not the space beside it.

### 3 · Search with empty-today fallback — 25 s
- Account: same as above.
- Tap "Where are you going?" → pick an origin + destination (any pair
  the staging seed has; "Madina → Circle" is safe).
- If the time of day has no trips left, expect the `Tomorrow, EEE d MMM`
  chip + "Showing tomorrow's first trips instead" subline.
- If filming during the day, change device clock to 23:30 first so
  this scene reaches the fallback.

### 4 · Seat selection + Payment + Cancel reason — 40 s
- Account: same.
- Pick a trip → pick seat #4 → Continue → Payment screen (MoMo).
- Enter a sandbox MoMo number with `9999` suffix (timeout case) → tap
  pay → wait for the pending state. Back out with the back arrow →
  "Release seats" prompts the cancel-reason sheet.
- Pick "Changed my mind" → booking ends up as "Cancelled by you ·
  Changed my mind".

### 5 · Payment success + ticket QR swipe + Save — 35 s
- Account: same, same trip or any confirmed booking.
- From Trips, tap an upcoming booking that's paid → "Show ticket".
- Swipe horizontally between seat pages (expect smooth page change;
  hero widgets stay stable).
- Expected: the OS prevents screenshots on this screen (both
  FLAG_SECURE on Android and the privacy cover on iOS). The recorder
  will capture it only because `screenrecord` bypasses that for adb;
  the phone's own screenshot shortcut would see black.
- Tap Save → the file lands in the Downloads folder (toast confirms).
  Tap Share → system sheet.

### 6 · Trip Details + Live tracking — 30 s
- Account: same, pick a trip that's in progress.
- From the ticket, tap "Trip details" → driver name, avatar, verified
  pill (if verified), Call / Message buttons appear.
- Tap "Track" → map opens, WS connects. If WS takes >2 s the fallback
  banner reads "Using polling — reconnecting…".
- Point at the live-fare tile; the number updates as more riders
  board.

### 7 · Wallet top-up — 25 s
- Account: same.
- Profile → Wallet → Top up.
- Enter ₵50 → MoMo sandbox success number → confirm.
- Expected: the transaction appears in the list within 2 s with the
  balance updated. Repeat the tap on Top up immediately — the
  idempotency key means the same request resumes, not a second
  charge.

### 8 · SOS hold-to-send (cancel before 3 s) — 25 s
- Account: same, mid-trip.
- From Trip Details, tap SOS (should be reachable within 2 taps).
- The SOS screen opens, big red button in the middle.
- Press and hold the SOS button for ~2 seconds, then release. Expected:
  the ring fills part-way then resets; the alert is NOT sent (no
  "Sending alert…" state, no confirmation).
- Point at Call 191 button — should sit above the hold button.

### 9 · Profile + Sign out — 20 s
- Account: same.
- Profile → scroll through: Personal info, Reset password,
  Preferences, Favourite routes, Delete account.
- Tap Sign out → confirm.
- Expected: land back on Welcome. Sign in again to confirm there's
  no leaked state.

## Notes

- Keep each scene's narration to one sentence; the point is the
  behaviour, not voice-over.
- If a scene doesn't match "expected", stop recording and file a
  bug — don't ad-lib around it.
- Total time target: ~4 min. If a scene slips, trim scene 4 or 6
  first; 1–3, 5, 7–9 are the load-bearing ones.
