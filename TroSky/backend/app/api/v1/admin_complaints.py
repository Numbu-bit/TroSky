"""The support team's complaint workflow: the queue with due times, figures,
one complaint's thread, assignment, priority, review, internal notes,
messages to the passenger, and decisions. Mounted under ``/admin``; every
endpoint needs ``complaints:manage``.
"""

from __future__ import annotations

import uuid
from datetime import UTC, datetime
from typing import Annotated

from fastapi import APIRouter, Depends, Query, Response, status

from app.api.auth_dependencies import CurrentPrincipal
from app.api.common_dependencies import DbSession, Pagination
from app.api.dependencies import ComplaintServiceDep
from app.api.v1.admin_analytics import City, DateFrom, DateTo, get_analytics
from app.api.v1.analytics_views import count_figure, period_response
from app.api.v1.listing import (
    CSV_RESPONSE,
    ExportFormat,
    FormatQuery,
    csv_response,
    export_window,
    parse_sort,
)
from app.core.exceptions import NotFoundError
from app.core.permissions import Permission, require_permissions
from app.models.feedback import ComplaintCategory, ComplaintPriority, ComplaintStatus
from app.repositories.admin_complaints_repository import (
    AdminComplaintsRepository,
    ComplaintFilters,
    ComplaintRow,
)
from app.schemas.admin_analytics import Compared
from app.schemas.admin_workflow import (
    AdminComplaintDetailResponse,
    AdminComplaintResponse,
    CategoryCount,
    ComplaintNoteRequest,
    ComplaintNoteResponse,
    ComplaintStatsResponse,
    ComplaintUpdateRequest,
    PriorityCount,
)
from app.schemas.common import PaginatedResponse
from app.schemas.feedback import ComplaintDecisionRequest, ComplaintResponse
from app.services.admin_analytics_service import AdminAnalyticsService, Period
from app.services.system_settings_service import admin_settings
from app.utilities.query_params import parse_enum_list

router = APIRouter(dependencies=[Depends(require_permissions(Permission.COMPLAINTS_MANAGE))])

Analytics = Annotated[AdminAnalyticsService, Depends(get_analytics)]


def _response(row: ComplaintRow, now: datetime) -> AdminComplaintResponse:
    complaint = row.complaint
    return AdminComplaintResponse(
        **ComplaintResponse.model_validate(complaint).model_dump(),
        priority=complaint.priority,
        filed_by_name=row.filed_by_name,
        filed_by_phone=row.filed_by_phone,
        assigned_to=complaint.assigned_to,
        assignee_name=row.assignee_name,
        assigned_at=complaint.assigned_at,
        first_response_at=complaint.first_response_at,
        due_at=row.due_at,
        is_overdue=(
            complaint.status in (ComplaintStatus.OPEN, ComplaintStatus.IN_REVIEW)
            and row.due_at < now
        ),
    )


async def _one(db: DbSession, complaint_id: uuid.UUID) -> AdminComplaintResponse:
    sla = (await admin_settings(db)).complaint_sla_hours
    row = await AdminComplaintsRepository(db).get(complaint_id, sla_hours=sla)
    if row is None:
        raise NotFoundError("Complaint not found.")
    return _response(row, datetime.now(UTC))


@router.get(
    "/complaints",
    responses=CSV_RESPONSE,
    response_model=PaginatedResponse[AdminComplaintResponse],
)
async def list_complaints(
    db: DbSession,
    pagination: Pagination,
    complaint_status: Annotated[
        str | None, Query(description="Comma-separated, e.g. 'open,in_review'.")
    ] = None,
    priority: Annotated[str | None, Query(description="Comma-separated.")] = None,
    category: Annotated[str | None, Query(description="Comma-separated.")] = None,
    assigned_to: uuid.UUID | None = None,
    unassigned: bool = False,
    overdue: bool | None = None,
    sort: Annotated[
        str | None,
        Query(description="created_at, due_at or priority; '-' first for descending."),
    ] = None,
    export: ExportFormat = FormatQuery,
) -> PaginatedResponse[AdminComplaintResponse] | Response:
    """The complaint queue, newest first by default, each with its due time
    (filed + the resolution time for its priority) and whether it is
    overdue."""
    field, descending = parse_sort(sort, AdminComplaintsRepository.SORTS, default="-created_at")
    limit, offset = export_window(pagination, export)
    now = datetime.now(UTC)
    rows, total = await AdminComplaintsRepository(db).list_complaints(
        ComplaintFilters(
            statuses=parse_enum_list(complaint_status, ComplaintStatus, param="complaint_status"),
            priorities=parse_enum_list(priority, ComplaintPriority, param="priority"),
            categories=parse_enum_list(category, ComplaintCategory, param="category"),
            assigned_to=assigned_to,
            unassigned=unassigned,
            overdue=overdue,
        ),
        sla_hours=(await admin_settings(db)).complaint_sla_hours,
        now=now,
        sort=field,
        descending=descending,
        limit=limit,
        offset=offset,
    )
    items = [_response(row, now) for row in rows]
    if export == "csv":
        return csv_response(items, name="complaints")
    return PaginatedResponse(
        items=items, total=total, limit=pagination.limit, offset=pagination.offset
    )


@router.get("/complaints/stats", response_model=ComplaintStatsResponse)
async def get_complaint_stats(
    db: DbSession,
    analytics: Analytics,
    date_from: DateFrom = None,
    date_to: DateTo = None,
    city: City = None,
) -> ComplaintStatsResponse:
    """What is open now (by priority, with how many are overdue or
    unassigned), and over the period against the one before: complaints
    filed, per 1,000 trips, average hours to a first response and to a
    decision, and by category. With ``city``, only complaints about a trip
    starting there count."""
    period = Period.resolve(date_from, date_to)
    sla = (await admin_settings(db)).complaint_sla_hours
    stats = await analytics.complaints(period, city, sla_hours=sla)
    return ComplaintStatsResponse(
        period=period_response(period, city),
        open=sum(count.open for count in stats.open_now),
        overdue=sum(count.overdue for count in stats.open_now),
        unassigned=sum(count.unassigned for count in stats.open_now),
        by_priority=[
            PriorityCount(
                priority=count.priority,
                resolution_hours=sla[count.priority.value],
                open=count.open,
                overdue=count.overdue,
                unassigned=count.unassigned,
            )
            for count in stats.open_now
        ],
        filed=count_figure(stats.filed),
        per_1000_trips=Compared(
            value=stats.per_1000_trips.value, previous=stats.per_1000_trips.previous
        ),
        avg_first_response_hours=Compared(
            value=stats.avg_first_response_hours.value,
            previous=stats.avg_first_response_hours.previous,
        ),
        avg_resolution_hours=Compared(
            value=stats.avg_resolution_hours.value, previous=stats.avg_resolution_hours.previous
        ),
        by_category=[
            CategoryCount(category=category, filed=int(figure.value), previous=int(figure.previous))
            for category, figure in stats.by_category.items()
        ],
    )


@router.get("/complaints/{complaint_id}", response_model=AdminComplaintDetailResponse)
async def get_complaint(complaint_id: uuid.UUID, db: DbSession) -> AdminComplaintDetailResponse:
    """One complaint with its internal notes and messages, oldest first."""
    complaint = await _one(db, complaint_id)
    notes = await AdminComplaintsRepository(db).notes(complaint_id)
    return AdminComplaintDetailResponse(
        **complaint.model_dump(),
        notes=[
            ComplaintNoteResponse(
                id=row.note.id,
                kind=row.note.kind,
                body=row.note.body,
                author_id=row.note.author_id,
                author_name=row.author_name,
                created_at=row.note.created_at,
            )
            for row in notes
        ],
    )


@router.patch("/complaints/{complaint_id}", response_model=AdminComplaintResponse)
async def update_complaint(
    complaint_id: uuid.UUID,
    body: ComplaintUpdateRequest,
    db: DbSession,
    complaints: ComplaintServiceDep,
) -> AdminComplaintResponse:
    """Assign it (``assigned_to: null`` unassigns), set its priority, or
    move it into review. A resolved or dismissed complaint cannot change
    (409)."""
    await complaints.update(
        complaint_id,
        assign="assigned_to" in body.model_fields_set,
        assigned_to=body.assigned_to,
        priority=body.priority,
        in_review=body.status == "in_review",
    )
    return await _one(db, complaint_id)


@router.post(
    "/complaints/{complaint_id}/notes",
    response_model=ComplaintNoteResponse,
    status_code=status.HTTP_201_CREATED,
)
async def add_complaint_note(
    complaint_id: uuid.UUID,
    body: ComplaintNoteRequest,
    principal: CurrentPrincipal,
    complaints: ComplaintServiceDep,
) -> ComplaintNoteResponse:
    """An internal note for the team, or a message to the passenger: they
    are notified, and see it with the complaint in the app."""
    note = await complaints.add_note(
        complaint_id, author_id=principal.user_id, kind=body.kind, body=body.body
    )
    return ComplaintNoteResponse(
        id=note.id,
        kind=note.kind,
        body=note.body,
        author_id=note.author_id,
        author_name=None,
        created_at=note.created_at,
    )


@router.post("/complaints/{complaint_id}/resolve", response_model=AdminComplaintResponse)
async def resolve_complaint(
    complaint_id: uuid.UUID,
    body: ComplaintDecisionRequest,
    principal: CurrentPrincipal,
    db: DbSession,
    complaints: ComplaintServiceDep,
) -> AdminComplaintResponse:
    await complaints.resolve(complaint_id, reviewer_id=principal.user_id, notes=body.notes)
    return await _one(db, complaint_id)


@router.post("/complaints/{complaint_id}/dismiss", response_model=AdminComplaintResponse)
async def dismiss_complaint(
    complaint_id: uuid.UUID,
    body: ComplaintDecisionRequest,
    principal: CurrentPrincipal,
    db: DbSession,
    complaints: ComplaintServiceDep,
) -> AdminComplaintResponse:
    await complaints.dismiss(complaint_id, reviewer_id=principal.user_id, notes=body.notes)
    return await _one(db, complaint_id)
