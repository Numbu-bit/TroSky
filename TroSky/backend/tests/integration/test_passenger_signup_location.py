"""Passengers sign up from where TroSky runs: they share the phone's
location, and it must be in Ghana. They then verify their email with the
code sent to it before signing in, like every account."""

from __future__ import annotations

import pytest
from redis.asyncio import Redis
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.exceptions import AccountNotVerifiedError, ValidationAppError
from app.models.identity import OtpPurpose
from app.providers.email.sandbox import SandboxEmailProvider
from app.providers.sms.sandbox import SandboxSmsProvider
from app.schemas.auth import RegisterRequest
from app.services.auth_service import AuthService

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]

_PHONE = "0241234567"
_EMAIL = "ama.mensah@gmail.com"
_ACCRA = (5.6037, -0.1870)
_LAGOS = (6.52, 3.38)


@pytest.fixture(autouse=True)
def _clear_sandbox_outboxes():
    SandboxSmsProvider.clear()
    SandboxEmailProvider.clear()
    yield
    SandboxSmsProvider.clear()
    SandboxEmailProvider.clear()


def _service(db_session: AsyncSession, redis: Redis, **changes: object) -> AuthService:
    """As production: codes by email, verification on, passengers from Ghana."""
    settings = get_settings().model_copy(
        update={
            "OTP_DELIVERY_CHANNEL": "email",
            "REQUIRE_VERIFIED_ACCOUNT": True,
            "PASSENGER_SIGNUP_COUNTRIES": "GH",
            **changes,
        }
    )
    return AuthService(db_session, redis, SandboxSmsProvider(), SandboxEmailProvider(), settings)


def _signup(role: str = "passenger", where: tuple[float, float] | None = _ACCRA) -> RegisterRequest:
    return RegisterRequest(
        phone_number=_PHONE,
        email=_EMAIL,
        password="Str0ngPass",
        full_name="Ama Mensah",
        role=role,
        latitude=where[0] if where else None,
        longitude=where[1] if where else None,
    )


async def _redis(require_redis: None) -> Redis:
    from app.core.redis import get_redis_client

    return get_redis_client()


def _emailed_code() -> str:
    sent = SandboxEmailProvider.get_last_email(_EMAIL)
    assert sent is not None, "no code was emailed"
    return "".join(filter(str.isdigit, sent.body_text.split("is ")[1].split(".")[0]))


async def test_a_passenger_must_share_their_location(
    db_session: AsyncSession, seeded_roles, require_redis: None
) -> None:
    service = _service(db_session, await _redis(require_redis))
    with pytest.raises(ValidationAppError) as raised:
        await service.register(_signup(where=None))
    assert raised.value.code == "LOCATION_REQUIRED"
    assert "Ghana" in raised.value.message


async def test_a_passenger_outside_ghana_is_turned_away(
    db_session: AsyncSession, seeded_roles, require_redis: None
) -> None:
    service = _service(db_session, await _redis(require_redis))
    with pytest.raises(ValidationAppError) as raised:
        await service.register(_signup(where=_LAGOS))
    assert raised.value.code == "LOCATION_NOT_SERVED"
    # Nothing was created, and no code went out.
    assert SandboxEmailProvider.get_sent_emails(_EMAIL) == []


async def test_a_passenger_in_ghana_verifies_their_email_then_signs_in(
    db_session: AsyncSession, seeded_roles, require_redis: None
) -> None:
    service = _service(db_session, await _redis(require_redis))
    _, otp_target = await service.register(_signup())
    assert otp_target == _EMAIL

    # Not before entering the code sent to their email...
    with pytest.raises(AccountNotVerifiedError):
        await service.login_password(_PHONE, "Str0ngPass", None, None)

    # ...and straight in after.
    verified = await service.verify_otp(_EMAIL, OtpPurpose.REGISTRATION, _emailed_code())
    assert verified is not None
    assert verified.email_verified_at is not None
    tokens = await service.login_password(_PHONE, "Str0ngPass", None, None)
    assert tokens.access_token


async def test_drivers_need_no_location(
    db_session: AsyncSession, seeded_roles, require_redis: None
) -> None:
    service = _service(db_session, await _redis(require_redis))
    user, _ = await service.register(_signup(role="driver", where=None))
    assert user.id is not None


async def test_the_check_can_be_switched_off(
    db_session: AsyncSession, seeded_roles, require_redis: None
) -> None:
    service = _service(db_session, await _redis(require_redis), PASSENGER_SIGNUP_COUNTRIES="")
    user, _ = await service.register(_signup(where=None))
    assert user.id is not None


async def test_latitude_and_longitude_come_together() -> None:
    with pytest.raises(ValueError, match="both latitude and longitude"):
        RegisterRequest(
            phone_number=_PHONE,
            email=_EMAIL,
            password="Str0ngPass",
            full_name="Ama Mensah",
            latitude=5.6,
        )
