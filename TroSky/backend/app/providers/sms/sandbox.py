"""Sandbox SMS provider: captures sent messages in memory for tests.

Never makes a network call. Tests exercising OTP flows use
:meth:`SandboxSmsProvider.get_sent_messages` to retrieve the message body
(and therefore the plaintext OTP code) without ever touching a real vendor.
"""

from __future__ import annotations

import uuid
from collections import defaultdict
from typing import ClassVar

from app.providers.sms.base import SmsSendResult


class SandboxSmsProvider:
    """Process-wide in-memory SMS outbox. State is a class variable so a
    provider instantiated inside a service and inspected from a test both
    see the same outbox without needing to share an instance."""

    _outbox: ClassVar[dict[str, list[str]]] = defaultdict(list)

    async def send_sms(self, to: str, message: str) -> SmsSendResult:
        self._outbox[to].append(message)
        return SmsSendResult(success=True, provider_reference=f"sandbox-{uuid.uuid4().hex[:12]}")

    @classmethod
    def get_sent_messages(cls, to: str) -> list[str]:
        return list(cls._outbox.get(to, []))

    @classmethod
    def get_last_message(cls, to: str) -> str | None:
        messages = cls._outbox.get(to)
        return messages[-1] if messages else None

    @classmethod
    def clear(cls) -> None:
        cls._outbox.clear()
