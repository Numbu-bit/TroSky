"""Console SMS provider: logs the message instead of sending it.

Used for local development (``SMS_PROVIDER=console``) so OTPs and alerts are
visible in the API container's logs without any external dependency.
"""

from __future__ import annotations

import uuid

from app.core.logging import get_logger
from app.providers.sms.base import SmsSendResult

logger = get_logger(__name__)


class ConsoleSmsProvider:
    async def send_sms(self, to: str, message: str) -> SmsSendResult:
        reference = f"console-{uuid.uuid4().hex[:12]}"
        logger.info("sms_sent_console", to=to, message=message, provider_reference=reference)
        return SmsSendResult(success=True, provider_reference=reference)
