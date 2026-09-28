"""FastAPI application factory and ASGI entrypoint.

Run locally with::

    uvicorn app.main:app --reload

Production runs via Gunicorn + Uvicorn workers (see ``Dockerfile`` /
``Makefile``) invoking the same ``app`` object produced by :func:`create_app`.
"""

from __future__ import annotations

from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI
from starlette.middleware.cors import CORSMiddleware
from starlette.middleware.trustedhost import TrustedHostMiddleware

from app.api import dependencies as api_dependencies
from app.api.health import router as health_router
from app.api.router import api_router
from app.core.background import drain_background_jobs
from app.core.config import Settings, get_settings
from app.core.database import dispose_engine, get_engine
from app.core.exceptions import register_exception_handlers
from app.core.logging import configure_logging, get_logger
from app.core.permissions import get_current_principal as placeholder_get_current_principal
from app.core.redis import close_redis, get_redis_client
from app.core.telemetry import configure_telemetry
from app.middleware.request_context import (
    AccessLogMiddleware,
    CorrelationIdMiddleware,
    RequestSizeLimitMiddleware,
)

logger = get_logger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    settings = get_settings()
    logger.info(
        "application_starting",
        app_env=settings.APP_ENV.value,
        app_version=settings.APP_VERSION,
    )
    # Warm the DB engine and Redis client eagerly so a broken connection
    # surfaces at startup, not on the first unlucky request.
    get_engine()
    get_redis_client()
    yield
    logger.info("application_shutting_down")
    await drain_background_jobs(timeout_seconds=10)
    await dispose_engine()
    await close_redis()


def create_app(settings: Settings | None = None) -> FastAPI:
    settings = settings or get_settings()
    configure_logging(log_level=settings.LOG_LEVEL, json_logs=settings.LOG_JSON)

    docs_enabled = settings.DEBUG or not settings.is_production
    app = FastAPI(
        title=settings.APP_NAME,
        version=settings.APP_VERSION,
        description=(
            "TroSky: Smart Public Transport Platform for Ghana — backend API. "
            "Monetary values are GHS minor units (pesewas). All timestamps are "
            "UTC unless explicitly documented otherwise."
        ),
        docs_url="/docs" if docs_enabled else None,
        redoc_url="/redoc" if docs_enabled else None,
        openapi_url="/openapi.json" if docs_enabled else None,
        lifespan=lifespan,
    )

    # --- Security-relevant middleware (order matters: outermost first) ----
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins,
        allow_credentials=True,
        allow_methods=["GET", "POST", "PATCH", "PUT", "DELETE", "OPTIONS"],
        allow_headers=["Authorization", "Content-Type", "Idempotency-Key", "X-Request-ID"],
        expose_headers=["X-Request-ID"],
    )
    app.add_middleware(TrustedHostMiddleware, allowed_hosts=settings.trusted_hosts)
    app.add_middleware(RequestSizeLimitMiddleware, settings=settings)
    app.add_middleware(AccessLogMiddleware)
    app.add_middleware(CorrelationIdMiddleware)

    register_exception_handlers(app)
    configure_telemetry(app, settings)

    # `app.core.permissions.require_roles` / `require_permissions` depend on
    # a placeholder `get_current_principal` (kept dependency-free of the
    # database/repositories to preserve core/ layering). The real,
    # database-backed implementation lives in `app.api.dependencies` — swap
    # it in here via FastAPI's dependency-override mechanism so every route
    # built on `require_roles`/`require_permissions` gets real auth without
    # importing api-layer code from core/.
    app.dependency_overrides[placeholder_get_current_principal] = (
        api_dependencies.get_current_principal
    )

    app.include_router(health_router)
    app.include_router(api_router, prefix=settings.API_PREFIX)

    return app


app = create_app()
