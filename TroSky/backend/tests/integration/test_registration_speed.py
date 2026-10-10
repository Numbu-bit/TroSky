"""A new account's code goes out early in registration: every database round
trip before it is time the person spends waiting for their code (each is
~0.15 s to the hosted database from Accra). Guarded here so a later change
cannot quietly push the code back behind more work."""

from __future__ import annotations

import secrets

import pytest
from sqlalchemy import event
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.redis import get_redis_client
from app.providers.email.sandbox import SandboxEmailProvider
from app.providers.sms.base import SmsSendResult
from app.schemas.auth import RegisterRequest
from app.services.auth_service import AuthService

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]


async def test_the_code_goes_out_after_three_statements(
    db_session: AsyncSession, seeded_roles: dict[str, object], require_redis: None
) -> None:
    happened: list[str] = []

    class Recorder:
        async def send_sms(self, to: str, message: str) -> SmsSendResult:
            happened.append("code sent")
            return SmsSendResult(success=True, provider_reference="recorded")

    connection = (await db_session.connection()).sync_connection
    assert connection is not None

    def statement(*_: object) -> None:
        happened.append("statement")

    event.listen(connection, "before_cursor_execute", statement)
    try:
        await AuthService(
            db_session, get_redis_client(), Recorder(), SandboxEmailProvider()
        ).register(
            RegisterRequest(
                phone_number=f"024{secrets.randbelow(10**7):07d}",
                password="Str0ng-Passw0rd!",
                full_name="Ama Mensah",
            )
        )
    finally:
        event.remove(connection, "before_cursor_execute", statement)

    # The contact check, then the account and its profile; the role and the
    # preferences come after.
    assert happened.index("code sent") <= 3
    assert happened.count("statement") > 3
