"""Driver profile, document, and (admin) approval business logic."""

from __future__ import annotations

import uuid

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings, get_settings
from app.core.exceptions import (
    ConflictError,
    ForbiddenError,
    InvalidStateTransitionError,
    NotFoundError,
)
from app.core.logging import get_logger
from app.core.permissions import SystemRole
from app.models.drivers import (
    ApprovalDecision,
    ApprovalStatus,
    DocumentType,
    Driver,
    DriverAssignment,
    DriverDocument,
)
from app.providers.storage.base import ObjectStorageProvider
from app.providers.storage.malware_scan import MalwareScanner
from app.repositories.driver_repository import DriverRepository
from app.schemas.driver import DriverRegisterRequest, DriverUpdateRequest
from app.services.document_service import store_uploaded_document
from app.services.role_service import grant_role

logger = get_logger(__name__)

# A driver may only be assigned to a trip (Phase 4+) while in this status.
OPERATIONAL_STATUS = ApprovalStatus.APPROVED


class DriverService:
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
        self._drivers = DriverRepository(session)

    async def register(self, user_id: uuid.UUID, request: DriverRegisterRequest) -> Driver:
        if await self._drivers.get_by_user_id(user_id) is not None:
            raise ConflictError("A driver profile already exists for this account.")
        if await self._drivers.get_by_license_number(request.license_number) is not None:
            raise ConflictError(
                "This driver's license number is already registered.",
                code="LICENSE_ALREADY_REGISTERED",
            )
        driver = await self._drivers.create(
            user_id=user_id,
            license_number=request.license_number,
            license_expiry=request.license_expiry,
            license_class=request.license_class,
            years_of_experience=request.years_of_experience,
        )
        await self._drivers.set_status(
            driver,
            new_status=ApprovalStatus.PENDING,
            changed_by=user_id,
            reason="Initial registration",
        )
        # Creating the profile is what makes an account a driver. Without
        # this the holder keeps only the role chosen at registration and is
        # locked out of every other /drivers and /driver-trips route, so a
        # passenger could never become a driver without a second account.
        await grant_role(self._session, user_id, SystemRole.DRIVER)
        logger.info("driver_registered", driver_id=str(driver.id), user_id=str(user_id))
        return driver

    async def get_own_profile(self, user_id: uuid.UUID) -> Driver:
        driver = await self._drivers.get_by_user_id(user_id)
        if driver is None:
            raise NotFoundError("No driver profile exists for this account.")
        return driver

    async def update_own_profile(self, user_id: uuid.UUID, request: DriverUpdateRequest) -> Driver:
        driver = await self.get_own_profile(user_id)
        fields = request.model_dump(exclude_unset=True)
        for key, value in fields.items():
            if value is not None:
                setattr(driver, key, value)
        await self._session.flush()
        return driver

    async def upload_document(
        self,
        user_id: uuid.UUID,
        *,
        document_type: DocumentType,
        filename: str,
        content_type: str,
        data: bytes,
    ) -> DriverDocument:
        driver = await self.get_own_profile(user_id)
        uploaded = await store_uploaded_document(
            storage=self._storage,
            scanner=self._scanner,
            settings=self._settings,
            key_prefix=f"drivers/{driver.id}/documents",
            filename=filename,
            content_type=content_type,
            data=data,
        )
        document = await self._drivers.add_document(
            driver_id=driver.id,
            document_type=document_type,
            storage_key=uploaded.storage_key,
            original_filename=filename,
            mime_type=content_type,
            file_size_bytes=uploaded.size_bytes,
        )
        logger.info(
            "driver_document_uploaded", driver_id=str(driver.id), document_id=str(document.id)
        )
        return document

    async def list_documents(self, user_id: uuid.UUID) -> list[DriverDocument]:
        driver = await self.get_own_profile(user_id)
        return await self._drivers.list_documents(driver.id)

    async def get_document_download_url(
        self, user_id: uuid.UUID, document_id: uuid.UUID, *, requested_by: uuid.UUID
    ) -> str:
        driver = await self.get_own_profile(user_id)
        document = await self._drivers.get_document(document_id, driver.id)
        if document is None:
            raise NotFoundError("Document not found.")
        logger.info(
            "driver_document_download_url_issued",
            driver_id=str(driver.id),
            document_id=str(document.id),
            requested_by=str(requested_by),
        )
        return await self._storage.generate_download_url(
            document.storage_key, expires_in_seconds=self._settings.S3_PRESIGNED_URL_TTL_SECONDS
        )

    async def list_own_assignments(self, user_id: uuid.UUID) -> list[DriverAssignment]:
        driver = await self.get_own_profile(user_id)
        return await self._drivers.list_active_assignments_for_driver(driver.id)

    # ------------------------------------------------------------------
    # Admin review
    # ------------------------------------------------------------------
    async def list_pending(self, *, limit: int, offset: int) -> tuple[list[Driver], int]:
        return await self._drivers.list_by_status(
            ApprovalStatus.PENDING, limit=limit, offset=offset
        )

    async def approve(
        self, driver_id: uuid.UUID, *, reviewer_id: uuid.UUID, notes: str | None
    ) -> Driver:
        driver = await self._drivers.get_by_id(driver_id)
        if driver is None:
            raise NotFoundError("Driver not found.")
        if driver.status == ApprovalStatus.APPROVED:
            raise InvalidStateTransitionError("This driver is already approved.")
        await self._drivers.record_approval_decision(
            driver,
            reviewer_id=reviewer_id,
            decision=ApprovalDecision.APPROVED,
            notes=notes,
            rejection_reason=None,
        )
        await self._drivers.set_status(
            driver, new_status=ApprovalStatus.APPROVED, changed_by=reviewer_id, reason=notes
        )
        logger.info("driver_approved", driver_id=str(driver_id), reviewer_id=str(reviewer_id))
        return driver

    async def reject(
        self,
        driver_id: uuid.UUID,
        *,
        reviewer_id: uuid.UUID,
        rejection_reason: str,
        notes: str | None,
    ) -> Driver:
        driver = await self._drivers.get_by_id(driver_id)
        if driver is None:
            raise NotFoundError("Driver not found.")
        await self._drivers.record_approval_decision(
            driver,
            reviewer_id=reviewer_id,
            decision=ApprovalDecision.REJECTED,
            notes=notes,
            rejection_reason=rejection_reason,
        )
        await self._drivers.set_status(
            driver,
            new_status=ApprovalStatus.REJECTED,
            changed_by=reviewer_id,
            reason=rejection_reason,
        )
        logger.info("driver_rejected", driver_id=str(driver_id), reviewer_id=str(reviewer_id))
        return driver

    async def assert_eligible_for_trip_assignment(self, driver_id: uuid.UUID) -> Driver:
        """Used by Phase 4's trip-assignment flow: only approved drivers may
        ever be assigned to an active trip."""
        driver = await self._drivers.get_by_id(driver_id)
        if driver is None:
            raise NotFoundError("Driver not found.")
        if driver.status != OPERATIONAL_STATUS:
            raise ForbiddenError("Only approved drivers may be assigned to trips.")
        return driver
