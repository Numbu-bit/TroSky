"""Sandbox push provider: captures sent pushes in memory for tests.

Never makes a network call — mirrors ``SandboxSmsProvider``'s process-wide
outbox pattern exactly.
"""

from __future__ import annotations

import uuid
from collections import defaultdict
from typing import Any, ClassVar

from app.providers.push.base import PushSendResult


class SandboxPushProvider:
    _outbox: ClassVar[dict[str, list[dict[str, Any]]]] = defaultdict(list)

    async def send(
        self, *, token: str, title: str, body: str, data: dict[str, Any]
    ) -> PushSendResult:
        self._outbox[token].append({"title": title, "body": body, "data": data})
        return PushSendResult(success=True, provider_message_id=f"sandbox-{uuid.uuid4().hex[:12]}")

    @classmethod
    def get_sent(cls, token: str) -> list[dict[str, Any]]:
        return list(cls._outbox.get(token, []))

    @classmethod
    def clear(cls) -> None:
        cls._outbox.clear()
