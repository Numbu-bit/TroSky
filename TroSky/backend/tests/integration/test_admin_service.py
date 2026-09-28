"""Integration tests for AdminService: listing, suspending (which also
revokes all outstanding sessions), and reactivating user accounts —
against a real Postgres."""

from __future__ import annotations

import uuid

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.repositories.session_repository import SessionRepository
from app.repositories.user_repository import UserRepository
from app.services.admin_service import AdminService

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]


async def _make_user(session: AsyncSession, phone: str):
    return await UserRepository(session).create(
        phone_number=phone,
        email=None,
        password_hash="not-a-real-hash",
        full_name="Test User",
    )


class TestListUsers:
    async def test_list_users_finds_by_phone_search(self, db_session: AsyncSession) -> None:
        user = await _make_user(db_session, "0571199901")
        service = AdminService(db_session)
        users, total = await service.list_users(search="0571199901", limit=10, offset=0)
        assert total == 1
        assert users[0].id == user.id

    @pytest.mark.parametrize("search", ["0571199903", "057 119 9903", "057-119-9903", "0571199"])
    async def test_a_registered_number_is_found_by_its_local_form(
        self, db_session: AsyncSession, search: str
    ) -> None:
        # Registration stores numbers in international form.
        user = await _make_user(db_session, "+233571199903")
        users, total = await AdminService(db_session).list_users(search=search, limit=10, offset=0)
        assert total == 1
        assert users[0].id == user.id


class TestSuspendReactivate:
    async def test_suspend_sets_flag_and_revokes_sessions(self, db_session: AsyncSession) -> None:
        user = await _make_user(db_session, "0571199902")
        session_record = await SessionRepository(db_session).create_session(
            user_id=user.id, device_id=None, device_name=None, ip_address=None, user_agent=None
        )

        service = AdminService(db_session)
        suspended = await service.suspend_user(
            user.id, reason="Fraud investigation", actioned_by=uuid.uuid4()
        )
        assert suspended.is_suspended is True
        assert suspended.suspended_reason == "Fraud investigation"

        active = await SessionRepository(db_session).get_active_session(session_record.id)
        assert active is None

    async def test_reactivate_clears_suspension(self, db_session: AsyncSession) -> None:
        user = await _make_user(db_session, "0571199903")
        service = AdminService(db_session)
        await service.suspend_user(user.id, reason="x", actioned_by=uuid.uuid4())
        reactivated = await service.reactivate_user(user.id, actioned_by=uuid.uuid4())
        assert reactivated.is_suspended is False
        assert reactivated.suspended_reason is None
