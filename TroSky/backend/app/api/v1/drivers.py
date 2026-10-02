"""Driver self-service endpoints: profile, verification documents, and
(non-trip) vehicle assignments.

Every route requires the ``driver`` role except the one that creates the
profile — that endpoint is how an account acquires the role in the first
place (see :mod:`app.services.role_service`), so gating it would make the
role unreachable for anyone who registered as a passenger."""

from __future__ import annotations

import uuid
from datetime import UTC, date, datetime
from typing import Annotated, Literal

from fastapi import APIRouter, Depends, File, Form, Query, UploadFile, status

from app.api.dependencies import (
    CurrentPrincipal,
    DriverServiceDep,
    Pagination,
    RatingServiceDep,
    WalletServiceDep,
)
from app.api.v1.views import driver_response, rating_summary
from app.core.config import get_settings
from app.core.exceptions import ValidationAppError
from app.core.permissions import SystemRole, require_roles
from app.models.drivers import DocumentType
from app.models.trips import TripStatus
from app.models.vehicles import Vehicle
from app.schemas.common import PaginatedResponse
from app.schemas.driver import (
    AssignedVehicleResponse,
    DocumentDownloadUrlResponse,
    DriverAssignmentResponse,
    DriverDocumentResponse,
    DriverRegisterRequest,
    DriverResponse,
    DriverUpdateRequest,
    EarningsSummaryResponse,
)
from app.schemas.feedback import DriverRatingSummaryResponse
from app.schemas.trip import TripSummaryResponse
from app.services.wallet_service import period_start
from app.utilities.query_params import parse_enum_list

router = APIRouter(dependencies=[Depends(require_roles(SystemRole.DRIVER))])

# Onboarding: authenticated, but deliberately not role-gated.
onboarding_router = APIRouter()


@onboarding_router.post("/me", response_model=DriverResponse, status_code=status.HTTP_201_CREATED)
async def register_driver(
    body: DriverRegisterRequest, principal: CurrentPrincipal, drivers: DriverServiceDep
) -> DriverResponse:
    """Create this account's driver verification profile and grant it the
    ``driver`` role (status starts ``pending``; see
    ``/api/v1/admin/drivers/pending`` for the review flow).

    Any signed-in account may call this — that is what lets one TroSky
    login be a passenger and a driver at once. The role takes effect
    immediately: ``get_current_principal`` reloads roles from the database
    on every request, so the existing access token keeps working."""
    driver = await drivers.register(principal.user_id, body)
    return await driver_response(driver, drivers)


@router.get("/me", response_model=DriverResponse)
async def get_my_driver_profile(
    principal: CurrentPrincipal, drivers: DriverServiceDep
) -> DriverResponse:
    driver = await drivers.get_own_profile(principal.user_id)
    return await driver_response(driver, drivers)


@router.patch("/me", response_model=DriverResponse)
async def update_my_driver_profile(
    body: DriverUpdateRequest, principal: CurrentPrincipal, drivers: DriverServiceDep
) -> DriverResponse:
    driver = await drivers.update_own_profile(principal.user_id, body)
    return await driver_response(driver, drivers)


@router.post(
    "/me/documents", response_model=DriverDocumentResponse, status_code=status.HTTP_201_CREATED
)
async def upload_my_document(
    principal: CurrentPrincipal,
    drivers: DriverServiceDep,
    document_type: DocumentType = Form(...),
    file: UploadFile = File(...),
) -> DriverDocumentResponse:
    data = await file.read()
    document = await drivers.upload_document(
        principal.user_id,
        document_type=document_type,
        filename=file.filename or "upload",
        content_type=file.content_type or "application/octet-stream",
        data=data,
    )
    return DriverDocumentResponse.model_validate(document)


@router.get("/me/documents", response_model=list[DriverDocumentResponse])
async def list_my_documents(
    principal: CurrentPrincipal, drivers: DriverServiceDep
) -> list[DriverDocumentResponse]:
    documents = await drivers.list_documents(principal.user_id)
    return [DriverDocumentResponse.model_validate(d) for d in documents]


@router.get("/me/documents/{document_id}/download-url", response_model=DocumentDownloadUrlResponse)
async def get_my_document_download_url(
    document_id: uuid.UUID, principal: CurrentPrincipal, drivers: DriverServiceDep
) -> DocumentDownloadUrlResponse:
    url = await drivers.get_document_download_url(
        principal.user_id, document_id, requested_by=principal.user_id
    )
    return DocumentDownloadUrlResponse(
        download_url=url, expires_in_seconds=get_settings().S3_PRESIGNED_URL_TTL_SECONDS
    )


@router.get("/me/assignments", response_model=list[DriverAssignmentResponse])
async def list_my_assignments(
    principal: CurrentPrincipal, drivers: DriverServiceDep
) -> list[DriverAssignmentResponse]:
    """Vehicles this driver is currently authorized to operate, with their
    details. The trips themselves are at ``GET /drivers/me/trips``."""
    return [
        DriverAssignmentResponse.model_validate(assignment).model_copy(
            update={"vehicle": _assigned_vehicle(vehicle) if vehicle else None}
        )
        for assignment, vehicle in await drivers.list_own_assignments(principal.user_id)
    ]


def _assigned_vehicle(vehicle: Vehicle) -> AssignedVehicleResponse:
    make_model = " ".join(part for part in (vehicle.make, vehicle.model) if part) or None
    return AssignedVehicleResponse(
        id=vehicle.id,
        registration_number=vehicle.registration_number,
        vehicle_type=vehicle.vehicle_type,
        make_model=make_model,
        capacity=vehicle.capacity,
        status=vehicle.status,
    )


@router.get("/me/rating-summary", response_model=DriverRatingSummaryResponse)
async def get_my_rating_summary(
    principal: CurrentPrincipal, drivers: DriverServiceDep, ratings: RatingServiceDep
) -> DriverRatingSummaryResponse:
    """How passengers rate this driver: overall and per category."""
    driver = await drivers.get_own_profile(principal.user_id)
    return await rating_summary(driver.id, ratings)


@router.get("/me/trips", response_model=PaginatedResponse[TripSummaryResponse])
async def list_my_trips(
    principal: CurrentPrincipal,
    drivers: DriverServiceDep,
    pagination: Pagination,
    status_filter: Annotated[
        str | None,
        Query(
            alias="status",
            description="Comma-separated trip statuses, e.g. scheduled,boarding.",
        ),
    ] = None,
    on_date: Annotated[
        date | None,
        Query(alias="date", description="Only trips departing on this day (YYYY-MM-DD)."),
    ] = None,
) -> PaginatedResponse[TripSummaryResponse]:
    """Trips this driver is assigned to, soonest departure first.
    ``seats_booked`` counts paid seats (the manifest); ``boarded_count`` the
    tickets scanned so far."""
    summaries, total = await drivers.list_own_trips(
        principal.user_id,
        statuses=parse_enum_list(status_filter, TripStatus, param="status"),
        on_date=on_date,
        limit=pagination.limit,
        offset=pagination.offset,
    )
    return PaginatedResponse(
        items=[TripSummaryResponse.model_validate(s) for s in summaries],
        total=total,
        limit=pagination.limit,
        offset=pagination.offset,
    )


@router.get("/me/earnings", response_model=EarningsSummaryResponse)
async def get_my_earnings(
    principal: CurrentPrincipal,
    wallets: WalletServiceDep,
    period: Literal["day", "week", "month"] = "week",
    from_date: Annotated[
        date | None,
        Query(alias="from", description="First day to include. Default: start of the period."),
    ] = None,
    to_date: Annotated[
        date | None, Query(alias="to", description="Last day to include. Default: today.")
    ] = None,
) -> EarningsSummaryResponse:
    """Trip earnings between ``from`` and ``to`` (inclusive, UTC -- Ghana
    time), totalled per day, week (from Monday) or month. Every period in
    the range has a bucket, empty ones included. With no dates, covers the
    current day/week/month up to today."""
    end = to_date or datetime.now(UTC).date()
    start = from_date or period_start(end, period)
    if start > end:
        raise ValidationAppError("'from' must not be after 'to'.")
    if (end - start).days > 366:
        raise ValidationAppError("Ask for at most 366 days at a time.")
    summary = await wallets.earnings_summary(principal.user_id, period=period, start=start, end=end)
    return EarningsSummaryResponse.model_validate(summary)
