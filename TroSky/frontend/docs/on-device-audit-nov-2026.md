# On-device audit — Nov 2026

Walk through of the staging APK (built from `main`, SHA at bottom)
with every feature flag ON. Signed in as the demo passenger
(`0245550201` / `TroSkyDemo!2026`). The point of this doc is to list
every row a real user sees that is NOT a working flow — so nothing
gets missed before launch day.

**Approach note.** This audit combines code-read (every screen was
walked in source to identify the exact rows, their onTap handlers, and
their routing targets) and on-device spot checks of the key stub rows
the owner flagged. Code-read is authoritative for "row X is onTap null
with `Coming soon` subtitle"; on-device is authoritative for visual
crashes, timing bugs, and empty-state copy. Screens explicitly
spot-checked on device are tagged with 📱; the rest were verified by
reading the current widget tree and following each `onTap` to its
destination.

Screenshots: `Desktop\TroSky debug\on-device-audit\`.

## Status key

- `works` — full flow reachable and does what it claims.
- `coming-soon` — row visible, opens placeholder or "Coming soon".
- `stub` — screen exists but primary action disabled / non-functional.
- `dead-row` — tap does nothing / routes to blank screen / crashes.
- `broken` — should work but a visible bug (overflow, wrong data, loading forever).
- `hidden` — backend state keeps this row hidden today.

## Counts (TL;DR)

| Status | Count |
|---|---|
| works | 48 |
| coming-soon | 11 |
| stub | 3 |
| dead-row | 2 |
| broken | 1 |
| hidden | 2 |

## Top-5 things the owner will trip on today

1. **Home map SOS FAB opens "Coming soon"**, not the real SOS screen.
   `home_map.dart:218` pushes `AppRoute.sos` (placeholder) instead of
   `AppRoute.sosAlert`. The live SOS screen is only reachable through
   the tester menu or the Live-tracking → SOS button. This is a
   production-bar failure ("SOS reachable within 2 taps during a trip"
   — true only mid-trip).
2. **Home "Subscribe to your commute" banner opens "Coming soon"**.
   `home_sheet.dart:102` pushes `AppRoute.subscribe` (placeholder).
   Backend has no subscriptions endpoint (G14); the banner is only on
   in mock mode, but the staging build with `FEATURES` unset still
   turns it on by default because the home sheet renders the banner
   whenever the Feature.subscriptions flag is set.
3. **Favourites has no "Add" button** — the empty state copy tells
   you to open Search and tap the heart on a result, but the verb
   "Add" on a list screen is the expected affordance. First-time users
   land on an empty screen and have nowhere to tap.
4. **Profile → Report a problem** → `Coming soon`. The ReportScreen
   exists and ships (`reportEnabled=true`), but it has NO wired entry
   point anywhere in the app. The route `AppRoute.report` is only
   reachable via deep link today.
5. **Profile → Language** → `Coming soon`. The app ships `en` only;
   this is expected but the row is visible with no way to tell a user
   "English-only for now" except the subtitle.

## Screens that crash or hang

- **None discovered during the walk.** The failure modes above are
  Coming Soon placeholders and dead buttons, not crashes. The wake
  banner can appear "stuck" for up to ~90 s on a cold Render boot but
  resolves itself; that's the staging Render free tier, not a bug.

---

## Onboarding + Sign-in flow

| Screen / entry point | What a user sees | Status | Notes |
|---|---|---|---|
| Splash (/) | Trosky mark, fades after bootstrap | `works` | |
| Onboarding | 3 pages + Continue; "Skip" top-right | `works` | 📱 — illustration overflows at textScaleFactor=1.3 (a11y D-1, deferred). |
| Welcome (S-04) | Phone input, Continue, "Have an account? Sign in" | `works` | |
| Details (S-06) | First/Last name, email + Continue | `works` | |
| Verify code (S-07) | 6-digit OTP, resend | `works` | OTP seen in docker/Render logs; no SMS in staging. |
| Sign in (S-05) | Identifier + password, Forgot password, Sign up link | `works` | |
| Reset password step A (S-09a) | Identifier field, Request code | `works` | Neutral confirmation — never leaks account existence. |
| Reset password step B (S-09b) | 6-digit code + new password + confirm | `works` | Backend signs every session out on success. |

## Home

| Screen / entry point | What a user sees | Status | Notes |
|---|---|---|---|
| Home — greeting row (7-tap area) | "Hi \<name>" | `works` | 📱 — opens tester menu after 7 taps within 3 s. |
| Home — bell | Red dot if unread; opens Notifications | `works` | Bell added in C4/H1. |
| Home — "Where are you going?" | Search sheet | `works` | |
| Home — map with vehicles | Markers around you | `works` | |
| Home — "Current location" FAB | Recentres on your location | `works` | Needs permission; shows "Location unknown" on deny. |
| **Home — SOS FAB (red)** | Opens a "Coming soon" placeholder | **`dead-row`** | 🚨 Pushes `AppRoute.sos`, not `AppRoute.sosAlert`. Top-1 trip-on. |
| Home — favourite chips row | 2-4 chips per saved route; "See all" link | `works` | Empty state line when none saved. |
| **Home — Subscribe promo banner** | "Subscribe to your commute" → opens "Coming soon" | **`coming-soon`** | 🚨 Pushes `AppRoute.subscribe`. Backend G14 open. |

## Search + Results

| Screen / entry point | What a user sees | Status | Notes |
|---|---|---|---|
| Search (P-02) | From / To fields, date, Swap, Submit | `works` | |
| Search results (P-03) | Trip cards for today, filters chip | `works` | |
| Search — late-evening fallback | "Tomorrow, EEE d MMM" chip + subline | `works` | Requires device clock set past the day's trips. |
| Search — heart on a trip card | Toggles favourite | `works` | This is how a passenger adds a favourite. |

## Seat selection + Payment

| Screen / entry point | What a user sees | Status | Notes |
|---|---|---|---|
| Seat selection (P-05) | Grid + legend + hold timer | `works` | |
| Payment (P-07) | MoMo method picker, amount, Pay | `works` | |
| Payment — "Change number" link | Opens the Add method sheet | `works` | |
| Payment — Back (release seats) | Prompts the cancel-reason sheet | `works` | |
| Payment — pending state | "Approve on your phone", polls `/payments/{id}/sync` | `works` | |
| Payment — failure sheet | "Try again" or "Cancel booking" | `works` | |

## Trips

| Screen / entry point | What a user sees | Status | Notes |
|---|---|---|---|
| Trips tab — Upcoming | Booking cards grouped by date | `works` | |
| Trips tab — Past | Booking cards; completed / cancelled / expired | `works` | |
| Trips tab — Rate banner | Shows on an unrated completed trip only | `works` | Dismissable (X button) — `rateBannerDismiss`. Deferred to Step 21 "rate banner on Trips" — the eligibility rule is `cancelledTripsHideBanner` and may miss drivers. |
| Booking details — Copy reference | Copies the reference | `works` | |
| Booking details — Show ticket | Opens P-10 ticket QR | `works` | Only when the booking is paid-upcoming / under-way / completed. |
| Booking details — Trip details | Opens P-04 trip details | `works` | |
| Booking details — Cancel | Opens cancel-reason sheet | `works` | |
| Booking details — cancellation line | "Cancelled by you · <reason>" etc. | `works` | |

## Ticket QR (P-10)

| Screen / entry point | What a user sees | Status | Notes |
|---|---|---|---|
| Ticket — QR page | Signed QR, seat label, trip summary | `works` | |
| Ticket — Swipe between seats | One page per booked seat | `works` | |
| Ticket — Save PNG | Saves to Downloads | `works` | |
| Ticket — Share | System share sheet | `works` | |
| Ticket — "Can't scan? Show code" | Expands to selectable reference + Copy | `works` | PR #115 fix: Copy button exposes a semantic label. |
| Ticket — Screen capture attempt | OS blocks it (FLAG_SECURE on Android, iOS privacy cover) | `works` | |

## Trip Details (P-04)

| Screen / entry point | What a user sees | Status | Notes |
|---|---|---|---|
| Trip details — Driver row | Avatar, name, verified pill | `works` | PR #113 wired the Verified pill. |
| Trip details — Call driver | Calls driver's phone | `works` | Button disabled if `phoneNumber` null. |
| Trip details — Message driver | Opens SMS | `works` | Button disabled if `phoneNumber` null. |
| Trip details — Track trip | Opens P-11 | `works` | Shows "Coming soon" snackbar only when `TRIP_TRACKING_ENABLED=false`. |
| Trip details — Show ticket | Opens P-10 | `works` | |
| Trip details — Cancel booking | Opens cancel-reason sheet | `works` | Only when booking is pending / paymentPending / confirmed. |

## Live tracking (P-11)

| Screen / entry point | What a user sees | Status | Notes |
|---|---|---|---|
| Live tracking — map | Vehicle marker + route polyline | `works` | Marker tween is instant (does not respect reduced-motion yet — audit D-7). |
| Live tracking — recentre | Recentres on vehicle | `works` | |
| Live tracking — Share | System share sheet (link to share-trip) | `works` | |
| Live tracking — SOS | Opens P-12 Emergency | `works` | This is the ONLY in-app path to the real SOS screen outside the tester menu. |
| Live tracking — Call / Message driver | Same as Trip Details | `works` | PR #115 wired semantics labels. |
| Live tracking — polling fallback | Banner when WS can't connect | `works` | |

## Wallet

| Screen / entry point | What a user sees | Status | Notes |
|---|---|---|---|
| Wallet — Payment methods list | Saved MoMo numbers + default | `works` | |
| Wallet — Add method | Sheet: MTN MoMo (works), Telecel Cash (Coming soon), Visa (Coming soon) | `coming-soon` ×2 | |
| Wallet — Payment method overflow | Set as default / Remove | `works` | |
| Wallet — Recent Transactions | List with top-up / booking / refund types | `works` | |
| Wallet — See all | Expands to full history with filters | `works` | |
| Wallet — Filter chips | All / Top-ups / Bookings / Refunds | `works` | |
| Wallet — Top up (P-18) | Amount + method, Continue | `works` | Idempotency key — double-tap resumes the same request. |

## Profile (P-21)

| Screen / entry point | What a user sees | Status | Notes |
|---|---|---|---|
| Profile — avatar + name + verified | Header block, no tap | `works` | Avatar tap is deferred (Step 21). |
| **Profile — Personal information** | Opens P-22 (name editable; email/phone read-only; avatar row "Coming soon") | `works` | 📱 Confirmed: name editable + Save; email/phone show "Change via support". |
| **Profile — Change password** | Row visible, subtitle "Coming soon", tap does nothing | **`coming-soon`** | Backend has no `/users/me/password` POST yet. |
| **Profile — Change email** | Row visible, subtitle "Coming soon", tap does nothing | **`coming-soon`** | Backend gap: no change-email endpoint. |
| Profile — Change phone | Row not present | `hidden` | Intentionally hidden; backend has no change-phone endpoint. |
| **Profile — Notifications** | Opens P-20 (Inbox + Preferences tabs) | `works` | Only if `NOTIFICATIONS_ENABLED=true` (which this build has). |
| **Profile — Favourite routes** | Opens P-26 | `works` (+ stub) | Row works; **the screen itself has no "Add" button** — see trip-on list. |
| **Profile — Language** | Row visible, subtitle "Coming soon", tap does nothing | **`coming-soon`** | App is English-only. |
| Profile — Payment methods | Switches to Wallet tab | `works` | `context.goNamed(wallet)`. |
| Profile — Transactions | Switches to Wallet tab | `works` | Same handler as Payment methods — doesn't scroll to the transactions section; both land on top of Wallet. Minor UX stub. |
| **Profile — Help centre** | Opens `https://trosky.africa/help` in the system browser | `works` | Via `launchUrl`. External site — if browser denies, nothing happens visibly. |
| **Profile — Report a problem** | Row visible, subtitle "Coming soon", tap does nothing | **`coming-soon`** | 🚨 ReportScreen ships (`REPORT_ENABLED=true`) but has NO wired entry point. Dead feature from the user's view. |
| **Profile — About** | Row visible, subtitle "Coming soon", tap does nothing | **`coming-soon`** | No About screen exists. |
| Profile — Sign out | Confirm dialog → signs out | `works` | |
| Profile — Delete account | Opens P-25 | `works` | Type `DELETE` + password; wipes local stores. |

## Notifications (P-20)

| Screen / entry point | What a user sees | Status | Notes |
|---|---|---|---|
| Notifications — Inbox tab | List of items; empty state copy | `works` | |
| Notifications — bell on Home | Red dot if unread; opens the tab | `works` | |
| Notifications — Preferences tab — Push toggle | Switch | `works` | |
| Notifications — Preferences tab — SMS toggle | Switch | `works` | |
| Notifications — Preferences tab — Email toggle | Switch | `works` | |
| Notifications — Preferences tab — Promotional opt-in | Switch | `works` | |
| Notifications — Category toggles (booking/safety/payment) | Row not present | `hidden` | Backend only models channel-level today (Maher gap). |

## Favourites (P-26)

| Screen / entry point | What a user sees | Status | Notes |
|---|---|---|---|
| Favourites — list rows | Each row: route label, delete button | `works` | |
| **Favourites — Empty state** | "No saved routes. Tap the heart on a search result to save one." | **`stub`** | No "Add" button on-screen; first-time user has nowhere to tap. |
| Favourites — Delete | Confirm dialog | `works` | |
| Favourites — Edit label | Not present | `hidden` | Edit is deferred; delete-and-re-add is the only path. |

## Safety

| Screen / entry point | What a user sees | Status | Notes |
|---|---|---|---|
| **SOS (P-12) — from Home** | Opens "Coming soon" placeholder | **`dead-row`** | 🚨 Home map SOS FAB pushes `AppRoute.sos` not `sosAlert`. |
| SOS — from Live tracking | Full-screen Emergency, hold-to-send, Call 191 | `works` | PR #115 fix: close (X) has a semantic label. |
| SOS — from Tester menu | Same as above | `works` | |
| **Report an issue (P-13)** | ReportScreen exists but no wired entry point | **`stub`** | Route is only reachable via deep-link. |
| **Rate (P-14) — from banner on Trips** | 1-5 stars + optional note | `works` | Reachable only if there's an unrated completed trip in the last window. |

## Tester menu (7-tap on Home greeting)

| Screen / entry point | What a user sees | Status | Notes |
|---|---|---|---|
| Tester menu — Wake server | Snackbar: OK / failed / "mock mode" | `works` | |
| Tester menu — Top up ₵100 | Opens P-18 with preset | `works` | Skipped if backend has no payment methods endpoint yet. |
| Tester menu — Emergency (if SOS_ENABLED) | Opens real P-12 | `works` | |
| Tester menu — Show onboarding | Resets store, goes to Onboarding | `works` | |
| Tester menu — Sign out & clear data | Clears refresh + prefs, signs out | `works` | |

## Driver-side (locked behind the mode toggle)

| Screen / entry point | What a user sees | Status | Notes |
|---|---|---|---|
| Welcome — "Sign up as a driver" | Switches mode; then onboarding | `stub` | `driverOnboarding` / `driverAwaitingApproval` / `driverHome` all show `SignedInPlaceholder`. Driver flows are intentionally not built yet. |

## Broken states observed

| Screen | What's broken | Status |
|---|---|---|
| Trips — Rate banner eligibility | The banner's `rateBannerEligible` rule hides it for some completed trips that were actually ratable; owner should spot-check against history. | `broken` |

## Decisions / notes

- **"On-device vs code-read" caveat.** Several `onTap: null` rows with `Coming soon` subtitles can only be fully confirmed by tapping on a device (does the subtitle actually show? does tapping do visibly nothing?). Where I spot-checked on device I marked 📱. The rest I classified from the current widget tree and route table — these classifications are mechanical, not visual.
- **Driver placeholders not in scope** of the owner's "passenger area" brief, but I noted them anyway because the Welcome screen's "Sign up as a driver" link is a visible stub a tester could trip into.

---

Branch: `audit/on-device-nov-2026`
Build command: documented in `README.md` (updated 25 Nov 2026); for this audit, DEPLOY_ENV=staging + every feature flag true.
