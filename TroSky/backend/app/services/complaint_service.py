"""Complaint filing and admin review."""

from __future__ import annotations

import uuid

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import InvalidStateTransitionError, NotFoundError
from app.core.logging import get_logger
from app.models.feedback import Complaint, ComplaintCategory, ComplaintStatus
from app.repositories.feedback_repository import ComplaintRepository

logger = get_logger(__name__)

_TERMINAL_STATUSES = frozenset({ComplaintStatus.RESOLVED, ComplaintStatus.DISMISSED})


class ComplaintService:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session
        self._complaints = ComplaintRepository(session)

    async def file_complaint(
        self,
        filed_by: uuid.UUID,
        *,
        booking_id: uuid.UUID | None,
        trip_id: uuid.UUID | None,
        category: ComplaintCategory,
        subject: str,
        description: str,
    ) -> Complaint:
        complaint = await self._complaints.create(
            filed_by=filed_by,
            booking_id=booking_id,
            trip_id=trip_id,
            category=category,
            subject=subject,
            description=description,
        )
        logger.info("complaint_filed", complaint_id=str(complaint.id), category=category.value)
        return complaint

    async def get_complaint(
        self, complaint_id: uuid.UUID, *, requesting_user_id: uuid.UUID, is_privileged: bool = False
    ) -> Complaint:
        complaint = await self._complaints.get_by_id(complaint_id)
        if complaint is None:
            raise NotFoundError("Complaint not found.")
        if not is_privileged and complaint.filed_by != requesting_user_id:
            raise NotFoundError("Complaint not found.")
        return complaint

    async def list_own_complaints(
        self, filed_by: uuid.UUID, *, limit: int, offset: int
    ) -> tuple[list[Complaint], int]:
        return await self._complaints.list_for_user(filed_by, limit=limit, offset=offset)

    async def list_all_complaints(
        self, *, status: ComplaintStatus | None, limit: int, offset: int
    ) -> tuple[list[Complaint], int]:
        return await self._complaints.list_all(status=status, limit=limit, offset=offset)

    async def resolve(
        self, complaint_id: uuid.UUID, *, reviewer_id: uuid.UUID, notes: str | None
    ) -> Complaint:
        return await self._decide(
            complaint_id, reviewer_id=reviewer_id, notes=notes, status=ComplaintStatus.RESOLVED
        )

    async def dismiss(
        self, complaint_id: uuid.UUID, *, reviewer_id: uuid.UUID, notes: str | None
    ) -> Complaint:
        return await self._decide(
            complaint_id, reviewer_id=reviewer_id, notes=notes, status=ComplaintStatus.DISMISSED
        )

    async def _decide(
        self,
        complaint_id: uuid.UUID,
        *,
        reviewer_id: uuid.UUID,
        notes: str | None,
        status: ComplaintStatus,
    ) -> Complaint:
        complaint = await self._complaints.get_for_update(complaint_id)
        if complaint is None:
            raise NotFoundError("Complaint not found.")
        if complaint.status in _TERMINAL_STATUSES:
            raise InvalidStateTransitionError(
                f"Cannot decide a complaint already in status '{complaint.status.value}'."
            )
        await self._complaints.set_status(
            complaint, new_status=status, resolved_by=reviewer_id, resolution_notes=notes
        )
        logger.info("complaint_decided", complaint_id=str(complaint_id), status=status.value)
        return complaint
