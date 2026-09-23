"""Push provider factory."""

from __future__ import annotations

from app.core.config import Settings, get_settings
from app.providers.push.base import PushProvider
from app.providers.push.firebase import FirebasePushProvider
from app.providers.push.sandbox import SandboxPushProvider


def get_push_provider(settings: Settings | None = None) -> PushProvider:
    settings = settings or get_settings()
    if settings.FIREBASE_ENABLED:
        return FirebasePushProvider(settings)
    return SandboxPushProvider()
