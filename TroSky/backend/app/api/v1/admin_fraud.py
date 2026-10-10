"""Fraud detection for the admin dashboard: the flags the rules raise, their
review and the actions taken, the figures, and the rules themselves.
Mounted under ``/admin``. Reading needs ``fraud:view`` (or
``fraud:manage``); changing anything needs ``fraud:manage``.
"""

from __future__ import annotations

import uuid
from datetime import UTC, datetime, time, timedelta
from decimal import Decimal
from typing import Annotated, Any

from fastapi import APIRouter, Depends, Query, Response
from sqlalchemy import func, select

from app.api.auth_dependencies import CurrentPrincipal
from app.api.common_dependencies import DbSession, Pagination
from app.api.v1.admin_analytics import DateFrom, DateTo
from app.api.v1.analytics_views import count_figure, period_response
from app.api.v1.listing import (
    CSV_RESPONSE,
    ExportFormat,
    FormatQuery,
    csv_response,
    export_window,
    parse_sort,
)
from app.core.exceptions import ConflictError, NotFoundError, ValidationAppError
from app.core.permissions import Permission, require_permissions
from app.core.redis import RedisLock, get_redis_client
from app.models.fraud import FraudFlag, FraudFlagEvent, FraudFlagStatus, FraudSeverity
from app.repositories.admin_analytics_repository import AdminAnalyticsRepository, DailyFigure
from app.repositories.admin_fraud_repository import (
    SORTS,
    AdminFraudRepository,
    FlagFilters,
    FlagRow,
)
from app.schemas.admin_analytics import Compared
from app.schemas.admin_fraud import (
    DetectionRunResponse,
    FraudActionRequest,
    FraudActionResponse,
    FraudFlagDetailResponse,
    FraudFlagEventResponse,
    FraudFlagResponse,
    FraudFlagUpdateRequest,
    FraudRuleResponse,
    FraudRuleUpdateRequest,
    FraudStatsResponse,
    LinkedBooking,
    LinkedPayment,
    LinkedTrip,
    LinkedUser,
    RuleCount,
)
from app.schemas.common import PaginatedResponse
from app.services.admin_analytics_service import Period, figure_from
from app.services.fraud_rules import RULES
from app.services.fraud_service import FraudService
from app.utilities.query_params import parse_enum_list

router = APIRouter()

_VIEW = [Depends(require_permissions(Permission.FRAUD_VIEW, Permission.FRAUD_MANAGE))]
_MANAGE = [Depends(require_permissions(Permission.FRAUD_MANAGE))]
# One detection run at a time, however it was started.
DETECTION_LOCK = "fraud:detection"
DETECTION_LOCK_SECONDS = 300

_DETECTED = DailyFigure(
    name="detected",
    base=select(FraudFlag.id).select_from(FraudFlag),
    timestamp=FraudFlag.first_detected_at,
    value=func.count(FraudFlag.id),
)


def _flag(row: FlagRow) -> FraudFlagResponse:
    flag = row.flag
    rule = RULES.get(flag.rule)
    return FraudFlagResponse(
        id=flag.id,
        rule=flag.rule,
        rule_title=rule.title if rule else flag.rule,
        severity=flag.severity,
        risk_score=flag.risk_score,
        entity_type=flag.entity_type,
        entity_id=flag.entity_id,
        subject_user_id=flag.subject_user_id,
        subject_name=row.subject_name,
        summary=flag.summary,
        amount_at_risk=flag.amount_at_risk,
        status=flag.status,
        assigned_to=flag.assigned_to,
        assignee_name=row.assignee_name,
        first_detected_at=flag.first_detected_at,
        last_detected_at=flag.last_detected_at,
        occurrences=flag.occurrences,
    )


def _event(event: FraudFlagEvent, actor_name: str | None) -> FraudFlagEventResponse:
    return FraudFlagEventResponse(
        id=event.id,
        kind=event.kind,
        actor_id=event.actor_id,
        actor_name=actor_name,
        details=event.details,
        created_at=event.created_at,
    )


async def _one(db: DbSession, flag_id: uuid.UUID) -> FlagRow:
    row = await AdminFraudRepository(db).get(flag_id)
    if row is None:
        raise NotFoundError("Fraud flag not found.")
    return row


def _ids(links: dict[str, Any], kind: str) -> list[uuid.UUID]:
    found = []
    for value in links.get(kind, []):
        try:
            found.append(uuid.UUID(str(value)))
        except ValueError:
            continue
    return found


# -------------------------------------------------------------------- flags
@router.get(
    "/fraud/flags",
    response_model=PaginatedResponse[FraudFlagResponse],
    responses=CSV_RESPONSE,
    dependencies=_VIEW,
)
async def list_fraud_flags(
    db: DbSession,
    pagination: Pagination,
    flag_status: Annotated[
        str | None,
        Query(alias="status", description="Comma-separated, e.g. 'open,investigating'."),
    ] = None,
    rule: Annotated[str | None, Query(description="Comma-separated rule keys.")] = None,
    severity: Annotated[str | None, Query(description="Comma-separated.")] = None,
    min_risk: Annotated[int | None, Query(ge=0, le=100)] = None,
    assigned_to: uuid.UUID | None = None,
    unassigned: bool = False,
    subject_user_id: uuid.UUID | None = None,
    date_from: DateFrom = None,
    date_to: DateTo = None,
    sort: Annotated[
        str | None,
        Query(
            description="risk_score, first_detected_at, last_detected_at or amount_at_risk; "
            "'-' first for descending."
        ),
    ] = None,
    export: ExportFormat = FormatQuery,
) -> PaginatedResponse[FraudFlagResponse] | Response:
    """What the fraud rules found, riskiest first by default: the rule, its
    severity and risk score (0-100), what it is about, a summary, the money
    at risk, the status and who is looking into it."""
    field, descending = parse_sort(sort, SORTS, default="-risk_score")
    rules = [part.strip() for part in (rule or "").split(",") if part.strip()] or None
    unknown = sorted(set(rules or []) - set(RULES))
    if unknown:
        raise ValidationAppError(
            f"Unknown rules: {', '.join(unknown)}.",
            details={"param": "rule", "allowed": sorted(RULES)},
        )
    limit, offset = export_window(pagination, export)
    rows, total = await AdminFraudRepository(db).list_flags(
        FlagFilters(
            statuses=parse_enum_list(flag_status, FraudFlagStatus, param="status"),
            rules=rules,
            severities=parse_enum_list(severity, FraudSeverity, param="severity"),
            min_risk=min_risk,
            assigned_to=assigned_to,
            unassigned=unassigned,
            subject_user_id=subject_user_id,
            since=datetime.combine(date_from, time.min, UTC) if date_from else None,
            until=(
                datetime.combine(date_to + timedelta(days=1), time.min, UTC) if date_to else None
            ),
        ),
        sort=field,
        descending=descending,
        limit=limit,
        offset=offset,
    )
    items = [_flag(row) for row in rows]
    if export == "csv":
        return csv_response(items, name="fraud-flags")
    return PaginatedResponse(
        items=items, total=total, limit=pagination.limit, offset=pagination.offset
    )


@router.get("/fraud/flags/{flag_id}", response_model=FraudFlagDetailResponse, dependencies=_VIEW)
async def get_fraud_flag(flag_id: uuid.UUID, db: DbSession) -> FraudFlagDetailResponse:
    """One flag with its evidence, its timeline (detected, assigned, status
    changes, actions taken), and the users, trips, bookings and payments it
    links to."""
    row = await _one(db, flag_id)
    flag = row.flag
    fraud = AdminFraudRepository(db)
    links = dict(flag.evidence.get("links", {}))
    timeline = await fraud.timeline(flag_id)
    return FraudFlagDetailResponse(
        **_flag(row).model_dump(),
        evidence=flag.evidence,
        reviewed_by=flag.reviewed_by,
        reviewed_at=flag.reviewed_at,
        review_reason=flag.review_reason,
        device_blocked=(
            await fraud.device_blocked(flag.entity_id) if flag.entity_type == "device" else None
        ),
        users=[
            LinkedUser(
                id=user_id,
                full_name=name,
                phone_number=phone,
                is_suspended=suspended,
                wallet_frozen=bool(frozen),
            )
            for user_id, name, phone, suspended, frozen in await fraud.users(_ids(links, "users"))
        ],
        trips=[
            LinkedTrip(id=trip_id, route_name=name, scheduled_departure_at=departs, status=status)
            for trip_id, name, departs, status in await fraud.trips(_ids(links, "trips"))
        ],
        bookings=[
            LinkedBooking(
                id=booking_id, booking_reference=reference, status=status, fare_amount=fare
            )
            for booking_id, reference, status, fare in await fraud.bookings(_ids(links, "bookings"))
        ],
        payments=[
            LinkedPayment(
                id=payment_id,
                internal_reference=reference,
                amount=amount,
                status=status,
                channel=channel,
            )
            for payment_id, reference, amount, status, channel in await fraud.payments(
                _ids(links, "payments")
            )
        ],
        timeline=[_event(event, name) for event, name in timeline],
    )


@router.patch("/fraud/flags/{flag_id}", response_model=FraudFlagResponse, dependencies=_MANAGE)
async def update_fraud_flag(
    flag_id: uuid.UUID, body: FraudFlagUpdateRequest, db: DbSession, principal: CurrentPrincipal
) -> FraudFlagResponse:
    """Set the status (investigating, confirmed, false positive, or back to
    open) or the assignee (``null`` unassigns). Confirming a flag or calling
    it a false positive needs a ``reason``."""
    await FraudService(db).update_flag(
        flag_id,
        status=body.status,
        assign="assigned_to" in body.model_fields_set,
        assigned_to=body.assigned_to,
        reason=body.reason,
        by=principal.user_id,
    )
    return _flag(await _one(db, flag_id))


@router.post(
    "/fraud/flags/{flag_id}/actions",
    response_model=FraudActionResponse,
    status_code=201,
    dependencies=_MANAGE,
)
async def act_on_fraud_flag(
    flag_id: uuid.UUID, body: FraudActionRequest, db: DbSession, principal: CurrentPrincipal
) -> FraudActionResponse:
    """Act on a flag, with a reason:

    * ``suspend_account`` -- the account is suspended and signed out
      everywhere (``/admin/users/{id}/reactivate`` undoes it);
    * ``freeze_wallet`` / ``unfreeze_wallet`` -- no payments or payouts
      leave the wallet while it is frozen;
    * ``block_device`` / ``unblock_device`` -- every session on the device
      ends and no one may sign in from it.

    The account defaults to the flag's subject and the device to the flag's
    device. An open flag moves to "investigating"."""
    event = await FraudService(db).act(
        flag_id,
        action=body.action,
        reason=body.reason,
        user_id=body.user_id,
        device_id=body.device_id,
        by=principal.user_id,
    )
    return FraudActionResponse(flag=_flag(await _one(db, flag_id)), event=_event(event, None))


# -------------------------------------------------------------------- stats
@router.get("/fraud/stats", response_model=FraudStatsResponse, dependencies=_VIEW)
async def get_fraud_stats(
    db: DbSession, date_from: DateFrom = None, date_to: DateTo = None
) -> FraudStatsResponse:
    """Open and high-risk flags and the money at risk, now; and over the
    period against the one before: flags raised per day, how many reviews
    confirmed fraud, the precision of the rules (confirmed out of all
    reviewed), and counts per rule."""
    period = Period.resolve(date_from, date_to)
    open_now, high_risk, at_risk = await FraudService(db).open_counts()
    daily = await AdminAnalyticsRepository(db).daily(
        [_DETECTED], start=period.previous.since, end=period.until, city=None
    )
    fraud = AdminFraudRepository(db)
    confirmed, false_positive = await fraud.reviewed(period.since, period.until)
    before = await fraud.reviewed(period.previous.since, period.previous.until)

    def precision(yes: int, no: int) -> Decimal | None:
        return (Decimal(yes) / (yes + no)).quantize(Decimal("0.0001")) if yes + no else None

    return FraudStatsResponse(
        period=period_response(period, None),
        open=open_now,
        high_risk=high_risk,
        amount_at_risk=at_risk,
        detected=count_figure(figure_from(daily.get("detected", {}), period)),
        confirmed=confirmed,
        false_positive=false_positive,
        precision=Compared(value=precision(confirmed, false_positive), previous=precision(*before)),
        by_rule=[
            RuleCount(
                rule=key,
                rule_title=RULES[key].title if key in RULES else key,
                detected=detected,
                confirmed=yes,
                false_positive=no,
            )
            for key, detected, yes, no in sorted(
                await fraud.detected_by_rule(period.since, period.until),
                key=lambda counts: -counts[1],
            )
        ],
    )


# -------------------------------------------------------------------- rules
def _rule(state: Any) -> FraudRuleResponse:
    return FraudRuleResponse(
        key=state.key,
        title=state.title,
        threshold_means=state.threshold_means,
        enabled=state.enabled,
        threshold=state.threshold,
        window_minutes=state.window_minutes,
        severity=state.severity,
        changed=state.changed,
        updated_by=state.updated_by,
        updated_at=state.updated_at,
    )


@router.get("/fraud/rules", response_model=list[FraudRuleResponse], dependencies=_MANAGE)
async def list_fraud_rules(db: DbSession) -> list[FraudRuleResponse]:
    """Every rule, with its threshold, time window, severity and whether it
    runs."""
    return [_rule(state) for state in await FraudService(db).rules()]


@router.patch("/fraud/rules/{rule}", response_model=FraudRuleResponse, dependencies=_MANAGE)
async def update_fraud_rule(
    rule: str, body: FraudRuleUpdateRequest, db: DbSession, principal: CurrentPrincipal
) -> FraudRuleResponse:
    """Change a rule's threshold, time window, severity, or turn it off.
    Applies from the next detection run."""
    state = await FraudService(db).update_rule(
        rule,
        enabled=body.enabled,
        threshold=body.threshold,
        window_minutes=body.window_minutes,
        severity=body.severity,
        by=principal.user_id,
    )
    return _rule(state)


@router.post("/fraud/scan", response_model=DetectionRunResponse, dependencies=_MANAGE)
async def run_fraud_detection(db: DbSession) -> DetectionRunResponse:
    """Run the detection now, rather than waiting for the next scheduled run
    (every 15 minutes): after changing a rule, say. 409 while a run is
    already going."""
    lock = RedisLock(get_redis_client(), DETECTION_LOCK, ttl_seconds=DETECTION_LOCK_SECONDS)
    if not await lock.acquire():
        raise ConflictError("A fraud detection run is already going.", code="DETECTION_RUNNING")
    try:
        result = await FraudService(db).detect()
    finally:
        await lock.release()
    return DetectionRunResponse(
        raised=result.raised, updated=result.updated, by_rule=result.by_rule
    )
