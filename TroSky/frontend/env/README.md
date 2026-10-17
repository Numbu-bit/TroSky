# Environments

Each app reads these compile-time defines:

| Define | Meaning | Default |
|---|---|---|
| `API_BASE_URL` | Backend REST base URL | none (needed in live mode) |
| `WS_BASE_URL` | Backend WebSocket base URL | none |
| `API_MODE` | `mock` (built-in data) or `live` (the backend) | `mock` |
| `MAP_TILE_URL` | Map tiles, with `{z}`, `{x}` and `{y}` | OpenStreetMap's public tiles |
| `FEATURES` | Comma-separated features to switch on, e.g. `subscriptions`. Empty switches all off | `subscriptions` in mock mode, none in live mode |

**OpenStreetMap's public tiles are for development only.** Their tile usage
policy doesn't allow an app's production traffic, so staging and prod need a
tile provider's URL before launch (frontend `docs/design-decisions.md`,
decision 13).

To use one:

1. Copy a template: `cp env/dev.example.json env/dev.json` (real `env/*.json`
   files are gitignored).
2. From the app's folder, pass it to Flutter:
   `flutter run --dart-define-from-file=../../env/dev.json`

On the Android emulator the host machine is `10.0.2.2`, not `localhost`.
`staging.example.json` points at the Render test server, `https://trosky-api.onrender.com`
(live since 11 Oct 2026, see `TroSky/backend/docs/deploy-render.md`). It sleeps after 15 minutes
without requests, so the first request after a quiet spell can take up to a minute. The prod host
is a placeholder until a real one exists.

A release APK for testers: `cp env/staging.example.json env/staging.json`, then from
`apps/mobile` run `flutter build apk --release --dart-define-from-file=../../env/staging.json`.
It is signed with the debug key (fine for testers, not for the Play Store).
