"""The audit listener on its own: what it notes for the rows an admin
request adds, changes and removes -- and what it leaves out.

The context is attached to the test session by hand, the way ``get_db``
attaches it; ``_commit`` does what the request's commit does.
"""

from __future__ import annotations

import uuid
from collections.abc import Iterator
from contextlib import contextmanager
from datetime import UTC, datetime
from types import SimpleNamespace
from typing import cast

import pytest
from fastapi import Request
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.audit import _SESSION_KEY, AuditContext, _record_request
from app.models.admin import AuditLog, SystemSetting

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]


@contextmanager
def _admin_request(session: AsyncSession, actor_id: uuid.UUID) -> Iterator[AuditContext]:
    request = SimpleNamespace(state=SimpleNamespace(principal=SimpleNamespace(user_id=actor_id)))
    context = AuditContext(
        request=cast(Request, request),
        action="test_action",
        method="POST",
        path="/api/v1/admin/test",
        ip_address="10.0.0.7",
        user_agent="pytest",
        request_id=f"req-{uuid.uuid4()}",
        reason="Checking the audit trail",
    )
    session.sync_session.info[_SESSION_KEY] = context
    try:
        yield context
    finally:
        session.sync_session.info.pop(_SESSION_KEY, None)


async def _commit(session: AsyncSession, context: AuditContext) -> list[AuditLog]:
    """What the request's commit does (the test's transaction is rolled
    back instead): the last audit rows, then a flush."""
    _record_request(session.sync_session)
    await session.flush()
    result = await session.execute(
        select(AuditLog).where(AuditLog.request_id == context.request_id)
    )
    return list(result.scalars())


def _setting() -> SystemSetting:
    return SystemSetting(key=f"test_{uuid.uuid4().hex[:8]}", value=7)


async def _insert_in_a_savepoint_then_fail(session: AsyncSession, row: SystemSetting) -> None:
    async with session.begin_nested():
        session.add(row)
        await session.flush()
        raise RuntimeError("lost the race")


class TestWhatIsRecorded:
    async def test_added_changed_and_removed_rows(
        self, db_session: AsyncSession, make_user
    ) -> None:
        actor, target = await make_user(), await make_user()
        removed = _setting()
        db_session.add(removed)
        await db_session.flush()

        with _admin_request(db_session, actor.id) as context:
            added = await make_user()
            target.is_suspended = True
            target.updated_at = datetime.now(UTC)
            await db_session.delete(removed)
            await db_session.flush()
            rows = await _commit(db_session, context)

        by_row = {(row.entity_type, row.entity_id): row for row in rows}
        insert = by_row[("users", str(added.id))]
        update = by_row[("users", str(target.id))]
        delete = by_row[("system_settings", removed.key)]
        assert insert.before is None
        assert insert.after is not None
        assert insert.after["phone_number"] == added.phone_number
        assert "password_hash" not in insert.after
        # Only what changed; the timestamp moves on every update and says nothing.
        assert (update.before, update.after) == ({"is_suspended": False}, {"is_suspended": True})
        assert delete.before is not None
        assert (delete.before["value"], delete.after) == (7, None)
        assert ("request", None) not in by_row
        assert {(r.actor_user_id, r.action, r.reason, r.ip_address) for r in rows} == {
            (actor.id, "test_action", "Checking the audit trail", "10.0.0.7")
        }

    async def test_a_request_that_changed_nothing_is_one_row(
        self, db_session: AsyncSession, make_user
    ) -> None:
        actor = await make_user()

        with _admin_request(db_session, actor.id) as context:
            rows = await _commit(db_session, context)

        [row] = rows
        assert (row.entity_type, row.entity_id, row.before, row.after) == (
            "request",
            None,
            None,
            None,
        )

    async def test_a_session_without_an_admin_request_records_nothing(
        self, db_session: AsyncSession, make_user
    ) -> None:
        user = await make_user()
        user.is_suspended = True
        await db_session.flush()

        _record_request(db_session.sync_session)
        await db_session.flush()

        found = await db_session.scalar(
            select(AuditLog.id).where(AuditLog.entity_id == str(user.id))
        )
        assert found is None


class TestSavepoints:
    """Repositories insert inside a savepoint to survive a lost race (the
    wallet, a booking's seat). Releasing one is not the request's commit."""

    async def test_changes_on_both_sides_of_a_released_savepoint(
        self, db_session: AsyncSession, make_user
    ) -> None:
        actor = await make_user()
        inside, after = _setting(), _setting()

        with _admin_request(db_session, actor.id) as context:
            async with db_session.begin_nested():
                pass  # released with nothing recorded yet
            async with db_session.begin_nested():
                db_session.add(inside)
                await db_session.flush()
            db_session.add(after)
            await db_session.flush()
            rows = await _commit(db_session, context)

        recorded = {row.entity_id for row in rows if row.entity_type == "system_settings"}
        assert recorded == {inside.key, after.key}
        assert all(row.entity_type != "request" for row in rows)

    async def test_a_rolled_back_savepoint_takes_its_audit_rows_with_it(
        self, db_session: AsyncSession, make_user
    ) -> None:
        actor = await make_user()
        undone = _setting()

        with _admin_request(db_session, actor.id) as context:
            with pytest.raises(RuntimeError):
                await _insert_in_a_savepoint_then_fail(db_session, undone)
            rows = await _commit(db_session, context)

        # Nothing happened, so the request is on record as having changed nothing.
        assert [(row.entity_type, row.entity_id) for row in rows] == [("request", None)]
