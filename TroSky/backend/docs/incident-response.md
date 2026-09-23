# Incident response notes

Operational notes for responding to production incidents in this
backend — not a substitute for an organization-wide incident-response
policy (severity definitions, communications/legal escalation, customer
notification obligations), which is out of scope for a single service's
repository and belongs at the org level once one exists.

## Two different things named "incident" in this codebase

Don't confuse them:

1. **This document** — an operational/security incident affecting the
   *platform itself* (an outage, a data breach, a security vulnerability
   being actively exploited).
2. **`Incident` the domain model** (`app/models/safety.py`, Phase 9) — a
   passenger/driver-reported problem *during a specific trip* (a
   breakdown, an accident, a safety concern), reviewed via
   `GET /admin/incidents` by anyone holding `incidents:manage`. Unrelated
   to this document except that a severe enough domain incident (a real
   accident) may also trigger the operational response below if it has
   platform-level implications (e.g. a surge of related support load, a
   press inquiry).

## First response: where to look

| Symptom | Where to look |
|---|---|
| Elevated error rate / latency | `/metrics` (Prometheus) — generic HTTP metrics from `prometheus-fastapi-instrumentator`, plus this app's own counters (`trosky_payment_events_total`, `trosky_webhook_events_total`, `trosky_booking_events_total`, `trosky_gps_ingest_total`, `trosky_notification_delivery_total`, `trosky_sos_events_total`) — see `app/core/telemetry.py` for the full list. |
| A specific request's failure | Structured JSON logs (`app/core/logging.py`) — every log line carries a `request_id`; the same id is returned to the client in every error envelope (`app/core/exceptions.py::_error_body`), so a user-reported error id is directly greppable. |
| A slow or hanging endpoint | OpenTelemetry traces, if `OTEL_ENABLED=true` and an OTLP collector is configured — disabled by default (see `README.md`'s Environment configuration section). |
| Database/Redis reachability | `GET /health/ready` (503 if either is unreachable — checked directly, not inferred). |
| A specific Celery task's failure | Worker pod logs (`kubectl logs -n trosky -l app.kubernetes.io/name=trosky-worker`) — `task_acks_late=True` means a crashed worker's in-flight task is redelivered, not lost, but a *logically* failing task (an exception inside it) still needs a human to look at the log. |

## SOS alerts specifically

An `SosAlert` (Phase 9) is the platform's own safety-critical event type —
worth calling out separately from generic operational incidents because
its response time matters to a real person's safety, not just to an SLA:

1. `SOS_EVENTS_TOTAL` (Prometheus, labeled by status) is the fastest
   signal that alerts are being created — alert on a sustained rate,
   since a spike could mean either a genuine cluster of emergencies or a
   platform bug generating false ones.
2. Emergency contacts are SMSed **immediately and unconditionally** at
   trigger time (`SafetyService._notify_emergency_contacts`, bypassing
   all notification preferences) — this already happens without any
   on-call action.
3. On-call/ops review the queue: `GET /admin/sos-alerts?status=active`
   (permission `sos:review`), then `POST
   /admin/sos-alerts/{id}/acknowledge` once a human is actively handling
   it, and `/resolve` (with `false_alarm: true` if applicable) once
   closed. There is currently no automated paging of on-call staff on a
   new SOS alert beyond the emergency-contact SMS — a real production
   deployment should wire the `active` count into an actual paging
   system (PagerDuty/Opsgenie/...), which is not implemented here.

## Payment/webhook incidents

- A payment stuck in `processing` longer than expected: check
  `trosky_webhook_events_total{result="unmatched"}` (a webhook arrived
  that doesn't correlate to a known payment — usually a reference
  mismatch worth investigating directly against the provider dashboard)
  and `trosky_payment_events_total`. `POST /payments/{id}/sync` (or the
  `reconcile_pending_payments` beat task, every 2 minutes) is the
  built-in recovery path for a lost webhook — see the Phase 6 CHANGELOG
  entry.
- A suspected double-charge or webhook replay: `payment_webhook_events`
  is the full audit log (every inbound webhook, matched or not,
  including ones rejected for a bad signature) — the dedupe key is
  `(channel, provider_reference, event_status)`; a literal replay is
  caught at the database level and never reprocessed (Phase 6).

## Suspected account compromise / abuse

`POST /admin/users/{id}/suspend` (permission `users:suspend`) — flips
`is_suspended` and immediately revokes every one of that user's
outstanding sessions (`AdminService.suspend_user`, Phase 10), so a
suspended account can't keep using a token minted before the suspension.
Reactivate with `POST /admin/users/{id}/reactivate` once resolved.

## Rollback

Application: redeploy the previous image tag (`kustomize edit set image
... :<previous-tag>` — see `deployments/kubernetes/README.md`).

Database: **migrations are additive-by-convention in this codebase** (new
tables/columns, not destructive `ALTER`s dropping data) specifically so a
rollback rarely needs a `alembic downgrade`. If one genuinely is needed,
every migration's `downgrade()` has been validated via `alembic downgrade
head:base --sql` (see each phase's CHANGELOG entry) — but downgrading a
migration that's already been running in production risks losing any
data written into a column/table it drops; prefer rolling the
*application* back to a version compatible with the current schema over
downgrading the schema itself, unless the migration is truly reversible
without data loss.

## What's not yet built

- No automated paging/on-call rotation integration (see the SOS section
  above).
- No runbook automation (this document is manual reference, not scripted
  remediation).
- No chaos-engineering/game-day practice has been run against this
  deployment — the failure-mode reasoning above (Redis outages degrade
  performance not correctness, a crashed worker redelivers its task,
  etc.) is architectural, not empirically drilled.
