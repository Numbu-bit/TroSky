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
