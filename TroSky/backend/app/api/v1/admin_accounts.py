"""People, for the admin dashboard: browsing users and one user's details
and devices, the admin team, an admin's own devices, and approval requests.
Mounted under ``/admin``.
"""

from __future__ import annotations

import uuid
from datetime import UTC, date, datetime, time, timedelta
from typing import Annotated, Literal, cast

from fastapi import APIRouter, Depends, Query, Response, status

from app.api.auth_dependencies import AuthServiceDep, CurrentPrincipal
from app.api.common_dependencies import DbSession, Pagination, StorageProviderDep
from app.api.v1.listing import (
    CSV_RESPONSE,
    ExportFormat,
    FormatQuery,
    csv_response,
    export_window,
    parse_sort,
)
from app.core.exceptions import NotFoundError
from app.core.permissions import Permission, SystemRole, require_permissions, require_roles
from app.repositories.user_repository import UserRepository
from app.schemas.admin_accounts import (
    AdminMeResponse,
    AdminSessionResponse,
    AdminUserDetailResponse,
    AdminUserResponse,
    DocumentLinkResponse,
    FavouriteRoute,
    InfoRequestBody,
    InfoRequestResponse,
    MaskedPaymentMethod,
    TeamInviteRequest,
    TeamInviteResponse,
    TeamMemberResponse,
    TeamUpdateRequest,
    TeamUpdateResponse,
)
from app.schemas.auth import SessionResponse
from app.schemas.common import PaginatedResponse
from app.services.admin_accounts_service import (
    AdminAccountsService,
    TeamMember,
    UserFilters,
    UserRow,
    UserSort,
    UserStatus,
)
from app.services.approval_requests_service import ApprovalRequestsService, InfoRequest
from app.utilities.query_params import parse_enum_list

router = APIRouter()

_USERS = [Depends(require_permissions(Permission.USERS_MANAGE, Permission.USERS_SUSPEND))]
_USERS_MANAGE = [Depends(require_permissions(Permission.USERS_MANAGE))]
_TEAM = [Depends(require_permissions(Permission.ADMINS_MANAGE))]
_ON_TEAM = [Depends(require_roles(SystemRole.SUPER_ADMIN, SystemRole.ADMIN, SystemRole.STAFF))]
_USER_SORTS = {"created_at", "last_login_at", "full_name"}


def _user(row: UserRow) -> AdminUserResponse:
    user = row.user
    return AdminUserResponse(
        id=user.id,
        phone_number=user.phone_number,
        email=user.email,
        full_name=row.full_name,
        roles=sorted(row.roles),
        is_active=user.is_active,
        is_suspended=user.is_suspended,
        suspended_reason=user.suspended_reason,
        created_at=user.created_at,
        last_login_at=user.last_login_at,
    )


def _member(member: TeamMember) -> TeamMemberResponse:
    return TeamMemberResponse(
        id=member.user.id,
        full_name=member.full_name,
        phone_number=member.user.phone_number,
        email=member.user.email,
        role=member.role,
        permissions=member.permissions,
        granted_permissions=member.granted,
        is_active=member.user.is_active,
        is_suspended=member.user.is_suspended,
        last_login_at=member.user.last_login_at,
        created_at=member.user.created_at,
    )


def _info(request: InfoRequest) -> InfoRequestResponse:
    return InfoRequestResponse(
        subject_type=request.subject_type,
        subject_id=request.subject_id,
        document_types=request.document_types,
        note=request.note,
        documents_returned=request.documents_returned,
        notified_user_id=request.notified_user_id,
        requested_at=request.requested_at,
    )


# -------------------------------------------------------------------- users
@router.get(
    "/users",
    response_model=PaginatedResponse[AdminUserResponse],
    responses=CSV_RESPONSE,
    dependencies=_USERS,
)
async def list_users(
    db: DbSession,
    pagination: Pagination,
    search: Annotated[
        str | None, Query(max_length=100, description="Name, phone number or email.")
    ] = None,
    role: Annotated[
        str | None, Query(description="Comma-separated, e.g. 'driver,fleet_owner'.")
    ] = None,
    user_status: Annotated[UserStatus | None, Query(alias="status")] = None,
    city: Annotated[
        str | None, Query(max_length=100, description="Booked a trip from a stop there.")
    ] = None,
    signed_up_from: date | None = None,
    signed_up_to: date | None = None,
    sort: Annotated[
        str | None,
        Query(description="created_at, last_login_at or full_name; '-' first for descending."),
    ] = None,
    export: ExportFormat = FormatQuery,
) -> PaginatedResponse[AdminUserResponse] | Response:
    """Everyone with an account, newest first by default: by role, status
    (active, suspended, inactive), city and sign-up date, or a search."""
    field, descending = parse_sort(sort, _USER_SORTS, default="-created_at")
    limit, offset = export_window(pagination, export)
    rows, total = await AdminAccountsService(db).list_users(
        UserFilters(
            search=search,
            roles=parse_enum_list(role, SystemRole, param="role"),
            status=user_status,
            city=city,
            signed_up_from=datetime.combine(signed_up_from, time.min, UTC)
            if signed_up_from
            else None,
            signed_up_until=datetime.combine(signed_up_to + timedelta(days=1), time.min, UTC)
            if signed_up_to
            else None,
        ),
        sort=cast(UserSort, field),  # one of _USER_SORTS, checked above
        descending=descending,
        limit=limit,
        offset=offset,
    )
    items = [_user(row) for row in rows]
    if export == "csv":
        return csv_response(items, name="users")
    return PaginatedResponse(
        items=items, total=total, limit=pagination.limit, offset=pagination.offset
    )


@router.get("/users/{user_id}", response_model=AdminUserDetailResponse, dependencies=_USERS)
async def get_user(user_id: uuid.UUID, db: DbSession) -> AdminUserDetailResponse:
    """One user: profile and roles, saved mobile money numbers (masked),
    favourite routes, bookings and complaints, wallet, devices, and any
    open fraud flags."""
    detail = await AdminAccountsService(db).user_detail(user_id)
    user = detail.row.user
    return AdminUserDetailResponse(
        **_user(detail.row).model_dump(),
        preferred_language=detail.preferred_language,
        phone_verified=user.phone_verified_at is not None,
        email_verified=user.email_verified_at is not None,
        payment_methods=[MaskedPaymentMethod(**method) for method in detail.payment_methods],
        favourite_routes=[FavouriteRoute(**route) for route in detail.favourite_routes],
        bookings=detail.bookings,
        complaints=detail.complaints,
        wallet_balance=detail.wallet_balance,
        wallet_frozen_at=detail.wallet_frozen_at,
        active_sessions=detail.active_sessions,
        driver_id=detail.driver_id,
        fleet_owner_id=detail.fleet_owner_id,
        open_fraud_flags=detail.open_fraud_flags,
    )


@router.get(
    "/users/{user_id}/sessions",
    response_model=list[AdminSessionResponse],
    dependencies=_USERS_MANAGE,
)
async def list_user_sessions(user_id: uuid.UUID, db: DbSession) -> list[AdminSessionResponse]:
    """The user's signed-in devices, most recently used first."""
    sessions = await AdminAccountsService(db).sessions(user_id)
    return [AdminSessionResponse.model_validate(session) for session in sessions]


@router.delete(
    "/users/{user_id}/sessions/{session_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    response_model=None,
    dependencies=_USERS_MANAGE,
)
async def sign_out_user_session(
    user_id: uuid.UUID, session_id: uuid.UUID, db: DbSession, principal: CurrentPrincipal
) -> None:
    """Sign the user out on one device (a lost phone, say)."""
    await AdminAccountsService(db).sign_out(user_id, session_id, by=principal.user_id)


# ---------------------------------------------------------------- the team
@router.get("/admins", response_model=list[TeamMemberResponse], dependencies=_TEAM)
async def list_team(db: DbSession) -> list[TeamMemberResponse]:
    """The admin team: super admins, admins and staff, with what each may
    do."""
    return [_member(member) for member in await AdminAccountsService(db).team()]


@router.post(
    "/admins",
    response_model=TeamInviteResponse,
    status_code=status.HTTP_201_CREATED,
    dependencies=_TEAM,
)
async def invite_team_member(
    body: TeamInviteRequest,
    db: DbSession,
    principal: CurrentPrincipal,
    auth: AuthServiceDep,
) -> TeamInviteResponse:
    """Add someone to the team as an admin, or as staff with the permissions
    given. An existing account (by phone number or email) joins as it is; a
    new one is created and sent a code to set its password. You can neither
    give a role above your own nor grant a permission you do not hold."""
    member, created = await AdminAccountsService(db).invite(
        principal,
        full_name=body.full_name,
        phone_number=body.phone_number,
        email=body.email,
        role=SystemRole(body.role),
        permissions=body.permissions,
        send_invitation=auth.forgot_password,
    )
    return TeamInviteResponse(member=_member(member), new_account=created, invitation_sent=created)


@router.patch("/admins/{admin_id}", response_model=TeamUpdateResponse, dependencies=_TEAM)
async def update_team_member(
    admin_id: uuid.UUID, body: TeamUpdateRequest, db: DbSession, principal: CurrentPrincipal
) -> TeamUpdateResponse:
    """Change a member's role or permissions, or take them off the team
    (``active: false`` -- they are signed out everywhere). Not your own; not
    someone above you."""
    member = await AdminAccountsService(db).update_member(
        principal,
        admin_id,
        role=SystemRole(body.role) if body.role else None,
        permissions=body.permissions,
        active=body.active,
    )
    return TeamUpdateResponse(
        on_team=member is not None, member=_member(member) if member else None
    )


# The most senior admin role wins.
_TEAM_ROLES = (SystemRole.SUPER_ADMIN, SystemRole.ADMIN, SystemRole.STAFF)


@router.get("/me", response_model=AdminMeResponse, dependencies=_ON_TEAM)
async def who_am_i(db: DbSession, principal: CurrentPrincipal) -> AdminMeResponse:
    """You: your admin role and every permission you hold, so the dashboard
    shows only the screens and actions open to you."""
    user = await UserRepository(db).get_by_id(principal.user_id)
    if user is None:  # signed in a moment ago, deleted since
        raise NotFoundError("Account not found.")
    role = next(role for role in _TEAM_ROLES if principal.has_role(role))
    permissions = (
        [permission.value for permission in Permission]
        if role == SystemRole.SUPER_ADMIN
        else principal.permissions
    )
    return AdminMeResponse(
        id=user.id,
        full_name=user.profile.full_name if user.profile else None,
        phone_number=user.phone_number,
        email=user.email,
        role=cast(Literal["super_admin", "admin", "staff"], role.value),
        permissions=sorted(permissions),
    )


@router.get("/me/sessions", response_model=list[SessionResponse], dependencies=_ON_TEAM)
async def list_my_sessions(
    principal: CurrentPrincipal, auth: AuthServiceDep
) -> list[SessionResponse]:
    """Where you are signed in."""
    sessions = await auth.list_sessions(principal.user_id)
    return [
        SessionResponse.model_validate(session).model_copy(
            update={"is_current": session.id == principal.session_id}
        )
        for session in sessions
    ]


@router.delete(
    "/me/sessions/{session_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    response_model=None,
    dependencies=_ON_TEAM,
)
async def sign_out_my_session(
    session_id: uuid.UUID, principal: CurrentPrincipal, auth: AuthServiceDep
) -> None:
    """Sign yourself out on one device."""
    await auth.revoke_session_for_user(principal.user_id, session_id)


# ---------------------------------------------------------------- approvals
@router.post(
    "/drivers/{driver_id}/request-info",
    response_model=InfoRequestResponse,
    status_code=status.HTTP_201_CREATED,
    dependencies=[Depends(require_permissions(Permission.DRIVERS_APPROVE))],
)
async def request_driver_documents(
    driver_id: uuid.UUID, body: InfoRequestBody, db: DbSession, principal: CurrentPrincipal
) -> InfoRequestResponse:
    """Ask the driver to upload these documents again, with a note, instead
    of rejecting them: the documents are marked for uploading again with
    the note, the driver is notified, and the approval clock restarts."""
    request = await ApprovalRequestsService(db).request_driver_info(
        driver_id, document_types=body.document_types, note=body.note, by=principal.user_id
    )
    return _info(request)


@router.post(
    "/vehicles/{vehicle_id}/request-info",
    response_model=InfoRequestResponse,
    status_code=status.HTTP_201_CREATED,
    dependencies=[Depends(require_permissions(Permission.VEHICLES_APPROVE))],
)
async def request_vehicle_documents(
    vehicle_id: uuid.UUID, body: InfoRequestBody, db: DbSession, principal: CurrentPrincipal
) -> InfoRequestResponse:
    """The same for a vehicle: its fleet owner is notified."""
    request = await ApprovalRequestsService(db).request_vehicle_info(
        vehicle_id, document_types=body.document_types, note=body.note, by=principal.user_id
    )
    return _info(request)


@router.get(
    "/documents/{document_id}",
    response_model=DocumentLinkResponse,
    dependencies=[
        Depends(require_permissions(Permission.DRIVERS_APPROVE, Permission.VEHICLES_APPROVE))
    ],
)
async def get_document_link(
    document_id: uuid.UUID,
    db: DbSession,
    principal: CurrentPrincipal,
    storage: StorageProviderDep,
) -> DocumentLinkResponse:
    """A driver's or vehicle's document with a link to view it, valid for
    five minutes."""
    link = await ApprovalRequestsService(db).document_link(
        document_id, principal=principal, storage=storage
    )
    return DocumentLinkResponse(
        document_id=link.document_id,
        owner_type=link.owner_type,
        owner_id=link.owner_id,
        document_type=link.document_type,
        status=link.status,
        expiry_date=link.expiry_date,
        original_filename=link.original_filename,
        mime_type=link.mime_type,
        file_size_bytes=link.file_size_bytes,
        url=link.url,
        expires_at=link.expires_at,
    )
