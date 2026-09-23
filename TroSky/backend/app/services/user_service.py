"""Profile, emergency contact, and notification preference business logic."""

from __future__ import annotations

import uuid

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import InvalidCredentialsError, NotFoundError
from app.core.security import verify_password
from app.models.identity import (
    DevicePlatform,
    DeviceRegistration,
    EmergencyContact,
    NotificationPreference,
    User,
)
from app.repositories.profile_repository import (
    DeviceRepository,
    EmergencyContactRepository,
    NotificationPreferenceRepository,
)
from app.repositories.session_repository import SessionRepository
from app.repositories.user_repository import UserRepository
from app.schemas.user import (
    EmergencyContactCreateRequest,
    EmergencyContactUpdateRequest,
    NotificationPreferencesUpdateRequest,
    UserProfileUpdateRequest,
)
from app.utilities.phone import normalize_phone_number


class UserService:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session
        self._users = UserRepository(session)
        self._contacts = EmergencyContactRepository(session)
        self._preferences = NotificationPreferenceRepository(session)
        self._sessions = SessionRepository(session)
        self._devices = DeviceRepository(session)

    async def get_user_with_roles(self, user_id: uuid.UUID) -> tuple[User, list[str]]:
        user = await self._users.get_by_id(user_id)
        if user is None:
            raise NotFoundError("User not found.")
        roles = await self._users.get_roles_for_user(user_id)
        return user, roles

    async def update_profile(self, user_id: uuid.UUID, request: UserProfileUpdateRequest) -> User:
        user = await self._users.get_by_id(user_id)
        if user is None or user.profile is None:
            raise NotFoundError("User not found.")
        await self._users.update_profile(user.profile, **request.model_dump(exclude_unset=True))
        return user

    async def delete_account(self, user_id: uuid.UUID, password: str) -> None:
        user = await self._users.get_by_id(user_id)
        if user is None:
            raise NotFoundError("User not found.")
        if not verify_password(password, user.password_hash):
            raise InvalidCredentialsError("Incorrect password.")
        await self._sessions.revoke_all_sessions_for_user(user_id, reason="account_deleted")
        await self._users.soft_delete(user)

    # ------------------------------------------------------------------
    # Emergency contacts
    # ------------------------------------------------------------------
    async def list_emergency_contacts(self, user_id: uuid.UUID) -> list[EmergencyContact]:
        return await self._contacts.list_for_user(user_id)

    async def create_emergency_contact(
        self, user_id: uuid.UUID, request: EmergencyContactCreateRequest
    ) -> EmergencyContact:
        return await self._contacts.create(
            user_id=user_id,
            name=request.name,
            phone_number=normalize_phone_number(request.phone_number),
            relationship_label=request.relationship_label,
            is_primary=request.is_primary,
        )

    async def update_emergency_contact(
        self, user_id: uuid.UUID, contact_id: uuid.UUID, request: EmergencyContactUpdateRequest
    ) -> EmergencyContact:
        contact = await self._contacts.get_for_user(contact_id, user_id)
        if contact is None:
            raise NotFoundError("Emergency contact not found.")
        fields = request.model_dump(exclude_unset=True)
        if "phone_number" in fields and fields["phone_number"] is not None:
            fields["phone_number"] = normalize_phone_number(fields["phone_number"])
        await self._contacts.update(contact, **fields)
        return contact

    async def delete_emergency_contact(self, user_id: uuid.UUID, contact_id: uuid.UUID) -> None:
        contact = await self._contacts.get_for_user(contact_id, user_id)
        if contact is None:
            raise NotFoundError("Emergency contact not found.")
        await self._contacts.soft_delete(contact)

    # ------------------------------------------------------------------
    # Notification preferences
    # ------------------------------------------------------------------
    async def get_notification_preferences(self, user_id: uuid.UUID) -> NotificationPreference:
        pref = await self._preferences.get_for_user(user_id)
        if pref is None:
            pref = await self._preferences.create_default(user_id)
        return pref

    async def update_notification_preferences(
        self, user_id: uuid.UUID, request: NotificationPreferencesUpdateRequest
    ) -> NotificationPreference:
        pref = await self.get_notification_preferences(user_id)
        await self._preferences.update(pref, **request.model_dump(exclude_unset=True))
        return pref

    # ------------------------------------------------------------------
    # Device registration (push tokens)
    # ------------------------------------------------------------------
    async def register_device(
        self,
        user_id: uuid.UUID,
        *,
        device_id: str,
        platform: DevicePlatform,
        push_token: str | None,
    ) -> DeviceRegistration:
        return await self._devices.upsert(
            user_id=user_id, device_id=device_id, platform=platform, push_token=push_token
        )
