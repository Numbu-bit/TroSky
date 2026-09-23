"""Console email provider: logs the message instead of sending it."""

from __future__ import annotations

import uuid

from app.core.logging import get_logger
from app.providers.email.base import EmailSendResult

logger = get_logger(__name__)


class ConsoleEmailProvider:
    async def send_email(
        self, to: str, subject: str, body_text: str, body_html: str | None = None
    ) -> EmailSendResult:
        reference = f"console-{uuid.uuid4().hex[:12]}"
        logger.info(
            "email_sent_console",
            to=to,
            subject=subject,
            body_text=body_text,
            provider_reference=reference,
        )
        return EmailSendResult(success=True, provider_reference=reference)
