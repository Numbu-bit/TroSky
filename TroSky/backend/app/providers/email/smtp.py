"""SMTP email provider.

Uses the standard SMTP protocol (RFC 5321), so this single adapter is
genuinely production-capable against MailHog locally *and* against any real
SMTP relay in production (Amazon SES's SMTP interface, SendGrid, Postmark,
Mailgun, etc.) — no vendor-specific API guessing required.

# PRODUCTION CREDENTIALS REQUIRED
Set EMAIL_SMTP_HOST / EMAIL_SMTP_PORT / EMAIL_SMTP_USERNAME /
EMAIL_SMTP_PASSWORD / EMAIL_SMTP_USE_TLS to your provider's SMTP relay
credentials.
"""

from __future__ import annotations

import asyncio
import smtplib
import uuid
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

from app.core.config import Settings
from app.core.exceptions import ProviderError
from app.core.logging import get_logger
from app.providers.email.base import EmailSendResult

logger = get_logger(__name__)


class SmtpEmailProvider:
    def __init__(self, settings: Settings) -> None:
        self._host = settings.EMAIL_SMTP_HOST
        self._port = settings.EMAIL_SMTP_PORT
        self._username = settings.EMAIL_SMTP_USERNAME
        self._password = settings.EMAIL_SMTP_PASSWORD.get_secret_value()
        self._use_tls = settings.EMAIL_SMTP_USE_TLS
        self._from_address = settings.EMAIL_FROM_ADDRESS

    def _send_sync(self, to: str, subject: str, body_text: str, body_html: str | None) -> str:
        message: MIMEMultipart | MIMEText
        if body_html:
            message = MIMEMultipart("alternative")
            message.attach(MIMEText(body_text, "plain", "utf-8"))
            message.attach(MIMEText(body_html, "html", "utf-8"))
        else:
            message = MIMEText(body_text, "plain", "utf-8")
        message["Subject"] = subject
        message["From"] = self._from_address
        message["To"] = to
        message_id = f"<{uuid.uuid4().hex}@trosky.africa>"
        message["Message-ID"] = message_id

        with smtplib.SMTP(self._host, self._port, timeout=10) as client:
            if self._use_tls:
                client.starttls()
            if self._username and self._password:
                client.login(self._username, self._password)
            client.sendmail(self._from_address, [to], message.as_string())
        return message_id

    async def send_email(
        self, to: str, subject: str, body_text: str, body_html: str | None = None
    ) -> EmailSendResult:
        try:
            message_id = await asyncio.to_thread(self._send_sync, to, subject, body_text, body_html)
        except (OSError, smtplib.SMTPException) as exc:
            logger.error("smtp_send_failed", to=to, error=str(exc))
            raise ProviderError("Failed to send email via SMTP.") from exc
        return EmailSendResult(success=True, provider_reference=message_id)
