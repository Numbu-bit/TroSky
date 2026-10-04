"""Passenger/driver complaint filing. Admin review lives in
``app.api.v1.admin``."""

from __future__ import annotations

import uuid

from fastapi import APIRouter, status

from app.api.dependencies import ComplaintServiceDep, CurrentPrincipal, Pagination
from app.core.permissions import Permission
from app.schemas.common import PaginatedResponse
from app.schemas.feedback import (
    ComplaintMessageResponse,
    ComplaintResponse,
    FileComplaintRequest,
)

router = APIRouter()


@router.post("", response_model=ComplaintResponse, status_code=status.HTTP_201_CREATED)
async def file_complaint(
    body: FileComplaintRequest, principal: CurrentPrincipal, service: ComplaintServiceDep
) -> ComplaintResponse:
    complaint = await service.file_complaint(
        principal.user_id,
        booking_id=body.booking_id,
        trip_id=body.trip_id,
        category=body.category,
        subject=body.subject,
        description=body.description,
    )
    return ComplaintResponse.model_validate(complaint)


@router.get("", response_model=PaginatedResponse[ComplaintResponse])
async def list_my_complaints(
    principal: CurrentPrincipal, service: ComplaintServiceDep, pagination: Pagination
) -> PaginatedResponse[ComplaintResponse]:
    complaints, total = await service.list_own_complaints(
        principal.user_id, limit=pagination.limit, offset=pagination.offset
    )
    return PaginatedResponse(
        items=[ComplaintResponse.model_validate(c) for c in complaints],
        total=total,
        limit=pagination.limit,
        offset=pagination.offset,
    )


@router.get("/{complaint_id}", response_model=ComplaintResponse)
async def get_complaint(
    complaint_id: uuid.UUID, principal: CurrentPrincipal, service: ComplaintServiceDep
) -> ComplaintResponse:
    is_privileged = principal.has_permission(Permission.COMPLAINTS_MANAGE)
    complaint = await service.get_complaint(
        complaint_id, requesting_user_id=principal.user_id, is_privileged=is_privileged
    )
    return ComplaintResponse.model_validate(complaint)


@router.get("/{complaint_id}/messages", response_model=list[ComplaintMessageResponse])
async def list_complaint_messages(
    complaint_id: uuid.UUID, principal: CurrentPrincipal, service: ComplaintServiceDep
) -> list[ComplaintMessageResponse]:
    """Messages from TroSky support about your complaint, oldest first. Each
    new one also arrives as a notification."""
    messages = await service.list_messages(complaint_id, requesting_user_id=principal.user_id)
    return [ComplaintMessageResponse.model_validate(message) for message in messages]
