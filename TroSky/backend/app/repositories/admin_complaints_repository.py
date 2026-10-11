"""Complaints as the support team sees them: lists with each complaint's due
time, one complaint's thread, what is open now, and the daily figures behind
``/admin/complaints/stats``.

A complaint is due ``complaint_sla_hours[priority]`` after it was filed (an
admin setting), and overdue while still open (or in review) after that.
"""

from __future__ import annotations

import uuid
from collections.abc import Mapping
from dataclasses import dataclass
from datetime import datetime
from typing import Any

from sqlalchemy import ColumnElement, Select, and_, case, func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import aliased

from app.models.bookings import Booking
from app.models.feedback import (
    Complaint,
    ComplaintCategory,
    ComplaintNote,
    ComplaintNoteKind,
    ComplaintPriority,
    ComplaintStatus,
)
from app.models.identity import User, UserProfile
from app.models.routes import Route, Stop
from app.models.trips import Trip
from app.repositories.admin_analytics_repository import DailyFigure

OPEN_STATUSES = (ComplaintStatus.OPEN, ComplaintStatus.IN_REVIEW)

# The trip a complaint is about: named on the complaint, or its booking's.
COMPLAINT_TRIP = func.coalesce(Complaint.trip_id, Booking.trip_id)


def due_at(sla_hours: Mapping[str, int]) -> ColumnElement[datetime]:
    hours = case(
        {priority: sla_hours[priority.value] for priority in ComplaintPriority},
        value=Complaint.priority,
    )
    return Complaint.created_at + func.make_interval(0, 0, 0, 0, hours)


def is_overdue(sla_hours: Mapping[str, int], now: datetime) -> ColumnElement[bool]:
    return and_(Complaint.status.in_(OPEN_STATUSES), due_at(sla_hours) < now)


def _with_booking(stmt: Select[Any]) -> Select[Any]:
    return stmt.outerjoin(Booking, Booking.id == Complaint.booking_id)


def _in_city(stmt: Select[Any], city: str) -> Select[Any]:
    trip, route, origin = aliased(Trip), aliased(Route), aliased(Stop)
    return (
        stmt.join(trip, trip.id == COMPLAINT_TRIP)
        .join(route, route.id == trip.route_id)
        .join(origin, origin.id == route.origin_stop_id)
        .where(func.lower(origin.city) == city.strip().lower())
    )


def _hours_since_filed(moment: Any) -> Any:
    return func.extract("epoch", moment - Complaint.created_at) / 3600


def complaint_figures() -> list[DailyFigure]:
    """Per day: complaints filed (and by category), and the hours they took
    to get a first response and a decision."""
    base = _with_booking(select(Complaint.id).select_from(Complaint))
    responded = (Complaint.first_response_at.is_not(None),)
    decided = (Complaint.resolved_at.is_not(None),)
    return [
        DailyFigure("filed", base, Complaint.created_at, func.count(Complaint.id), COMPLAINT_TRIP),
        DailyFigure(
            "by_category",
            base,
            Complaint.created_at,
            func.count(Complaint.id),
            COMPLAINT_TRIP,
            group=Complaint.category,
        ),
        DailyFigure(
            "responded",
            base,
            Complaint.created_at,
            func.count(Complaint.id),
            COMPLAINT_TRIP,
            conditions=responded,
        ),
        DailyFigure(
            "response_hours",
            base,
            Complaint.created_at,
            func.sum(_hours_since_filed(Complaint.first_response_at)),
            COMPLAINT_TRIP,
            conditions=responded,
        ),
        DailyFigure(
            "decided",
            base,
            Complaint.resolved_at,
            func.count(Complaint.id),
            COMPLAINT_TRIP,
            conditions=decided,
        ),
        DailyFigure(
            "resolution_hours",
            base,
            Complaint.resolved_at,
            func.sum(_hours_since_filed(Complaint.resolved_at)),
            COMPLAINT_TRIP,
            conditions=decided,
        ),
    ]


@dataclass(frozen=True, slots=True)
class ComplaintFilters:
    statuses: list[ComplaintStatus] | None = None
    priorities: list[ComplaintPriority] | None = None
    categories: list[ComplaintCategory] | None = None
    assigned_to: uuid.UUID | None = None
    unassigned: bool = False
    overdue: bool | None = None


@dataclass(frozen=True, slots=True)
class ComplaintRow:
    complaint: Complaint
    filed_by_name: str | None
    filed_by_phone: str | None
    assignee_name: str | None
    due_at: datetime


@dataclass(frozen=True, slots=True)
class OpenCount:
    priority: ComplaintPriority
    open: int
    overdue: int
    unassigned: int


@dataclass(frozen=True, slots=True)
class NoteRow:
    note: ComplaintNote
    author_name: str | None


_SORTS = {"created_at", "due_at", "priority"}


class AdminComplaintsRepository:
    SORTS = frozenset(_SORTS)

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    def _rows(self, sla_hours: Mapping[str, int]) -> Select[Any]:
        filer, assignee = aliased(UserProfile), aliased(UserProfile)
        return (
            select(
                Complaint,
                filer.full_name,
                User.phone_number,
                assignee.full_name,
                due_at(sla_hours).label("due_at"),
            )
            .join(User, User.id == Complaint.filed_by)
            .outerjoin(filer, filer.user_id == Complaint.filed_by)
            .outerjoin(assignee, assignee.user_id == Complaint.assigned_to)
        )

    async def list_complaints(
        self,
        filters: ComplaintFilters,
        *,
        sla_hours: Mapping[str, int],
        now: datetime,
        sort: str,
        descending: bool,
        limit: int,
        offset: int,
    ) -> tuple[list[ComplaintRow], int]:
        conditions: list[ColumnElement[bool]] = []
        if filters.statuses:
            conditions.append(Complaint.status.in_(filters.statuses))
        if filters.priorities:
            conditions.append(Complaint.priority.in_(filters.priorities))
        if filters.categories:
            conditions.append(Complaint.category.in_(filters.categories))
        if filters.assigned_to is not None:
            conditions.append(Complaint.assigned_to == filters.assigned_to)
        if filters.unassigned:
            conditions.append(Complaint.assigned_to.is_(None))
        if filters.overdue is not None:
            late = is_overdue(sla_hours, now)
            conditions.append(late if filters.overdue else ~late)
        total = int(
            await self._session.scalar(select(func.count(Complaint.id)).where(*conditions)) or 0
        )
        column: Any = {
            "created_at": Complaint.created_at,
            "due_at": due_at(sla_hours),
            "priority": Complaint.priority,
        }[sort]
        ordered = column.desc() if descending else column.asc()
        result = await self._session.execute(
            self._rows(sla_hours)
            .where(*conditions)
            .order_by(ordered, Complaint.created_at.desc(), Complaint.id)
            .limit(limit)
            .offset(offset)
        )
        return [ComplaintRow(*row) for row in result.all()], total

    async def get(
        self, complaint_id: uuid.UUID, *, sla_hours: Mapping[str, int]
    ) -> ComplaintRow | None:
        row = (
            await self._session.execute(self._rows(sla_hours).where(Complaint.id == complaint_id))
        ).first()
        return ComplaintRow(*row) if row is not None else None

    async def notes(
        self, complaint_id: uuid.UUID, *, kind: ComplaintNoteKind | None = None
    ) -> list[NoteRow]:
        """Oldest first, as a conversation reads."""
        stmt = (
            select(ComplaintNote, UserProfile.full_name)
            .outerjoin(UserProfile, UserProfile.user_id == ComplaintNote.author_id)
            .where(ComplaintNote.complaint_id == complaint_id)
            .order_by(ComplaintNote.created_at, ComplaintNote.id)
        )
        if kind is not None:
            stmt = stmt.where(ComplaintNote.kind == kind)
        return [NoteRow(*row) for row in (await self._session.execute(stmt)).all()]

    async def open_counts(
        self, *, sla_hours: Mapping[str, int], now: datetime, city: str | None
    ) -> list[OpenCount]:
        """What is open right now, by priority."""
        stmt = _with_booking(
            select(
                Complaint.priority,
                func.count(Complaint.id),
                func.count(Complaint.id).filter(due_at(sla_hours) < now),
                func.count(Complaint.id).filter(Complaint.assigned_to.is_(None)),
            ).select_from(Complaint)
        ).where(Complaint.status.in_(OPEN_STATUSES))
        if city is not None:
            stmt = _in_city(stmt, city)
        rows = {
            priority: (int(n), int(late), int(free))
            for priority, n, late, free in (
                await self._session.execute(stmt.group_by(Complaint.priority))
            ).all()
        }
        return [
            OpenCount(priority, *rows.get(priority, (0, 0, 0))) for priority in ComplaintPriority
        ]
