#!/usr/bin/env bash
# Entrypoint for the api/worker/scheduler containers.
#
# Responsibilities:
#   1. Wait for Postgres and Redis to accept connections.
#   2. If SERVICE_ROLE=api, run Alembic migrations exactly once before serving
#      traffic (a Kubernetes Job also runs migrations independently for the
#      cluster deployment path — this covers docker-compose/local use).
#   3. Exec the real process (replaces PID 1, so signals propagate correctly).
set -euo pipefail

SERVICE_ROLE="${SERVICE_ROLE:-api}"

echo "[entrypoint] waiting for dependencies..."
python -m scripts.wait_for_services

if [ "$SERVICE_ROLE" = "api" ] && [ "${RUN_MIGRATIONS_ON_START:-true}" = "true" ]; then
    echo "[entrypoint] running database migrations..."
    alembic upgrade head
fi

echo "[entrypoint] starting: $*"
exec "$@"
