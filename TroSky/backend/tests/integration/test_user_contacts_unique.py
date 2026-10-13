"""Phone numbers and emails are unique among accounts that are not deleted,
enforced by the database itself (sign-up's own check can lose a race)."""

from __future__ import annotations

import secrets

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.identity import User
from app.repositories.user_repository import DuplicateUserError, UserRepository

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]


def _phone() -> str:
    return f"+23324{secrets.randbelow(10**7):07d}"


def _email() -> str:
    return f"ama.{secrets.token_hex(4)}@example.com"


async def _create(users: UserRepository, phone: str, email: str | None) -> User:
    return await users.create(
        phone_number=phone, email=email, password_hash="x", full_name="Ama Owusu"
    )


async def test_two_live_accounts_cannot_share_a_number(db_session: AsyncSession) -> None:
    users = UserRepository(db_session)
    phone = _phone()
    await _create(users, phone, None)

    with pytest.raises(DuplicateUserError) as raised:
        await _create(users, phone, None)

    assert raised.value.field == "phone number"


async def test_or_an_email_whatever_its_case(db_session: AsyncSession) -> None:
    users = UserRepository(db_session)
    email = _email()
    await _create(users, _phone(), email)

    with pytest.raises(DuplicateUserError) as raised:
        await _create(users, _phone(), email.upper())

    assert raised.value.field == "email"


async def test_a_deleted_accounts_number_and_email_are_free(db_session: AsyncSession) -> None:
    users = UserRepository(db_session)
    phone, email = _phone(), _email()
    gone = await _create(users, phone, email)
    await users.soft_delete(gone)

    again = await _create(users, phone, email)

    assert await users.get_by_phone(phone) is again
    assert await users.get_by_email(email) is again
