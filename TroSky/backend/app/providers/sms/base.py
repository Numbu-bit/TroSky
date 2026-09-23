"""SMS provider interface.

Every SMS-sending code path (OTP delivery, SOS alerts, transactional
notifications) goes through this interface — never directly through an
HTTP client — so the active provider can be swapped via configuration and
tests never touch a real vendor.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Protocol


@dataclass(frozen=True, slots=True)
class SmsSendResult:
    success: bool
    provider_reference: str | None
    error: str | None = None


class SmsProvider(Protocol):
    """Interface every SMS provider adapter implements."""

    async def send_sms(self, to: str, message: str) -> SmsSendResult:
        """Send ``message`` to ``to`` (E.164). Must never raise for an
        expected provider-side failure — return a failed :class:`SmsSendResult`
        instead; only raise :class:`app.core.exceptions.ProviderError` for
        transport-level failures the caller cannot otherwise interpret."""
        ...
