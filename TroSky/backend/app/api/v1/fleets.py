"""Fleet-owner self-service endpoints: fleet-owner profile, fleets,
vehicles, vehicle documents, seat layouts, and (non-trip) driver
assignment. Every route requires the ``fleet_owner`` role and every
fleet/vehicle lookup is scoped to the caller's own fleet-owner record —
see ``app.services.fleet_service`` module docstring for the tenant-isolation
guarantee.
"""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, File, Form, UploadFile, status

from app.api.dependencies import AnalyticsServiceDep, CurrentPrincipal, FleetServiceDep
from app.core.config import get_settings
from app.core.permissions import SystemRole, require_roles
from app.models.drivers import DocumentType
from app.schemas.analytics import FleetSummaryResponse
from app.schemas.driver import DocumentDownloadUrlResponse
from app.schemas.driver import DriverDocumentResponse as VehicleDocumentResponse
from app.schemas.fleet import (
    AssignDriverRequest,
    FleetCreateRequest,
    FleetOwnerRegisterRequest,
    FleetOwnerResponse,
    FleetResponse,
    FleetUpdateRequest,
    SeatLayoutRequest,
    SeatLayoutResponse,
    SeatResponse,
    VehicleCreateRequest,
    VehicleResponse,
    VehicleUpdateRequest,
)

router = APIRouter(dependencies=[Depends(require_roles(SystemRole.FLEET_OWNER))])

# Onboarding: authenticated, but deliberately not role-gated -- this is how
# an account acquires the fleet-owner role.
onboarding_router = APIRouter()


# ---------------------------------------------------------------------------
# Fleet owner profile
# ---------------------------------------------------------------------------
@onboarding_router.post(
    "/fleet-owners/me", response_model=FleetOwnerResponse, status_code=status.HTTP_201_CREATED
)
async def register_fleet_owner(
    body: FleetOwnerRegisterRequest, principal: CurrentPrincipal, fleets: FleetServiceDep
) -> FleetOwnerResponse:
    """Create this account's fleet-owner profile and grant it the
    ``fleet_owner`` role. Open to any signed-in account; the role takes
    effect immediately, without re-authenticating."""
    owner = await fleets.register(principal.user_id, body)
    return FleetOwnerResponse.model_validate(owner)


@router.get("/fleet-owners/me", response_model=FleetOwnerResponse)
async def get_my_fleet_owner_profile(
    principal: CurrentPrincipal, fleets: FleetServiceDep
) -> FleetOwnerResponse:
    owner = await fleets.get_own_profile(principal.user_id)
    return FleetOwnerResponse.model_validate(owner)


# ---------------------------------------------------------------------------
# Fleets
# ---------------------------------------------------------------------------
@router.post("/fleets", response_model=FleetResponse, status_code=status.HTTP_201_CREATED)
async def create_fleet(
    body: FleetCreateRequest, principal: CurrentPrincipal, fleets: FleetServiceDep
) -> FleetResponse:
    fleet = await fleets.create_fleet(principal.user_id, body)
    return FleetResponse.model_validate(fleet)


@router.get("/fleets", response_model=list[FleetResponse])
async def list_my_fleets(
    principal: CurrentPrincipal, fleets: FleetServiceDep
) -> list[FleetResponse]:
    records = await fleets.list_own_fleets(principal.user_id)
    return [FleetResponse.model_validate(f) for f in records]


@router.get("/fleets/{fleet_id}", response_model=FleetResponse)
async def get_my_fleet(
    fleet_id: uuid.UUID, principal: CurrentPrincipal, fleets: FleetServiceDep
) -> FleetResponse:
    fleet = await fleets.get_own_fleet(principal.user_id, fleet_id)
    return FleetResponse.model_validate(fleet)


@router.get("/fleets/{fleet_id}/analytics", response_model=FleetSummaryResponse)
async def get_fleet_analytics(
    fleet_id: uuid.UUID, principal: CurrentPrincipal, analytics: AnalyticsServiceDep
) -> FleetSummaryResponse:
    summary = await analytics.get_fleet_summary(principal.user_id, fleet_id)
    return FleetSummaryResponse.model_validate(summary)


@router.patch("/fleets/{fleet_id}", response_model=FleetResponse)
async def update_my_fleet(
    fleet_id: uuid.UUID,
    body: FleetUpdateRequest,
    principal: CurrentPrincipal,
    fleets: FleetServiceDep,
) -> FleetResponse:
    fleet = await fleets.update_fleet(principal.user_id, fleet_id, body)
    return FleetResponse.model_validate(fleet)


# ---------------------------------------------------------------------------
# Vehicles
# ---------------------------------------------------------------------------
@router.post(
    "/fleets/{fleet_id}/vehicles",
    response_model=VehicleResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_vehicle(
    fleet_id: uuid.UUID,
    body: VehicleCreateRequest,
    principal: CurrentPrincipal,
    fleets: FleetServiceDep,
) -> VehicleResponse:
    vehicle = await fleets.create_vehicle(principal.user_id, fleet_id, body)
    return VehicleResponse.model_validate(vehicle)


@router.get("/fleets/{fleet_id}/vehicles", response_model=list[VehicleResponse])
async def list_fleet_vehicles(
    fleet_id: uuid.UUID, principal: CurrentPrincipal, fleets: FleetServiceDep
) -> list[VehicleResponse]:
    vehicles = await fleets.list_vehicles_for_fleet(principal.user_id, fleet_id)
    return [VehicleResponse.model_validate(v) for v in vehicles]


@router.get("/vehicles/{vehicle_id}", response_model=VehicleResponse)
async def get_my_vehicle(
    vehicle_id: uuid.UUID, principal: CurrentPrincipal, fleets: FleetServiceDep
) -> VehicleResponse:
    vehicle = await fleets.get_own_vehicle(principal.user_id, vehicle_id)
    return VehicleResponse.model_validate(vehicle)


@router.patch("/vehicles/{vehicle_id}", response_model=VehicleResponse)
async def update_my_vehicle(
    vehicle_id: uuid.UUID,
    body: VehicleUpdateRequest,
    principal: CurrentPrincipal,
    fleets: FleetServiceDep,
) -> VehicleResponse:
    vehicle = await fleets.update_vehicle(principal.user_id, vehicle_id, body)
    return VehicleResponse.model_validate(vehicle)


@router.post(
    "/vehicles/{vehicle_id}/documents",
    response_model=VehicleDocumentResponse,
    status_code=status.HTTP_201_CREATED,
)
async def upload_vehicle_document(
    vehicle_id: uuid.UUID,
    principal: CurrentPrincipal,
    fleets: FleetServiceDep,
    document_type: DocumentType = Form(...),
    file: UploadFile = File(...),
) -> VehicleDocumentResponse:
    data = await file.read()
    document = await fleets.upload_vehicle_document(
        principal.user_id,
        vehicle_id,
        document_type=document_type,
        filename=file.filename or "upload",
        content_type=file.content_type or "application/octet-stream",
        data=data,
    )
    return VehicleDocumentResponse.model_validate(document)


@router.get("/vehicles/{vehicle_id}/documents", response_model=list[VehicleDocumentResponse])
async def list_vehicle_documents(
    vehicle_id: uuid.UUID, principal: CurrentPrincipal, fleets: FleetServiceDep
) -> list[VehicleDocumentResponse]:
    documents = await fleets.list_vehicle_documents(principal.user_id, vehicle_id)
    return [VehicleDocumentResponse.model_validate(d) for d in documents]


@router.get(
    "/vehicles/{vehicle_id}/documents/{document_id}/download-url",
    response_model=DocumentDownloadUrlResponse,
)
async def get_vehicle_document_download_url(
    vehicle_id: uuid.UUID,
    document_id: uuid.UUID,
    principal: CurrentPrincipal,
    fleets: FleetServiceDep,
) -> DocumentDownloadUrlResponse:
    url = await fleets.get_vehicle_document_download_url(principal.user_id, vehicle_id, document_id)
    return DocumentDownloadUrlResponse(
        download_url=url, expires_in_seconds=get_settings().S3_PRESIGNED_URL_TTL_SECONDS
    )


# ---------------------------------------------------------------------------
# Seat layout
# ---------------------------------------------------------------------------
@router.put("/vehicles/{vehicle_id}/seat-layout", response_model=SeatLayoutResponse)
async def set_vehicle_seat_layout(
    vehicle_id: uuid.UUID,
    body: SeatLayoutRequest,
    principal: CurrentPrincipal,
    fleets: FleetServiceDep,
) -> SeatLayoutResponse:
    layout, seats = await fleets.set_seat_layout(principal.user_id, vehicle_id, body)
    return SeatLayoutResponse(
        id=layout.id,
        vehicle_id=layout.vehicle_id,
        name=layout.name,
        rows=layout.rows,
        columns=layout.columns,
        total_seats=layout.total_seats,
        seats=[SeatResponse.model_validate(s) for s in seats],
    )


@router.get("/vehicles/{vehicle_id}/seat-layout", response_model=SeatLayoutResponse)
async def get_vehicle_seat_layout(
    vehicle_id: uuid.UUID, principal: CurrentPrincipal, fleets: FleetServiceDep
) -> SeatLayoutResponse:
    layout, seats = await fleets.get_seat_layout(principal.user_id, vehicle_id)
    return SeatLayoutResponse(
        id=layout.id,
        vehicle_id=layout.vehicle_id,
        name=layout.name,
        rows=layout.rows,
        columns=layout.columns,
        total_seats=layout.total_seats,
        seats=[SeatResponse.model_validate(s) for s in seats],
    )


# ---------------------------------------------------------------------------
# Driver assignment (non-trip)
# ---------------------------------------------------------------------------
@router.post(
    "/vehicles/{vehicle_id}/assign-driver",
    status_code=status.HTTP_204_NO_CONTENT,
    response_model=None,
)
async def assign_driver_to_vehicle(
    vehicle_id: uuid.UUID,
    body: AssignDriverRequest,
    principal: CurrentPrincipal,
    fleets: FleetServiceDep,
) -> None:
    await fleets.assign_driver(principal.user_id, vehicle_id, body.driver_id)


@router.delete(
    "/vehicles/{vehicle_id}/assign-driver/{driver_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    response_model=None,
)
async def unassign_driver_from_vehicle(
    vehicle_id: uuid.UUID,
    driver_id: uuid.UUID,
    principal: CurrentPrincipal,
    fleets: FleetServiceDep,
) -> None:
    await fleets.unassign_driver(principal.user_id, vehicle_id, driver_id)
