"""Amazon SES email provider, via boto3's official SES client.

# PRODUCTION CREDENTIALS REQUIRED
Uses boto3's standard credential resolution (environment variables,
IAM role, or shared credentials file) — no credentials are read directly
from application settings. The sending identity (``EMAIL_FROM_ADDRESS``)
must be a verified SES sender/domain in the target AWS account and region;
see https://docs.aws.amazon.com/ses/latest/dg/verify-addresses-and-domains.html.
"""

from __future__ import annotations

import asyncio
from typing import Any

import boto3
from botocore.exceptions import BotoCoreError, ClientError

from app.core.config import Settings
from app.core.exceptions import ProviderError
from app.core.logging import get_logger
from app.providers.email.base import EmailSendResult

logger = get_logger(__name__)


class SesEmailProvider:
    def __init__(self, settings: Settings, region_name: str = "eu-west-1") -> None:
        self._from_address = settings.EMAIL_FROM_ADDRESS
        self._client: Any = boto3.client("ses", region_name=region_name)

    def _send_sync(self, to: str, subject: str, body_text: str, body_html: str | None) -> str:
        body: dict[str, Any] = {"Text": {"Data": body_text, "Charset": "UTF-8"}}
        if body_html:
            body["Html"] = {"Data": body_html, "Charset": "UTF-8"}
        response = self._client.send_email(
            Source=self._from_address,
            Destination={"ToAddresses": [to]},
            Message={"Subject": {"Data": subject, "Charset": "UTF-8"}, "Body": body},
        )
        return str(response["MessageId"])

    async def send_email(
        self, to: str, subject: str, body_text: str, body_html: str | None = None
    ) -> EmailSendResult:
        try:
            message_id = await asyncio.to_thread(self._send_sync, to, subject, body_text, body_html)
        except (BotoCoreError, ClientError) as exc:
            logger.error("ses_send_failed", to=to, error=str(exc))
            raise ProviderError("Failed to send email via SES.") from exc
        return EmailSendResult(success=True, provider_reference=message_id)
