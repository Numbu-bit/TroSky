"""Email provider interface."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Protocol


@dataclass(frozen=True, slots=True)
class EmailSendResult:
    success: bool
    provider_reference: str | None
    error: str | None = None


class EmailProvider(Protocol):
    """Interface every email provider adapter implements."""

    async def send_email(
        self, to: str, subject: str, body_text: str, body_html: str | None = None
    ) -> EmailSendResult:
        """Send an email. Must never raise for an expected provider-side
        failure — return a failed :class:`EmailSendResult` instead."""
        ...
