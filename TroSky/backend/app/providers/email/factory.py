"""Email provider factory: resolves the configured provider by name."""

from __future__ import annotations

from app.core.config import EmailProviderName, Settings, get_settings
from app.providers.email.base import EmailProvider
from app.providers.email.console import ConsoleEmailProvider
from app.providers.email.gmail_api import GmailApiEmailProvider
from app.providers.email.https_api import BrevoEmailProvider, ResendEmailProvider
from app.providers.email.sandbox import SandboxEmailProvider
from app.providers.email.ses import SesEmailProvider
from app.providers.email.smtp import SmtpEmailProvider


def get_email_provider(settings: Settings | None = None) -> EmailProvider:
    settings = settings or get_settings()
    match settings.EMAIL_PROVIDER:
        case EmailProviderName.CONSOLE:
            return ConsoleEmailProvider()
        case EmailProviderName.SANDBOX:
            return SandboxEmailProvider()
        case EmailProviderName.SMTP:
            return SmtpEmailProvider(settings)
        case EmailProviderName.SES:
            return SesEmailProvider(settings)
        case EmailProviderName.BREVO:
            return BrevoEmailProvider(settings)
        case EmailProviderName.RESEND:
            return ResendEmailProvider(settings)
        case EmailProviderName.GMAIL_API:
            return GmailApiEmailProvider.from_settings(settings)
