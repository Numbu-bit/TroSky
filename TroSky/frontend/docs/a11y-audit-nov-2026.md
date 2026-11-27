# Accessibility audit — Nov 2026 (Step 21/B)

Passenger app, pre-launch pass. Checklist per screen, pass/fail per item,
small issues fixed inline, large ones deferred for tiny follow-up PRs.

## Summary

- Screens audited: 27 (passenger + entry/auth)
- Pass: 174 items
- Fail (deferred): 18 items
- Fixed inline this PR: 4 items
- Each inline fix has a widget test; see `test/a11y/`.

### Checklist (applied to every screen)

1. **Semantics labels** on every interactive widget
2. **Tap target ≥ 48dp** hit rect on every tappable
3. **Contrast ≥ WCAG AA** (4.5:1 body, 3:1 large text)
4. **Reduced motion** (`MediaQuery.disableAnimations` respected)
5. **Text scaling** tolerates `textScaleFactor` 1.3 without overflow
6. **Colour isn't sole signifier** — shape/icon/text backs status colour
7. **Screen-reader reading order** top-to-bottom, as sighted expects
8. **Form field labels** — accessible label (not just hint), announce errors

Legend: ✅ pass · ❌ fail (deferred) · 🛠 fixed inline · n/a not applicable
(screen has no widget of that kind)

## Per-screen findings

| Screen | 1 Sem | 2 Tap | 3 Con | 4 Mot | 5 Scale | 6 Color | 7 Order | 8 Form |
|---|---|---|---|---|---|---|---|---|
| entry/splash | ✅ | n/a | ✅ | ✅ | ✅ | n/a | ✅ | n/a |
| entry/onboarding | ✅ | ✅ | ✅ | ✅ | ❌ D-1 | ✅ | ✅ | n/a |
| entry/auth/welcome | ✅ | ✅ | ✅ | ✅ | ✅ | n/a | ✅ | n/a |
| entry/auth/sign_in | ✅ | ✅ | ✅ | ✅ | ✅ | n/a | ✅ | ✅ |
| entry/auth/details | ✅ | ✅ | ✅ | ✅ | ❌ D-2 | n/a | ✅ | ✅ |
| entry/auth/verify_code | ✅ | ✅ | ✅ | ✅ | ✅ | n/a | ✅ | ✅ |
| passenger/home | ✅ | ✅ | ✅ | ✅ | ❌ D-3 | ✅ | ✅ | n/a |
| passenger/search | ✅ | ✅ | ✅ | ✅ | ✅ | n/a | ✅ | ✅ |
| passenger/search/results | ✅ | ✅ | ✅ | ✅ | ❌ D-4 | ✅ | ✅ | n/a |
| passenger/seats | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | n/a |
| passenger/booking/payment | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| passenger/trips | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | n/a |
| passenger/trips/booking_details | ✅ | ✅ | ✅ | ✅ | ❌ D-5 | ✅ | ✅ | n/a |
| passenger/trips/ticket | 🛠 F-1 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | n/a |
| passenger/trips/trip_details | ✅ | ✅ | ✅ | ✅ | ❌ D-6 | ✅ | ✅ | n/a |
| passenger/tracking/track_trip | 🛠 F-2 | ✅ | ✅ | ❌ D-7 | ❌ D-8 | ✅ | ✅ | n/a |
| passenger/wallet | ✅ | ✅ | ✅ | ✅ | ❌ D-9 | ✅ | ✅ | n/a |
| passenger/wallet/top_up | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| passenger/safety/sos | 🛠 F-3 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | n/a |
| passenger/safety/report | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| passenger/safety/rate | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | n/a |
| passenger/account/profile | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | n/a |
| passenger/account/personal_info | ✅ | ✅ | ✅ | ✅ | ✅ | n/a | ✅ | ✅ |
| passenger/account/reset_password | ✅ | ✅ | ✅ | ✅ | ✅ | n/a | ✅ | ✅ |
| passenger/account/delete_account | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| passenger/notifications | ✅ | ✅ | ✅ | ✅ | ❌ D-10 | ✅ | ✅ | n/a |
| passenger/favourites | ✅ | ✅ | ✅ | ✅ | ❌ D-11 | ✅ | ✅ | ✅ |

## Inline fixes applied in this PR

- **F-1 Ticket QR / booking reference copy button** — `IconButton(Icons.copy)`
  had no tooltip/semantics. Added `tooltip:
  l10n.bookingCopyReference`, so TalkBack announces "Copy booking
  reference" instead of "button". Widget test:
  `ticket_screen_a11y_test.dart`.
- **F-2 Live tracking driver call/message buttons** —
  `_DarkIconButton` had no `Semantics.label`; icon was announced as
  "button" alone. Added a required `semanticsLabel` arg, wired to
  `tripDetailsCallDriver` / `tripDetailsMessageDriver`. Widget test:
  `track_trip_a11y_test.dart`.
- **F-3 SOS screen close (X) button** — `IconButton(Icons.close)` had
  no tooltip. Added `tooltip: l10n.sosClose` ("Close"). Widget test:
  `sos_screen_a11y_test.dart`.
- **F-4 (bundled with F-3)** — new l10n string `sosClose` in
  `app_en.arb`.

## Deferred (tiny follow-up PRs)

- **D-1 Onboarding** — hero illustration overflows at
  textScaleFactor=1.3; needs responsive size.
- **D-2 Auth details** — 3-field column overflows at 1.3 scale;
  wrap in `SingleChildScrollView`.
- **D-3 Home** — favourites chip row clips at 1.3; needs horizontal
  scroll or wrap.
- **D-4 Search results** — trip card row overflows at 1.3; split into
  two lines when scale is high.
- **D-5 Booking details** — stop list rows truncate times at 1.3.
- **D-6 Trip details** — driver card + rating overflows at 1.3.
- **D-7 Track trip — reduced motion** — marker tween ignores
  `MediaQuery.disableAnimations`; needs instant-snap branch (also
  deferred in Step 21/A as "marker tween on map").
- **D-8 Track trip — text scale** — live-fare tile clips at 1.3.
- **D-9 Wallet** — transaction row amounts clip at 1.3.
- **D-10 Notifications** — inbox tile title clips at 1.3; needs
  `maxLines: 2`.
- **D-11 Favourites** — route label clips at 1.3; wrap or
  `ellipsis`.
- **D-12 Favourites — add/edit sheet** — deferred to its own PR
  (draggable Home sheet thread).
- **D-13 Wallet sheet wrap** — H1 follow-up, tracked separately.
- **D-14 App-lock UI** — H3 follow-up, tracked separately.
- **D-15 Rate banner on Trips** — Step 21 deferral.
- **D-16 Search favourite chips** — Step 21 deferral.
- **D-17 Avatar upload** — Step 21 deferral.
- **D-18 Report photo attach** — Step 21 deferral.

## Decisions

Fix inline:

- A missing `tooltip:` / `semanticLabel` on an existing stock widget
  (fits in one line, no copy approval needed — "Copy", "Close",
  existing driver strings reused).

Defer:

- Anything needing a new copy string the owner should approve, new
  widget wrappers, token changes, or layout rework (text scale
  overflows, reduced-motion paths for the map marker tween, draggable
  sheet). Each of these is a tiny follow-up PR.

## Production-bar impact

- Analytics: no new events.
- Localization: one new key (`sosClose`).
- Performance: wraps add one `Semantics` widget each — no new
  rebuilds in hot paths (icon buttons are tapped, not rebuilt).
- Observability: no changes.
- Rollout: no flags.
