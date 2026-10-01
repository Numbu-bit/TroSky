"""Profile, notification preference, and emergency contact endpoints."""

from __future__ import annotations

import uuid

from fastapi import APIRouter, File, UploadFile, status

from app.api.dependencies import (
    CurrentPrincipal,
    MalwareScannerDep,
    StorageProviderDep,
    UserServiceDep,
)
from app.core.config import get_settings
from app.models.identity import User, UserProfile
from app.providers.storage.base import ObjectStorageProvider
from app.schemas.common import MessageResponse
from app.schemas.notification import DeviceRegisterRequest, DeviceResponse
from app.schemas.user import (
    AccountDeletionRequest,
    EmergencyContactCreateRequest,
    EmergencyContactResponse,
    EmergencyContactUpdateRequest,
    FavouriteRouteCreateRequest,
    FavouriteRouteResponse,
    NotificationPreferencesResponse,
    NotificationPreferencesUpdateRequest,
    UserProfileResponse,
    UserProfileUpdateRequest,
    UserResponse,
)

router = APIRouter()


async def _avatar_url(profile: UserProfile, storage: ObjectStorageProvider) -> str | None:
    """A signed, short-lived URL for an uploaded photo; else the URL set by hand."""
    if profile.avatar_storage_key:
        return await storage.generate_download_url(
            profile.avatar_storage_key,
            expires_in_seconds=get_settings().AVATAR_URL_TTL_SECONDS,
        )
    return profile.avatar_url


async def _user_response(
    user: User, roles: list[str], storage: ObjectStorageProvider
) -> UserResponse:
    profile = None
    if user.profile is not None:
        profile = UserProfileResponse(
            full_name=user.profile.full_name,
            date_of_birth=user.profile.date_of_birth,
            gender=user.profile.gender,
            preferred_language=user.profile.preferred_language,
            avatar_url=await _avatar_url(user.profile, storage),
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
async def get_me(
    principal: CurrentPrincipal, users: UserServiceDep, storage: StorageProviderDep
) -> UserResponse:
    user, roles = await users.get_user_with_roles(principal.user_id)
    return await _user_response(user, roles, storage)


@router.patch("/me", response_model=UserResponse)
async def update_me(
    body: UserProfileUpdateRequest,
    principal: CurrentPrincipal,
    users: UserServiceDep,
    storage: StorageProviderDep,
) -> UserResponse:
    await users.update_profile(principal.user_id, body)
    user, roles = await users.get_user_with_roles(principal.user_id)
    return await _user_response(user, roles, storage)


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


@router.post("/me/avatar", response_model=UserResponse)
async def upload_avatar(
    principal: CurrentPrincipal,
    users: UserServiceDep,
    storage: StorageProviderDep,
    scanner: MalwareScannerDep,
    file: UploadFile = File(..., description="A JPEG or PNG, up to 5 MB."),
) -> UserResponse:
    """Upload a profile photo, replacing any earlier one. ``avatar_url`` in
    the response is a signed link valid for an hour; ``GET /users/me``
    always returns a fresh one."""
    await users.set_avatar(
        principal.user_id,
        filename=file.filename or "avatar",
        content_type=file.content_type or "application/octet-stream",
        data=await file.read(),
        storage=storage,
        scanner=scanner,
    )
    user, roles = await users.get_user_with_roles(principal.user_id)
    return await _user_response(user, roles, storage)


@router.get("/me/favourite-routes", response_model=list[FavouriteRouteResponse])
async def list_favourite_routes(
    principal: CurrentPrincipal, users: UserServiceDep
) -> list[FavouriteRouteResponse]:
    """Journeys pinned to the Home screen, oldest first."""
    favourites = await users.list_favourite_routes(principal.user_id)
    return [FavouriteRouteResponse.model_validate(f) for f in favourites]


@router.post(
    "/me/favourite-routes",
    response_model=FavouriteRouteResponse,
    status_code=status.HTTP_201_CREATED,
)
async def add_favourite_route(
    body: FavouriteRouteCreateRequest, principal: CurrentPrincipal, users: UserServiceDep
) -> FavouriteRouteResponse:
    """Pin a journey (board at one stop, get off at another). 409 if it is
    already pinned, or the limit is reached."""
    favourite = await users.add_favourite_route(
        principal.user_id,
        origin_stop_id=body.origin_stop_id,
        destination_stop_id=body.destination_stop_id,
        label=body.label,
    )
    return FavouriteRouteResponse.model_validate(favourite)


@router.delete(
    "/me/favourite-routes/{favourite_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    response_model=None,
)
async def delete_favourite_route(
    favourite_id: uuid.UUID, principal: CurrentPrincipal, users: UserServiceDep
) -> None:
    await users.delete_favourite_route(principal.user_id, favourite_id)
