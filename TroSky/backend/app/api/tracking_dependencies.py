"""A trip while it is moving: live location, and safety (SOS, incidents)."""

from __future__ import annotations

from typing import Annotated

from fastapi import Depends

from app.api.common_dependencies import DbSession, RedisClient
from app.services.safety_service import SafetyService
from app.services.system_settings_service import effective_settings
from app.services.tracking_service import TrackingService


async def get_tracking_service(db: DbSession, redis: RedisClient) -> TrackingService:
    # The live-update interval is an admin setting.
    return TrackingService(db, redis, await effective_settings(db))


def get_safety_service(db: DbSession) -> SafetyService:
    return SafetyService(db)


TrackingServiceDep = Annotated[TrackingService, Depends(get_tracking_service)]
SafetyServiceDep = Annotated[SafetyService, Depends(get_safety_service)]
