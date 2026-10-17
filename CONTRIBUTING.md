# Contributing to TroSky

## Where things live

| Folder | What | CI workflow (runs when the folder changes) |
|---|---|---|
| `TroSky/backend` | FastAPI backend | Backend CI (`.github/workflows/backend.yml`) |
| `TroSky/frontend` | Flutter mobile app (passenger and driver) and fleet-owner web | Frontend (`frontend.yml`) |
| `TroSky/admin-dashboard` | React admin dashboard | Admin dashboard (`admin-dashboard.yml`) |
| `render.yaml` | The Render staging server (see `TroSky/backend/docs/deploy-render.md`) | none |

## How changes reach `main`

`main` is protected, for admins too:

- **No direct pushes.** Every change goes through a pull request: make a branch, push it, open a PR.
  No approval is required, but ask a teammate to review.
- **The `ci-gate` check must pass.** It runs on every PR and waits for the workflows that the PR's
  changes started, so a docs-only PR passes it straight away. If a workflow fails and you re-run
  it, re-run `ci-gate` as well.
- **The branch must be up to date with `main`.** If GitHub says it's behind, press
  **Update branch** and wait for the checks again.
- **No force pushes to `main`, and it can't be deleted.**

Merge with **Create a merge commit**, not squash, so every author's commits and history stay in
`main`.
