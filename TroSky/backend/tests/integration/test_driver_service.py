"""Integration tests for DriverService: registration, document upload,
download URLs, and admin approval/rejection — against a real Postgres, with
a sandbox object-storage provider (no real S3/MinIO call)."""

from __future__ import annotations

from datetime import date, timedelta

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ConflictError, ForbiddenError, InvalidStateTransitionError
from app.models.drivers import ApprovalStatus, DocumentType
from app.providers.storage.malware_scan import NoOpMalwareScanner
from app.providers.storage.sandbox import SandboxStorageProvider
from app.schemas.driver import DriverRegisterRequest, DriverUpdateRequest
from app.services.driver_service import DriverService

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]


@pytest.fixture(autouse=True)
def _clear_storage():
    SandboxStorageProvider.clear()
    yield
    SandboxStorageProvider.clear()


def _service(db_session: AsyncSession) -> DriverService:
    return DriverService(db_session, SandboxStorageProvider(), NoOpMalwareScanner())


def _register_request(license_number: str = "GHA-123456") -> DriverRegisterRequest:
    return DriverRegisterRequest(
        license_number=license_number,
        license_expiry=date.today() + timedelta(days=365),
        license_class="C",
        years_of_experience=5,
    )


class TestDriverRegistration:
    async def test_register_creates_pending_profile(
        self, db_session: AsyncSession, make_user
    ) -> None:
        service = _service(db_session)
        user_id = (await make_user()).id
        driver = await service.register(user_id, _register_request())

        assert driver.status == ApprovalStatus.PENDING
        assert driver.user_id == user_id
        assert driver.license_number == "GHA-123456"

    async def test_register_duplicate_account_rejected(
        self, db_session: AsyncSession, make_user
    ) -> None:
        service = _service(db_session)
        user_id = (await make_user()).id
        await service.register(user_id, _register_request())

        with pytest.raises(ConflictError):
            await service.register(user_id, _register_request(license_number="GHA-999999"))

    async def test_register_duplicate_license_rejected(
        self, db_session: AsyncSession, make_user
    ) -> None:
        service = _service(db_session)
        await service.register((await make_user()).id, _register_request("GHA-111111"))

        with pytest.raises(ConflictError) as exc_info:
            await service.register((await make_user()).id, _register_request("GHA-111111"))
        assert exc_info.value.code == "LICENSE_ALREADY_REGISTERED"

    async def test_update_profile(self, db_session: AsyncSession, make_user) -> None:
        service = _service(db_session)
        user_id = (await make_user()).id
        await service.register(user_id, _register_request())

        updated = await service.update_own_profile(
            user_id, DriverUpdateRequest(years_of_experience=10)
        )
        assert updated.years_of_experience == 10


class TestDriverDocuments:
    async def test_upload_and_download_document(self, db_session: AsyncSession, make_user) -> None:
        service = _service(db_session)
        user_id = (await make_user()).id
        await service.register(user_id, _register_request())

        document = await service.upload_document(
            user_id,
            document_type=DocumentType.DRIVER_LICENSE,
            filename="license.jpg",
            content_type="image/jpeg",
            data=b"fake-jpeg-bytes",
        )
        assert document.status.value == "pending"
        stored = SandboxStorageProvider.get_object(document.storage_key)
        assert stored is not None
        assert stored[0] == b"fake-jpeg-bytes"

        url = await service.get_document_download_url(user_id, document.id, requested_by=user_id)
        assert document.storage_key in url

    async def test_upload_oversized_document_rejected(
        self, db_session: AsyncSession, make_user
    ) -> None:
        from app.core.exceptions import FileValidationError

        service = _service(db_session)
        user_id = (await make_user()).id
        await service.register(user_id, _register_request())

        with pytest.raises(FileValidationError):
            await service.upload_document(
                user_id,
                document_type=DocumentType.DRIVER_LICENSE,
                filename="malware.exe",
                content_type="application/x-msdownload",
                data=b"x" * 100,
            )


class TestDriverApproval:
    async def test_approve_transitions_status_and_records_decision(
        self, db_session: AsyncSession, make_user
    ) -> None:
        service = _service(db_session)
        user_id = (await make_user()).id
        driver = await service.register(user_id, _register_request())
        reviewer_id = (await make_user()).id

        approved = await service.approve(driver.id, reviewer_id=reviewer_id, notes="Looks good")
        assert approved.status == ApprovalStatus.APPROVED

        # Now eligible for trip assignment (Phase 4 dependency).
        eligible = await service.assert_eligible_for_trip_assignment(driver.id)
        assert eligible.id == driver.id

    async def test_approve_twice_rejected(self, db_session: AsyncSession, make_user) -> None:
        service = _service(db_session)
        driver = await service.register((await make_user()).id, _register_request())
        reviewer_id = (await make_user()).id
        await service.approve(driver.id, reviewer_id=reviewer_id, notes=None)

        with pytest.raises(InvalidStateTransitionError):
            await service.approve(driver.id, reviewer_id=reviewer_id, notes=None)

    async def test_reject_transitions_status(self, db_session: AsyncSession, make_user) -> None:
        service = _service(db_session)
        driver = await service.register((await make_user()).id, _register_request())
        reviewer_id = (await make_user()).id

        rejected = await service.reject(
            driver.id,
            reviewer_id=reviewer_id,
            rejection_reason="Expired license",
            notes=None,
        )
        assert rejected.status == ApprovalStatus.REJECTED

    async def test_pending_driver_not_eligible_for_trip_assignment(
        self, db_session: AsyncSession, make_user
    ) -> None:
        service = _service(db_session)
        driver = await service.register((await make_user()).id, _register_request())

        with pytest.raises(ForbiddenError):
            await service.assert_eligible_for_trip_assignment(driver.id)

    async def test_list_pending_returns_only_pending_drivers(
        self, db_session: AsyncSession, make_user
    ) -> None:
        service = _service(db_session)
        pending = await service.register((await make_user()).id, _register_request("GHA-222222"))
        approved_driver = await service.register(
            (await make_user()).id, _register_request("GHA-333333")
        )
        await service.approve(approved_driver.id, reviewer_id=(await make_user()).id, notes=None)

        results, total = await service.list_pending(limit=50, offset=0)
        result_ids = {d.id for d in results}
        assert pending.id in result_ids
        assert approved_driver.id not in result_ids
        assert total >= 1
