"""Firebase Cloud Messaging (FCM) push adapter.

Uses the official ``firebase-admin`` SDK against Google's publicly
documented FCM API — genuinely production-ready once a real service
account is supplied, same bar as ``TwilioSmsProvider``/the MTN MoMo
adapter. The app is initialized lazily and once per process (the SDK
itself is not safe to re-initialize under the same name).
"""

from __future__ import annotations

from typing import Any, ClassVar

import firebase_admin
from firebase_admin import credentials, messaging

from app.core.config import Settings
from app.core.exceptions import ProviderError
from app.core.logging import get_logger
from app.providers.push.base import PushSendResult

logger = get_logger(__name__)


class FirebasePushProvider:
    _app: ClassVar[firebase_admin.App | None] = None

    def __init__(self, settings: Settings) -> None:
        if not settings.FIREBASE_ENABLED:
            raise ProviderError("Firebase push provider selected but FIREBASE_ENABLED is false.")
        if FirebasePushProvider._app is None:
            FirebasePushProvider._app = self._init_app(settings)

    @staticmethod
    def _init_app(settings: Settings) -> firebase_admin.App:
        if settings.FIREBASE_CREDENTIALS_JSON:
            import json

            cred = credentials.Certificate(json.loads(settings.FIREBASE_CREDENTIALS_JSON))
        elif settings.FIREBASE_CREDENTIALS_PATH:
            cred = credentials.Certificate(settings.FIREBASE_CREDENTIALS_PATH)
        else:
            raise ProviderError(
                "Firebase push provider selected but neither FIREBASE_CREDENTIALS_JSON "
                "nor FIREBASE_CREDENTIALS_PATH is configured."
            )
        return firebase_admin.initialize_app(cred, name="trosky")

    async def send(
        self, *, token: str, title: str, body: str, data: dict[str, Any]
    ) -> PushSendResult:
        message = messaging.Message(
            token=token,
            notification=messaging.Notification(title=title, body=body),
            data={k: str(v) for k, v in data.items()},
        )
        try:
            message_id = messaging.send(message, app=self._app)
        except messaging.UnregisteredError:
            return PushSendResult(success=False, error="Device token is no longer registered.")
        except firebase_admin.exceptions.FirebaseError as exc:
            logger.warning("firebase_push_send_failed", error=str(exc))
            return PushSendResult(success=False, error=str(exc))
        return PushSendResult(success=True, provider_message_id=message_id)
