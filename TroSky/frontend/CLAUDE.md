# TroSky Frontend — Rules for Claude Code

Read `docs/frontend-inventory.md` first. It maps every screen to its backend endpoints and lists the known backend gaps.

## Products
| App | Path | Platform | Users |
|---|---|---|---|
| TroSky mobile | `apps/mobile` | Android, iOS | Passenger **and** Driver. A role chooser at entry leads to two fully separate interfaces |
| Fleet owner web | `apps/fleet_web` | Web | fleet_owner |

Shared packages: `trosky_ui` (theme + widgets), `trosky_core`, `trosky_api`, `trosky_auth`. All of it is Flutter, using a Dart pub workspace with Melos scripts.

The admin web app is not part of this workspace: it is the React app in `TroSky/admin-dashboard` (Maahir). See `docs/design-decisions.md`, 26.

## Design source of truth: the Figma Make file
- **Never invent a color, font, size, spacing, radius, shadow, icon or illustration.** Every visual value comes from `docs/design-tokens.md`, which is extracted from the Figma Make theme/code, or from the screenshot in `design/<SCREEN-ID>/`.
- If a value you need is not in the tokens or the screenshot, **stop and ask**. Do not guess.
- If a screenshot and the tokens disagree, flag it in your summary and follow the screenshot.
- If Figma Make code is provided (React/Tailwind), treat it as a **spec for exact values and layout**, then rebuild it in idiomatic Flutter. Never embed web code.
- Match screenshots closely: layout, hierarchy, copy text, icon choice, and states.

## Derived designs (Figma Make credits are used up)
- A screen with no files in `design/<ID>/` may be **derived**. Figma screenshots always win when they exist.
- Build a derived screen only from existing `trosky_ui` components and tokens, copying layouts from the closest designed screens. **No new colours, fonts, sizes, shadows, radii or icons.** Flag anything truly new in the PR and the summary instead of making it up.
- Reference screens:
  - passenger forms, lists and settings: S-06, Search Results (P-03), Profile (Figma P11), Wallet (Figma P9);
  - status and result screens: the P-07 states (waiting, accepted, moved, not accepted);
  - code input: S-07;
  - driver screens: Figma D1–D9.
- For each derived screen: save golden PNGs of every state to `design/<ID>/derived/`, attach them to the PR, record the screen in `docs/design-decisions.md`, and mark it **Design: derived** in `docs/frontend-inventory.md`. The project owner approves them from the screenshots before the PR merges.
- Screens to derive later: S-09, P-13, P-18, P-19, P-20, P-22–P-25, D-01–D-03, D-06, D-12.

## Backend is the source of truth for data
- `../backend` is complete. Read `app/api/v1/`, `app/schemas/` and `app/core/exceptions.py` before building any data layer. Never invent endpoints or fields.
- Do not modify `../backend`. Record anything the UI needs that the backend lacks in `docs/backend-gaps.md`.
- Key contracts:
  - Errors arrive as `{"error": {code, message, details, request_id}}`.
  - Money is a Decimal serialized as a string. **Never `double`.**
  - Refresh tokens rotate, so refreshes must run single-flight.
  - The WebSocket takes `?token=`.
  - The seat hold is 600 s, driven by `expires_at`.
  - Only the `mtn_momo` and `wallet` payment channels are live.

## Staying in sync with the backend (run at the start of every session)
The backend is built by a different developer and changes over time. Before any task:
1. Run `git pull`. Read `docs/backend-sync.md` to get the last synced commit, then run `git log --oneline <last>..HEAD -- backend/` and read `backend/CHANGELOG.md` for new entries.
2. If anything under `backend/app/api` or `backend/app/schemas` changed, read the diff. Then:
   - Update the affected DTOs and repositories.
   - Update the status of each gap in `docs/frontend-inventory.md` and `docs/backend-requests.md` (❌ → ✅) when it lands.
   - Switch the matching mock repository to the live one. Keep the mock for tests.
3. If a backend change **breaks** a contract the frontend already uses (a renamed or removed field or endpoint), stop and report it before coding.
4. Write the new HEAD commit and a one-line summary into `docs/backend-sync.md`.
5. For endpoints that don't exist yet, build against the shapes in `docs/backend-requests.md` using mocks. Never block on the backend.

## Architecture
- Code is organized feature-first: `lib/<area>/<feature>/{data,domain,presentation}`.
- State uses Riverpod (codegen), routing uses go_router, models use freezed and json_serializable.
- Widgets only talk to providers. Only repositories touch the API.
- Every repository has a mock twin with realistic Ghanaian data. `--dart-define=API_MODE=mock|live` chooses between them.
- Every async screen has four states: loading (skeleton), empty, error (message + retry), and data.
- Every screen declares its status bar style with AnnotatedRegion: light icons on dark/green/navy backgrounds, dark icons on light backgrounds. Use `TroskySystemUi.lightIcons` or `TroskySystemUi.darkIcons` from `trosky_ui`, never imperative `SystemChrome` style calls. The app's default is dark icons.
- **Mobile app modes:** the app mode (`passenger` or `driver`, `AppModeController` in `trosky_auth`) is persisted. There is no role-chooser screen: the Welcome screen's "Sign up as a driver" link switches to driver (`docs/design-decisions.md`, decision 7). go_router has separate shells per mode. Guards check `/users/me.roles` against the mode. A driver stays gated behind onboarding and the approval screen until approved.

## Ghana and low-bandwidth rules
- Phone input accepts `024…`, `24…` and `+233…`.
- Tickets are stored locally so the QR **works offline**.
- MoMo payment shows an "approve on your phone" state and polls `/payments/{id}/sync`.
- Tracking uses the WebSocket with backoff and falls back to polling every 5–10 s.
- Bundle fonts; don't fetch them at runtime. Cache images. Keep requests minimal.
- SOS is reachable within 2 taps during a trip.

## Quality bar
- `flutter analyze` must report 0 issues.
- Tests: widget tests for every screen state, unit tests for notifiers and repositories, goldens for `trosky_ui` widgets.
- Semantics labels on interactive widgets, touch targets ≥ 48 dp, no overflow at 1.3× text scale.
- No secrets committed. Env comes from `--dart-define-from-file`.

## Workflow per screen batch
1. Look at the screenshots in `design/<ID>/` and list the components, states, navigation and endpoints (cite backend file paths).
2. Build new reusable widgets in `trosky_ui` first, then the screens.
3. Run analyze and test.
4. Update the inventory status and `backend-gaps.md`.
5. Report the files changed, any deviations from the design, gaps found, and questions.
