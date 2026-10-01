# Prompt 01 — Foundation + Splash + Onboarding

Paste everything in the code block into Claude Code, run from the repo root (the folder that contains `backend/` and `frontend/`).

```
Read these first, fully:
- frontend/CLAUDE.md                (rules — non-negotiable)
- frontend/docs/design-tokens.md    (the ONLY source of visual values)
- frontend/docs/frontend-inventory.md
- frontend/design/figma-make/globals.css
- the screenshots in frontend/design/S-01/ and frontend/design/S-02/
If frontend/design/figma-make/ contains component code (.tsx) for Splash or
Onboarding, it overrides measurements taken from screenshots.

GOAL: Stand up the Flutter workspace and design system, then build the Splash
screen (S-01) and the 3 Onboarding screens (S-02) pixel-faithful to Figma.
Nothing else. No auth screens, no API calls beyond what Splash needs.

PART A — Workspace
1. frontend/ as a Dart pub workspace + Melos scripts: analyze, test, format,
   gen (build_runner), golden-update. Latest stable Flutter; pin versions and
   list them in your summary.
2. Create: apps/mobile (Android+iOS, applicationId/bundle com.trosky.app),
   apps/admin_web, apps/fleet_web (web, placeholder home only),
   packages/trosky_ui, trosky_core, trosky_api, trosky_auth (skeletons).
3. Strict shared analysis_options. Env via --dart-define-from-file=env/*.json
   (commit only *.example.json): API_BASE_URL, WS_BASE_URL, API_MODE=mock|live.
4. .github/workflows/frontend.yml at repo root: on frontend/** changes run
   format check, analyze, test, build apk (mobile), build web (both web apps).

PART B — trosky_ui design system (from design-tokens.md ONLY)
1. TroskyColors: every token in the table, exact hex, named as in the "Token
   (Dart)" column. No other colors anywhere in the codebase. Add a test that
   greps apps/ and packages/ (excluding trosky_ui/lib/src/tokens) for
   `Color(0x` / `Colors.` and fails if found.
2. Fonts: bundle Plus Jakarta Sans (400–800) and Inter (300–700) as assets in
   trosky_ui (download the OFL static TTFs from the official Google Fonts
   GitHub repos; include the OFL license files). No google_fonts runtime fetch.
3. TroskyTypography: heading styles (Plus Jakarta Sans 800) and body styles
   (Inter). Derive sizes from the Figma code if present; otherwise measure
   from the 390x844 screenshots and mark each `// measured`.
4. TroskyMotion: the 6 animations in design-tokens.md as reusable widgets or
   helpers (PulseDot, SlideUpIn, Floating, SlowSpin, PriceFlash, Ripple),
   exact durations/curves, all respecting MediaQuery.disableAnimations.
5. TroskyTheme.light() (Material 3) wired to the tokens.
6. Components needed by this batch only (build more later as screens need them):
   - TroskyButton: variants seen in Figma — filled green (Onboarding 2),
     filled amber with ink text (Onboarding 3 "Get Started"), light/white
     filled with green text (Onboarding 1 "Next"). Full-width pill shape,
     soft glow shadow as in the screenshots. Pressed/disabled/loading states.
   - PageDots: inactive dots + elongated active pill (amber on onboarding,
     white on splash), animated.
   - SkipButton (top-right text button).
   - DecorativeCircles / concentric rings backgrounds seen on splash and
     onboarding.
   - TroskyLogo: use the SVG asset if frontend/design/assets/ has one;
     otherwise a clearly-marked placeholder widget + TODO — do NOT draw a
     made-up logo.
7. Golden tests for each component; a debug-only gallery route in apps/mobile
   (/_gallery) showing every component and state.

PART C — Screens (apps/mobile/lib/entry/)
S-01 Splash:
- Green vertical gradient background (stops from Figma code, else sample
  from screenshot and mark // measured), decorative concentric rings and
  corner circles, white rounded card with the logo, "Your Journey. On Time."
  (heading) and "Ghana's Shared Transport Platform" (secondary, white ~70%),
  three animated dots near the bottom as a loading indicator.
- Logic: show min ~1.5 s while it (a) reads the "onboarding seen" flag and
  (b) checks for a stored session (trosky_auth stub for now). Routes:
  onboarding not seen -> S-02; seen + no session -> S-03 placeholder
  (role chooser, pending design); session -> placeholder home.
- Set the system status bar style to light icons on this screen.

S-02 Onboarding (one PageView, 3 pages, swipeable):
- Page 1: green background, bus illustration with "YOUR SEAT" amber tag on
  a road; title "Book a Seat,\nNot a Whole Car"; body "Find a shared vehicle
  going your way, book a single seat, and split the fare with fellow riders.";
  light "Next" button with green text.
- Page 2: navy gradient background; fare-split illustration (center amber ₵
  coin, 4 rider avatars around it with fare chips ₵6/₵8/₵7, "price drops"
  label, dashed connecting circle); title "Share the Ride,\nSplit the Fare";
  body text as in screenshot; green "Next" button.
- Page 3: navy background; calendar card "July 2026", weekday row, 5 green
  check circles, route pill "Madina → Circle 07:15" (time in amber); title
  "Subscribe Your\nDaily Commute"; body as in screenshot; amber
  "Get Started" button with ink text.
- Background color transitions smoothly between pages as the user swipes.
- Illustrations: build them as Flutter widgets from the Figma code/shapes
  (they are simple geometric shapes) — or use exported SVGs if present in
  design/assets. Apply Floating animation to illustrations, SlideUpIn to text.
- "Skip" (all pages) and "Get Started" both: set onboarding-seen flag, go to
  S-03 placeholder. Android back on page 2/3 goes to previous page.
- Status bar icons: light on all three pages.
- Copy text must be EXACTLY as in the screenshots; externalize to ARB (en).

PART D — Quality
- Widget tests: splash routing (3 cases), onboarding next/skip/swipe/back,
  flag persistence. Goldens for S-01 and each S-02 page at 390x844 AND 360x800.
- No overflow at 1.3x text scale; Semantics labels on buttons and dots.
- `melos run analyze` = 0 issues, all tests green.

REPORT BACK
- Package versions; token → Dart mapping table.
- Every value you had to measure from screenshots (so we can replace with
  Figma code values).
- Side-by-side check: for each screen, list any visible difference between
  your golden and the Figma screenshot.
- Anything you couldn't match without inventing (logo, gradient stops, etc.).
Stop after this. Do not start auth screens.
```

## Before you run it
- If you can get the **Figma Make code** for Splash and Onboarding (the `.tsx` files), put it in `frontend/design/figma-make/`. With it, sizes and gradients come out exact instead of measured from the screenshots.
- Put the **logo SVG** in `frontend/design/assets/trosky-logo.svg`. Without it, Claude Code will leave a clearly marked placeholder.
