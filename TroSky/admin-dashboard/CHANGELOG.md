# Changelog

Notable changes to the TroSky admin dashboard, newest last. The dashboard as first built (phases 1 to
6: every screen, demo mode, tests, Docker image) is described in the README.

## 2026-10-11 - Live on Vercel, checked on every pull request

- **Continuous integration on `main`:** `.github/workflows/admin-dashboard.yml` runs lint, the
  format check, typecheck, unit tests with coverage, the production build checks, the end-to-end and
  accessibility tests on a demo build, and the Docker image. It had only been on the
  `admin-dashboard` branch, so pull requests touching the dashboard got no checks.
- **Deploys on Vercel against the Render backend:** `vercel.json` (build, SPA fallback, asset
  caching, and the nginx image's security headers). Two projects from the same folder: the live
  dashboard, and one in demo mode (README, "On Vercel"). `render.yaml` lets the dashboard's address
  call the API (`CORS_ALLOWED_ORIGINS`).
- **Sign-in on a sleeping server:** when a sign-in waits more than 6 seconds, the page says the
  server is waking up (Render's free plan sleeps after 15 quiet minutes, and the first request then
  takes up to a minute).
- **LF line endings in every checkout** (`.gitattributes`): on Windows, Git could check files out
  with CRLF, and the format check then failed on almost every file.

## 2026-10-14 - Sessions survive a failed renewal; the live feed comes back

- **No more sign-out over a passing error:** when the access token expired and renewing it met a
  network error, a server or gateway error (5xx) or a rate limit, the dashboard signed the admin out
  and deleted a refresh token that was still good. Only the backend refusing the token ends the
  session now; otherwise the request fails with "try again in a moment" (queries retry by
  themselves) and the session is renewed once the server answers.
- **The live feed reconnects after the token expires:** the backend ends the stream once the access
  token it was opened with expires (they last 15 minutes), and the dashboard stopped there, polling
  for the rest of the session while saying it was reconnecting. It now renews the token if needed
  and reconnects.

## 2026-10-17 - The TroSky logo

- **TroSky's pin logo replaces the placeholder bus icon** in the sidebar, on the sign-in page and
  as the browser tab icon (`public/favicon.svg`, which all three use). It's redrawn as SVG from the
  logo artwork, in the artwork's own colours, so it stays sharp at every size. It sits on a light
  rounded tile because the pin's navy would disappear against the navy sidebar and sign-in page.
  The wordmark version (name and tagline) isn't used: the name is already written beside the icon,
  and the sidebar folds down to the icon alone.

## 2026-11-08 - Security updates, maps on MapLibre 6, and a lost click in search

- **Every open security alert is fixed** (`npm audit` finds none): MapLibre GL 5 to 6 (a critical
  cross-site scripting hole through a map's attribution text, which comes from CARTO's style), Zod,
  Vite and undici. `minimatch` is forced past its advisory for `typescript-estree`, which still asks
  for the old version; remove that `overrides` entry once it asks for 11.
- **Maps on MapLibre 6:** it can't find its worker in a bundled app, and without one a map shows its
  markers on a blank background, with no error until the page runs. `MapView` now tells it where the
  worker is, and `check:build` fails if the worker isn't in the build. The security policy no longer
  allows workers from `blob:`, which only MapLibre 5 needed.
- **A click in the global search could be lost:** each new search swapped the results for a spinner,
  so a click arriving at that moment did nothing. The results now stay until the next ones arrive.
  This is what made the "finds a vehicle by its plate" test fail about one run in three.

## 2026-11-09 - Confirming document dates

- **Admins can accept a document with the date printed on it, or send it back with a reason,** on
  the approvals screen and on a driver's or vehicle's page. Nothing recorded these dates before, so
  the insurance dates on the fleet pages were always empty. Insurance can't be accepted without a
  date. Drivers are warned and blocked by the dates accepted here, and accepting a later one
  unblocks a driver at once (backend PR #69).

## 2026-11-10 - Availability instead of Now

- **The fleet lists say "Availability" where they said "Now",** in the vehicles and drivers columns,
  their filters and the record pages, and a vehicle or driver not on a trip is **Available** rather
  than **Free**. The filter's empty choice is now "Any availability".

## 2026-11-10 - The top bar stays put on wide pages

- **Scrolling a wide page sideways no longer slides the top bar over the sidebar and its logo.**
  The page column grew to fit its widest row (on Driver performance, by 174 px at 1280 px wide), so
  the whole window scrolled sideways and took the top bar with it. The column now keeps to the space
  beside the sidebar, tables scroll in their own box, and anything else still too wide scrolls in
  the content area.
- **Dispatch, What drivers did: a trip's link says "View"** rather than "Open".

## 2026-11-11 - "View trip"

- **Links to a trip say "View trip"** rather than "Open the trip" (a booking's drawer and a
  complaint) or "Open trip" (the live map's trip drawer).
- **Revenue: "1 payment"** rather than "1 payments" in the notes of By hour of the day, By route and
  By fleet.
