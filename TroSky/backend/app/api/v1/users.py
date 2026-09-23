"""Profile, notification preference, and emergency contact endpoints."""

from __future__ import annotations

import uuid

from fastapi import APIRouter, status

from app.api.dependencies import CurrentPrincipal, UserServiceDep
from app.models.identity import User
from app.schemas.common import MessageResponse
from app.schemas.notification import DeviceRegisterRequest, DeviceResponse
from app.schemas.user import (
    AccountDeletionRequest,
    EmergencyContactCreateRequest,
    EmergencyContactResponse,
    EmergencyContactUpdateRequest,
    NotificationPreferencesResponse,
    NotificationPreferencesUpdateRequest,
    UserProfileResponse,
    UserProfileUpdateRequest,
    UserResponse,
)

router = APIRouter()


def _user_response(user: User, roles: list[str]) -> UserResponse:
    profile = None
    if user.profile is not None:
        profile = UserProfileResponse(
            full_name=user.profile.full_name,
            date_of_birth=user.profile.date_of_birth,
            gender=user.profile.gender,
            preferred_language=user.profile.preferred_language,
            avatar_url=user.profile.avatar_url,
            ghana_card_number=user.profile.ghana_card_number,
            ghana_card_verified=user.profile.ghana_card_verified_at is not None,
        )
    return UserResponse(
        id=user.id,
        phone_number=user.phone_number,
        email=user.email,
        is_active=user.is_active,
        phone_verified=user.phone_verified_at is not None,
        email_verified=user.email_verified_at is not None,
        roles=roles,
        created_at=user.created_at,
        profile=profile,
    )


@router.get("/me", response_model=UserResponse)
async def get_me(principal: CurrentPrincipal, users: UserServiceDep) -> UserResponse:
    user, roles = await users.get_user_with_roles(principal.user_id)
    return _user_response(user, roles)


@router.patch("/me", response_model=UserResponse)
async def update_me(
    body: UserProfileUpdateRequest, principal: CurrentPrincipal, users: UserServiceDep
) -> UserResponse:
    await users.update_profile(principal.user_id, body)
    user, roles = await users.get_user_with_roles(principal.user_id)
    return _user_response(user, roles)


@router.delete("/me", response_model=MessageResponse)
async def delete_me(
    body: AccountDeletionRequest, principal: CurrentPrincipal, users: UserServiceDep
) -> MessageResponse:
    """Soft-deletes the account (data-minimization/retention rules apply
    server-side; see docs/data-retention-notes.md, Phase 11)."""
    await users.delete_account(principal.user_id, body.password)
    return MessageResponse(message="Account deleted.")


@router.get("/me/notification-preferences", response_model=NotificationPreferencesResponse)
async def get_notification_preferences(
    principal: CurrentPrincipal, users: UserServiceDep
) -> NotificationPreferencesResponse:
    pref = await users.get_notification_preferences(principal.user_id)
    return NotificationPreferencesResponse.model_validate(pref)


@router.patch("/me/notification-preferences", response_model=NotificationPreferencesResponse)
async def update_notification_preferences(
    body: NotificationPreferencesUpdateRequest, principal: CurrentPrincipal, users: UserServiceDep
) -> NotificationPreferencesResponse:
    pref = await users.update_notification_preferences(principal.user_id, body)
    return NotificationPreferencesResponse.model_validate(pref)


@router.get("/me/emergency-contacts", response_model=list[EmergencyContactResponse])
async def list_emergency_contacts(
    principal: CurrentPrincipal, users: UserServiceDep
) -> list[EmergencyContactResponse]:
    contacts = await users.list_emergency_contacts(principal.user_id)
    return [EmergencyContactResponse.model_validate(c) for c in contacts]


@router.post(
    "/me/emergency-contacts",
    response_model=EmergencyContactResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_emergency_contact(
    body: EmergencyContactCreateRequest, principal: CurrentPrincipal, users: UserServiceDep
) -> EmergencyContactResponse:
    contact = await users.create_emergency_contact(principal.user_id, body)
    return EmergencyContactResponse.model_validate(contact)


@router.patch("/me/emergency-contacts/{contact_id}", response_model=EmergencyContactResponse)
async def update_emergency_contact(
    contact_id: uuid.UUID,
    body: EmergencyContactUpdateRequest,
    principal: CurrentPrincipal,
    users: UserServiceDep,
) -> EmergencyContactResponse:
    contact = await users.update_emergency_contact(principal.user_id, contact_id, body)
    return EmergencyContactResponse.model_validate(contact)


@router.delete(
    "/me/emergency-contacts/{contact_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    response_model=None,
)
async def delete_emergency_contact(
    contact_id: uuid.UUID, principal: CurrentPrincipal, users: UserServiceDep
) -> None:
    await users.delete_emergency_contact(principal.user_id, contact_id)


@router.post("/me/devices", response_model=DeviceResponse, status_code=status.HTTP_201_CREATED)
async def register_device(
    body: DeviceRegisterRequest, principal: CurrentPrincipal, users: UserServiceDep
) -> DeviceResponse:
    """Registers (or refreshes) this device's push token. Idempotent per
    ``(user, device_id)`` — calling it again just updates the token."""
    device = await users.register_device(
        principal.user_id,
        device_id=body.device_id,
        platform=body.platform,
        push_token=body.push_token,
    )
    return DeviceResponse.model_validate(device)
