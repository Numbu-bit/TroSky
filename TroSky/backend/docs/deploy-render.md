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
| **Supabase project `trosky-staging`** (outside Render) | Free: Postgres 17, 500 MB | **The database**, in Frankfurt, reached through Supabase's Session pooler. See "Database: Supabase". Migration `20260804_0001` enables `postgis`, `pgcrypto` and `citext`. |
| **trosky-db** (Postgres 17) | Free: 256 MB RAM, 1 GB storage | **Not used since 15 Oct 2026.** The data was copied to Supabase; trosky-db stays as a fallback until it expires on 10 Nov 2026. |
| **trosky-redis** (Key Value) | Free: 25 MB | Rate limits, seat-hold hints, live vehicle positions, the Celery queue and its results, all in one database. `maxmemoryPolicy: noeviction`, Render's advice for job queues. |

`scripts/render-start.sh`, on every start:

1. Turns `DATABASE_URL` (Supabase's `postgresql://…` URI) into
   `DATABASE_URL=postgresql+asyncpg://…?ssl=require` (the app) and
   `DATABASE_URL_SYNC=postgresql+psycopg://…?sslmode=require` (Alembic). Any `?query` part of the
   given URL is dropped, because the two drivers spell TLS differently. It logs the database host
   and port, never the URL.
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

- **Key Value:** `REDIS_URL` is Render's internal connection string (`fromService`), reachable
  only from services in the same region.
- **Postgres:** Supabase's Session pooler, over the internet. `render-start.sh` requires TLS:
  `?ssl=require` on the asyncpg URL, `?sslmode=require` on the psycopg one (TLS 1.3, measured on
  15 Oct 2026). `require` encrypts without checking the certificate. Set `DATABASE_SSLMODE` to
  change the mode, e.g. `disable` for a local Postgres without TLS.
- **Pools:** `DATABASE_POOL_SIZE=3` and `DATABASE_MAX_OVERFLOW=2`, so at most 5 connections per
  process. "Database: Supabase" has the full count.

### Celery: one task at a time

The worker runs `--pool prefork --concurrency 1`: one child process, kept for good, runs the
tasks one after another. Since backend 0.22.1 every task in a process shares one event loop, and
with it the database and Redis connections (`app/workers/loop.py`). Before that, each task made a
loop of its own and every other run failed with `RuntimeError: … attached to a different loop`,
which this deployment worked around with `--max-tasks-per-child 1` (a fresh child process, and a
fork, for every task). That is no longer needed.

## Database: Supabase

Since 15 Oct 2026 the database is a free Supabase project, **`trosky-staging`**, in **Central EU
(Frankfurt)**, the same city as Render. Postgres 17.

### Which connection string, and why

Use the **Session pooler** URI: **Connect** (top of the project page) → **Session pooler**:
`postgresql://postgres.<project-ref>:<password>@aws-1-eu-central-1.pooler.supabase.com:5432/postgres`.

- **Not Direct:** on the free plan, direct connections (`db.<ref>.supabase.co`) are IPv6 only,
  and Render's services connect out over IPv4. The poolers are IPv4.
- **Not the Transaction pooler** (port 6543): it doesn't support prepared statements, and
  asyncpg uses them. Session mode keeps one server connection per client connection, so they work.
- **The password** goes into the URL as it is. Special characters (`@ # / ? %` …) must be
  URL-encoded, so a password of letters and digits is simplest.
- `render-start.sh` adds the TLS parameters itself (see "Database connections and TLS"). A URI
  with its own `?query` part works too, because the script drops it.

Put it in **trosky-api → Environment → `DATABASE_URL`**. `render.yaml` marks it `sync: false`,
so Blueprint syncs leave it alone.

### Settings on the Supabase side

- **Data API: off** (Project Settings → Data API). The app talks to Postgres directly and never
  uses Supabase's REST API.
- **The `anon` and `authenticated` roles have no rights in `public`.** Supabase grants them
  everything by default, which the Data API would expose. This was run once, before the tables
  were created, and only PostGIS's own reference tables keep their grants:
  ```sql
  ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON TABLES    FROM anon, authenticated;
  ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON SEQUENCES FROM anon, authenticated;
  ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON FUNCTIONS FROM anon, authenticated;
  ```
- **Recommended:** Database settings → SSL Configuration → **Enforce SSL on incoming
  connections**. The pooler otherwise also accepts unencrypted connections (the start script
  never makes one).

### Free-plan limits

| Limit | What it means for TroSky |
|---|---|
| **The project pauses after 7 days without activity.** | The `Keep staging awake` workflow (`.github/workflows/keep-awake.yml`) runs every 2 days. It wakes the API and calls `/health/ready`, which runs `SELECT 1` on the database. GitHub switches scheduled workflows off after 60 days without commits: re-enable it under **Actions** if that happens. A paused project is restored from its dashboard. |
| **500 MB of database.** | 21 MB on 15 Oct 2026, most of it the timetable (`SEED_DEMO_DATA` tops it up and never deletes past trips). Check under **Reports → Database**. |
| **Connections:** 60 to Postgres; the session pooler's pool is 15–20 server connections. | At most 5 per process (`DATABASE_POOL_SIZE=3` + `DATABASE_MAX_OVERFLOW=2`): the API process, and the Celery task process (one task at a time). Beat and the Celery parent use none, and Alembic and the seeds run one at a time before the app starts. That's at most about 11 for one instance, and 4–6 in normal use, leaving room for the old and new instance to overlap during a deploy. |
| **No backups** on the free plan. | Take them yourself, as below. |

### Taking a backup by hand

With Docker and the Session pooler URI in an environment variable (here `SUPABASE_DB_URL`), so it
never appears on the command line:

```sh
docker run --rm -e PGURL="$SUPABASE_DB_URL" -e PGSSLMODE=require -v "$PWD:/backup" postgres:17-alpine \
  sh -c 'pg_dump "$PGURL" -Fc --schema=public --no-owner --no-privileges -f /backup/trosky-$(date +%F).dump'
```

- **Use a matching client:** `postgres:17-alpine`, because the server is Postgres 17.
- **Keep the file out of git:** it contains personal data and password hashes. Store it somewhere
  private.
- **To restore into an empty database:** `pg_restore --no-owner --no-privileges -d "$PGURL"
  trosky-YYYY-MM-DD.dump`.

### How the data got there (15 Oct 2026)

1. The empty schema was built with `alembic upgrade head`, as the app does. PostGIS and citext are
   in `public`, as on Render.
2. The data came from a data-only `pg_dump` of trosky-db's `public` schema, without
   `alembic_version` and PostGIS's `spatial_ref_sys`. It was loaded in one transaction with
   `SET session_replication_role = replica`, so foreign keys didn't need any order and triggers
   didn't touch timestamps.
3. Afterwards, the row counts of all 71 tables matched (5,470 rows of app data), and
   `alembic_version` was `20261008_0021` on both sides.

trosky-db was only read during this, and stays as a fallback until it expires on 10 Nov 2026.

## Deploying

1. Create the Supabase project first ("Database: Supabase").
2. Render dashboard → **New → Blueprint** → connect the GitHub repo `Numbu-bit/TroSky`, branch
   `main`. Render reads `render.yaml` and lists `trosky-api`, `trosky-db` and `trosky-redis`.
3. It asks for the variables marked `sync: false`:
   - **`DATABASE_URL`**: the Supabase Session pooler URI.
   - **`DEV_ADMIN_PASSWORD`**: 12 characters or more. Leave it empty to create no administrator.

   Render asks only when the Blueprint is created. Later syncs leave `sync: false` variables
   alone, so change them under **trosky-api → Environment**.
4. **Apply.** Render creates Key Value (and the unused trosky-db), builds the image and deploys.
   The first start migrates the empty database. Watch the **Logs** tab for
   `[render-start] starting the API on port 10000`.
5. Check: `https://<your-service>.onrender.com/health/live` answers `{"status":"alive"}`, and
   `/health/ready` answers `"database":true`.

After that, every commit to `main` that changes `TroSky/backend/**` or `render.yaml` deploys
automatically (`autoDeployTrigger: commit` with a build filter).

### Environment variables

| Variable | Where it comes from |
|---|---|
| `DATABASE_URL` | Supabase's Session pooler URI, typed in the dashboard (`sync: false`) |
| `REDIS_URL` | Linked to trosky-redis (internal URL) |
| `SECRET_KEY`, `JWT_SECRET_KEY`, `TICKET_QR_SIGNING_SECRET`, `PAYMENTS_WEBHOOK_SIGNING_SECRET` | Generated by Render once (random 256-bit, base64) |
| `DEV_ADMIN_PASSWORD` | Typed in the dashboard (`sync: false`) |
| `APP_ENV=staging`, `DEBUG=false`, `EXPOSE_HEALTH_DETAILS=false`, `LOG_JSON=true` | `render.yaml` |
| `OTP_DELIVERY_CHANNEL=email`, `EMAIL_PROVIDER=console`, `SMS_PROVIDER=console`, `PAYMENTS_ACTIVE_PROVIDER=sandbox`, `FIREBASE_ENABLED=false`, `MAPS_PROVIDER=local` | `render.yaml` |
| `TRUSTED_PROXY_CIDRS` | `render.yaml` (see "Rate limits behind Render's proxy") |
| `DATABASE_POOL_SIZE=3`, `DATABASE_MAX_OVERFLOW=2`, `SEED_DEMO_DATA=false` | `render.yaml` |
| `PASSENGER_SIGNUP_COUNTRIES=GH` | `render.yaml`: passengers sign up only from Ghana. See "Passenger sign-up" |
| `BOOKING_ACCEPTANCE_REQUIRED=false` | `render.yaml`: bookings skip the driver's acceptance on this test server. See "Booking acceptance" |
| `CORS_ALLOWED_ORIGINS=http://localhost:3000` | `render.yaml`, the backend default for now. Add the admin dashboard's URL once it is deployed. See "The admin dashboard" |
| `DATABASE_URL_SYNC`, `CELERY_BROKER_URL`, `CELERY_RESULT_BACKEND`, `TRUSTED_HOSTS`, `MALLOC_ARENA_MAX` | Derived by `render-start.sh` |
| `PORT`, `RENDER_EXTERNAL_HOSTNAME` | Set by Render |
| `S3_*` | Not set: uploads don't work yet |

## Free-tier limits

| Limit | What it means for TroSky |
|---|---|
| **The web service sleeps after 15 minutes** without inbound requests. Render's own wake-up takes about a minute. | On top of that comes TroSky's start: the migration check, the seeds and booting the API. With a whole CPU that took 20 s. **Under a hard 0.1-CPU limit (`docker run --cpus=0.1`) it took 302 s.** Render's real figure may be better if its 0.1 CPU can burst, which I couldn't check. So the first request after a quiet spell can take minutes, and the app's request times out once before it works. While asleep **Celery doesn't run either**: seat holds aren't released, unanswered bookings aren't moved and trips don't change status until a request wakes it. |
| 750 free instance hours per workspace per month | One service awake all month uses about 744. A second free service would run out. |
| **The free Render database expires 30 days after it is created**, then has a 14-day grace period before Render deletes it. | That's why the data moved to Supabase. trosky-db is no longer used and expires on **10 Nov 2026**; then remove its block from `render.yaml`. Supabase's own limits are under "Database: Supabase". |
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

## Sending real email

Render's free plan blocks SMTP, so real email goes through an HTTPS API instead. Staging sends
through **Gmail's own API**, from TroSky's Gmail account (backend 0.22.9): free, and no domain of
our own needed. **Brevo** and **Resend** (0.22.3) are for when we send from a domain of our own.

### Gmail's API (what staging uses)

Codes go out as ordinary Gmail messages from `troskynoreply@gmail.com`, so they arrive like any
other Gmail mail. Gmail lets a free account send roughly 500 messages a day.

Once, signed in to Google as `troskynoreply@gmail.com`:

1. In [Google Cloud](https://console.cloud.google.com), create a project (for example
   "TroSky Mail").
2. **APIs & Services** → **Library** → **Gmail API** → **Enable**.
3. **Google Auth Platform** (the OAuth consent screen) → **Get started**: app name `TroSky`,
   support email `troskynoreply@gmail.com`, audience **External**. Under **Data Access**, add the
   scope `https://www.googleapis.com/auth/gmail.send`.
4. **Audience** → **Publish app**, so the status reads **In production**. While it says
   "Testing", Google's refresh tokens stop working after 7 days. Google doesn't have to verify an
   app that only its own account uses: its consent page warns "Google hasn't verified this app";
   choose **Advanced** → **Go to TroSky**.
5. **Clients** → **Create client** → application type **Desktop app**. Copy the client ID and the
   client secret straight away (Google may not show the secret again).
6. On your laptop, in `TroSky/backend`:

   ```
   python -m scripts.gmail_refresh_token --client-id <client ID> --test-to <your email>
   ```

   Paste the client secret when asked. The browser opens Google's page: sign in as
   `troskynoreply@gmail.com` and allow **Send email on your behalf**. The script sends a test
   email to `--test-to` and prints `GMAIL_REFRESH_TOKEN=…`.
7. In Render → **trosky-api** → **Environment**, add `GMAIL_CLIENT_ID`, `GMAIL_CLIENT_SECRET` and
   `GMAIL_REFRESH_TOKEN`, never in `render.yaml` or a chat. `render.yaml` already sets
   `EMAIL_PROVIDER=gmail_api`, `EMAIL_FROM_ADDRESS` and `EMAIL_FROM_NAME`. The server refuses to
   start with `gmail_api` and any of the three missing, so add them **before** that change
   reaches `main`.

If codes stop arriving, the logs say why (`otp_delivery_failed`, `email_api_refused`).
`invalid_grant` means the refresh token no longer works: the account's password was changed, its
access was removed at [myaccount.google.com/permissions](https://myaccount.google.com/permissions),
or the app was left in "Testing". Run the script again and replace `GMAIL_REFRESH_TOKEN`.

The same settings work on a developer's machine, in `.env` (which git ignores), in place of SMTP
or MailHog. Every code then goes to a real inbox and counts against the day's limit.

### Brevo or Resend (for a domain of our own)

Both services have a free tier:

- **Brevo** (about 300 emails a day free, to any address): Settings → **Senders, Domains &
  Dedicated IPs** → **Senders** → add the address codes come from and confirm it from the email
  Brevo sends; then Settings → **SMTP & API** → **API Keys** → generate one. The key starts with
  `xkeysib-` and is shown only once. If Brevo says the transactional platform is not activated,
  its support activates new accounts.
- **Resend** (about 100 a day free): it sends only from a domain you verify; its test sender reaches only
  your own address.

**The sender's domain.** Gmail and Yahoo have required senders to authenticate their domain since
February 2024. A free address such as a Gmail one can be added as a Brevo sender, but nobody but
Google can authenticate gmail.com, so Brevo sends such mail from an address of its own
(`…@….brevosend.com`): codes still arrive, more often in spam. Good enough for testing. For real
users, send from a domain you own: add it under **Senders, Domains & Dedicated IPs** →
**Domains**, publish the DNS records Brevo shows (a Brevo code, DKIM and DMARC; they can take up
to 48 hours), and set `EMAIL_FROM_ADDRESS` to an address on it, such as
`no-reply@trosky.africa`.

Then in `render.yaml` (or the service's **Environment** tab) set `EMAIL_PROVIDER` to `brevo` or
`resend` and `EMAIL_FROM_ADDRESS` to the verified sender, and add **`EMAIL_API_KEY`** in the
Environment tab only, never in `render.yaml` (it's a secret). The server refuses to start with
`brevo` or `resend` and no key. A code the service refuses to send (a sender not verified yet, the
day's quota reached) is reported to the person, who can ask again at once; the reason is in the
logs (`otp_delivery_failed`, `email_api_refused`).

The same settings work on a developer's machine, in `.env` (which git ignores), in place of
MailHog: `EMAIL_PROVIDER=brevo`, `EMAIL_API_KEY`, `EMAIL_FROM_ADDRESS` and `EMAIL_FROM_NAME`.
Every code then goes to the real inbox and counts against the day's quota.

## File uploads (Cloudflare R2)

Profile photos, driver and vehicle documents and incident photos go to a private S3-compatible
bucket; they are read back through signed links that expire after `S3_PRESIGNED_URL_TTL_SECONDS`.
Render keeps no files across deploys, so use Cloudflare R2 (10 GB free, no download fees):

1. Cloudflare dashboard → **R2** → **Create bucket** `trosky-documents`. Leave public access off.
2. R2 → **Manage API tokens** → **Create API token** with **Object Read & Write**, for that bucket
   only. Note its Access Key ID and Secret Access Key, and the account's S3 endpoint,
   `https://<account-id>.r2.cloudflarestorage.com`.
3. In trosky-api's **Environment** tab (the two keys are secrets, so not in `render.yaml`):

   | Variable | Value |
   | --- | --- |
   | `S3_ENDPOINT` | `https://<account-id>.r2.cloudflarestorage.com` |
   | `S3_REGION` | `auto` |
   | `S3_BUCKET` | `trosky-documents` |
   | `S3_USE_SSL` | `true` |
   | `S3_ACCESS_KEY` | the token's Access Key ID |
   | `S3_SECRET_KEY` | the token's Secret Access Key |

4. Check it from a checkout of the backend, with the test database running: the storage test
   uploads a file to the bucket, reads it back through a signed link, makes sure it can't be read
   without one, and deletes it:

   ```bash
   TROSKY_TEST_S3_ENDPOINT=https://<account-id>.r2.cloudflarestorage.com \
   TROSKY_TEST_S3_REGION=auto TROSKY_TEST_S3_BUCKET=trosky-documents \
   TROSKY_TEST_S3_ACCESS_KEY=... TROSKY_TEST_S3_SECRET_KEY=... \
   pytest tests/integration/test_s3_storage.py
   ```

Since backend 0.22.4 the uploads send checksums only where an operation requires them: newer
versions of the S3 library add them to every upload, which R2 has refused.

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

The demo seed books a sample trip for the demo passenger the way the app does: its driver
accepts it, then it is paid. It runs with booking acceptance on or off (since backend 0.22.1;
before, `render-start.sh` had to switch acceptance off for the seed).

## Passenger sign-up

Since backend 0.21.0 a passenger can only sign up with the phone's location, and it must be in
Ghana: `render.yaml` sets `PASSENGER_SIGNUP_COUNTRIES=GH`.
- **The app:** sends the location since frontend Step 12 (PR #44, the staging APK of 20 Oct
  2026). **Older builds can't sign passengers up any more** (`422 LOCATION_REQUIRED`): testers
  need the new APK. Drivers aren't affected.
- **Checking it:** the start log says `the phone's location must be in GH` (or
  `passenger sign-up: no location needed` when the check is off).
- **Switching it off** (e.g. for an old build): set the value to a single space `" "` in
  `render.yaml` and push. The backend ignores blank entries, so it reads as empty. Change it in
  `render.yaml`, not the dashboard: a Blueprint sync overwrites dashboard edits.

## Payments: MTN MoMo sandbox

`render.yaml` pays through the built-in sandbox provider (`PAYMENTS_ACTIVE_PROVIDER=sandbox`), which
approves everything without calling anyone. To take test payments through MTN's own sandbox
(backend 0.22.5), where the payer approves a prompt, with play money:

1. Sign up at https://momodeveloper.mtn.com, subscribe to the **Collections** product, and copy
   its **Primary key** (Profile → Subscriptions).
2. From a checkout of the backend, make the sandbox API user and key. The script checks them by
   asking MTN for a token, then prints the settings:

   ```bash
   python -m scripts.momo_sandbox_setup --subscription-key <primary key> \
       --callback-host trosky-api.onrender.com
   ```

3. In `render.yaml` set `PAYMENTS_ACTIVE_PROVIDER` to `mtn_momo` (a Blueprint sync would put back
   any other value), and in the service's **Environment** tab add the rest the script printed:
   `PAYMENTS_MTN_MOMO_CURRENCY=EUR` (the sandbox takes only euros),
   `PAYMENTS_MTN_MOMO_CALLBACK_URL`, and the three secrets (`..._SUBSCRIPTION_KEY`, `..._API_KEY`,
   `..._API_SECRET`). Wallet payments carry on as before; Telecel Cash, AirtelTigo Money and cards
   then answer that the channel is unavailable.
4. Pay for a booking: `POST /api/v1/bookings/{id}/pay` with
   `{"channel": "mtn_momo", "payer_phone_number": "0241234567"}`. The payment is `processing` until
   MTN answers, then the booking is confirmed.

How a payment completes. MTN posts the outcome to the callback URL (POST or PUT). It isn't signed,
so the backend doesn't believe it: it asks MTN for that payment's status and applies MTN's answer.
The reconciliation task also asks MTN every 2 minutes about payments still processing, so they
complete even if a callback is lost.

Test numbers: MTN's sandbox documentation lists payer numbers with fixed outcomes (such as one that
always fails and one that stays pending); other numbers are approved. They aren't Ghanaian numbers,
so the backend passes them to MTN as typed.

Refunds: MTN Collections has no refund. A refund of a MoMo payment is paid to the passenger's wallet
or by hand, as before.

Going live later: MTN issues the production API user and key itself. Set
`PAYMENTS_MTN_MOMO_BASE_URL` to MTN's production address, `PAYMENTS_MTN_MOMO_TARGET_ENVIRONMENT` to
`mtnghana`, and `PAYMENTS_MTN_MOMO_CURRENCY` empty (GHS).

## Booking acceptance

Since backend 0.20.0 a new booking waits for the trip's driver, or an admin, to accept it:
- **Waiting:** the booking is `awaiting_acceptance`, and `expires_at` is the deadline for an
  answer (`BOOKING_ACCEPT_TIMEOUT_SECONDS`, 120 s).
- **Unanswered or declined:** it moves to another vehicle going the same way, or ends uncharged.
- **Once accepted:** it is `pending`, and the passenger has 10 minutes to pay.

**On this test server acceptance is off:** `render.yaml` sets `BOOKING_ACCEPTANCE_REQUIRED=false`.
New bookings go straight to `pending` with 10 minutes to pay, as before 0.20.0, which is what the
current app expects (it doesn't know the waiting state yet). The start log shows
`booking acceptance by the driver: false`.

Change it in `render.yaml`, not in the dashboard: a Blueprint sync overwrites dashboard edits to
variables `render.yaml` sets. That happened once: the value set in the dashboard was reset to
`true` by the next sync.

**Switch acceptance on** (`"true"` in `render.yaml`) to test the waiting step, then accept as
below.

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
| Supabase | Pro plan | No pausing, daily backups, more room than 500 MB | Same connection string; nothing changes on Render. |
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
| Database password | Supabase → **Project Settings → Database → Reset database password**, then put the new Session pooler URI in trosky-api's `DATABASE_URL` and **Save, rebuild and deploy**. URL-encode special characters, or use letters and digits only. |
| Key Value credentials | Linked by `fromService`: after Render issues new credentials, redeploy trosky-api to pick them up. |

## Known issues found while testing (backend code, not this deployment)

Fixed in backend 0.22.1:
- **Celery tasks and event loops:** tasks now share one event loop per worker process (see
  "Celery: one task at a time" above).
- **Password hashing blocked the API:** under a hard 0.1-CPU limit one login took 17 s, and
  `/health/live` waited up to 8 s behind it, past Render's 5-second health-check timeout. Hashing
  now runs in a thread pool of its own, `PASSWORD_HASH_CONCURRENCY` (default 2) at a time, so
  health checks and other requests are answered meanwhile. A login still takes seconds on 0.1
  CPU; the Starter plan's 0.5 CPU, or lighter hash parameters for staging, would shorten it.
- **The demo seed and booking acceptance:** see "Demo data" above.

Still open:
1. **The Dockerfile's `HEALTHCHECK` probes port 8000**, not `$PORT`; see below.

## Running it locally like Render

The deployment was tested with:
- the image built from `TroSky/backend`;
- `postgis/postgis:17-3.5` and `valkey/valkey:8` (25 MB, `noeviction`);
- the container limited to 512 MB;
- only the variables `render.yaml` provides, with connection strings in Render's `postgresql://`
  and `postgres://` forms, plus `PORT`, `RENDER` and `RENDER_EXTERNAL_HOSTNAME`.

A local Postgres without TLS also needs `DATABASE_SSLMODE=disable` (the start script requires
TLS by default, for Supabase).

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
