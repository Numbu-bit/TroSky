"""Liveness, readiness, and (restricted) detail health endpoints.

Deliberately mounted *outside* ``/api/v1`` (at ``/health/*``) since these are
infrastructure probes (Kubernetes liveness/readiness), not versioned product
API surface.
"""

from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, status
from fastapi.responses import JSONResponse
from pydantic import BaseModel

from app.core.config import Settings, get_settings
from app.core.database import check_database_connection
from app.core.exceptions import NotFoundError
from app.core.redis import check_redis_connection

router = APIRouter(tags=["health"])


class LivenessResponse(BaseModel):
    status: str = "alive"


class ReadinessResponse(BaseModel):
    status: str
    database: bool
    redis: bool


class HealthDetailResponse(BaseModel):
    status: str
    app_name: str
    app_version: str
    app_env: str
    database: bool
    redis: bool


@router.get("/health/live", response_model=LivenessResponse)
async def liveness() -> LivenessResponse:
    """Process is up and able to serve requests at all (no dependency checks).

    Kubernetes uses this to decide whether to restart the pod.
    """
    return LivenessResponse()


@router.get("/health/ready", response_model=ReadinessResponse)
async def readiness() -> JSONResponse:
    """Process is ready to serve traffic: dependent services are reachable.

    Kubernetes uses this to decide whether to route traffic to the pod.
    """
    db_ok = await check_database_connection()
    redis_ok = await check_redis_connection()
    ready = db_ok and redis_ok
    body = ReadinessResponse(
        status="ready" if ready else "not_ready", database=db_ok, redis=redis_ok
    )
    return JSONResponse(
        status_code=status.HTTP_200_OK if ready else status.HTTP_503_SERVICE_UNAVAILABLE,
        content=body.model_dump(),
    )


@router.get("/health/details", response_model=HealthDetailResponse)
async def health_details(
    settings: Annotated[Settings, Depends(get_settings)],
) -> HealthDetailResponse:
    """Verbose health/version info. Restricted: disabled entirely in
    production (``EXPOSE_HEALTH_DETAILS=false``) and never returns secrets,
    credentials, or infrastructure internals — only booleans and version
    metadata already visible on the public OpenAPI schema."""
    if not settings.EXPOSE_HEALTH_DETAILS:
        raise NotFoundError()
    db_ok = await check_database_connection()
    redis_ok = await check_redis_connection()
    return HealthDetailResponse(
        status="ready" if (db_ok and redis_ok) else "degraded",
        app_name=settings.APP_NAME,
        app_version=settings.APP_VERSION,
        app_env=settings.APP_ENV.value,
        database=db_ok,
        redis=redis_ok,
    )
