"""Database access for vehicles, their verification documents/approvals,
status history, and seat layouts."""

from __future__ import annotations

import uuid
from collections.abc import Collection
from dataclasses import dataclass
from datetime import date

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.drivers import ApprovalDecision, ApprovalStatus, DocumentType
from app.models.vehicles import (
    Fleet,
    SeatType,
    Vehicle,
    VehicleApproval,
    VehicleDocument,
    VehicleSeat,
    VehicleSeatLayout,
    VehicleStatusHistory,
    VehicleType,
)


@dataclass(frozen=True, slots=True)
class SeatSpec:
    """One seat to create as part of a seat-layout replacement."""

    seat_number: str
    row_number: int
    column_number: int
    seat_type: SeatType = SeatType.STANDARD


class VehicleRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get_many(self, vehicle_ids: Collection[uuid.UUID]) -> dict[uuid.UUID, Vehicle]:
        if not vehicle_ids:
            return {}
        result = await self._session.execute(
            select(Vehicle).where(Vehicle.id.in_(list(vehicle_ids)))
        )
        return {vehicle.id: vehicle for vehicle in result.scalars()}

    async def get_by_id(self, vehicle_id: uuid.UUID) -> Vehicle | None:
        result = await self._session.execute(select(Vehicle).where(Vehicle.id == vehicle_id))
        return result.scalar_one_or_none()

    async def get_by_registration_number(self, registration_number: str) -> Vehicle | None:
        result = await self._session.execute(
            select(Vehicle).where(Vehicle.registration_number == registration_number)
        )
        return result.scalar_one_or_none()

    async def list_for_fleet(self, fleet_id: uuid.UUID) -> list[Vehicle]:
        result = await self._session.execute(
            select(Vehicle).where(Vehicle.fleet_id == fleet_id).order_by(Vehicle.created_at)
        )
        return list(result.scalars().all())

    async def list_fleet_ids_for_owner(self, fleet_owner_id: uuid.UUID) -> list[uuid.UUID]:
        result = await self._session.execute(
            select(Fleet.id).where(Fleet.fleet_owner_id == fleet_owner_id)
        )
        return list(result.scalars().all())

    async def create(
        self,
        *,
        fleet_id: uuid.UUID,
        registration_number: str,
        vehicle_type: VehicleType,
        make: str | None,
        model: str | None,
        year: int | None,
        capacity: int,
    ) -> Vehicle:
        vehicle = Vehicle(
            fleet_id=fleet_id,
            registration_number=registration_number,
            vehicle_type=vehicle_type,
            make=make,
            model=model,
            year=year,
            capacity=capacity,
        )
        self._session.add(vehicle)
        await self._session.flush()
        return vehicle

    async def list_by_status(
        self, status: ApprovalStatus, *, limit: int, offset: int
    ) -> tuple[list[Vehicle], int]:
        count_result = await self._session.execute(
            select(Vehicle.id).where(Vehicle.status == status)
        )
        total = len(count_result.scalars().all())
        result = await self._session.execute(
            select(Vehicle)
            .where(Vehicle.status == status)
            .order_by(Vehicle.created_at)
            .limit(limit)
            .offset(offset)
        )
        return list(result.scalars().all()), total

    async def set_status(
        self,
        vehicle: Vehicle,
        *,
        new_status: ApprovalStatus,
        changed_by: uuid.UUID | None,
        reason: str | None,
    ) -> None:
        previous = vehicle.status
        vehicle.status = new_status
        self._session.add(
            VehicleStatusHistory(
                vehicle_id=vehicle.id,
                from_status=previous,
                to_status=new_status,
                changed_by=changed_by,
                reason=reason,
            )
        )
        await self._session.flush()

    async def record_approval_decision(
        self,
        vehicle: Vehicle,
        *,
        reviewer_id: uuid.UUID,
        decision: ApprovalDecision,
        notes: str | None,
        rejection_reason: str | None,
    ) -> VehicleApproval:
        approval = VehicleApproval(
            vehicle_id=vehicle.id,
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
        vehicle_id: uuid.UUID,
        document_type: DocumentType,
        storage_key: str,
        original_filename: str,
        mime_type: str,
        file_size_bytes: int,
        expiry_date: date | None = None,
    ) -> VehicleDocument:
        document = VehicleDocument(
            vehicle_id=vehicle_id,
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

    async def list_documents(self, vehicle_id: uuid.UUID) -> list[VehicleDocument]:
        result = await self._session.execute(
            select(VehicleDocument)
            .where(VehicleDocument.vehicle_id == vehicle_id)
            .order_by(VehicleDocument.created_at.desc())
        )
        return list(result.scalars().all())

    async def get_document(
        self, document_id: uuid.UUID, vehicle_id: uuid.UUID
    ) -> VehicleDocument | None:
        result = await self._session.execute(
            select(VehicleDocument).where(
                VehicleDocument.id == document_id, VehicleDocument.vehicle_id == vehicle_id
            )
        )
        return result.scalar_one_or_none()

    async def get_document_by_id(self, document_id: uuid.UUID) -> VehicleDocument | None:
        result = await self._session.execute(
            select(VehicleDocument).where(VehicleDocument.id == document_id)
        )
        return result.scalar_one_or_none()

    # --- Seat layout ------------------------------------------------------
    async def get_seat_layout(self, vehicle_id: uuid.UUID) -> VehicleSeatLayout | None:
        result = await self._session.execute(
            select(VehicleSeatLayout).where(VehicleSeatLayout.vehicle_id == vehicle_id)
        )
        return result.scalar_one_or_none()

    async def replace_seat_layout(
        self,
        vehicle_id: uuid.UUID,
        *,
        name: str | None,
        rows: int,
        columns: int,
        seats: list[SeatSpec],
    ) -> VehicleSeatLayout:
        existing = await self.get_seat_layout(vehicle_id)
        if existing is not None:
            await self._session.delete(existing)
            await self._session.flush()

        layout = VehicleSeatLayout(
            vehicle_id=vehicle_id, name=name, rows=rows, columns=columns, total_seats=len(seats)
        )
        self._session.add(layout)
        await self._session.flush()

        for seat in seats:
            self._session.add(
                VehicleSeat(
                    layout_id=layout.id,
                    seat_number=seat.seat_number,
                    row_number=seat.row_number,
                    column_number=seat.column_number,
                    seat_type=seat.seat_type,
                )
            )
        await self._session.flush()
        return layout

    async def list_seats(self, layout_id: uuid.UUID) -> list[VehicleSeat]:
        result = await self._session.execute(
            select(VehicleSeat)
            .where(VehicleSeat.layout_id == layout_id)
            .order_by(VehicleSeat.row_number, VehicleSeat.column_number)
        )
        return list(result.scalars().all())
