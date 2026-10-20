"""Fleet owner, fleet, vehicle, vehicle-document, seat-layout, and
driver-assignment business logic.

Tenant isolation is enforced throughout: every fleet/vehicle lookup is
scoped to the caller's own ``FleetOwner`` record, and a fleet/vehicle
belonging to another owner is reported as :class:`NotFoundError` (never
:class:`ForbiddenError`) so its existence isn't leaked to a non-owner.
"""

from __future__ import annotations

import uuid
from dataclasses import dataclass
from datetime import datetime

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.admin_events import announce
from app.core.config import Settings, get_settings
from app.core.exceptions import (
    ConflictError,
    ForbiddenError,
    InvalidStateTransitionError,
    NotFoundError,
    ValidationAppError,
)
from app.core.logging import get_logger
from app.core.permissions import SystemRole
from app.models.drivers import ApprovalDecision, ApprovalStatus, DocumentType
from app.models.vehicles import (
    Fleet,
    FleetOwner,
    Vehicle,
    VehicleDocument,
    VehicleSeat,
    VehicleSeatLayout,
)
from app.providers.storage.base import ObjectStorageProvider
from app.providers.storage.malware_scan import MalwareScanner
from app.repositories.driver_repository import DriverRepository
from app.repositories.fleet_repository import FleetOwnerRepository, FleetRepository
from app.repositories.vehicle_repository import SeatSpec, VehicleRepository
from app.schemas.fleet import (
    FleetCreateRequest,
    FleetOwnerRegisterRequest,
    FleetUpdateRequest,
    SeatLayoutRequest,
    VehicleCreateRequest,
    VehicleUpdateRequest,
)
from app.services.document_service import store_uploaded_document
from app.services.role_service import assert_can_take_role, grant_role
from app.utilities.phone import (
    InvalidPhoneNumberError,
    mask_phone_number,
    normalize_phone_number,
)

logger = get_logger(__name__)

# Only vehicles in this status may ever be assigned to an active trip.
OPERATIONAL_STATUS = ApprovalStatus.APPROVED


@dataclass(frozen=True, slots=True)
class FleetDriverVehicle:
    vehicle_id: uuid.UUID
    registration_number: str
    assigned_at: datetime


@dataclass(frozen=True, slots=True)
class FleetDriver:
    driver_id: uuid.UUID
    full_name: str | None
    phone_number: str
    approval_status: ApprovalStatus
    vehicles: list[FleetDriverVehicle]


@dataclass(frozen=True, slots=True)
class DriverLookup:
    driver_id: uuid.UUID
    full_name: str | None
    phone_number: str  # masked
    approval_status: ApprovalStatus


class FleetService:
    def __init__(
        self,
        session: AsyncSession,
        storage: ObjectStorageProvider,
        scanner: MalwareScanner,
        settings: Settings | None = None,
    ) -> None:
        self._session = session
        self._storage = storage
        self._scanner = scanner
        self._settings = settings or get_settings()
        self._owners = FleetOwnerRepository(session)
        self._fleets = FleetRepository(session)
        self._vehicles = VehicleRepository(session)
        self._drivers = DriverRepository(session)

    # ------------------------------------------------------------------
    # Fleet owner
    # ------------------------------------------------------------------
    async def register(self, user_id: uuid.UUID, request: FleetOwnerRegisterRequest) -> FleetOwner:
        if await self._owners.get_by_user_id(user_id) is not None:
            raise ConflictError("A fleet-owner profile already exists for this account.")
        # Not a passenger account: fleet owners have accounts of their own
        # (app.services.role_service). A driver may become one.
        await assert_can_take_role(self._session, user_id, SystemRole.FLEET_OWNER)
        owner = await self._owners.create(
            user_id=user_id,
            business_name=request.business_name,
            business_registration_number=request.business_registration_number,
        )
        await grant_role(self._session, user_id, SystemRole.FLEET_OWNER)
        logger.info("fleet_owner_registered", fleet_owner_id=str(owner.id), user_id=str(user_id))
        return owner

    async def get_own_profile(self, user_id: uuid.UUID) -> FleetOwner:
        owner = await self._owners.get_by_user_id(user_id)
        if owner is None:
            raise NotFoundError("No fleet-owner profile exists for this account.")
        return owner

    # ------------------------------------------------------------------
    # Fleets
    # ------------------------------------------------------------------
    async def create_fleet(self, user_id: uuid.UUID, request: FleetCreateRequest) -> Fleet:
        owner = await self.get_own_profile(user_id)
        return await self._fleets.create(
            fleet_owner_id=owner.id, name=request.name, description=request.description
        )

    async def list_own_fleets(self, user_id: uuid.UUID) -> list[Fleet]:
        owner = await self.get_own_profile(user_id)
        return await self._fleets.list_for_owner(owner.id)

    async def get_own_fleet(self, user_id: uuid.UUID, fleet_id: uuid.UUID) -> Fleet:
        owner = await self.get_own_profile(user_id)
        fleet = await self._fleets.get_by_id(fleet_id)
        if fleet is None or fleet.fleet_owner_id != owner.id:
            raise NotFoundError("Fleet not found.")
        return fleet

    async def update_fleet(
        self, user_id: uuid.UUID, fleet_id: uuid.UUID, request: FleetUpdateRequest
    ) -> Fleet:
        fleet = await self.get_own_fleet(user_id, fleet_id)
        await self._fleets.update(fleet, **request.model_dump(exclude_unset=True))
        return fleet

    # ------------------------------------------------------------------
    # Vehicles
    # ------------------------------------------------------------------
    async def create_vehicle(
        self, user_id: uuid.UUID, fleet_id: uuid.UUID, request: VehicleCreateRequest
    ) -> Vehicle:
        fleet = await self.get_own_fleet(user_id, fleet_id)
        if await self._vehicles.get_by_registration_number(request.registration_number):
            raise ConflictError(
                "A vehicle with this registration number already exists.",
                code="VEHICLE_ALREADY_REGISTERED",
            )
        vehicle = await self._vehicles.create(
            fleet_id=fleet.id,
            registration_number=request.registration_number,
            vehicle_type=request.vehicle_type,
            make=request.make,
            model=request.model,
            year=request.year,
            capacity=request.capacity,
        )
        await self._vehicles.set_status(
            vehicle,
            new_status=ApprovalStatus.PENDING,
            changed_by=user_id,
            reason="Initial registration",
        )
        announce(
            self._session,
            "approval.requested",
            kind="vehicle",
            vehicle_id=vehicle.id,
            fleet_id=fleet.id,
            registration_number=vehicle.registration_number,
        )
        return vehicle

    async def list_vehicles_for_fleet(
        self, user_id: uuid.UUID, fleet_id: uuid.UUID
    ) -> list[Vehicle]:
        await self.get_own_fleet(user_id, fleet_id)
        return await self._vehicles.list_for_fleet(fleet_id)

    async def get_own_vehicle(self, user_id: uuid.UUID, vehicle_id: uuid.UUID) -> Vehicle:
        owner = await self.get_own_profile(user_id)
        vehicle = await self._vehicles.get_by_id(vehicle_id)
        if vehicle is None:
            raise NotFoundError("Vehicle not found.")
        owned_fleet_ids = set(await self._vehicles.list_fleet_ids_for_owner(owner.id))
        if vehicle.fleet_id not in owned_fleet_ids:
            raise NotFoundError("Vehicle not found.")
        return vehicle

    async def update_vehicle(
        self, user_id: uuid.UUID, vehicle_id: uuid.UUID, request: VehicleUpdateRequest
    ) -> Vehicle:
        vehicle = await self.get_own_vehicle(user_id, vehicle_id)
        fields = request.model_dump(exclude_unset=True)
        for key, value in fields.items():
            if value is not None:
                setattr(vehicle, key, value)
        await self._session.flush()
        return vehicle

    async def upload_vehicle_document(
        self,
        user_id: uuid.UUID,
        vehicle_id: uuid.UUID,
        *,
        document_type: DocumentType,
        filename: str,
        content_type: str,
        data: bytes,
    ) -> VehicleDocument:
        vehicle = await self.get_own_vehicle(user_id, vehicle_id)
        uploaded = await store_uploaded_document(
            storage=self._storage,
            scanner=self._scanner,
            settings=self._settings,
            key_prefix=f"vehicles/{vehicle.id}/documents",
            filename=filename,
            content_type=content_type,
            data=data,
        )
        document = await self._vehicles.add_document(
            vehicle_id=vehicle.id,
            document_type=document_type,
            storage_key=uploaded.storage_key,
            original_filename=filename,
            mime_type=content_type,
            file_size_bytes=uploaded.size_bytes,
        )
        logger.info(
            "vehicle_document_uploaded", vehicle_id=str(vehicle.id), document_id=str(document.id)
        )
        announce(
            self._session,
            "approval.document_uploaded",
            kind="vehicle",
            vehicle_id=vehicle.id,
            document_id=document.id,
            document_type=document_type,
        )
        return document

    async def list_vehicle_documents(
        self, user_id: uuid.UUID, vehicle_id: uuid.UUID
    ) -> list[VehicleDocument]:
        vehicle = await self.get_own_vehicle(user_id, vehicle_id)
        return await self._vehicles.list_documents(vehicle.id)

    async def get_vehicle_document_download_url(
        self, user_id: uuid.UUID, vehicle_id: uuid.UUID, document_id: uuid.UUID
    ) -> str:
        vehicle = await self.get_own_vehicle(user_id, vehicle_id)
        document = await self._vehicles.get_document(document_id, vehicle.id)
        if document is None:
            raise NotFoundError("Document not found.")
        logger.info(
            "vehicle_document_download_url_issued",
            vehicle_id=str(vehicle.id),
            document_id=str(document.id),
            requested_by=str(user_id),
        )
        return await self._storage.generate_download_url(
            document.storage_key, expires_in_seconds=self._settings.S3_PRESIGNED_URL_TTL_SECONDS
        )

    # ------------------------------------------------------------------
    # Seat layout
    # ------------------------------------------------------------------
    async def set_seat_layout(
        self, user_id: uuid.UUID, vehicle_id: uuid.UUID, request: SeatLayoutRequest
    ) -> tuple[VehicleSeatLayout, list[VehicleSeat]]:
        vehicle = await self.get_own_vehicle(user_id, vehicle_id)
        if len(request.seats) > vehicle.capacity:
            raise ConflictError(
                f"Seat layout has {len(request.seats)} seats, exceeding the vehicle's "
                f"capacity of {vehicle.capacity}.",
                code="SEAT_LAYOUT_EXCEEDS_CAPACITY",
            )
        seat_specs = [
            SeatSpec(
                seat_number=s.seat_number,
                row_number=s.row_number,
                column_number=s.column_number,
                seat_type=s.seat_type,
            )
            for s in request.seats
        ]
        layout = await self._vehicles.replace_seat_layout(
            vehicle.id,
            name=request.name,
            rows=request.rows,
            columns=request.columns,
            seats=seat_specs,
        )
        seats = await self._vehicles.list_seats(layout.id)
        return layout, seats

    async def get_seat_layout(
        self, user_id: uuid.UUID, vehicle_id: uuid.UUID
    ) -> tuple[VehicleSeatLayout, list[VehicleSeat]]:
        vehicle = await self.get_own_vehicle(user_id, vehicle_id)
        layout = await self._vehicles.get_seat_layout(vehicle.id)
        if layout is None:
            raise NotFoundError("No seat layout has been configured for this vehicle.")
        seats = await self._vehicles.list_seats(layout.id)
        return layout, seats

    # ------------------------------------------------------------------
    # Driver assignment (non-trip)
    # ------------------------------------------------------------------
    async def list_fleet_drivers(
        self, user_id: uuid.UUID, fleet_id: uuid.UUID
    ) -> list[FleetDriver]:
        """Drivers currently assigned to the fleet's vehicles, each with the
        vehicles they are assigned to."""
        fleet = await self.get_own_fleet(user_id, fleet_id)
        drivers: dict[uuid.UUID, FleetDriver] = {}
        for row in await self._drivers.list_active_for_fleet(fleet.id):
            driver = drivers.setdefault(
                row.driver_id,
                FleetDriver(
                    driver_id=row.driver_id,
                    full_name=row.full_name,
                    phone_number=row.phone_number,
                    approval_status=row.status,
                    vehicles=[],
                ),
            )
            driver.vehicles.append(
                FleetDriverVehicle(
                    vehicle_id=row.vehicle_id,
                    registration_number=row.registration_number,
                    assigned_at=row.assigned_at,
                )
            )
        return list(drivers.values())

    async def lookup_driver(self, phone: str) -> DriverLookup:
        """Find an approved driver by phone number, to assign to a vehicle.
        Unknown numbers and drivers not (yet) approved are both 404."""
        try:
            normalized = normalize_phone_number(phone)
        except InvalidPhoneNumberError:
            raise ValidationAppError(
                "Enter a valid phone number.", details={"param": "phone"}
            ) from None
        found = await self._drivers.find_by_phone(normalized)
        if found is None or found[0].status != ApprovalStatus.APPROVED:
            raise NotFoundError("No approved driver uses this phone number.")
        driver, user, full_name = found
        return DriverLookup(
            driver_id=driver.id,
            full_name=full_name,
            phone_number=mask_phone_number(user.phone_number),
            approval_status=driver.status,
        )

    async def assign_driver(
        self, user_id: uuid.UUID, vehicle_id: uuid.UUID, driver_id: uuid.UUID
    ) -> None:
        vehicle = await self.get_own_vehicle(user_id, vehicle_id)
        driver = await self._drivers.get_by_id(driver_id)
        if driver is None:
            raise NotFoundError("Driver not found.")
        if driver.status != ApprovalStatus.APPROVED:
            raise ForbiddenError("Only approved drivers can be assigned to a vehicle.")
        if await self._drivers.get_active_assignment(driver_id, vehicle_id) is not None:
            raise ConflictError("This driver is already assigned to this vehicle.")
        await self._drivers.create_assignment(
            driver_id=driver_id,
            vehicle_id=vehicle.id,
            fleet_id=vehicle.fleet_id,
            assigned_by=user_id,
        )

    async def unassign_driver(
        self, user_id: uuid.UUID, vehicle_id: uuid.UUID, driver_id: uuid.UUID
    ) -> None:
        await self.get_own_vehicle(user_id, vehicle_id)
        assignment = await self._drivers.get_active_assignment(driver_id, vehicle_id)
        if assignment is None:
            raise NotFoundError("Active assignment not found.")
        await self._drivers.deactivate_assignment(assignment)

    # ------------------------------------------------------------------
    # Admin review — fleet owners
    # ------------------------------------------------------------------
    async def list_pending_fleet_owners(
        self, *, limit: int, offset: int
    ) -> tuple[list[FleetOwner], int]:
        return await self._owners.list_by_status(ApprovalStatus.PENDING, limit=limit, offset=offset)

    async def approve_fleet_owner(self, fleet_owner_id: uuid.UUID) -> FleetOwner:
        owner = await self._owners.get_by_id(fleet_owner_id)
        if owner is None:
            raise NotFoundError("Fleet owner not found.")
        await self._owners.set_status(owner, new_status=ApprovalStatus.APPROVED)
        return owner

    async def reject_fleet_owner(self, fleet_owner_id: uuid.UUID) -> FleetOwner:
        owner = await self._owners.get_by_id(fleet_owner_id)
        if owner is None:
            raise NotFoundError("Fleet owner not found.")
        await self._owners.set_status(owner, new_status=ApprovalStatus.REJECTED)
        return owner

    # ------------------------------------------------------------------
    # Admin review — vehicles
    # ------------------------------------------------------------------
    async def list_pending_vehicles(self, *, limit: int, offset: int) -> tuple[list[Vehicle], int]:
        return await self._vehicles.list_by_status(
            ApprovalStatus.PENDING, limit=limit, offset=offset
        )

    async def approve_vehicle(
        self, vehicle_id: uuid.UUID, *, reviewer_id: uuid.UUID, notes: str | None
    ) -> Vehicle:
        vehicle = await self._vehicles.get_by_id(vehicle_id)
        if vehicle is None:
            raise NotFoundError("Vehicle not found.")
        if vehicle.status == ApprovalStatus.APPROVED:
            raise InvalidStateTransitionError("This vehicle is already approved.")
        await self._vehicles.record_approval_decision(
            vehicle,
            reviewer_id=reviewer_id,
            decision=ApprovalDecision.APPROVED,
            notes=notes,
            rejection_reason=None,
        )
        await self._vehicles.set_status(
            vehicle, new_status=ApprovalStatus.APPROVED, changed_by=reviewer_id, reason=notes
        )
        return vehicle

    async def reject_vehicle(
        self,
        vehicle_id: uuid.UUID,
        *,
        reviewer_id: uuid.UUID,
        rejection_reason: str,
        notes: str | None,
    ) -> Vehicle:
        vehicle = await self._vehicles.get_by_id(vehicle_id)
        if vehicle is None:
            raise NotFoundError("Vehicle not found.")
        await self._vehicles.record_approval_decision(
            vehicle,
            reviewer_id=reviewer_id,
            decision=ApprovalDecision.REJECTED,
            notes=notes,
            rejection_reason=rejection_reason,
        )
        await self._vehicles.set_status(
            vehicle,
            new_status=ApprovalStatus.REJECTED,
            changed_by=reviewer_id,
            reason=rejection_reason,
        )
        return vehicle

    async def assert_eligible_for_trip_assignment(self, vehicle_id: uuid.UUID) -> Vehicle:
        """Used by Phase 4's trip-assignment flow: only approved vehicles
        may ever be assigned to an active trip."""
        vehicle = await self._vehicles.get_by_id(vehicle_id)
        if vehicle is None:
            raise NotFoundError("Vehicle not found.")
        if vehicle.status != OPERATIONAL_STATUS:
            raise ForbiddenError("Only approved vehicles may be assigned to trips.")
        return vehicle
