#!/usr/bin/env bash
# Entrypoint for the api/worker/scheduler containers.
#
# Responsibilities:
#   1. Wait for Postgres and Redis to accept connections.
#   2. If SERVICE_ROLE=api, run Alembic migrations exactly once before serving
#      traffic, then add any missing roles/permissions (a Kubernetes Job also
#      does both independently for the cluster deployment path — this covers
#      docker-compose/local use).
#   3. Exec the real process (replaces PID 1, so signals propagate correctly).
set -euo pipefail

SERVICE_ROLE="${SERVICE_ROLE:-api}"

echo "[entrypoint] waiting for dependencies..."
python -m scripts.wait_for_services

if [ "$SERVICE_ROLE" = "api" ] && [ "${RUN_MIGRATIONS_ON_START:-true}" = "true" ]; then
    echo "[entrypoint] running database migrations..."
    alembic upgrade head
    echo "[entrypoint] ensuring roles and permissions..."
    python -m scripts.seed_reference_data
fi

echo "[entrypoint] starting: $*"
exec "$@"
