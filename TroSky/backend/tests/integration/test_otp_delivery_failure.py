"""A code the email or SMS provider refused to send is reported, not taken
as sent: the person is told, and may ask again at once."""

from __future__ import annotations

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ProviderError
from app.core.redis import get_redis_client
from app.models.identity import OtpChannel, OtpPurpose
from app.providers.email.base import EmailSendResult
from app.providers.email.sandbox import SandboxEmailProvider
from app.providers.sms.sandbox import SandboxSmsProvider
from app.services.otp_service import OtpService

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]

_ADDRESS = "ama.mensah@gmail.com"


class _RefusingEmail:
    """As Brevo answers with a sender that is not verified yet."""

    async def send_email(
        self, to: str, subject: str, body_text: str, body_html: str | None = None
    ) -> EmailSendResult:
        return EmailSendResult(
            success=False, provider_reference=None, error="Brevo refused it (HTTP 400)"
        )


async def test_a_refused_code_is_reported_and_can_be_asked_for_again(
    db_session: AsyncSession, require_redis: None
) -> None:
    redis = get_redis_client()
    refusing = OtpService(db_session, redis, SandboxSmsProvider(), _RefusingEmail())

    with pytest.raises(ProviderError, match="could not be sent by email"):
        await refusing.request_otp(
            target=_ADDRESS, channel=OtpChannel.EMAIL, purpose=OtpPurpose.REGISTRATION
        )

    # No cooldown to wait out: nothing reached the person.
    working = OtpService(db_session, redis, SandboxSmsProvider(), SandboxEmailProvider())
    challenge = await working.request_otp(
        target=_ADDRESS, channel=OtpChannel.EMAIL, purpose=OtpPurpose.REGISTRATION
    )
    assert challenge.target == _ADDRESS
