"""Supply side: drivers and fleet owners, both of which handle document uploads."""

from __future__ import annotations

from typing import Annotated

from fastapi import Depends

from app.api.common_dependencies import DbSession, MalwareScannerDep, StorageProviderDep
from app.services.driver_service import DriverService
from app.services.fleet_service import FleetService


def get_driver_service(
    db: DbSession, storage: StorageProviderDep, scanner: MalwareScannerDep
) -> DriverService:
    return DriverService(db, storage, scanner)


def get_fleet_service(
    db: DbSession, storage: StorageProviderDep, scanner: MalwareScannerDep
) -> FleetService:
    return FleetService(db, storage, scanner)


DriverServiceDep = Annotated[DriverService, Depends(get_driver_service)]
FleetServiceDep = Annotated[FleetService, Depends(get_fleet_service)]
