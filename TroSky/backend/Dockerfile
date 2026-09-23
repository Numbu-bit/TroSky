# syntax=docker/dockerfile:1.7
# =============================================================================
# TroSky backend — multi-stage production image
# =============================================================================

# --- Stage 1: builder --------------------------------------------------
FROM python:3.12-slim AS builder

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /build

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        libpq-dev \
    && rm -rf /var/lib/apt/lists/*

COPY pyproject.toml ./
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Install runtime dependencies only (no dev/test extras) into the venv.
RUN pip install --upgrade pip \
    && pip install .

COPY app ./app
COPY alembic ./alembic
COPY alembic.ini ./alembic.ini
RUN pip install --no-deps .

# --- Stage 2: runtime -----------------------------------------------
FROM python:3.12-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH" \
    APP_ENV=production

RUN apt-get update && apt-get install -y --no-install-recommends \
        libpq5 \
        curl \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid 1000 trosky \
    && useradd --uid 1000 --gid trosky --shell /usr/sbin/nologin --create-home trosky

COPY --from=builder /opt/venv /opt/venv
WORKDIR /app
COPY --chown=trosky:trosky app ./app
COPY --chown=trosky:trosky alembic ./alembic
COPY --chown=trosky:trosky alembic.ini ./alembic.ini
COPY --chown=trosky:trosky scripts ./scripts

USER trosky

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD curl --fail http://localhost:8000/health/live || exit 1

# Production start command: Gunicorn managing Uvicorn workers.
# Worker count / timeouts are tunable via env vars in the Helm chart / k8s manifests.
CMD ["gunicorn", "app.main:app", \
     "--worker-class", "uvicorn.workers.UvicornWorker", \
     "--workers", "4", \
     "--bind", "0.0.0.0:8000", \
     "--timeout", "30", \
     "--graceful-timeout", "30", \
     "--access-logfile", "-", \
     "--error-logfile", "-"]
