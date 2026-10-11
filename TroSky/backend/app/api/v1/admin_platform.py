"""Platform administration: the audit log, system settings, feature flags
and wallet adjustments. Mounted under ``/admin``; the permissions
(``audit_logs:view``, ``system_settings:manage``, ``feature_flags:manage``,
``wallet:adjust``) existed before these endpoints did.
"""

from __future__ import annotations

import uuid
from datetime import UTC, date, datetime, time, timedelta
from typing import Annotated

from fastapi import APIRouter, Depends, Query, Response
from sqlalchemy import ColumnElement, func, select

from app.api.auth_dependencies import CurrentPrincipal
from app.api.common_dependencies import DbSession, OptionalIdempotencyKey, Pagination
from app.api.v1.listing import (
    CSV_RESPONSE,
    ExportFormat,
    FormatQuery,
    csv_response,
    export_window,
)
from app.core.config import from_minor_units, get_settings
from app.core.exceptions import NotFoundError
from app.core.permissions import Permission, require_permissions
from app.models.admin import AuditLog
from app.models.identity import User, UserProfile
from app.models.payments import WalletReferenceType, WalletTransaction
from app.repositories.wallet_repository import WalletRepository
from app.schemas.admin_platform import (
    AdminWalletResponse,
    AuditLogResponse,
    FeatureFlagResponse,
    FeatureFlagUpdateRequest,
    SettingResponse,
    SettingsUpdateRequest,
    WalletAdjustmentRequest,
    WalletAdjustmentResponse,
    WalletOwner,
)
from app.schemas.common import PaginatedResponse
from app.schemas.payment import WalletTransactionResponse
from app.services.system_settings_service import SystemSettingsService
from app.services.wallet_service import WalletService

router = APIRouter()


def _transaction(t: WalletTransaction) -> WalletTransactionResponse:
    return WalletTransactionResponse(
        id=t.id,
        entry_type=t.entry_type,
        amount=from_minor_units(t.amount_minor_units),
        balance_after=from_minor_units(t.balance_after_minor_units),
        reference_type=t.reference_type,
        reference_id=t.reference_id,
        description=t.description,
        created_at=t.created_at,
    )


# ---------------------------------------------------------------- audit log
@router.get(
    "/audit-logs",
    response_model=PaginatedResponse[AuditLogResponse],
    responses=CSV_RESPONSE,
    dependencies=[Depends(require_permissions(Permission.AUDIT_LOGS_VIEW))],
)
async def list_audit_logs(
    db: DbSession,
    pagination: Pagination,
    actor_id: uuid.UUID | None = None,
    action: Annotated[str | None, Query(max_length=100)] = None,
    entity_type: Annotated[str | None, Query(max_length=60, examples=["trips"])] = None,
    entity_id: Annotated[str | None, Query(max_length=100)] = None,
    date_from: Annotated[date | None, Query(alias="from")] = None,
    date_to: Annotated[date | None, Query(alias="to")] = None,
    export: ExportFormat = FormatQuery,
) -> PaginatedResponse[AuditLogResponse] | Response:
    """What admins changed, newest first: who, which endpoint, which row,
    the changed columns before and after, why, and from where."""
    conditions: list[ColumnElement[bool]] = []
    if actor_id is not None:
        conditions.append(AuditLog.actor_user_id == actor_id)
    if action:
        conditions.append(AuditLog.action == action)
    if entity_type:
        conditions.append(AuditLog.entity_type == entity_type)
    if entity_id:
        conditions.append(AuditLog.entity_id == entity_id)
    if date_from:
        conditions.append(AuditLog.created_at >= datetime.combine(date_from, time.min, UTC))
    if date_to:
        end = datetime.combine(date_to + timedelta(days=1), time.min, UTC)
        conditions.append(AuditLog.created_at < end)
    limit, offset = export_window(pagination, export)
    total = int(await db.scalar(select(func.count(AuditLog.id)).where(*conditions)) or 0)
    rows = (
        await db.execute(
            select(AuditLog, UserProfile.full_name)
            .outerjoin(UserProfile, UserProfile.user_id == AuditLog.actor_user_id)
            .where(*conditions)
            .order_by(AuditLog.created_at.desc(), AuditLog.id)
            .limit(limit)
            .offset(offset)
        )
    ).all()
    items = [
        AuditLogResponse.model_validate(entry).model_copy(update={"actor_name": name})
        for entry, name in rows
    ]
    if export == "csv":
        return csv_response(items, name="audit-log")
    return PaginatedResponse(
        items=items, total=total, limit=pagination.limit, offset=pagination.offset
    )


@router.get(
    "/audit-logs/{entry_id}",
    response_model=AuditLogResponse,
    dependencies=[Depends(require_permissions(Permission.AUDIT_LOGS_VIEW))],
)
async def get_audit_log(entry_id: uuid.UUID, db: DbSession) -> AuditLogResponse:
    row = (
        await db.execute(
            select(AuditLog, UserProfile.full_name)
            .outerjoin(UserProfile, UserProfile.user_id == AuditLog.actor_user_id)
            .where(AuditLog.id == entry_id)
        )
    ).first()
    if row is None:
        raise NotFoundError("Audit log entry not found.")
    return AuditLogResponse.model_validate(row[0]).model_copy(update={"actor_name": row[1]})


# ----------------------------------------------------------------- settings
_SETTINGS = require_permissions(Permission.SYSTEM_SETTINGS_MANAGE)


@router.get("/settings", response_model=list[SettingResponse], dependencies=[Depends(_SETTINGS)])
async def get_system_settings(db: DbSession) -> list[SettingResponse]:
    """Every adjustable setting: its value now, and whether an admin changed
    it from the default."""
    entries = await SystemSettingsService(db).list_settings()
    return [SettingResponse.model_validate(entry) for entry in entries]


@router.patch("/settings", response_model=list[SettingResponse], dependencies=[Depends(_SETTINGS)])
async def update_system_settings(
    body: SettingsUpdateRequest, db: DbSession, principal: CurrentPrincipal
) -> list[SettingResponse]:
    """Change any settings at once (``null`` restores a default). They are
    checked together; nothing is saved if one is invalid. Fees, the payment
    hold, the driver's share and the live-update interval apply to new
    bookings and trips within 30 seconds."""
    changes = body.model_dump(exclude_unset=True, exclude={"reason"})
    service = SystemSettingsService(db)
    await service.update_settings(changes, by=principal.user_id)
    return [SettingResponse.model_validate(entry) for entry in await service.list_settings()]


# ------------------------------------------------------------ feature flags
_FLAGS = require_permissions(Permission.FEATURE_FLAGS_MANAGE)


@router.get(
    "/feature-flags", response_model=list[FeatureFlagResponse], dependencies=[Depends(_FLAGS)]
)
async def list_feature_flags(db: DbSession) -> list[FeatureFlagResponse]:
    flags = await SystemSettingsService(db).list_flags()
    return [FeatureFlagResponse.model_validate(flag) for flag in flags]


@router.patch(
    "/feature-flags/{key}", response_model=FeatureFlagResponse, dependencies=[Depends(_FLAGS)]
)
async def update_feature_flag(
    key: str,
    body: FeatureFlagUpdateRequest,
    db: DbSession,
    principal: CurrentPrincipal,
) -> FeatureFlagResponse:
    """Turn a flag on or off, or roll it out to a share of users (the same
    users each time). Flags that switch a platform-wide setting are on or
    off for everyone."""
    flag = await SystemSettingsService(db).update_flag(
        key,
        enabled=body.enabled,
        rollout_percent=body.rollout_percent,
        by=principal.user_id,
    )
    return FeatureFlagResponse.model_validate(flag)


# ------------------------------------------------------------------ wallets
_WALLETS = require_permissions(Permission.WALLET_ADJUST)


async def _owner(db: DbSession, user_id: uuid.UUID) -> WalletOwner:
    row = (
        await db.execute(
            select(User.id, UserProfile.full_name, User.phone_number)
            .outerjoin(UserProfile, UserProfile.user_id == User.id)
            .where(User.id == user_id)
        )
    ).first()
    if row is None:
        raise NotFoundError("User not found.")
    return WalletOwner(id=row[0], full_name=row[1], phone_number=row[2])


@router.get(
    "/wallets/{user_id}", response_model=AdminWalletResponse, dependencies=[Depends(_WALLETS)]
)
async def get_user_wallet(
    user_id: uuid.UUID, db: DbSession, pagination: Pagination
) -> AdminWalletResponse:
    """A user's balance, money held for withdrawals, and transactions,
    newest first."""
    owner = await _owner(db, user_id)
    wallets = WalletService(db)
    transactions, total = await wallets.list_transactions(
        user_id, limit=pagination.limit, offset=pagination.offset
    )
    wallet = await WalletRepository(db).get_by_user_id(user_id)
    return AdminWalletResponse(
        user=owner,
        balance=await wallets.get_balance(user_id),
        currency=get_settings().PAYMENTS_DEFAULT_CURRENCY,
        held_for_withdrawals=await WalletRepository(db).pending_withdrawals_total(user_id),
        frozen_at=wallet.frozen_at if wallet else None,
        frozen_reason=wallet.frozen_reason if wallet else None,
        transactions=[_transaction(t) for t in transactions],
        transactions_total=total,
        limit=pagination.limit,
        offset=pagination.offset,
    )


@router.post(
    "/wallets/{user_id}/adjustments",
    response_model=WalletAdjustmentResponse,
    status_code=201,
    dependencies=[Depends(_WALLETS)],
)
async def adjust_user_wallet(
    user_id: uuid.UUID,
    body: WalletAdjustmentRequest,
    db: DbSession,
    principal: CurrentPrincipal,
    idempotency_key: OptionalIdempotencyKey,
) -> WalletAdjustmentResponse:
    """Credit or debit a wallet by hand, with a reason (shown to the user as
    the transaction's description, and kept in the audit log). A debit may
    not take the balance below zero. Send an ``Idempotency-Key`` so a retry
    does not adjust twice."""
    await _owner(db, user_id)
    wallets = WalletService(db)
    description = f"Adjustment by TroSky: {body.reason}"
    if body.reference:
        description = f"{description} (ref {body.reference})"
    adjust = wallets.credit if body.direction == "credit" else wallets.debit
    transaction = await adjust(
        user_id,
        amount=body.amount,
        reference_type=WalletReferenceType.ADMIN_ADJUSTMENT,
        reference_id=principal.user_id,
        description=description[:255],
        idempotency_key=f"admin-adjustment-{idempotency_key}" if idempotency_key else None,
    )
    return WalletAdjustmentResponse(
        transaction=_transaction(transaction), balance=await wallets.get_balance(user_id)
    )
