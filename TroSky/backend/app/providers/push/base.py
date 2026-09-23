"""Push notification provider interface."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Protocol


@dataclass(frozen=True, slots=True)
class PushSendResult:
    success: bool
    provider_message_id: str | None = None
    error: str | None = None


class PushProvider(Protocol):
    async def send(
        self, *, token: str, title: str, body: str, data: dict[str, Any]
    ) -> PushSendResult:
        """Send a push notification to a single device token. Must never
        raise for an expected provider-side failure (an invalid/expired
        token, the device unregistered) — return a failed
        :class:`PushSendResult` instead; only raise
        :class:`app.core.exceptions.ProviderError` for transport-level
        failures the caller cannot otherwise interpret."""
        ...
