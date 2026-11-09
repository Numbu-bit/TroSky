"""Through the API: confirming a document's date, and what a driver then sees."""

from __future__ import annotations

import secrets
import uuid
from dataclasses import dataclass
from datetime import UTC, date, datetime, timedelta

import pytest
from httpx import AsyncClient
from sqlalchemy import select

from app.core.database import get_session_factory
from app.core.permissions import SystemRole
from app.core.security import hash_password
from app.models.drivers import ApprovalStatus, DocumentStatus, DocumentType, DriverDocument
from app.models.identity import User, UserProfile
from app.models.notifications import Notification
from app.repositories.driver_repository import DriverRepository
from app.services.insurance_service import BLOCK_REASON
from app.workers.tasks.insurance import _check_driver_insurance_async
from tests.api.test_admin_dashboard_api import PASSWORD, _committed_user, _login
from tests.integration.scenarios import approved_driver

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]


def _today() -> date:
    return datetime.now(UTC).date()


def _local_number() -> str:
    return "057" + "".join(secrets.choice("0123456789") for _ in range(7))


@dataclass(frozen=True)
class CommittedDriver:
    driver_id: uuid.UUID
    user_id: uuid.UUID
    phone: str
    document_id: uuid.UUID


async def _driver(
    *,
    document_type: DocumentType = DocumentType.VEHICLE_INSURANCE,
    status: DocumentStatus = DocumentStatus.PENDING,
    expiry: date | None = None,
    blocked: bool = False,
) -> CommittedDriver:
    phones: dict[uuid.UUID, str] = {}
    async with get_session_factory()() as session:

        async def make_user(**_: object) -> User:
            local = _local_number()
            user = User(phone_number="+233" + local[1:], password_hash=hash_password(PASSWORD))
            user.profile = UserProfile(full_name="Kofi Mensah", preferred_language="en")
            session.add(user)
            await session.flush()
            phones[user.id] = local
            return user

        user, driver = await approved_driver(session, make_user)
        document = DriverDocument(
            driver_id=driver.id,
            document_type=document_type,
            storage_key="drivers/document.pdf",
            original_filename="document.pdf",
            mime_type="application/pdf",
            file_size_bytes=100,
            status=status,
            expiry_date=expiry,
        )
        session.add(document)
        await session.flush()
        if blocked:
            await DriverRepository(session).set_status(
                driver,
                new_status=ApprovalStatus.SUSPENDED,
                changed_by=None,
                reason=f"{BLOCK_REASON}: expired {_today().isoformat()}",
            )
        await session.commit()
        return CommittedDriver(driver.id, user.id, phones[user.id], document.id)


@pytest.fixture
async def admin(client: AsyncClient, seed_identity_data: None, require_redis: None):
    return await _login(client, await _committed_user(SystemRole.ADMIN))


async def _review(client: AsyncClient, headers, document_id, **body):
    return await client.post(
        f"/api/v1/admin/documents/{document_id}/review", headers=headers, json=body
    )


class TestReview:
    async def test_approving_insurance_records_its_date(
        self, client: AsyncClient, admin: dict[str, str]
    ) -> None:
        driver = await _driver()
        expiry = _today() + timedelta(days=200)
        response = await _review(
            client,
            admin,
            driver.document_id,
            decision="approved",
            expiry_date=expiry.isoformat(),
        )
        assert response.status_code == 200, response.text
        body = response.json()
        assert body["status"] == "approved"
        assert body["expiry_date"] == expiry.isoformat()
        assert body["owner_type"] == "driver"
        assert body["owner_id"] == str(driver.driver_id)

    async def test_insurance_cannot_be_approved_without_a_date(
        self, client: AsyncClient, admin: dict[str, str]
    ) -> None:
        driver = await _driver()
        response = await _review(client, admin, driver.document_id, decision="approved")
        assert response.status_code == 422
        assert response.json()["error"]["details"]["param"] == "expiry_date"

    async def test_the_date_the_uploader_gave_is_kept_if_none_is_entered(
        self, client: AsyncClient, admin: dict[str, str]
    ) -> None:
        expiry = _today() + timedelta(days=90)
        driver = await _driver(expiry=expiry)
        response = await _review(client, admin, driver.document_id, decision="approved")
        assert response.status_code == 200, response.text
        assert response.json()["expiry_date"] == expiry.isoformat()

    async def test_other_documents_need_no_date(
        self, client: AsyncClient, admin: dict[str, str]
    ) -> None:
        driver = await _driver(document_type=DocumentType.GHANA_CARD)
        response = await _review(client, admin, driver.document_id, decision="approved")
        assert response.status_code == 200, response.text

    async def test_rejecting_needs_a_reason(
        self, client: AsyncClient, admin: dict[str, str]
    ) -> None:
        driver = await _driver()
        response = await _review(client, admin, driver.document_id, decision="rejected")
        assert response.status_code == 422
        assert response.json()["error"]["details"]["param"] == "rejection_reason"

    async def test_rejecting_tells_the_driver_why(
        self, client: AsyncClient, admin: dict[str, str]
    ) -> None:
        driver = await _driver()
        reason = "The photo is too blurred to read."
        response = await _review(
            client, admin, driver.document_id, decision="rejected", rejection_reason=reason
        )
        assert response.status_code == 200, response.text
        assert response.json()["status"] == "rejected"
        async with get_session_factory()() as session:
            notes = (
                (
                    await session.execute(
                        select(Notification).where(Notification.user_id == driver.user_id)
                    )
                )
                .scalars()
                .all()
            )
        assert any(reason in note.body for note in notes)

    async def test_an_unknown_document_is_not_found(
        self, client: AsyncClient, admin: dict[str, str]
    ) -> None:
        response = await _review(client, admin, uuid.uuid4(), decision="rejected")
        assert response.status_code == 404

    async def test_a_passenger_may_not_review(
        self, client: AsyncClient, seed_identity_data: None, require_redis: None
    ) -> None:
        driver = await _driver()
        headers = await _login(client, await _committed_user(SystemRole.PASSENGER))
        response = await _review(client, headers, driver.document_id, decision="approved")
        assert response.status_code == 403


class TestBlockedDriver:
    async def test_confirming_a_later_date_unblocks_them_at_once(
        self, client: AsyncClient, admin: dict[str, str]
    ) -> None:
        driver = await _driver(blocked=True)
        response = await _review(
            client,
            admin,
            driver.document_id,
            decision="approved",
            expiry_date=(_today() + timedelta(days=365)).isoformat(),
        )
        assert response.status_code == 200, response.text
        assert response.json()["drivers_unblocked"] == [str(driver.driver_id)]
        headers = await _login(client, driver.phone)
        profile = await client.get("/api/v1/drivers/me", headers=headers)
        assert profile.json()["status"] == "approved"

    async def test_confirming_a_date_in_the_past_does_not(
        self, client: AsyncClient, admin: dict[str, str]
    ) -> None:
        driver = await _driver(blocked=True)
        response = await _review(
            client,
            admin,
            driver.document_id,
            decision="approved",
            expiry_date=(_today() - timedelta(days=1)).isoformat(),
        )
        assert response.status_code == 200, response.text
        assert response.json()["drivers_unblocked"] == []

    async def test_they_can_still_sign_in_and_upload_the_renewal(
        self, client: AsyncClient, seed_identity_data: None, require_redis: None
    ) -> None:
        driver = await _driver(blocked=True)
        headers = await _login(client, driver.phone)
        standing = await client.get("/api/v1/drivers/me/insurance", headers=headers)
        assert standing.status_code == 200, standing.text
        assert standing.json()["status"] == "blocked"
        upload = await client.post(
            "/api/v1/drivers/me/documents",
            data={
                "document_type": "vehicle_insurance",
                "expiry_date": (_today() + timedelta(days=365)).isoformat(),
            },
            files={"file": ("insurance.jpg", b"fake-bytes", "image/jpeg")},
            headers=headers,
        )
        assert upload.status_code == 201, upload.text


class TestUpload:
    async def test_the_date_is_kept_until_an_admin_confirms_it(
        self, client: AsyncClient, seed_identity_data: None, require_redis: None
    ) -> None:
        driver = await _driver()
        headers = await _login(client, driver.phone)
        expiry = (_today() + timedelta(days=100)).isoformat()
        upload = await client.post(
            "/api/v1/drivers/me/documents",
            data={"document_type": "vehicle_insurance", "expiry_date": expiry},
            files={"file": ("insurance.jpg", b"fake-bytes", "image/jpeg")},
            headers=headers,
        )
        assert upload.status_code == 201, upload.text
        assert upload.json()["expiry_date"] == expiry
        assert upload.json()["status"] == "pending"
        standing = await client.get("/api/v1/drivers/me/insurance", headers=headers)
        assert standing.json()["status"] == "unknown"

    async def test_a_date_already_passed_is_refused(
        self, client: AsyncClient, seed_identity_data: None, require_redis: None
    ) -> None:
        driver = await _driver()
        headers = await _login(client, driver.phone)
        upload = await client.post(
            "/api/v1/drivers/me/documents",
            data={
                "document_type": "vehicle_insurance",
                "expiry_date": (_today() - timedelta(days=1)).isoformat(),
            },
            files={"file": ("insurance.jpg", b"fake-bytes", "image/jpeg")},
            headers=headers,
        )
        assert upload.status_code == 422

    async def test_a_date_is_optional(
        self, client: AsyncClient, seed_identity_data: None, require_redis: None
    ) -> None:
        """What the app sends today, so it keeps working."""
        driver = await _driver()
        headers = await _login(client, driver.phone)
        upload = await client.post(
            "/api/v1/drivers/me/documents",
            data={"document_type": "vehicle_insurance"},
            files={"file": ("insurance.jpg", b"fake-bytes", "image/jpeg")},
            headers=headers,
        )
        assert upload.status_code == 201, upload.text
        assert upload.json()["expiry_date"] is None


class TestStanding:
    async def test_once_confirmed_a_driver_sees_their_date(
        self, client: AsyncClient, admin: dict[str, str]
    ) -> None:
        expiry = _today() + timedelta(days=200)
        driver = await _driver(status=DocumentStatus.APPROVED, expiry=expiry)
        headers = await _login(client, driver.phone)
        body = (await client.get("/api/v1/drivers/me/insurance", headers=headers)).json()
        assert body == {"status": "valid", "expiry_date": expiry.isoformat(), "renew_by": None}


class TestHourlyTask:
    async def test_it_warns_a_driver_whose_insurance_has_expired(
        self, seed_identity_data: None, require_redis: None
    ) -> None:
        driver = await _driver(status=DocumentStatus.APPROVED, expiry=_today() - timedelta(days=1))
        outcomes = await _check_driver_insurance_async()
        assert outcomes.get("warned", 0) >= 1
        assert "failed" not in outcomes
        async with get_session_factory()() as session:
            warned = await session.scalar(
                select(Notification.id).where(
                    Notification.user_id == driver.user_id,
                    Notification.data.contains({"action": "insurance_warning"}),
                )
            )
        assert warned is not None

    async def test_it_is_scheduled(self) -> None:
        from app.workers.celery_app import celery_app

        assert (
            celery_app.conf.beat_schedule["check-driver-insurance"]["task"]
            == "app.workers.tasks.insurance.check_driver_insurance"
        )
