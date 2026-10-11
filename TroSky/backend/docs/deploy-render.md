# Deploying to Render (free tier, staging)

TroSky's shared **test server** runs on [Render](https://render.com) from the Blueprint
`render.yaml` at the repository root. It is a staging server (`APP_ENV=staging`), not
production: everything is on Render's free plans, in the **Frankfurt** region (the closest
to Ghana).

Render docs: [Blueprint spec](https://render.com/docs/blueprint-spec) ·
[free plans](https://render.com/docs/free) · [Postgres](https://render.com/docs/postgresql-creating-connecting) ·
[Key Value](https://render.com/docs/key-value) · [health checks](https://render.com/docs/health-checks)

## What runs where

| Render resource | Plan | What it is |
|---|---|---|
| **trosky-api** (web service, Docker) | Free: 512 MB RAM, 0.1 CPU | This image (`dockerfilePath: ./TroSky/backend/Dockerfile`, `dockerContext: ./TroSky/backend`, both from the repo root) started by `/app/scripts/render-start.sh`. It runs the API **and** a Celery worker with beat in one container, because free plans have no background workers. |
| **trosky-db** (Postgres 17) | Free: 256 MB RAM, 1 GB storage | The database. Migration `20260804_0001` enables `postgis`, `pgcrypto` and `citext`. |
| **trosky-redis** (Key Value) | Free: 25 MB | Rate limits, seat-hold hints, live vehicle positions, the Celery queue and its results, all in one database. `maxmemoryPolicy: noeviction`, Render's advice for job queues. |

`scripts/render-start.sh`, on every start:

1. Turns Render's `DATABASE_URL` (`postgres://…` or `postgresql://…`) into
   `DATABASE_URL=postgresql+asyncpg://…` (the app) and `DATABASE_URL_SYNC=postgresql+psycopg://…`
   (Alembic). Only the scheme changes.
2. Points `CELERY_BROKER_URL` and `CELERY_RESULT_BACKEND` at `REDIS_URL`. Render documents no
   logical database indexes for Key Value, so everything shares the URL as given.
3. Adds `$RENDER_EXTERNAL_HOSTNAME` (`trosky-api.onrender.com`) to `TRUSTED_HOSTS`. Render's
   health checks send that hostname, and any other `Host` gets 400.
4. Waits for Postgres and Key Value with a TCP check in bash (no Python: on 0.1 CPU every
   Python process that imports the app costs most of a minute), then runs `alembic upgrade head`.
5. In one Python process, adds the roles and permissions (`scripts.seed_reference_data`;
   idempotent, creates no users) and the **administrator**, only from `DEV_ADMIN_PASSWORD`
   (see below).
6. Loads the **demo data** only when `SEED_DEMO_DATA=true`.
7. Starts Gunicorn with one Uvicorn worker on `0.0.0.0:$PORT` (10000) first, because Render's
   health check waits for it. Once `/health/live` answers, it starts the Celery worker with
   embedded beat, then watches both:
   - Render's stop signal is passed on to both, and the script exits 0.
   - If either process ends by itself, the script stops the other and exits 1, so Render restarts
     the instance.

   Gunicorn isn't `exec`'d, because it exits 0 when stopped and Render doesn't document
   restarting a web service that exits 0.

`scripts/seed_dev_data.py` is **not** run on Render: it would fall back to a password written in
the code when `DEV_ADMIN_PASSWORD` is unset, and it adds example intercity routes. The start
script calls only its `ensure_dev_admin()`, after checking the password.

### Database connections and TLS

The URLs are Render's **internal** connection strings (`fromDatabase` / `fromService` in
`render.yaml`), reachable only from services in the same region. Internal Postgres connections
offer TLS with a self-signed certificate; both drivers default to `sslmode=prefer`, so they use
it when offered and need no extra parameters. To *require* TLS, the two drivers spell it
differently: `?ssl=require` on the asyncpg URL, `?sslmode=require` on the psycopg one. A
`verify-ca`/`verify-full` mode can't work on internal connections.

Pool sizes are small (`DATABASE_POOL_SIZE=5`, `DATABASE_MAX_OVERFLOW=5`): the API and one Celery
process share the free database (100 connections) and 512 MB of memory.

### Celery: one task at a time, each in a fresh process

The Celery tasks call `asyncio.run()`, which makes a new event loop for each task, while the
database engine and the Redis client are created once per process. A second task in the same
process then gets connections tied to the first task's closed loop and fails with
`RuntimeError: … attached to a different loop`. Locally this failed about half the runs of
`expire_stale_bookings`, `move_unanswered_bookings` and `reconcile_pending_payments` under the
solo pool, and 523 task runs on a docker-compose style worker.

Until the tasks are fixed in code, the worker runs `--pool prefork --concurrency 1
--max-tasks-per-child 1`: each task gets a fresh child process and works. The cost is one fork per
task (every 15 s at the busiest), which fits in 512 MB.

## Deploying

1. Render dashboard → **New → Blueprint** → connect the GitHub repo `Numbu-bit/TroSky`, branch
   `main`. Render reads `render.yaml` and lists `trosky-api`, `trosky-db` and `trosky-redis`.
2. It asks for the one variable marked `sync: false`: **`DEV_ADMIN_PASSWORD`** (12 characters or
   more). Leave it empty to create no administrator.
3. **Apply.** Render creates the database and Key Value, builds the image and deploys. The first
   start migrates the empty database. Watch the **Logs** tab for
   `[render-start] starting the API on port 10000`.
4. Check: `https://<your-service>.onrender.com/health/live` answers `{"status":"alive"}`.

After that, every commit to `main` that changes `TroSky/backend/**` or `render.yaml` deploys
automatically (`autoDeployTrigger: commit` with a build filter).

### Environment variables

| Variable | Where it comes from |
|---|---|
| `DATABASE_URL`, `REDIS_URL` | Linked to trosky-db / trosky-redis (internal URLs) |
| `SECRET_KEY`, `JWT_SECRET_KEY`, `TICKET_QR_SIGNING_SECRET`, `PAYMENTS_WEBHOOK_SIGNING_SECRET` | Generated by Render once (random 256-bit, base64) |
| `DEV_ADMIN_PASSWORD` | Typed in the dashboard (`sync: false`) |
| `APP_ENV=staging`, `DEBUG=false`, `EXPOSE_HEALTH_DETAILS=false`, `LOG_JSON=true` | `render.yaml` |
| `OTP_DELIVERY_CHANNEL=email`, `EMAIL_PROVIDER=console`, `SMS_PROVIDER=console`, `PAYMENTS_ACTIVE_PROVIDER=sandbox`, `FIREBASE_ENABLED=false`, `MAPS_PROVIDER=local` | `render.yaml` |
| `TRUSTED_PROXY_CIDRS` | `render.yaml` (see "Rate limits behind Render's proxy") |
| `DATABASE_POOL_SIZE=5`, `DATABASE_MAX_OVERFLOW=5`, `SEED_DEMO_DATA=false` | `render.yaml` |
| `PASSENGER_SIGNUP_COUNTRIES=" "` (empty) | `render.yaml`. **TEMPORARY — set back to GH once the app sends location (next frontend step).** See "Passenger sign-up" |
| `BOOKING_ACCEPTANCE_REQUIRED=true` | `render.yaml`, the normal behaviour. See "Booking acceptance" |
| `CORS_ALLOWED_ORIGINS=http://localhost:3000` | `render.yaml`, the backend default for now. Add the admin dashboard's URL once it is deployed. See "The admin dashboard" |
| `DATABASE_URL_SYNC`, `CELERY_BROKER_URL`, `CELERY_RESULT_BACKEND`, `TRUSTED_HOSTS`, `MALLOC_ARENA_MAX` | Derived by `render-start.sh` |
| `PORT`, `RENDER_EXTERNAL_HOSTNAME` | Set by Render |
| `S3_*` | Not set: uploads don't work yet |

## Free-tier limits

| Limit | What it means for TroSky |
|---|---|
| **The web service sleeps after 15 minutes** without inbound requests. Render's own wake-up takes about a minute. | On top of that comes TroSky's start: the migration check, the seeds and booting the API. With a whole CPU that took 20 s. **Under a hard 0.1-CPU limit (`docker run --cpus=0.1`) it took 302 s.** Render's real figure may be better if its 0.1 CPU can burst, which I couldn't check. So the first request after a quiet spell can take minutes, and the app's request times out once before it works. While asleep **Celery doesn't run either**: seat holds aren't released, unanswered bookings aren't moved and trips don't change status until a request wakes it. |
| 750 free instance hours per workspace per month | One service awake all month uses about 744. A second free service would run out. |
| **The free database expires 30 days after it is created**, then has a 14-day grace period before Render deletes it. No backups. 1 GB. | Note the creation date on trosky-db's page. Upgrade before day 30, or at the latest within the grace period, or the data is lost. For a database created on **12 Oct 2026**: expires **11 Nov 2026**, deleted **25 Nov 2026**. Act by **4 Nov 2026**. |
| Free Key Value keeps nothing on restart. 25 MB. | A restart forgets rate-limit counters, live positions and queued tasks. Nothing permanent lives there. |
| **SMTP is blocked** (ports 25, 465 and 587 on free web services). | Verification codes go to the console provider: read them in the logs (below). |
| **No object storage.** | Avatar, document and incident-photo uploads answer `502 PROVIDER_ERROR` ("Failed to store the uploaded file."). Everything else works. |
| The filesystem is ephemeral. | Nothing is written outside `/tmp` (beat's schedule). |
| The region can't be changed after creation. | Moving away from Frankfurt means new resources. |

## Reading verification codes in the logs

With `EMAIL_PROVIDER=console` every code is written to the log instead of being sent.

1. Dashboard → **trosky-api** → **Logs**.
2. Type `email_sent_console` (or part of the person's email address) in the search box above the
   log and press Enter. Without a search, Render's health checks (`/health/live`, every 5 s) push
   the line out of view.
3. The JSON line has `"to": "<their address>"` and
   `"body_text": "Your TroSky verification code is 123456. It expires in 5 minutes."`.

Codes expire after 5 minutes (`OTP_EXPIRATION_SECONDS`). The log search covers the running
instance; after a restart, ask for a new code.

## The administrator account

When `DEV_ADMIN_PASSWORD` is set (12 characters or more), the first start creates
`+233200000000` / `admin@trosky.africa` with that password, verified, with the admin role.
Later starts leave it alone, so **changing `DEV_ADMIN_PASSWORD` afterwards doesn't change the
password**: use the app's password reset (`POST /auth/password/forgot`, the code arrives in the
logs). Unset, or the old public development default: no administrator is created.

## The admin dashboard

The React dashboard in `TroSky/admin-dashboard` takes the API's address from its build settings;
nothing is hard-coded (its README, "Environment variables"). Sign in with the administrator account
above.

**From your machine (`npm run dev`).** In `TroSky/admin-dashboard`, create `.env.local`:

```sh
VITE_API_BASE_URL=/api/v1
VITE_API_PROXY_TARGET=https://trosky-api.onrender.com
```

The dev server forwards `/api` to Render, so the browser only talks to `localhost:5173`, and the
backend needs no CORS change.

**A deployed dashboard** (on its own address, e.g. `https://admin.example.com`):

1. Build it with `VITE_API_BASE_URL=https://trosky-api.onrender.com/api/v1`:
   - as a Docker image:
     `docker build --build-arg VITE_API_BASE_URL=https://trosky-api.onrender.com/api/v1 -t trosky-admin-dashboard TroSky/admin-dashboard`;
   - or as static files: put the line in `.env.staging` and run `npm run build -- --mode staging`.
2. When running the image, set `API_ORIGIN=https://trosky-api.onrender.com`. Without it, the
   image's Content-Security-Policy blocks the calls to Render.
3. Allow the dashboard's address on Render: add it to `CORS_ALLOWED_ORIGINS` in `render.yaml`
   (comma-separated, e.g. `http://localhost:3000,https://admin.example.com`) and push. Until then
   only the backend default, `http://localhost:3000`, is allowed, and browsers block the
   dashboard's requests.

Free services sleep (see "Free-tier limits"): after a quiet spell, the first requests wait for the
server to start, and the dashboard shows errors until it is up.

## Demo data

Set `SEED_DEMO_DATA=true` (Environment tab) and save. The next start loads:
- 10 Accra stops and 6 routes;
- 12 vehicles with drivers;
- a trip every 30 minutes from 05:30 to 21:00 (Ghana time) on every route, from now **until 7 days
  ahead**;
- the demo accounts (password `TroSkyDemo!2026`, listed in the backend changelog, 0.13.0, D1);
- for the demo passenger: GHS 200 in the wallet, 3 past trips and 1 upcoming booking.

### Keeping trips available

The timetable stops 7 days after the last run of the seed: a run on 12 Oct leaves trips up to
19 Oct, 21:00. Every run fills the timetable up to 7 days ahead of *that* day. There are two ways
to keep trips coming:

- **Leave `SEED_DEMO_DATA=true`.** Every start, including every wake-up from sleep, tops the
  timetable up, so it never runs out while people use the server. The cost is a slower start: a
  run with nothing to add took 5 s with a whole CPU, so roughly a minute on 0.1 CPU.
- **Top up by hand when needed.** Set `SEED_DEMO_DATA=true` and save; Render restarts the
  service, and the start adds the missing days. Then set it back to `false`, which restarts once
  more. Free services have no shell, so this is the manual way. Do it at least once a week.

Re-running **duplicates nothing** (checked locally: a second run added 0 trips, users, vehicles,
routes, stops, bookings or wallet entries).
- Stops (by code), routes (by name), accounts (by phone), vehicles (by registration) and drivers
  are created only when missing.
- Trips are added only for route-and-departure pairs that don't exist yet.
- The wallet top-up has an idempotency key.
- The demo passenger's history (3 past trips, 1 upcoming booking) is only created while they have
  no bookings at all. After a week their "upcoming" booking is in the past and isn't renewed.

Past trips are never deleted. They add about 190 trips a day while topping up, which is small
for the 1 GB database.

The demo seed books and confirms its sample trip directly. Since backend 0.20.0 that would fail
(new bookings wait for the driver), so `render-start.sh` runs the seed with
`BOOKING_ACCEPTANCE_REQUIRED=false` for that one process only.

## Passenger sign-up (TEMPORARY)

**TEMPORARY — set back to GH once the app sends location (next frontend step).**

Since backend 0.21.0 a passenger can only sign up with the phone's location, and it must be in
Ghana (`PASSENGER_SIGNUP_COUNTRIES=GH`). The current app doesn't send a location yet, so on this
test server the check is switched off:
- **The value:** `PASSENGER_SIGNUP_COUNTRIES` is a single space in `render.yaml`. The backend
  ignores blank entries, so it reads as empty, and an empty value is guaranteed to reach the
  service (Render doesn't document keeping one that is truly empty).
- **Checking it:** the start log says `passenger sign-up: no location needed` (or
  `the phone's location must be in GH`).
- **Tested locally:** registering without `latitude`/`longitude` succeeds with this setting; with
  `GH` it answers 422 `LOCATION_REQUIRED`.

To turn the check back on, set the value to `GH` in `render.yaml` and push, or edit it under
Environment.

## Booking acceptance

Since backend 0.20.0 a new booking waits for the trip's driver, or an admin, to accept it:
- **Waiting:** the booking is `awaiting_acceptance`, and `expires_at` is the deadline for an
  answer (`BOOKING_ACCEPT_TIMEOUT_SECONDS`, 120 s).
- **Unanswered or declined:** it moves to another vehicle going the same way, or ends uncharged.
- **Once accepted:** it is `pending`, and the passenger has 10 minutes to pay.

`render.yaml` keeps this normal behaviour (`BOOKING_ACCEPTANCE_REQUIRED=true`). Two ways to test
on the staging server:

**Switch acceptance off.** Set `BOOKING_ACCEPTANCE_REQUIRED=false` (Environment tab, or in
`render.yaml`) and save; Render restarts the service. New bookings then go straight to `pending`
with 10 minutes to pay, as before 0.20.0. The start log shows
`booking acceptance by the driver: false`. The current app expects this behaviour: it doesn't know
the waiting state yet.

**Keep it on and accept as the admin** (or as the demo driver of that trip, in the driver app or
its API). Every call needs the admin's access token (`POST /api/v1/auth/login` with
`+233200000000` and `DEV_ADMIN_PASSWORD`):

```sh
API=https://trosky-api.onrender.com/api/v1
TOKEN=$(curl -s -X POST $API/auth/login -H "Content-Type: application/json" \
  -d '{"identifier":"+233200000000","password":"<DEV_ADMIN_PASSWORD>"}' | jq -r .access_token)

# Bookings waiting for an answer, the nearest deadline first
curl -s $API/admin/booking-requests -H "Authorization: Bearer $TOKEN"

# Accept one: it becomes "pending" and the passenger is told to pay
curl -s -X POST $API/admin/bookings/<booking_id>/accept -H "Authorization: Bearer $TOKEN"

# Or decline it, moving it to another vehicle if one has seats
curl -s -X POST $API/admin/bookings/<booking_id>/decline -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" -d '{"reason":"Testing","move_to_another_trip":true}'
```

Tested locally:
- **Acceptance on:** a booking was `awaiting_acceptance` with 120 s left. It appeared in
  `/admin/booking-requests`. After `accept` it was `pending` with 600 s to pay.
- **Acceptance off:** the booking was `pending` with 600 s straight away.

To give testers more time to answer without switching acceptance off, raise
`BOOKING_ACCEPT_TIMEOUT_SECONDS` (15 to 3600).

## Rate limits behind Render's proxy

Rate limits key on the client's IP address (`app/core/client_ip.py`). The app only believes
`X-Forwarded-For` when the TCP peer is in `TRUSTED_PROXY_CIDRS`, and then reads it right to
left, skipping trusted proxies. Every request reaches the app through Cloudflare and Render's
load balancer, so the TCP peer is always Render's proxy. If that proxy isn't trusted, every
phone shares one bucket, and 10 logins in 5 minutes *across all testers* would lock everyone
out.

`render.yaml` trusts `10.0.0.0/8` (Render's private network, where its load balancer connects
from) and [Cloudflare's published ranges](https://www.cloudflare.com/ips/). Render doesn't
document its proxy addresses or the exact `X-Forwarded-For` layout, so **check after the first
deploy**:

1. **Which address the proxy connects from.** The access log's `client_ip` field
   (`"event": "http_request"`) is the raw TCP peer. Make any request and look at it: it should
   be inside `10.0.0.0/8`. If it is another private range (`100.64.0.0/10`, `172.16.0.0/12`),
   add that range to `TRUSTED_PROXY_CIDRS` in `render.yaml`.
2. **Each phone gets its own limit.** The login limit is 10 per 5 minutes. From phone A on mobile
   data, make 11 wrong logins: the 11th answers `429 RATE_LIMIT_EXCEEDED`. Straight after, log in
   from phone B on a **different network**: it must *not* get 429. If it does, all clients share
   one bucket: recheck step 1.
3. **A client can't choose its own address.** While A is still limited, from A run
   `curl -X POST https://<service>.onrender.com/api/v1/auth/login -H "Content-Type: application/json" -H "X-Forwarded-For: 203.0.113.7" -d '{"identifier":"0240000000","password":"x"}'`.
   It must still answer 429. If it doesn't, Render places the client's own header value at the
   right-hand end, and the limit can be dodged. Tell the backend owner: the fix is in code
   (reading the first entry, or Cloudflare's `CF-Connecting-IP`), not in this setting.

**Results on 11 Oct 2026** (details: `TroSky/frontend/docs/staging-test/2026-10-11/README.md`):

1. Render's health checks arrive from `10.231.24.45`, inside `10.0.0.0/8`. Still to read: the
   `client_ip` of a request from outside (search a response's `request_id` in the log).
2. **Not shown yet.** Both "clients" were on one public IP: the PC was on the phone's hotspot, so
   the phone's sign-in after the PC's 11th try got 429 as well, as it should for one address.
   Repeat with a second phone on another network (another carrier, or Wi-Fi elsewhere).
3. **Passed.** The 11th wrong login answered 429, and with `X-Forwarded-For: 203.0.113.7` it
   still answered 429.

## Upgrading to paid plans later

Change `plan:` in `render.yaml` and push to `main` (the Blueprint syncs), or change the plan on
the resource's page. Prices change; check [render.com/pricing](https://render.com/pricing).

| Part | Paid step | What it fixes | Note |
|---|---|---|---|
| trosky-api | `starter` (512 MB, 0.5 CPU, no sleeping) | No cold starts; Celery runs all the time | Then move Celery to its own **background worker** (`type: worker`, same image, `dockerCommand` running only the worker with beat), and drop it from `render-start.sh`. Raise Gunicorn's `--workers` with the RAM. |
| trosky-db | `basic-256mb` or larger | No 30-day expiry; backups | Upgrade within the grace period at the latest; the data is kept. |
| trosky-redis | `starter` | More memory; persistence options | Free data is lost on upgrade; harmless here. |
| Email | an SMTP or SES provider | Real codes by email | Paid web services can use SMTP. Set `EMAIL_PROVIDER` and its settings. |
| Uploads | S3-compatible storage | Avatars, documents, photos | Set `S3_ENDPOINT`, `S3_BUCKET`, `S3_ACCESS_KEY`, `S3_SECRET_KEY`, `S3_REGION`, `S3_USE_SSL=true`. |

For production proper, use `APP_ENV=production` on a separate Blueprint or environment. The
backend then refuses to start with `DEBUG`, `EXPOSE_HEALTH_DETAILS` or weak secrets.

## Rotating secrets

`generateValue` only fills a variable that doesn't exist yet, so syncing the Blueprint never
rotates anything. Rotate in the dashboard: **trosky-api → Environment →** edit the value (type a
new random 32+ character value, e.g. `openssl rand -base64 32`) **→ Save, rebuild and deploy**.

| Secret | Effect of rotating |
|---|---|
| `JWT_SECRET_KEY` | Every access and refresh token stops working: everyone signs in again. |
| `SECRET_KEY` | Keys the stored hashes of verification codes and live-trip share links: codes already sent and share links already given out stop working. |
| `TICKET_QR_SIGNING_SECRET` | QR tickets already issued no longer validate. |
| `PAYMENTS_WEBHOOK_SIGNING_SECRET` | Must match what the payment provider signs with (the sandbox for now). |
| `DEV_ADMIN_PASSWORD` | No effect on an existing administrator (see above). |
| Database / Key Value credentials | Linked by `fromDatabase` / `fromService`: after Render issues new credentials, redeploy trosky-api to pick them up. |

## Known issues found while testing (backend code, not this deployment)

1. **Celery tasks and event loops.** Each task runs `asyncio.run()` against a process-wide
   database engine and Redis client, so a second task in the same process fails with
   `RuntimeError: … attached to a different loop`. The worker setting above avoids it. The
   lasting fix is in `app/workers/tasks/*`: dispose the engine and close the Redis client at the
   end of each task, or keep one event loop per worker process. Without either, a docker-compose style
   worker failed 408 runs of `expire_stale_bookings` in about 16 hours.
2. **Password hashing blocks the API.** `hash_password` / `verify_password` (Argon2id, 64 MiB,
   time cost 3) run on the event loop.
   - Under a hard 0.1-CPU limit one login took 17 s, and `/health/live` waited up to 8 s behind
     it, longer than Render's 5-second health-check timeout.
   - Render stops routing to an instance after 15 s of failed checks and restarts it after 60 s,
     so a run of logins could restart the service.
   - The fix is in code: hash in a thread (`asyncio.to_thread`; argon2 releases the GIL). Lighter
     parameters for staging, or the Starter plan's 0.5 CPU, would also help.
3. **The demo seed and booking acceptance.** `scripts/seed_demo_data.py` confirms its sample
   booking at once, which fails since 0.20.0 because new bookings wait for the driver
   (`InvalidStateTransitionError`). The start script runs the seed alone with
   `BOOKING_ACCEPTANCE_REQUIRED=false`, and a failed demo seed no longer stops the server.
4. **The Dockerfile's `HEALTHCHECK` probes port 8000**, not `$PORT`; see below.

## Running it locally like Render

The deployment was tested with:
- the image built from `TroSky/backend`;
- `postgis/postgis:17-3.5` and `valkey/valkey:8` (25 MB, `noeviction`);
- the container limited to 512 MB;
- only the variables `render.yaml` provides, with connection strings in Render's `postgresql://`
  and `postgres://` forms, plus `PORT`, `RENDER` and `RENDER_EXTERNAL_HOSTNAME`.

Memory: about 385 MiB while running, at most 454 MiB, including bursts of 200 requests and 6
logins at once (each Argon2 hash takes 64 MiB, one at a time).

```sh
docker build --target runtime -t trosky-api:render-test TroSky/backend
docker run --memory=512m --memory-swap=512m -p 18000:10000 --env-file render.env \
  trosky-api:render-test bash /app/scripts/render-start.sh
curl -H "Host: trosky-api.onrender.com" http://localhost:18000/health/live
```

The Dockerfile's own `HEALTHCHECK` probes port 8000, so locally `docker ps` shows the container
"unhealthy". Render runs its own health check, on `/health/live` at `$PORT`.
