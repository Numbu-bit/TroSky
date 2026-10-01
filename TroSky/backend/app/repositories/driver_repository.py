"""Database access for driver profiles, documents, approvals, status
history, and (non-trip) vehicle assignments."""

from __future__ import annotations

import uuid
from datetime import UTC, date, datetime
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.drivers import (
    ApprovalDecision,
    ApprovalStatus,
    DocumentType,
    Driver,
    DriverApproval,
    DriverAssignment,
    DriverDocument,
    DriverStatusHistory,
)
from app.models.identity import User, UserProfile
from app.models.vehicles import Vehicle


class DriverRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get_by_id(self, driver_id: uuid.UUID) -> Driver | None:
        result = await self._session.execute(select(Driver).where(Driver.id == driver_id))
        return result.scalar_one_or_none()

    async def get_by_user_id(self, user_id: uuid.UUID) -> Driver | None:
        result = await self._session.execute(select(Driver).where(Driver.user_id == user_id))
        return result.scalar_one_or_none()

    async def get_by_license_number(self, license_number: str) -> Driver | None:
        result = await self._session.execute(
            select(Driver).where(Driver.license_number == license_number)
        )
        return result.scalar_one_or_none()

    async def create(
        self,
        *,
        user_id: uuid.UUID,
        license_number: str,
        license_expiry: date,
        license_class: str | None,
        years_of_experience: int | None,
    ) -> Driver:
        driver = Driver(
            user_id=user_id,
            license_number=license_number,
            license_expiry=license_expiry,
            license_class=license_class,
            years_of_experience=years_of_experience,
        )
        self._session.add(driver)
        await self._session.flush()
        return driver

    async def list_by_status(
        self, status: ApprovalStatus, *, limit: int, offset: int
    ) -> tuple[list[Driver], int]:
        count_result = await self._session.execute(select(Driver.id).where(Driver.status == status))
        total = len(count_result.scalars().all())
        result = await self._session.execute(
            select(Driver)
            .where(Driver.status == status)
            .order_by(Driver.created_at)
            .limit(limit)
            .offset(offset)
        )
        return list(result.scalars().all()), total

    async def set_status(
        self,
        driver: Driver,
        *,
        new_status: ApprovalStatus,
        changed_by: uuid.UUID | None,
        reason: str | None,
    ) -> None:
        previous = driver.status
        driver.status = new_status
        self._session.add(
            DriverStatusHistory(
                driver_id=driver.id,
                from_status=previous,
                to_status=new_status,
                changed_by=changed_by,
                reason=reason,
            )
        )
        await self._session.flush()

    async def record_approval_decision(
        self,
        driver: Driver,
        *,
        reviewer_id: uuid.UUID,
        decision: ApprovalDecision,
        notes: str | None,
        rejection_reason: str | None,
    ) -> DriverApproval:
        approval = DriverApproval(
            driver_id=driver.id,
            reviewer_id=reviewer_id,
            decision=decision,
            notes=notes,
            rejection_reason=rejection_reason,
        )
        self._session.add(approval)
        await self._session.flush()
        return approval

    # --- Documents ------------------------------------------------------
    async def add_document(
        self,
        *,
        driver_id: uuid.UUID,
        document_type: DocumentType,
        storage_key: str,
        original_filename: str,
        mime_type: str,
        file_size_bytes: int,
        expiry_date: date | None = None,
    ) -> DriverDocument:
        document = DriverDocument(
            driver_id=driver_id,
            document_type=document_type,
            storage_key=storage_key,
            original_filename=original_filename,
            mime_type=mime_type,
            file_size_bytes=file_size_bytes,
            expiry_date=expiry_date,
        )
        self._session.add(document)
        await self._session.flush()
        return document

    async def list_documents(self, driver_id: uuid.UUID) -> list[DriverDocument]:
        result = await self._session.execute(
            select(DriverDocument)
            .where(DriverDocument.driver_id == driver_id)
            .order_by(DriverDocument.created_at.desc())
        )
        return list(result.scalars().all())

    async def get_document(
        self, document_id: uuid.UUID, driver_id: uuid.UUID
    ) -> DriverDocument | None:
        result = await self._session.execute(
            select(DriverDocument).where(
                DriverDocument.id == document_id, DriverDocument.driver_id == driver_id
            )
        )
        return result.scalar_one_or_none()

    async def get_document_by_id(self, document_id: uuid.UUID) -> DriverDocument | None:
        result = await self._session.execute(
            select(DriverDocument).where(DriverDocument.id == document_id)
        )
        return result.scalar_one_or_none()

    # --- Assignments (driver <-> vehicle, non-trip) ----------------------
    async def create_assignment(
        self,
        *,
        driver_id: uuid.UUID,
        vehicle_id: uuid.UUID,
        fleet_id: uuid.UUID,
        assigned_by: uuid.UUID,
    ) -> DriverAssignment:
        assignment = DriverAssignment(
            driver_id=driver_id, vehicle_id=vehicle_id, fleet_id=fleet_id, assigned_by=assigned_by
        )
        self._session.add(assignment)
        await self._session.flush()
        return assignment

    async def get_active_assignment(
        self, driver_id: uuid.UUID, vehicle_id: uuid.UUID
    ) -> DriverAssignment | None:
        result = await self._session.execute(
            select(DriverAssignment).where(
                DriverAssignment.driver_id == driver_id,
                DriverAssignment.vehicle_id == vehicle_id,
                DriverAssignment.is_active.is_(True),
            )
        )
        return result.scalar_one_or_none()

    async def list_active_assignments_for_driver(
        self, driver_id: uuid.UUID
    ) -> list[DriverAssignment]:
        result = await self._session.execute(
            select(DriverAssignment).where(
                DriverAssignment.driver_id == driver_id, DriverAssignment.is_active.is_(True)
            )
        )
        return list(result.scalars().all())

    async def deactivate_assignment(self, assignment: DriverAssignment) -> None:
        assignment.is_active = False
        assignment.unassigned_at = datetime.now(UTC)
        await self._session.flush()

    async def list_active_for_fleet(self, fleet_id: uuid.UUID) -> list[Any]:
        """One row per driver-vehicle pairing currently active in the fleet:
        driver id/status/name/phone plus the vehicle and when it was
        assigned."""
        result = await self._session.execute(
            select(
                Driver.id.label("driver_id"),
                Driver.status,
                User.phone_number,
                UserProfile.full_name,
                Vehicle.id.label("vehicle_id"),
                Vehicle.registration_number,
                DriverAssignment.assigned_at,
            )
            .select_from(DriverAssignment)
            .join(Driver, Driver.id == DriverAssignment.driver_id)
            .join(User, User.id == Driver.user_id)
            .outerjoin(UserProfile, UserProfile.user_id == User.id)
            .join(Vehicle, Vehicle.id == DriverAssignment.vehicle_id)
            .where(DriverAssignment.fleet_id == fleet_id, DriverAssignment.is_active.is_(True))
            .order_by(UserProfile.full_name, Driver.id, Vehicle.registration_number)
        )
        return list(result.all())

    async def find_by_phone(self, phone_number: str) -> tuple[Driver, User, str | None] | None:
        """The driver profile, account and name behind a (normalized) phone
        number, if that account has a driver profile."""
        result = await self._session.execute(
            select(Driver, User, UserProfile.full_name)
            .join(User, User.id == Driver.user_id)
            .outerjoin(UserProfile, UserProfile.user_id == User.id)
            .where(User.phone_number == phone_number, User.deleted_at.is_(None))
        )
        row = result.first()
        return (row[0], row[1], row[2]) if row is not None else None
