# Data retention notes

Scope: what this backend stores, for how long, and what already enforces
that — not a substitute for the legal/regulatory review
`production-readiness-checklist.md` flags as still owed (Ghana's Data
Protection Act, 2012 (Act 843), most directly). This is the technical
inventory that review would start from.

## Backup and restore

A managed Postgres provider (e.g. Supabase, RDS, Cloud SQL) is the assumed
deployment target — point-in-time recovery (PITR) via the provider is the
primary backup mechanism. For a self-hosted Postgres, `pg_dump` logical
backups are the documented fallback:

```bash
pg_dump --format=custom --file=trosky-$(date +%F).dump "$DATABASE_URL_SYNC"
# restore:
pg_restore --clean --if-exists --dbname="$DATABASE_URL_SYNC" trosky-2026-08-12.dump
```

Redis holds no data that isn't reconstructable from Postgres (see
`app.repositories.booking_repository`'s module docstring and every
subsequent phase's restatement of the same principle) — a lost Redis
instance degrades performance, never correctness, and needs no backup.

Object storage (driver/vehicle documents) should use the storage
provider's own versioning/replication (e.g. S3 versioning + cross-region
replication) rather than an application-level backup — out of scope for
this backend to implement directly.

## Retention by table (or table group)

| Data | Retention | Enforced by |
|---|---|---|
| Raw GPS pings (`trip_locations`) | `GPS_RAW_RETENTION_DAYS` (default 30) | `app.workers.tasks.tracking.purge_old_trip_locations`, a daily Celery beat task (Phase 8) |
| Live GPS state (Redis) | `GPS_STALE_THRESHOLD_SECONDS × 20` as a TTL safety net | `TrackingService._cache_location` (Phase 8) |
| Seat holds (`seat_reservations` in `held` status) | `SEAT_RESERVATION_HOLD_SECONDS` (default 600s) before the sweep releases them | `app.workers.tasks.bookings.expire_stale_bookings`, a 30-second Celery beat task (Phase 5) |
| OTP challenges | `OTP_EXPIRATION_SECONDS` (default 300s) | Checked at verification time; expired rows are not proactively purged (small table, low volume — a future retention sweep is a reasonable addition, not yet built) |
| Refresh token rows / sessions | Until explicit logout, expiry (`REFRESH_TOKEN_TTL_SECONDS`), or reuse-detected revocation | `app.services.auth_service`, `app.repositories.session_repository` (Phase 2) |
| User accounts | Soft-deleted (`deleted_at` set, `is_active=False`) on account deletion — never hard-deleted. The phone number and email stay on the row but are free for a new sign-up (unique only among accounts not deleted) | `UserRepository.soft_delete` (Phase 2); hard-deletion on a legal erasure request is a manual DBA action today, not yet an automated flow |
| Booking/payment/ticket/rating/complaint/incident history | Retained indefinitely — this is the financial and safety audit trail the platform is built around | No purge job exists or is planned; these are the records a regulator or a dispute would need |
| Notification inbox (`notifications`) | Retained indefinitely | No purge job yet — a reasonable future addition (e.g. 12-month rolling purge of read, non-safety-category notifications) once real usage volume is known |
| Payment webhook audit log (`payment_webhook_events`) | Retained indefinitely | Deliberate — this is the replay-protection and dispute-resolution record for real money movement |

## Soft-delete vs. hard-delete

Every domain table in this codebase that represents a person or an
account (`users`, `emergency_contacts`) uses `SoftDeleteMixin`
(`deleted_at`) rather than a hard `DELETE` — consistent with the base
model's own documented convention (`app/models/base.py`): "Hard deletes
are avoided for auditable domain data." Financial and safety tables
(`payments`, `bookings`, `incidents`, `sos_alerts`, ...) have no delete
path at all, soft or hard — they're append/status-transition-only.

## What is *not* yet built

- An automated data-subject-erasure flow (a user requesting full erasure
  under Act 843, beyond the existing soft-delete-on-account-deletion) —
  today this would be a manual DBA action informed by this document, not
  a self-service API endpoint.
- A retention/purge job for OTP challenges and read notifications (both
  low-risk, low-volume tables where the absence of a sweep is a
  reasonable MVP simplification, not an oversight — flagged here so it
  isn't a silent one).
- Encryption at rest is delegated entirely to the managed Postgres/S3
  provider's own at-rest encryption (both Supabase and AWS RDS/S3 encrypt
  by default) — this codebase does not implement application-level
  field encryption for any column, including PII (phone numbers, Ghana
  Card numbers). Worth an explicit decision (not a default) once the
  legal review above happens.
