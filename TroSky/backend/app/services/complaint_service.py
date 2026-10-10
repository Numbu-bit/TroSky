"""Complaints: filing, and the support team's workflow -- assignment,
priority, review, internal notes, messages to the passenger, decisions."""

from __future__ import annotations

import uuid
from datetime import UTC, datetime

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.admin_events import announce
from app.core.exceptions import InvalidStateTransitionError, NotFoundError, ValidationAppError
from app.core.logging import get_logger
from app.core.permissions import Permission, SystemRole
from app.models.feedback import (
    Complaint,
    ComplaintCategory,
    ComplaintNote,
    ComplaintNoteKind,
    ComplaintPriority,
    ComplaintStatus,
)
from app.models.notifications import NotificationCategory
from app.repositories.feedback_repository import ComplaintRepository
from app.repositories.user_repository import UserRepository
from app.services.notification_service import NotificationService

logger = get_logger(__name__)

_TERMINAL_STATUSES = frozenset({ComplaintStatus.RESOLVED, ComplaintStatus.DISMISSED})
# Anything else starts at medium; the support team can change it.
_STARTING_PRIORITY = {ComplaintCategory.SAFETY: ComplaintPriority.HIGH}
# A push notification shows the start of a message; the app shows it all.
_PREVIEW_CHARACTERS = 200


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
            priority=_STARTING_PRIORITY.get(category, ComplaintPriority.MEDIUM),
        )
        logger.info("complaint_filed", complaint_id=str(complaint.id), category=category.value)
        announce(
            self._session,
            "complaint.created",
            complaint_id=complaint.id,
            category=complaint.category,
            priority=complaint.priority,
            subject=complaint.subject,
        )
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
        complaint.first_response_at = complaint.first_response_at or complaint.resolved_at
        await self._session.flush()
        logger.info("complaint_decided", complaint_id=str(complaint_id), status=status.value)
        self._announce_update(complaint)
        return complaint

    # ------------------------------------------------------------- workflow
    async def update(
        self,
        complaint_id: uuid.UUID,
        *,
        assign: bool = False,
        assigned_to: uuid.UUID | None = None,
        priority: ComplaintPriority | None = None,
        in_review: bool = False,
    ) -> Complaint:
        """Assign (``assign`` with ``assigned_to``, or ``None`` to unassign),
        set the priority, or move an open complaint into review. A decided
        complaint is closed to all three."""
        complaint = await self._complaints.get_for_update(complaint_id)
        if complaint is None:
            raise NotFoundError("Complaint not found.")
        if complaint.status in _TERMINAL_STATUSES:
            raise InvalidStateTransitionError(
                f"This complaint is already {complaint.status.value}; it can no longer be changed."
            )
        now = datetime.now(UTC)
        if assign and assigned_to != complaint.assigned_to:
            if assigned_to is not None:
                await self._ensure_handles_complaints(assigned_to)
            complaint.assigned_to = assigned_to
            complaint.assigned_at = now if assigned_to is not None else None
        if priority is not None:
            complaint.priority = priority
        if in_review and complaint.status == ComplaintStatus.OPEN:
            complaint.status = ComplaintStatus.IN_REVIEW
            complaint.first_response_at = complaint.first_response_at or now
        await self._session.flush()
        self._announce_update(complaint)
        return complaint

    async def add_note(
        self,
        complaint_id: uuid.UUID,
        *,
        author_id: uuid.UUID,
        kind: ComplaintNoteKind,
        body: str,
    ) -> ComplaintNote:
        """An internal note for the team, or a message to the passenger
        (sent to them, and their first response if nothing came before)."""
        complaint = await self._complaints.get_for_update(complaint_id)
        if complaint is None:
            raise NotFoundError("Complaint not found.")
        note = ComplaintNote(complaint_id=complaint.id, author_id=author_id, kind=kind, body=body)
        self._session.add(note)
        if kind == ComplaintNoteKind.MESSAGE:
            complaint.first_response_at = complaint.first_response_at or datetime.now(UTC)
        await self._session.flush()
        if kind == ComplaintNoteKind.MESSAGE:
            preview = body
            if len(body) > _PREVIEW_CHARACTERS:
                preview = body[: _PREVIEW_CHARACTERS - 1] + "\u2026"
            await NotificationService(self._session).notify(
                complaint.filed_by,
                category=NotificationCategory.TRANSACTIONAL,
                title=f"TroSky support: {complaint.subject}"[:200],
                body=preview,
                data={
                    "type": "complaint_message",
                    "complaint_id": str(complaint.id),
                    "message_id": str(note.id),
                },
            )
        self._announce_update(complaint)
        return note

    async def list_messages(
        self, complaint_id: uuid.UUID, *, requesting_user_id: uuid.UUID
    ) -> list[ComplaintNote]:
        """The support team's messages on the caller's own complaint, oldest
        first. Internal notes are never shown."""
        await self.get_complaint(complaint_id, requesting_user_id=requesting_user_id)
        result = await self._session.execute(
            select(ComplaintNote)
            .where(
                ComplaintNote.complaint_id == complaint_id,
                ComplaintNote.kind == ComplaintNoteKind.MESSAGE,
            )
            .order_by(ComplaintNote.created_at, ComplaintNote.id)
        )
        return list(result.scalars().all())

    async def _ensure_handles_complaints(self, user_id: uuid.UUID) -> None:
        users = UserRepository(self._session)
        user = await users.get_by_id(user_id)
        allowed = False
        if user is not None and user.is_active and not user.is_suspended:
            roles = await users.get_roles_for_user(user_id)
            allowed = SystemRole.SUPER_ADMIN.value in roles or (
                Permission.COMPLAINTS_MANAGE.value in await users.get_permissions_for_roles(roles)
            )
        if not allowed:
            raise ValidationAppError(
                "Complaints can only be assigned to an active admin who handles complaints.",
                details={"param": "assigned_to"},
            )

    def _announce_update(self, complaint: Complaint) -> None:
        announce(
            self._session,
            "complaint.updated",
            complaint_id=complaint.id,
            status=complaint.status,
            priority=complaint.priority,
            assigned_to=complaint.assigned_to,
        )
