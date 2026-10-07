# Backend deployment via GitHub Actions + third-party platforms

This repository uses `.github/workflows/backend.yml` to validate, build, and publish the backend image to GHCR, then trigger an environment-specific deployment webhook.

## 1) Collaborator permissions required

To run deployments safely:

- Collaborators need at least **Write** access to run workflows.
- Collaborators must be allowed by each target GitHub Environment's protection rules.
- Only trusted maintainers should be Environment required reviewers for `production`.
- Do **not** share production provider credentials directly with all collaborators.

## 2) Configure GitHub Environments

Create three repository Environments in **Settings → Environments**:

- `development`
- `staging`
- `production`

Recommended protections:

- `development`: optional reviewer gate.
- `staging`: reviewer gate for release owners.
- `production`: **Required reviewers must be enabled** (manual approval).

Add these environment secrets:

- `DEPLOY_WEBHOOK_URL` (required in each environment): third-party deploy endpoint for that environment.

Optional environment variables:

- `DEPLOY_WEBHOOK_TIMEOUT_SECONDS` (defaults to `30`): curl request timeout used by the workflow when calling the deploy webhook.

Never commit webhook URLs or credentials in source control.

## 3) GHCR image publishing and access

The workflow publishes an immutable image tag:

- `ghcr.io/<owner>/trosky-backend:<commit-sha>`

Publishing uses `GITHUB_TOKEN` with explicit least-privilege permissions (`contents: read`, `packages: write` in the image job only).

For private repositories, your deployment platform must be able to pull private GHCR packages. Use one of:

- A GitHub App installation token with package read access, or
- A PAT/token scoped to package read access for the package owner.

## 4) How third-party deployment webhook should work

Each deploy job sends a POST request to `DEPLOY_WEBHOOK_URL` with JSON:

```json
{
  "environment": "staging",
  "image_ref": "ghcr.io/numbu-bit/trosky-backend:<commit-sha>"
}
```

Third-party platform requirements:

1. Authenticate incoming webhook requests (allow-list source/signature/token on the platform side).
2. Pull the exact `image_ref` from GHCR.
3. Deploy that immutable image to the selected environment.
4. Apply runtime configuration from the platform's secret/config manager (not from git).

## 5) Runtime secrets and configuration required by backend

Use `.env.example` as the complete placeholder template and source of truth for key names.

At minimum, configure these categories per environment:

- Postgres (`DATABASE_URL`, `DATABASE_URL_SYNC`)
- Redis (`REDIS_URL`, `CELERY_BROKER_URL`, `CELERY_RESULT_BACKEND`)
- Email/SMTP (`EMAIL_PROVIDER`, `EMAIL_SMTP_*`, `EMAIL_FROM_ADDRESS`)
- Object storage (`S3_*`)
- Payment providers (`PAYMENTS_*`, `PAYMENTS_WEBHOOK_SIGNING_SECRET`)
- Maps provider (`MAPS_PROVIDER`, `MAPS_API_KEY` when using non-local providers)
- Observability/OpenTelemetry (`OTEL_*`)
- Core app secrets (`SECRET_KEY`, `JWT_SECRET_KEY`, `TICKET_QR_SIGNING_SECRET`)

Kubernetes example secret placeholders live in `deployments/kubernetes/secret.example.yaml` and must remain placeholders only.

## 6) Running a deployment

### Automatic (branch-based)

- Push to `develop` → `development` deployment job runs.
- Push to `main` → `staging` and `production` deployment jobs are available (`production` still requires Environment approval).

Deployments are blocked on lint, tests, dependency scan, and image build/scan.

### Manual (workflow_dispatch)

1. Open **Actions → Backend CI → Run workflow**.
2. Choose `development`, `staging`, or `production`.
3. Run workflow from the intended branch/commit.
4. Approve Environment gates when prompted (especially `production`).

## 7) Rollback

Rollback by redeploying a previously known-good immutable GHCR tag:

1. Identify the older commit SHA tag (`ghcr.io/<owner>/trosky-backend:<sha>`).
2. Trigger your deployment platform with that exact `image_ref`.
3. Verify `/health/live` and key business flows after rollback.

Avoid mutable tags (`latest`) for production rollback paths.
