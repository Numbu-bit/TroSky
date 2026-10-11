"""Asking a driver or fleet owner for better documents instead of rejecting
them, and short-lived links for reviewers to look at a document.

Asking for documents marks those documents rejected with the admin's note
(the app already shows a rejected document with its reason and lets it be
uploaded again), records the request in the status history -- which also
restarts the "waiting for approval" clock, since the next move is theirs --
and notifies the person who must act.
"""

from __future__ import annotations

import uuid
from collections.abc import Sequence
from dataclasses import dataclass
from datetime import UTC, date, datetime, timedelta
from typing import Literal

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ForbiddenError, NotFoundError
from app.core.logging import get_logger
from app.core.permissions import Permission, Principal
from app.models.drivers import (
    DocumentStatus,
    DocumentType,
    Driver,
    DriverDocument,
    DriverStatusHistory,
)
from app.models.notifications import NotificationCategory
from app.models.vehicles import (
    Fleet,
    FleetOwner,
    Vehicle,
    VehicleDocument,
    VehicleStatusHistory,
)
from app.providers.storage.base import ObjectStorageProvider
from app.services.notification_service import NotificationService

logger = get_logger(__name__)

LINK_SECONDS = 300
_STILL_OPEN = (DocumentStatus.PENDING, DocumentStatus.UNDER_REVIEW, DocumentStatus.APPROVED)


def _names(types: Sequence[DocumentType]) -> str:
    return ", ".join(t.value.replace("_", " ") for t in types)


@dataclass(frozen=True, slots=True)
class InfoRequest:
    subject_type: Literal["driver", "vehicle"]
    subject_id: uuid.UUID
    document_types: list[DocumentType]
    note: str
    documents_returned: list[uuid.UUID]
    notified_user_id: uuid.UUID | None
    requested_at: datetime


@dataclass(frozen=True, slots=True)
class DocumentLink:
    document_id: uuid.UUID
    owner_type: Literal["driver", "vehicle"]
    owner_id: uuid.UUID
    document_type: DocumentType
    status: DocumentStatus
    expiry_date: date | None
    original_filename: str
    mime_type: str
    file_size_bytes: int
    url: str
    expires_at: datetime


class ApprovalRequestsService:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def request_driver_info(
        self,
        driver_id: uuid.UUID,
        *,
        document_types: Sequence[DocumentType],
        note: str,
        by: uuid.UUID,
    ) -> InfoRequest:
        driver = await self._session.get(Driver, driver_id)
        if driver is None:
            raise NotFoundError("Driver not found.")
        now = datetime.now(UTC)
        documents = (
            (
                await self._session.execute(
                    select(DriverDocument).where(
                        DriverDocument.driver_id == driver_id,
                        DriverDocument.document_type.in_(document_types),
                        DriverDocument.status.in_(_STILL_OPEN),
                    )
                )
            )
            .scalars()
            .all()
        )
        for document in documents:
            document.status = DocumentStatus.REJECTED
            document.rejection_reason = note[:500]
            document.reviewed_by, document.reviewed_at = by, now
        self._session.add(
            DriverStatusHistory(
                driver_id=driver_id,
                from_status=driver.status,
                to_status=driver.status,
                changed_by=by,
                reason=f"Documents requested ({_names(document_types)}): {note}"[:500],
            )
        )
        await self._session.flush()
        await self._notify(driver.user_id, "driver", driver_id, document_types, note)
        logger.info("driver_documents_requested", driver_id=str(driver_id), by=str(by))
        return InfoRequest(
            subject_type="driver",
            subject_id=driver_id,
            document_types=list(document_types),
            note=note,
            documents_returned=[document.id for document in documents],
            notified_user_id=driver.user_id,
            requested_at=now,
        )

    async def request_vehicle_info(
        self,
        vehicle_id: uuid.UUID,
        *,
        document_types: Sequence[DocumentType],
        note: str,
        by: uuid.UUID,
    ) -> InfoRequest:
        vehicle = await self._session.get(Vehicle, vehicle_id)
        if vehicle is None:
            raise NotFoundError("Vehicle not found.")
        now = datetime.now(UTC)
        documents = (
            (
                await self._session.execute(
                    select(VehicleDocument).where(
                        VehicleDocument.vehicle_id == vehicle_id,
                        VehicleDocument.document_type.in_(document_types),
                        VehicleDocument.status.in_(_STILL_OPEN),
                    )
                )
            )
            .scalars()
            .all()
        )
        for document in documents:
            document.status = DocumentStatus.REJECTED
            document.rejection_reason = note[:500]
            document.reviewed_by, document.reviewed_at = by, now
        self._session.add(
            VehicleStatusHistory(
                vehicle_id=vehicle_id,
                from_status=vehicle.status,
                to_status=vehicle.status,
                changed_by=by,
                reason=f"Documents requested ({_names(document_types)}): {note}"[:500],
            )
        )
        await self._session.flush()
        owner = await self._session.scalar(
            select(FleetOwner.user_id)
            .join(Fleet, Fleet.fleet_owner_id == FleetOwner.id)
            .where(Fleet.id == vehicle.fleet_id)
        )
        if owner is not None:
            await self._notify(owner, "vehicle", vehicle_id, document_types, note)
        logger.info("vehicle_documents_requested", vehicle_id=str(vehicle_id), by=str(by))
        return InfoRequest(
            subject_type="vehicle",
            subject_id=vehicle_id,
            document_types=list(document_types),
            note=note,
            documents_returned=[document.id for document in documents],
            notified_user_id=owner,
            requested_at=now,
        )

    async def _notify(
        self,
        user_id: uuid.UUID,
        subject_type: str,
        subject_id: uuid.UUID,
        document_types: Sequence[DocumentType],
        note: str,
    ) -> None:
        what = "your" if subject_type == "driver" else "your vehicle's"
        await NotificationService(self._session).notify(
            user_id,
            category=NotificationCategory.TRANSACTIONAL,
            title="TroSky needs new documents",
            body=f"Please upload {what} {_names(document_types)} again. {note}"[:1000],
            data={
                "type": "documents_requested",
                f"{subject_type}_id": str(subject_id),
                "document_types": [t.value for t in document_types],
            },
        )

    async def document_link(
        self, document_id: uuid.UUID, *, principal: Principal, storage: ObjectStorageProvider
    ) -> DocumentLink:
        """A link to look at a driver's or vehicle's document, valid for five
        minutes. A driver's document needs ``drivers:approve``, a vehicle's
        ``vehicles:approve``."""
        owner_type: Literal["driver", "vehicle"]
        driver_document = await self._session.get(DriverDocument, document_id)
        if driver_document is not None:
            needed, owner_type = Permission.DRIVERS_APPROVE, "driver"
            document: DriverDocument | VehicleDocument = driver_document
            owner_id = driver_document.driver_id
        else:
            vehicle_document = await self._session.get(VehicleDocument, document_id)
            if vehicle_document is None:
                raise NotFoundError("Document not found.")
            needed, owner_type = Permission.VEHICLES_APPROVE, "vehicle"
            document, owner_id = vehicle_document, vehicle_document.vehicle_id
        if not principal.has_permission(needed):
            raise ForbiddenError("This document needs a permission your account does not have.")
        url = await storage.generate_download_url(
            document.storage_key, expires_in_seconds=LINK_SECONDS
        )
        logger.info(
            "admin_document_link_issued",
            document_id=str(document_id),
            owner_type=owner_type,
            by=str(principal.user_id),
        )
        return DocumentLink(
            document_id=document.id,
            owner_type=owner_type,
            owner_id=owner_id,
            document_type=document.document_type,
            status=document.status,
            expiry_date=document.expiry_date,
            original_filename=document.original_filename,
            mime_type=document.mime_type,
            file_size_bytes=document.file_size_bytes,
            url=url,
            expires_at=datetime.now(UTC) + timedelta(seconds=LINK_SECONDS),
        )
