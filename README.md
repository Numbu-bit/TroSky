# TroSky

Ghanaian shared-transport app: a Flutter mobile app on a FastAPI backend, with a React admin
dashboard and a fare engine and seat allocation service. See `TroSky/frontend/CLAUDE.md` and
`TroSky/backend/README.md` for per-module instructions.

## How to test

Owner-facing walkthrough. Tester APKs live in `Desktop\TroSky staging APK\`. Install with
`adb install -r <path>`. Record every phone test with `adb shell screenrecord` into
`Desktop\TroSky test videos\<date>-<what>.mp4`.

### Wake on open
The app wakes the Render backend automatically on launch — no Retry button. The banner reads
"Waking up the server… usually under a minute" and clears itself once the first request lands.

### No more trips today
A late-evening search that has no trips left today auto-loads tomorrow's first departures and
shows a `Tomorrow, EEE d MMM` chip above the list (empty-state subline: "Showing tomorrow's first
trips instead"). To reach it on camera when today still has trips, change the device clock
forward or pick a date in the search sheet.

### Cancel reasons
Every cancel path — Payment "Cancel booking", Payment back → "Release seats", Trips →
"Cancel" — opens the same reason sheet (`showCancelBookingSheet`). Once cancelled, the booking
line reads:
- "Cancelled by you · \<reason\>" for passenger cancels,
- "Cancelled by TroSky · \<reason\>" for ops/driver cancels,
- "Expired · Not paid in time" for payment-timeout cancels.

### Tester menu
Staging and demo builds only (`TESTER_MENU=true`). On Home, tap the greeting 7 times within
3 s to open. Actions: Wake server, Top up wallet ₵100, Show onboarding again, Sign out & clear
data. The sheet header documents the trigger spot. Release APKs tree-shake the whole menu — it
is not present in a production build.
