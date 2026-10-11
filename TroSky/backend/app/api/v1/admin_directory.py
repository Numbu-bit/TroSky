"""Admin directory: every vehicle, driver and fleet, not only those awaiting
approval. Mounted under ``/admin``.

Lists take filters as query parameters, ``limit``/``offset``, ``sort``
(``field`` or ``-field``) and ``format=csv``. Permissions reuse the existing
ones: whoever approves vehicles or drivers, or watches live trips, can see
them; fleets need vehicle approval or reports.
"""

from __future__ import annotations

import uuid
from datetime import UTC, datetime, timedelta
from typing import Annotated

from fastapi import APIRouter, Depends, Query, Response

from app.api.common_dependencies import DbSession, Pagination
from app.api.v1.listing import (
    CSV_EXPORT_MAX_ROWS,
    CSV_RESPONSE,
    ExportFormat,
    FormatQuery,
    csv_response,
    export_window,
    parse_sort,
)
from app.core.exceptions import NotFoundError, ValidationAppError
from app.core.permissions import Permission, require_permissions
from app.models.drivers import ApprovalStatus, Driver
from app.repositories.admin_directory_repository import (
    AdminDirectoryRepository,
    DriverFilters,
    DriverRow,
    FleetRow,
    VehicleFilters,
    VehicleRow,
)
from app.schemas.admin_directory import (
    AdminDriverDetailResponse,
    AdminDriverResponse,
    AdminFleetDetailResponse,
    AdminFleetResponse,
    AdminVehicleDetailResponse,
    AdminVehicleResponse,
    AssignedVehicle,
    DocumentSummary,
    FleetOwnerRef,
    IncidentSummary,
    Ref,
    VehicleActivity,
    VehicleRef,
)
from app.schemas.common import PaginatedResponse
from app.utilities.query_params import parse_enum_list

router = APIRouter()

_SEE_VEHICLES = require_permissions(Permission.VEHICLES_APPROVE, Permission.TRIPS_MONITOR_LIVE)
_SEE_DRIVERS = require_permissions(Permission.DRIVERS_APPROVE, Permission.TRIPS_MONITOR_LIVE)
_SEE_FLEETS = require_permissions(Permission.VEHICLES_APPROVE, Permission.REPORTS_VIEW)
_LIVE_STATUSES = ("on_trip", "idle", "offline")


def get_directory(db: DbSession) -> AdminDirectoryRepository:
    return AdminDirectoryRepository(db)


Directory = Annotated[AdminDirectoryRepository, Depends(get_directory)]


def _live_statuses(raw: str | None) -> list[str] | None:
    if not raw:
        return None
    values = [part.strip() for part in raw.split(",") if part.strip()]
    unknown = [value for value in values if value not in _LIVE_STATUSES]
    if unknown:
        raise ValidationAppError(
            "Unknown live status.", details={"param": "live_status", "allowed": _LIVE_STATUSES}
        )
    return values


# ---------------------------------------------------------------- vehicles
def vehicle_response(row: VehicleRow) -> AdminVehicleResponse:
    make_model = " ".join(part for part in (row.make, row.model) if part) or None
    return AdminVehicleResponse(
        id=row.vehicle_id,
        registration_number=row.registration_number,
        vehicle_type=row.vehicle_type,
        make_model=make_model,
        year=row.year,
        capacity=row.capacity,
        status=row.status,
        fleet=Ref(id=row.fleet_id, name=row.fleet_name),
        fleet_owner=Ref(id=row.fleet_owner_id, name=row.fleet_owner_name),
        driver=Ref(id=row.driver_id, name=row.driver_name) if row.driver_id else None,
        live_status=row.live_status,
        current_trip_id=row.current_trip_id,
        insurance_expiry=row.insurance_expiry,
        roadworthy_expiry=row.roadworthy_expiry,
        created_at=row.created_at,
    )


_VEHICLE_SORTS = (
    "registration_number",
    "created_at",
    "capacity",
    "status",
    "live_status",
    "insurance_expiry",
    "roadworthy_expiry",
)


@router.get(
    "/vehicles",
    response_model=PaginatedResponse[AdminVehicleResponse],
    responses=CSV_RESPONSE,
    dependencies=[Depends(_SEE_VEHICLES)],
)
async def list_vehicles(
    directory: Directory,
    pagination: Pagination,
    status: Annotated[str | None, Query(description="Approval statuses, comma-separated.")] = None,
    live_status: Annotated[
        str | None, Query(description="on_trip, idle and/or offline, comma-separated.")
    ] = None,
    fleet_id: uuid.UUID | None = None,
    fleet_owner_id: uuid.UUID | None = None,
    city: Annotated[
        str | None, Query(description="Has a trip starting there in the last 30 or next 7 days.")
    ] = None,
    expiring_within_days: Annotated[
        int | None,
        Query(ge=0, le=365, description="Insurance or roadworthiness expires within (or before)."),
    ] = None,
    q: Annotated[str | None, Query(max_length=40, description="Part of the plate.")] = None,
    sort: Annotated[str | None, Query(description=f"One of {', '.join(_VEHICLE_SORTS)}.")] = None,
    export: ExportFormat = FormatQuery,
) -> PaginatedResponse[AdminVehicleResponse] | Response:
    """Every vehicle on the platform with its fleet, driver and live status."""
    field, descending = parse_sort(sort, _VEHICLE_SORTS, default="registration_number")
    limit, offset = export_window(pagination, export)
    rows, total = await directory.list_vehicles(
        VehicleFilters(
            statuses=parse_enum_list(status, ApprovalStatus, param="status"),
            live_statuses=_live_statuses(live_status),
            fleet_id=fleet_id,
            fleet_owner_id=fleet_owner_id,
            city=city,
            expiring_within_days=expiring_within_days,
            query=q,
        ),
        sort=field,
        descending=descending,
        limit=limit,
        offset=offset,
    )
    items = [vehicle_response(row) for row in rows]
    if export == "csv":
        return csv_response(items, name="vehicles")
    return PaginatedResponse(items=items, total=total, limit=limit, offset=offset)


@router.get(
    "/vehicles/{vehicle_id}",
    response_model=AdminVehicleDetailResponse,
    dependencies=[Depends(_SEE_VEHICLES)],
)
async def get_vehicle(vehicle_id: uuid.UUID, directory: Directory) -> AdminVehicleDetailResponse:
    """One vehicle: its documents, the last 30 days of trips and revenue, and
    its most recent incidents."""
    rows, _ = await directory.list_vehicles(
        VehicleFilters(vehicle_id=vehicle_id),
        sort="registration_number",
        descending=False,
        limit=1,
        offset=0,
    )
    if not rows:
        raise NotFoundError("Vehicle not found.")
    trips, completed, revenue = await directory.vehicle_activity(
        vehicle_id, since=datetime.now(UTC) - timedelta(days=30)
    )
    documents = await directory.vehicle_documents(vehicle_id)
    incidents = await directory.vehicle_incidents(vehicle_id, limit=10)
    return AdminVehicleDetailResponse(
        **vehicle_response(rows[0]).model_dump(),
        documents=[DocumentSummary.model_validate(d) for d in documents],
        last_30_days=VehicleActivity(trips=trips, completed_trips=completed, revenue=revenue),
        recent_incidents=[IncidentSummary.model_validate(i) for i in incidents],
    )


# ----------------------------------------------------------------- drivers
def driver_response(row: DriverRow) -> AdminDriverResponse:
    return AdminDriverResponse(
        id=row.driver_id,
        user_id=row.user_id,
        full_name=row.full_name,
        phone_number=row.phone_number,
        email=row.email,
        status=row.status,
        license_number=row.license_number,
        license_expiry=row.license_expiry,
        fleet=Ref(id=row.fleet_id, name=row.fleet_name) if row.fleet_id else None,
        vehicle=(
            VehicleRef(id=row.vehicle_id, registration_number=row.vehicle_registration_number)
            if row.vehicle_id and row.vehicle_registration_number
            else None
        ),
        live_status=row.live_status,
        current_trip_id=row.current_trip_id,
        average_rating=row.average_rating,
        rating_count=row.rating_count,
        last_active_at=row.last_active_at,
        created_at=row.created_at,
    )


_DRIVER_SORTS = (
    "full_name",
    "created_at",
    "status",
    "live_status",
    "average_rating",
    "rating_count",
    "last_active_at",
    "license_expiry",
)


@router.get(
    "/drivers",
    response_model=PaginatedResponse[AdminDriverResponse],
    responses=CSV_RESPONSE,
    dependencies=[Depends(_SEE_DRIVERS)],
)
async def list_drivers(
    directory: Directory,
    pagination: Pagination,
    status: Annotated[str | None, Query(description="Approval statuses, comma-separated.")] = None,
    live_status: Annotated[
        str | None, Query(description="on_trip, idle and/or offline, comma-separated.")
    ] = None,
    fleet_id: uuid.UUID | None = None,
    city: Annotated[
        str | None, Query(description="Has a trip starting there in the last 30 or next 7 days.")
    ] = None,
    expiring_within_days: Annotated[
        int | None,
        Query(ge=0, le=365, description="Licence or an approved document expires within."),
    ] = None,
    q: Annotated[str | None, Query(max_length=60, description="Name, phone or licence.")] = None,
    sort: Annotated[str | None, Query(description=f"One of {', '.join(_DRIVER_SORTS)}.")] = None,
    export: ExportFormat = FormatQuery,
) -> PaginatedResponse[AdminDriverResponse] | Response:
    """Every driver with their fleet, vehicle, rating and live status."""
    field, descending = parse_sort(sort, _DRIVER_SORTS, default="full_name")
    limit, offset = export_window(pagination, export)
    rows, total = await directory.list_drivers(
        DriverFilters(
            statuses=parse_enum_list(status, ApprovalStatus, param="status"),
            live_statuses=_live_statuses(live_status),
            fleet_id=fleet_id,
            city=city,
            expiring_within_days=expiring_within_days,
            query=q,
        ),
        sort=field,
        descending=descending,
        limit=limit,
        offset=offset,
    )
    items = [driver_response(row) for row in rows]
    if export == "csv":
        return csv_response(items, name="drivers")
    return PaginatedResponse(items=items, total=total, limit=limit, offset=offset)


@router.get(
    "/drivers/{driver_id}",
    response_model=AdminDriverDetailResponse,
    dependencies=[Depends(_SEE_DRIVERS)],
)
async def get_driver(
    driver_id: uuid.UUID, directory: Directory, db: DbSession
) -> AdminDriverDetailResponse:
    """One driver: profile, documents with expiry dates, and vehicles."""
    rows, _ = await directory.list_drivers(
        DriverFilters(driver_id=driver_id),
        sort="full_name",
        descending=False,
        limit=1,
        offset=0,
    )
    driver = await db.get(Driver, driver_id)
    if not rows or driver is None:
        raise NotFoundError("Driver not found.")
    documents = await directory.driver_documents(driver_id)
    assignments = await directory.driver_assignments(driver_id)
    return AdminDriverDetailResponse(
        **driver_response(rows[0]).model_dump(),
        license_class=driver.license_class,
        years_of_experience=driver.years_of_experience,
        documents=[DocumentSummary.model_validate(d) for d in documents],
        vehicles=[
            AssignedVehicle(
                id=vehicle.id,
                registration_number=vehicle.registration_number,
                vehicle_type=vehicle.vehicle_type,
                fleet_id=assignment.fleet_id,
                assigned_at=assignment.assigned_at,
            )
            for assignment, vehicle in assignments
        ],
    )


# ------------------------------------------------------------------ fleets
def fleet_response(row: FleetRow) -> AdminFleetResponse:
    return AdminFleetResponse(
        id=row.fleet_id,
        name=row.fleet_name,
        is_active=row.is_active,
        owner=FleetOwnerRef(
            id=row.fleet_owner_id,
            business_name=row.business_name,
            status=row.owner_status,
            name=row.owner_name,
            phone_number=row.owner_phone,
        ),
        vehicle_count=row.vehicle_count,
        approved_vehicles=row.approved_vehicles,
        active_now=row.active_now,
        driver_count=row.driver_count,
        utilization_7d=row.utilization_7d,
        revenue_30d=row.revenue_30d,
        average_rating=row.average_rating,
        created_at=row.created_at,
    )


_FLEET_SORTS = (
    "fleet_name",
    "business_name",
    "created_at",
    "vehicle_count",
    "active_now",
    "revenue_30d",
    "average_rating",
)


@router.get(
    "/fleets",
    response_model=PaginatedResponse[AdminFleetResponse],
    responses=CSV_RESPONSE,
    dependencies=[Depends(_SEE_FLEETS)],
)
async def list_fleets(
    directory: Directory,
    pagination: Pagination,
    owner_status: Annotated[
        str | None, Query(description="Fleet owners' approval statuses, comma-separated.")
    ] = None,
    q: Annotated[str | None, Query(max_length=60, description="Fleet or business name.")] = None,
    sort: Annotated[str | None, Query(description=f"One of {', '.join(_FLEET_SORTS)}.")] = None,
    export: ExportFormat = FormatQuery,
) -> PaginatedResponse[AdminFleetResponse] | Response:
    """Fleets with their size, vehicles out now, use over the last week,
    revenue over the last 30 days and average driver rating."""
    field, descending = parse_sort(sort, _FLEET_SORTS, default="fleet_name")
    limit, offset = export_window(pagination, export)
    rows, total = await directory.list_fleets(
        owner_statuses=parse_enum_list(owner_status, ApprovalStatus, param="owner_status"),
        query=q,
        sort=field,
        descending=descending,
        limit=limit,
        offset=offset,
    )
    items = [fleet_response(row) for row in rows]
    if export == "csv":
        return csv_response(items, name="fleets")
    return PaginatedResponse(items=items, total=total, limit=limit, offset=offset)


@router.get(
    "/fleets/{fleet_id}",
    response_model=AdminFleetDetailResponse,
    dependencies=[Depends(_SEE_FLEETS)],
)
async def get_fleet(fleet_id: uuid.UUID, directory: Directory) -> AdminFleetDetailResponse:
    """One fleet with all its vehicles and drivers."""
    rows, _ = await directory.list_fleets(
        owner_statuses=None,
        query=None,
        sort="fleet_name",
        descending=False,
        limit=1,
        offset=0,
        fleet_id=fleet_id,
    )
    if not rows:
        raise NotFoundError("Fleet not found.")
    vehicles, _ = await directory.list_vehicles(
        VehicleFilters(fleet_id=fleet_id),
        sort="registration_number",
        descending=False,
        limit=CSV_EXPORT_MAX_ROWS,
        offset=0,
    )
    drivers, _ = await directory.list_drivers(
        DriverFilters(fleet_id=fleet_id),
        sort="full_name",
        descending=False,
        limit=CSV_EXPORT_MAX_ROWS,
        offset=0,
    )
    return AdminFleetDetailResponse(
        **fleet_response(rows[0]).model_dump(),
        vehicles=[vehicle_response(row) for row in vehicles],
        drivers=[driver_response(row) for row in drivers],
    )
