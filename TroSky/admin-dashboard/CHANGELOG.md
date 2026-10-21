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
