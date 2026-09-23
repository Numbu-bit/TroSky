"""Driver self-service endpoints: profile, verification documents, and
(non-trip) vehicle assignments.

Every route requires the ``driver`` role except the one that creates the
profile — that endpoint is how an account acquires the role in the first
place (see :mod:`app.services.role_service`), so gating it would make the
role unreachable for anyone who registered as a passenger."""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, File, Form, UploadFile, status

from app.api.dependencies import CurrentPrincipal, DriverServiceDep
from app.core.config import get_settings
from app.core.permissions import SystemRole, require_roles
from app.models.drivers import DocumentType
from app.schemas.driver import (
    DocumentDownloadUrlResponse,
    DriverAssignmentResponse,
    DriverDocumentResponse,
    DriverRegisterRequest,
    DriverResponse,
    DriverUpdateRequest,
)

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
    return DriverResponse.model_validate(driver)


@router.get("/me", response_model=DriverResponse)
async def get_my_driver_profile(
    principal: CurrentPrincipal, drivers: DriverServiceDep
) -> DriverResponse:
    driver = await drivers.get_own_profile(principal.user_id)
    return DriverResponse.model_validate(driver)


@router.patch("/me", response_model=DriverResponse)
async def update_my_driver_profile(
    body: DriverUpdateRequest, principal: CurrentPrincipal, drivers: DriverServiceDep
) -> DriverResponse:
    driver = await drivers.update_own_profile(principal.user_id, body)
    return DriverResponse.model_validate(driver)


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
    """Vehicles this driver is currently authorized to operate. Trip-specific
    assignments are added to this response from Phase 4 onward."""
    assignments = await drivers.list_own_assignments(principal.user_id)
    return [DriverAssignmentResponse.model_validate(a) for a in assignments]
