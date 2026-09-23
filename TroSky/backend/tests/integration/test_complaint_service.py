"""Integration tests for ComplaintService: filing, ownership-scoped reads,
and the resolve/dismiss terminal-state guard — against a real Postgres."""

from __future__ import annotations

import uuid

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import InvalidStateTransitionError, NotFoundError
from app.models.feedback import ComplaintCategory, ComplaintStatus
from app.services.complaint_service import ComplaintService

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]


class TestFileComplaint:
    async def test_file_complaint_creates_open_complaint(self, db_session: AsyncSession) -> None:
        service = ComplaintService(db_session)
        user_id = uuid.uuid4()
        complaint = await service.file_complaint(
            user_id,
            booking_id=None,
            trip_id=None,
            category=ComplaintCategory.DRIVER_CONDUCT,
            subject="Rude driver",
            description="The driver was rude during boarding.",
        )
        assert complaint.status == ComplaintStatus.OPEN
        assert complaint.filed_by == user_id

    async def test_owner_can_read_own_complaint(self, db_session: AsyncSession) -> None:
        service = ComplaintService(db_session)
        user_id = uuid.uuid4()
        complaint = await service.file_complaint(
            user_id,
            booking_id=None,
            trip_id=None,
            category=ComplaintCategory.OTHER,
            subject="X",
            description="Y",
        )
        fetched = await service.get_complaint(complaint.id, requesting_user_id=user_id)
        assert fetched.id == complaint.id

    async def test_non_owner_cannot_read_complaint(self, db_session: AsyncSession) -> None:
        service = ComplaintService(db_session)
        complaint = await service.file_complaint(
            uuid.uuid4(),
            booking_id=None,
            trip_id=None,
            category=ComplaintCategory.OTHER,
            subject="X",
            description="Y",
        )
        with pytest.raises(NotFoundError):
            await service.get_complaint(complaint.id, requesting_user_id=uuid.uuid4())


class TestComplaintDecisions:
    async def test_resolve_moves_to_resolved(self, db_session: AsyncSession) -> None:
        service = ComplaintService(db_session)
        complaint = await service.file_complaint(
            uuid.uuid4(),
            booking_id=None,
            trip_id=None,
            category=ComplaintCategory.PAYMENT,
            subject="X",
            description="Y",
        )
        resolved = await service.resolve(complaint.id, reviewer_id=uuid.uuid4(), notes="Refunded")
        assert resolved.status == ComplaintStatus.RESOLVED

    async def test_dismiss_moves_to_dismissed(self, db_session: AsyncSession) -> None:
        service = ComplaintService(db_session)
        complaint = await service.file_complaint(
            uuid.uuid4(),
            booking_id=None,
            trip_id=None,
            category=ComplaintCategory.OTHER,
            subject="X",
            description="Y",
        )
        dismissed = await service.dismiss(complaint.id, reviewer_id=uuid.uuid4(), notes=None)
        assert dismissed.status == ComplaintStatus.DISMISSED

    async def test_cannot_decide_an_already_decided_complaint(
        self, db_session: AsyncSession
    ) -> None:
        service = ComplaintService(db_session)
        complaint = await service.file_complaint(
            uuid.uuid4(),
            booking_id=None,
            trip_id=None,
            category=ComplaintCategory.OTHER,
            subject="X",
            description="Y",
        )
        await service.resolve(complaint.id, reviewer_id=uuid.uuid4(), notes=None)
        with pytest.raises(InvalidStateTransitionError):
            await service.dismiss(complaint.id, reviewer_id=uuid.uuid4(), notes=None)
