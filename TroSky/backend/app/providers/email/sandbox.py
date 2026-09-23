"""Sandbox email provider: captures sent emails in memory for tests."""

from __future__ import annotations

import uuid
from collections import defaultdict
from dataclasses import dataclass
from typing import ClassVar

from app.providers.email.base import EmailSendResult


@dataclass(frozen=True, slots=True)
class SentEmail:
    subject: str
    body_text: str
    body_html: str | None


class SandboxEmailProvider:
    """Process-wide in-memory email outbox, mirroring :class:`SandboxSmsProvider`."""

    _outbox: ClassVar[dict[str, list[SentEmail]]] = defaultdict(list)

    async def send_email(
        self, to: str, subject: str, body_text: str, body_html: str | None = None
    ) -> EmailSendResult:
        self._outbox[to].append(
            SentEmail(subject=subject, body_text=body_text, body_html=body_html)
        )
        return EmailSendResult(success=True, provider_reference=f"sandbox-{uuid.uuid4().hex[:12]}")

    @classmethod
    def get_sent_emails(cls, to: str) -> list[SentEmail]:
        return list(cls._outbox.get(to, []))

    @classmethod
    def get_last_email(cls, to: str) -> SentEmail | None:
        emails = cls._outbox.get(to)
        return emails[-1] if emails else None

    @classmethod
    def clear(cls) -> None:
        cls._outbox.clear()
