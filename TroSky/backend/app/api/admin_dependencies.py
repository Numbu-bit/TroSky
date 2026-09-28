"""Operations: account administration and platform analytics."""

from __future__ import annotations

from typing import Annotated

from fastapi import Depends

from app.api.common_dependencies import DbSession
from app.services.admin_service import AdminService
from app.services.analytics_service import AnalyticsService


def get_admin_service(db: DbSession) -> AdminService:
    return AdminService(db)


def get_analytics_service(db: DbSession) -> AnalyticsService:
    return AnalyticsService(db)


AdminServiceDep = Annotated[AdminService, Depends(get_admin_service)]
AnalyticsServiceDep = Annotated[AnalyticsService, Depends(get_analytics_service)]
