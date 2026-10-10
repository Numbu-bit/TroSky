"""Automatic audit trail for admin actions.

Every mutating request under ``/admin`` runs with an ``AuditContext`` (set
by the ``audit_admin_requests`` router dependency). While it is set, each
flush of the request's database session adds one ``AuditLog`` row per row it
inserted, changed or deleted -- which columns, from what, to what -- to the
same transaction. The audit rows share their changes' fate: a request that
fails is rolled back with its audit (nothing happened), and so is a
savepoint. A request that changed nothing still gets one row when it
commits, so every admin action is on record.

Done at the session rather than in each endpoint so no admin action can be
added later and forgotten: if it writes, it is recorded. Bulk ``UPDATE`` and
``DELETE`` statements change rows without loading them, so their rows are
not itemised; the request is still on record.
"""

from __future__ import annotations

import enum
import uuid
from collections.abc import AsyncIterator
from contextvars import ContextVar
from dataclasses import dataclass, field
from datetime import date, datetime
from decimal import Decimal
from typing import Any

from fastapi import Request
from sqlalchemy import event, inspect
from sqlalchemy.orm import Session, UOWTransaction

from app.core.client_ip import resolve_client_ip
from app.core.config import get_settings
from app.models.admin import AuditLog

# Never written to the audit trail.
_SECRET_COLUMNS = frozenset(
    {"password_hash", "code_hash", "token_hash", "refresh_token_hash", "secret"}
)
# Bookkeeping that changes on every update and says nothing about the action.
_NOISE_COLUMNS = frozenset({"updated_at", "version"})
# Tables that only echo a change already recorded on its own row.
_SKIPPED_TABLES = frozenset(
    {
        "audit_logs",
        "booking_status_history",
        "trip_status_history",
        "driver_status_history",
        "vehicle_status_history",
        "trip_events",
    }
)
# Body fields an admin explains themselves in, most specific first.
_REASON_FIELDS = ("reason", "rejection_reason", "notes", "decision_notes", "resolution_notes")


@dataclass
class AuditContext:
    request: Request
    action: str
    method: str
    path: str
    ip_address: str | None
    user_agent: str | None
    request_id: str | None
    reason: str | None = None
    rows: list[AuditLog] = field(default_factory=list)


_context: ContextVar[AuditContext | None] = ContextVar("audit_context", default=None)
_SESSION_KEY = "trosky.audit"


def attach_to_session(session: Session) -> None:
    """Make ``session`` record changes for the admin request in progress,
    if there is one. Called by ``get_db`` as it opens the request's session,
    so only that session is audited -- never one a background job opens
    while the request runs."""
    context = _context.get()
    if context is not None:
        session.info[_SESSION_KEY] = context


def _json(value: Any) -> Any:
    if value is None or isinstance(value, bool | int | float | str):
        return value
    if isinstance(value, uuid.UUID | Decimal):
        return str(value)
    if isinstance(value, datetime | date):
        return value.isoformat()
    if isinstance(value, enum.Enum):
        return value.value
    if isinstance(value, list | tuple):
        return [_json(item) for item in value]
    if isinstance(value, dict):
        return {str(k): _json(v) for k, v in value.items()}
    # Geometry, bytes and the like: noted, not copied.
    return f"<{type(value).__name__}>"


def _columns(obj: Any) -> list[str]:
    return [
        attr.key
        for attr in inspect(obj).mapper.column_attrs
        if attr.key not in _SECRET_COLUMNS and attr.key not in _NOISE_COLUMNS
    ]


def _identity(obj: Any) -> str | None:
    state = inspect(obj)
    # A row inserted by this flush has no identity key until the flush is
    # finalised, after ``after_flush``; its primary key is set already.
    key = state.identity or tuple(state.mapper.primary_key_from_instance(obj))
    if all(part is None for part in key):
        return None
    return ",".join(str(part) for part in key)


def _changes(
    session: Session,
) -> list[tuple[str, str | None, dict[str, Any] | None, dict[str, Any] | None]]:
    """What each new, changed or deleted row looked like before and after.
    Read in ``after_flush``: ids are assigned and the flush's history is
    still there."""
    changes: list[tuple[str, str | None, dict[str, Any] | None, dict[str, Any] | None]] = []
    for obj in session.new:
        table = obj.__tablename__
        if table in _SKIPPED_TABLES:
            continue
        after = {key: _json(getattr(obj, key)) for key in _columns(obj)}
        changes.append((table, _identity(obj), None, after))
    for obj in session.dirty:
        table = obj.__tablename__
        if table in _SKIPPED_TABLES or not session.is_modified(obj, include_collections=False):
            continue
        state = inspect(obj)
        before: dict[str, Any] = {}
        after = {}
        for key in _columns(obj):
            history = state.attrs[key].history
            if history.has_changes():
                before[key] = _json(history.deleted[0]) if history.deleted else None
                after[key] = _json(history.added[0]) if history.added else None
        if after:
            changes.append((table, _identity(obj), before, after))
    for obj in session.deleted:
        table = obj.__tablename__
        if table in _SKIPPED_TABLES:
            continue
        before = {key: _json(getattr(obj, key)) for key in _columns(obj)}
        changes.append((table, _identity(obj), before, None))
    return changes


def _actor(request: Request) -> uuid.UUID | None:
    # Set by authentication, which writes nothing and runs before anything
    # else in the request does.
    principal = getattr(request.state, "principal", None)
    return getattr(principal, "user_id", None)


def _add_row(
    session: Session,
    context: AuditContext,
    entity_type: str,
    entity_id: str | None,
    before: dict[str, Any] | None,
    after: dict[str, Any] | None,
) -> None:
    row = AuditLog(
        actor_user_id=_actor(context.request),
        action=context.action,
        method=context.method,
        path=context.path[:300],
        entity_type=entity_type[:60],
        entity_id=entity_id[:100] if entity_id else None,
        before=before,
        after=after,
        reason=context.reason[:1000] if context.reason else None,
        ip_address=context.ip_address,
        user_agent=context.user_agent[:500] if context.user_agent else None,
        request_id=context.request_id,
    )
    context.rows.append(row)
    session.add(row)


def _record(session: Session, flush_context: UOWTransaction) -> None:
    """After each flush: an audit row for every row it wrote, added to the
    session for the next flush (at the latest, the commit's). Rows recorded
    inside a savepoint that is rolled back are discarded with it."""
    context: AuditContext | None = session.info.get(_SESSION_KEY)
    if context is None:
        return
    for entity_type, entity_id, before, after in _changes(session):
        _add_row(session, context, entity_type, entity_id, before, after)


def _kept(row: AuditLog) -> bool:
    state = inspect(row)
    return state.pending or state.persistent


def _record_request(session: Session) -> None:
    """Before the request's commit: a request that changed nothing (or whose
    changes were all undone) is still on record, as one row. Releasing a
    savepoint fires this event too; that is not the request's commit."""
    context: AuditContext | None = session.info.get(_SESSION_KEY)
    if context is None or session.in_nested_transaction():
        return
    if not any(_kept(row) for row in context.rows):
        _add_row(session, context, "request", None, None, None)


event.listen(Session, "after_flush", _record)
event.listen(Session, "before_commit", _record_request)


async def _reason(request: Request) -> str | None:
    if "json" not in request.headers.get("content-type", ""):
        return None
    try:
        body = await request.json()
    except ValueError:
        return None
    if not isinstance(body, dict):
        return None
    for name in _REASON_FIELDS:
        value = body.get(name)
        if isinstance(value, str) and value.strip():
            return value.strip()
    return None


async def audit_admin_requests(request: Request) -> AsyncIterator[None]:
    """Router dependency: record what this admin request changes. Reads
    pass straight through.

    Deliberately depends on nothing that opens the database session: as the
    first dependency resolved, it sets the context before ``get_db`` opens
    the session that carries it. (Asking for the principal here would open
    the session first, without the context.) The actor is read from the
    request when the rows are written, after authentication has run."""
    if request.method in ("GET", "HEAD", "OPTIONS"):
        yield
        return
    route = request.scope.get("route")
    context = AuditContext(
        request=request,
        action=getattr(route, "name", None) or request.url.path,
        method=request.method,
        path=getattr(route, "path", None) or request.url.path,
        ip_address=resolve_client_ip(request, get_settings().trusted_proxy_networks),
        user_agent=request.headers.get("user-agent"),
        request_id=getattr(request.state, "request_id", None),
        reason=await _reason(request),
    )
    token = _context.set(context)
    try:
        yield
    finally:
        _context.reset(token)
