"""Profile, emergency contact, and notification preference business logic."""

from __future__ import annotations

import uuid
from decimal import Decimal

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings, get_settings
from app.core.exceptions import (
    ConflictError,
    FileValidationError,
    InvalidCredentialsError,
    NotFoundError,
)
from app.core.logging import get_logger
from app.core.security import verify_password_async
from app.models.identity import (
    DevicePlatform,
    DeviceRegistration,
    EmergencyContact,
    FavouritePlace,
    FavouritePlaceKind,
    NotificationPreference,
    User,
)
from app.providers.storage.base import ObjectStorageProvider
from app.providers.storage.malware_scan import MalwareScanner
from app.repositories.profile_repository import (
    DeviceRepository,
    EmergencyContactRepository,
    FavouritePlaceExistsError,
    FavouritePlaceRepository,
    FavouritePlaceView,
    FavouriteRouteExistsError,
    FavouriteRouteRepository,
    FavouriteRouteView,
    NotificationPreferenceRepository,
)
from app.repositories.route_repository import StopRepository
from app.repositories.session_repository import SessionRepository
from app.repositories.user_repository import UserRepository
from app.schemas.user import (
    EmergencyContactCreateRequest,
    EmergencyContactUpdateRequest,
    FavouritePlaceCreateRequest,
    FavouritePlaceUpdateRequest,
    NotificationPreferencesUpdateRequest,
    UserProfileUpdateRequest,
)
from app.services.document_service import store_uploaded_document
from app.utilities.geo import wkb_to_latlng
from app.utilities.phone import normalize_phone_number

logger = get_logger(__name__)

_DEFAULT_PLACE_LABELS = {FavouritePlaceKind.HOME: "Home", FavouritePlaceKind.WORK: "Work"}


def _coordinate(value: float) -> Decimal:
    """Six decimal places (about 10 cm), as stored."""
    return Decimal(str(round(value, 6)))


_AVATAR_TYPES = {"image/jpeg", "image/png"}


class UserService:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session
        self._users = UserRepository(session)
        self._contacts = EmergencyContactRepository(session)
        self._preferences = NotificationPreferenceRepository(session)
        self._sessions = SessionRepository(session)
        self._devices = DeviceRepository(session)
        self._favourites = FavouriteRouteRepository(session)
        self._places = FavouritePlaceRepository(session)

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
        fields = request.model_dump(exclude_unset=True)
        if fields.get("avatar_url") is not None:
            # A photo URL set by hand replaces an uploaded one.
            user.profile.avatar_storage_key = None
        await self._users.update_profile(user.profile, **fields)
        return user

    async def delete_account(self, user_id: uuid.UUID, password: str) -> None:
        user = await self._users.get_by_id(user_id)
        if user is None:
            raise NotFoundError("User not found.")
        if not await verify_password_async(password, user.password_hash):
            raise InvalidCredentialsError("Incorrect password.")
        await self._sessions.revoke_all_sessions_for_user(user_id, reason="account_deleted")
        # Where someone lives and works is not kept once they leave.
        await self._places.delete_all_for_user(user_id)
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
        await self._preferences.update(pref, **request.stored_fields())
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

    # ------------------------------------------------------------------
    # Favourite routes (Home screen shortcuts)
    # ------------------------------------------------------------------
    async def list_favourite_routes(self, user_id: uuid.UUID) -> list[FavouriteRouteView]:
        return await self._favourites.list_for_user(user_id)

    async def add_favourite_route(
        self,
        user_id: uuid.UUID,
        *,
        origin_stop_id: uuid.UUID,
        destination_stop_id: uuid.UUID,
        label: str | None,
    ) -> FavouriteRouteView:
        stops = StopRepository(self._session)
        for stop_id in (origin_stop_id, destination_stop_id):
            if await stops.get_by_id(stop_id) is None:
                raise NotFoundError("Stop not found.", details={"stop_id": str(stop_id)})
        limit = get_settings().FAVOURITE_ROUTES_MAX_PER_USER
        if await self._favourites.count_for_user(user_id) >= limit:
            raise ConflictError(
                f"You can save up to {limit} favourite routes. Remove one first.",
                code="FAVOURITE_ROUTES_LIMIT",
            )
        try:
            favourite = await self._favourites.create(
                user_id=user_id,
                origin_stop_id=origin_stop_id,
                destination_stop_id=destination_stop_id,
                label=label,
            )
        except FavouriteRouteExistsError:
            raise ConflictError(
                "This journey is already in your favourites.", code="FAVOURITE_ROUTE_EXISTS"
            ) from None
        [view] = await self._favourites.list_for_user(user_id, favourite_id=favourite.id)
        return view

    async def delete_favourite_route(self, user_id: uuid.UUID, favourite_id: uuid.UUID) -> None:
        favourite = await self._favourites.get_for_user(user_id, favourite_id)
        if favourite is None:
            raise NotFoundError("Favourite route not found.")
        await self._favourites.delete(favourite)

    # ------------------------------------------------------------------
    # Favourite places (Home and Work shortcuts)
    # ------------------------------------------------------------------
    async def list_favourite_places(self, user_id: uuid.UUID) -> list[FavouritePlaceView]:
        return await self._places.list_for_user(user_id)

    async def add_favourite_place(
        self, user_id: uuid.UUID, request: FavouritePlaceCreateRequest
    ) -> FavouritePlaceView:
        stop_id, latitude, longitude = await self._place_location(
            request.stop_id, request.latitude, request.longitude
        )
        limit = get_settings().FAVOURITE_PLACES_MAX_PER_USER
        if await self._places.count_for_user(user_id) >= limit:
            raise ConflictError(
                f"You can save up to {limit} places. Remove one first.",
                code="FAVOURITE_PLACES_LIMIT",
            )
        label = request.label or _DEFAULT_PLACE_LABELS.get(request.kind, "")
        try:
            place = await self._places.create(
                FavouritePlace(
                    user_id=user_id,
                    kind=request.kind,
                    label=label,
                    stop_id=stop_id,
                    latitude=latitude,
                    longitude=longitude,
                )
            )
        except FavouritePlaceExistsError:
            raise ConflictError(
                f"You already saved your {request.kind.value}. Change or remove it instead.",
                code="FAVOURITE_PLACE_EXISTS",
            ) from None
        [view] = await self._places.list_for_user(user_id, place_id=place.id)
        return view

    async def update_favourite_place(
        self, user_id: uuid.UUID, place_id: uuid.UUID, request: FavouritePlaceUpdateRequest
    ) -> FavouritePlaceView:
        place = await self._places.get_for_user(user_id, place_id)
        if place is None:
            raise NotFoundError("Favourite place not found.")
        if request.label is not None:
            place.label = request.label
        if request.moves:
            place.stop_id, place.latitude, place.longitude = await self._place_location(
                request.stop_id, request.latitude, request.longitude
            )
        await self._places.save(place)
        [view] = await self._places.list_for_user(user_id, place_id=place.id)
        return view

    async def delete_favourite_place(self, user_id: uuid.UUID, place_id: uuid.UUID) -> None:
        place = await self._places.get_for_user(user_id, place_id)
        if place is None:
            raise NotFoundError("Favourite place not found.")
        await self._places.delete(place)

    async def _place_location(
        self, stop_id: uuid.UUID | None, latitude: float | None, longitude: float | None
    ) -> tuple[uuid.UUID | None, Decimal, Decimal]:
        """The stop (checked), and the coordinates: those given, else the
        stop's own."""
        if stop_id is not None:
            stop = await StopRepository(self._session).get_by_id(stop_id)
            if stop is None:
                raise NotFoundError("Stop not found.", details={"stop_id": str(stop_id)})
            if latitude is None or longitude is None:
                point = wkb_to_latlng(stop.location)
                if point is None:  # every stop has a location; defensive only
                    raise NotFoundError("Stop has no location.", details={"stop_id": str(stop_id)})
                latitude, longitude = point
        if latitude is None or longitude is None:  # the request schema rules this out
            raise ValueError("A place needs a stop or coordinates.")
        return stop_id, _coordinate(latitude), _coordinate(longitude)

    # ------------------------------------------------------------------
    # Profile photo
    # ------------------------------------------------------------------
    async def set_avatar(
        self,
        user_id: uuid.UUID,
        *,
        filename: str,
        content_type: str,
        data: bytes,
        storage: ObjectStorageProvider,
        scanner: MalwareScanner,
        settings: Settings | None = None,
    ) -> None:
        """Store an uploaded JPEG/PNG as the user's profile photo, replacing
        (and deleting) any earlier upload."""
        settings = settings or get_settings()
        if content_type not in _AVATAR_TYPES:
            raise FileValidationError(
                "Upload a JPEG or PNG image.", details={"allowed_types": sorted(_AVATAR_TYPES)}
            )
        if len(data) > settings.AVATAR_MAX_SIZE_BYTES:
            raise FileValidationError(
                "The photo is too large.",
                details={"max_bytes": settings.AVATAR_MAX_SIZE_BYTES, "actual_bytes": len(data)},
            )
        user = await self._users.get_by_id(user_id)
        if user is None or user.profile is None:
            raise NotFoundError("User not found.")
        uploaded = await store_uploaded_document(
            storage=storage,
            scanner=scanner,
            settings=settings,
            key_prefix=f"avatars/{user_id}",
            filename=filename,
            content_type=content_type,
            data=data,
        )
        previous = user.profile.avatar_storage_key
        user.profile.avatar_storage_key = uploaded.storage_key
        user.profile.avatar_url = None
        await self._session.flush()
        if previous and previous != uploaded.storage_key:
            try:
                await storage.delete_object(previous)
            except Exception:
                # Only costs storage: the old photo is no longer referenced.
                logger.warning("avatar_previous_object_not_deleted", user_id=str(user_id))
