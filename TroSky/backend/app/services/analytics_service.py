"""Fleet-owner analytics (tenant-isolated to the caller's own fleet) and
the admin platform overview report."""

from __future__ import annotations

import uuid

from sqlalchemy.ext.asyncio import AsyncSession

from app.providers.storage.malware_scan import NoOpMalwareScanner
from app.providers.storage.sandbox import SandboxStorageProvider
from app.repositories.analytics_repository import (
    AnalyticsRepository,
    FleetSummary,
    PlatformOverview,
)
from app.repositories.vehicle_repository import VehicleRepository
from app.services.fleet_service import FleetService


class AnalyticsService:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session
        self._analytics = AnalyticsRepository(session)
        self._vehicles = VehicleRepository(session)
        # FleetService needs storage/scanner dependencies it doesn't
        # actually exercise here (only `get_own_fleet`'s tenant-isolation
        # check is used) — the sandbox implementations are the correct,
        # side-effect-free choice for a component that never touches a
        # document.
        self._fleets = FleetService(session, SandboxStorageProvider(), NoOpMalwareScanner())

    async def get_fleet_summary(self, user_id: uuid.UUID, fleet_id: uuid.UUID) -> FleetSummary:
        await self._fleets.get_own_fleet(user_id, fleet_id)  # tenant-isolation check
        vehicles = await self._vehicles.list_for_fleet(fleet_id)
        return await self._analytics.get_fleet_summary([v.id for v in vehicles])

    async def get_platform_overview(self) -> PlatformOverview:
        return await self._analytics.get_platform_overview()
