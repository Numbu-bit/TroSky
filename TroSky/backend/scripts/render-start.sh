#!/usr/bin/env bash
# Start command of the Render web service "trosky-api" (render.yaml at the
# repository root). See docs/deploy-render.md.
#
# Render's free plan has no background workers, so this one container runs:
#   * a Celery worker with the beat scheduler embedded (seat holds expire,
#     unanswered bookings move, trips change status), in the background;
#   * the API: Gunicorn with one Uvicorn worker.
# If either of them stops, the container exits (status 1) and Render
# restarts it.
#
# Before that it turns Render's connection strings into the URLs the app
# expects, waits for Postgres and Key Value, migrates the database and adds
# the reference data (roles and permissions). The API starts first, Celery
# once the API answers. An administrator account is
# created only from DEV_ADMIN_PASSWORD, and demo data only with
# SEED_DEMO_DATA=true. No secret is ever printed.
set -euo pipefail

log() { echo "[render-start] $*"; }

# Fewer malloc arenas: less memory per Python process, to fit 512 MB.
export MALLOC_ARENA_MAX="${MALLOC_ARENA_MAX:-2}"

# --- Database: Render gives postgres://… or postgresql://… ------------------
# The app talks asyncpg, Alembic talks psycopg 3. Only the scheme changes:
# Render's internal URL has no query string, and both drivers default to
# sslmode "prefer", which Render's internal connections accept (they offer
# TLS with a self-signed certificate, so "verify-*" modes can't be used).
db_url="${DATABASE_URL:?DATABASE_URL is not set (render.yaml: fromDatabase trosky-db)}"
db_rest="${db_url#*://}"
export DATABASE_URL="postgresql+asyncpg://${db_rest}"
export DATABASE_URL_SYNC="postgresql+psycopg://${db_rest}"

# --- Key Value: one database for everything -------------------------------
# Render documents no logical database indexes for Key Value, so the cache,
# rate limits, the Celery broker and its results share the URL as given.
# Their keys don't collide (Celery's are "celery*", "_kombu.*").
redis_url="${REDIS_URL:?REDIS_URL is not set (render.yaml: fromService trosky-redis)}"
export CELERY_BROKER_URL="${CELERY_BROKER_URL:-$redis_url}"
export CELERY_RESULT_BACKEND="${CELERY_RESULT_BACKEND:-$redis_url}"

# --- Host header: Render's health checks use the onrender.com hostname -----
TRUSTED_HOSTS="${TRUSTED_HOSTS:-localhost,127.0.0.1}"
if [ -n "${RENDER_EXTERNAL_HOSTNAME:-}" ]; then
    TRUSTED_HOSTS="${TRUSTED_HOSTS},${RENDER_EXTERNAL_HOSTNAME}"
fi
export TRUSTED_HOSTS

# --- Say which test-server switches are on -----------------------------------
signup_countries="${PASSENGER_SIGNUP_COUNTRIES-GH}"
signup_countries="${signup_countries//[ ,]/}"
if [ -z "$signup_countries" ]; then
    log "passenger sign-up: no location needed (PASSENGER_SIGNUP_COUNTRIES is empty)"
else
    log "passenger sign-up: the phone's location must be in ${PASSENGER_SIGNUP_COUNTRIES-GH}"
fi
log "booking acceptance by the driver: ${BOOKING_ACCEPTANCE_REQUIRED:-true}"

# --- Wait for Postgres and Key Value ---------------------------------------
# A plain TCP check in bash: on Render's 0.1 CPU every Python process that
# imports the app costs most of a minute, and this runs on every start
# (every wake-up from sleep). Alembic then connects for real and stops the
# start (and Render retries) if the database isn't ready after all.
endpoint() {  # "host port" of a URL scheme://[user[:password]@]host[:port][/…]
    local rest="${1#*://}"
    rest="${rest##*@}"
    rest="${rest%%/*}"
    rest="${rest%%\?*}"
    local host="${rest%%:*}" port="${rest##*:}"
    [ "$port" = "$rest" ] && port="$2"
    echo "$host $port"
}
wait_for() {  # name host port
    local i
    for i in $(seq 1 60); do
        if (exec 3<>"/dev/tcp/$2/$3") 2>/dev/null; then
            return 0
        fi
        sleep 2
    done
    log "$1 ($2:$3) did not answer within 2 minutes"
    return 1
}
log "waiting for Postgres and Key Value"
wait_for Postgres $(endpoint "$db_url" 5432)
wait_for "Key Value" $(endpoint "$redis_url" 6379)

log "migrating the database"
alembic upgrade head

# --- Reference data, and the administrator only from DEV_ADMIN_PASSWORD -----
# Roles and permissions always (idempotent; creates no users). The
# administrator: scripts/seed_dev_data.py would fall back to a password
# written in the code, and also adds example routes, so it is not run here.
# Only its ensure_dev_admin() is, once the password has been checked here;
# it does nothing when the administrator already exists. One Python process
# for both, to keep starts short.
create_admin=0
admin_password="${DEV_ADMIN_PASSWORD:-}"
if [ -z "$admin_password" ]; then
    log "DEV_ADMIN_PASSWORD is not set: no administrator account is created"
elif [ "${#admin_password}" -lt 12 ]; then
    log "DEV_ADMIN_PASSWORD is shorter than 12 characters: no administrator account is created"
elif [ "$admin_password" = "TroSkyDevAdmin!2026" ]; then
    log "DEV_ADMIN_PASSWORD is the public development default: no administrator account is created"
else
    create_admin=1
fi
unset admin_password

log "adding missing roles and permissions"
CREATE_ADMIN="$create_admin" python - <<'PY'
import asyncio
import os

from app.core.database import dispose_engine, transactional_session
from app.core.logging import configure_logging
from app.core.permissions import SystemRole
from scripts.seed_dev_data import ensure_dev_admin
from scripts.seed_reference_data import ensure_roles, seed_reference_data


async def main() -> None:
    configure_logging(log_level="INFO", json_logs=True)
    try:
        await seed_reference_data()
        if os.environ.get("CREATE_ADMIN") == "1":
            async with transactional_session() as session:
                roles = await ensure_roles(session)
                await ensure_dev_admin(session, roles[SystemRole.ADMIN.value])
    finally:
        await dispose_engine()


asyncio.run(main())
PY

# --- Demo data: only on request --------------------------------------------
if [ "${SEED_DEMO_DATA:-false}" = "true" ]; then
    log "SEED_DEMO_DATA=true: loading demo stops, routes, trips and accounts"
    # The demo seed confirms its sample booking straight away, which a
    # booking still waiting for its driver can't be (0.20.0, booking
    # acceptance), so the seed alone runs without that step; the server
    # keeps it. Demo data is optional: if loading it fails, the server
    # starts anyway.
    if ! BOOKING_ACCEPTANCE_REQUIRED=false python -m scripts.seed_demo_data; then
        log "loading the demo data failed (see above): starting without it"
    fi
fi

# --- The API ----------------------------------------------------------------
# Started first: Render's health check waits for it, and on 0.1 CPU it boots
# faster without Celery booting alongside. One Uvicorn worker. Uvicorn only
# rewrites the client address for proxies in --forwarded-allow-ips (default
# 127.0.0.1), so the app sees Render's proxy as the peer and
# app.core.client_ip applies TRUSTED_PROXY_CIDRS.
port="${PORT:-10000}"
log "starting the API on port $port"
gunicorn app.main:app \
    --worker-class uvicorn.workers.UvicornWorker \
    --workers 1 \
    --bind "0.0.0.0:$port" \
    --timeout 120 \
    --graceful-timeout 30 \
    --access-logfile - \
    --error-logfile - &
api_pid=$!
celery_pid=""

# Gunicorn isn't exec'd: it exits 0 when stopped, so a Celery crash could
# only end the container "successfully", and Render doesn't document
# restarting a web service that exits 0. Instead this script stays PID 1:
# Render's stop signal (SIGTERM) is passed on and the script exits 0; if
# either process ends by itself, the other is stopped and the container
# exits 1, which Render treats as a crash and restarts.
stop_all() {
    local pids="$api_pid $celery_pid"
    # shellcheck disable=SC2086 # word splitting wanted: one or two PIDs
    kill -TERM $pids 2>/dev/null || true
    # shellcheck disable=SC2086
    wait $pids 2>/dev/null || true
}
trap 'log "stopping (SIGTERM)"; stop_all; exit 0' TERM INT

# Wait (up to 10 minutes) for the API to answer, unless it stops.
for i in $(seq 1 300); do
    if ! kill -0 "$api_pid" 2>/dev/null; then
        log "the API stopped while starting"
        stop_all
        exit 1
    fi
    if curl -fsS -m 5 -o /dev/null "http://127.0.0.1:$port/health/live" 2>/dev/null; then
        break
    fi
    sleep 2
done

# --- Celery worker with embedded beat ---------------------------------------
# One task at a time, each in a fresh child process (--max-tasks-per-child 1).
# The tasks call asyncio.run(), a new event loop per task, while the
# database engine and Redis client are process-wide; a second task in the
# same process gets connections tied to the first task's closed loop
# ("attached to a different loop"). The solo pool runs every task in one
# process, and about half of them failed that way. A fresh child per task
# costs a fork every few seconds and stays inside 512 MB.
# /app isn't writable by the trosky user, so beat keeps its schedule in
# /tmp (lost on restart, which only means each periodic task runs at start).
log "starting the Celery worker with beat"
celery -A app.workers.celery_app worker \
    --beat --schedule /tmp/celerybeat-schedule \
    --pool prefork --concurrency 1 --max-tasks-per-child 1 \
    --loglevel INFO &
celery_pid=$!

# --- Supervise both -----------------------------------------------------------
set +e
wait -n "$api_pid" "$celery_pid"
status=$?
set -e
if kill -0 "$api_pid" 2>/dev/null; then
    log "the Celery worker stopped (status $status): stopping the API"
else
    log "the API stopped (status $status): stopping the Celery worker"
fi
stop_all
exit 1
