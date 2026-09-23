"""SMS provider factory: resolves the configured provider by name."""

from __future__ import annotations

from app.core.config import Settings, SmsProviderName, get_settings
from app.providers.sms.base import SmsProvider
from app.providers.sms.console import ConsoleSmsProvider
from app.providers.sms.production import HubtelSmsProvider, TwilioSmsProvider
from app.providers.sms.sandbox import SandboxSmsProvider


def get_sms_provider(settings: Settings | None = None) -> SmsProvider:
    settings = settings or get_settings()
    match settings.SMS_PROVIDER:
        case SmsProviderName.CONSOLE:
            return ConsoleSmsProvider()
        case SmsProviderName.SANDBOX:
            return SandboxSmsProvider()
        case SmsProviderName.TWILIO:
            return TwilioSmsProvider(settings)
        case SmsProviderName.HUBTEL:
            return HubtelSmsProvider(settings)
