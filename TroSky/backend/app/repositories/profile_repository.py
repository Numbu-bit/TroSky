"""Database access for emergency contacts, notification preferences, and
device registrations."""

from __future__ import annotations

import uuid
from dataclasses import dataclass
from datetime import UTC, datetime

from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import aliased

from app.models.identity import (
    DevicePlatform,
    DeviceRegistration,
    EmergencyContact,
    FavouriteRoute,
    NotificationPreference,
)
from app.models.routes import Stop


class EmergencyContactRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def list_for_user(self, user_id: uuid.UUID) -> list[EmergencyContact]:
        stmt = (
            select(EmergencyContact)
            .where(EmergencyContact.user_id == user_id, EmergencyContact.deleted_at.is_(None))
            .order_by(EmergencyContact.is_primary.desc(), EmergencyContact.created_at)
        )
        result = await self._session.execute(stmt)
        return list(result.scalars().all())

    async def get_for_user(
        self, contact_id: uuid.UUID, user_id: uuid.UUID
    ) -> EmergencyContact | None:
        stmt = select(EmergencyContact).where(
            EmergencyContact.id == contact_id,
            EmergencyContact.user_id == user_id,
            EmergencyContact.deleted_at.is_(None),
        )
        result = await self._session.execute(stmt)
        return result.scalar_one_or_none()

    async def create(
        self,
        *,
        user_id: uuid.UUID,
        name: str,
        phone_number: str,
        relationship_label: str | None,
        is_primary: bool,
    ) -> EmergencyContact:
        contact = EmergencyContact(
            user_id=user_id,
            name=name,
            phone_number=phone_number,
            relationship_label=relationship_label,
            is_primary=is_primary,
        )
        self._session.add(contact)
        await self._session.flush()
        return contact

    async def update(self, contact: EmergencyContact, **fields: object) -> None:
        for key, value in fields.items():
            if value is not None:
                setattr(contact, key, value)
        await self._session.flush()

    async def soft_delete(self, contact: EmergencyContact) -> None:
        contact.deleted_at = datetime.now(UTC)
        await self._session.flush()


class NotificationPreferenceRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get_for_user(self, user_id: uuid.UUID) -> NotificationPreference | None:
        result = await self._session.execute(
            select(NotificationPreference).where(NotificationPreference.user_id == user_id)
        )
        return result.scalar_one_or_none()

    async def create_default(self, user_id: uuid.UUID) -> NotificationPreference:
        pref = NotificationPreference(user_id=user_id)
        self._session.add(pref)
        await self._session.flush()
        return pref

    async def update(self, pref: NotificationPreference, **fields: object) -> None:
        for key, value in fields.items():
            if value is not None:
                setattr(pref, key, value)
        await self._session.flush()


class DeviceRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def list_active_for_user(self, user_id: uuid.UUID) -> list[DeviceRegistration]:
        result = await self._session.execute(
            select(DeviceRegistration).where(
                DeviceRegistration.user_id == user_id,
                DeviceRegistration.is_active.is_(True),
                DeviceRegistration.push_token.is_not(None),
            )
        )
        return list(result.scalars().all())

    async def upsert(
        self,
        *,
        user_id: uuid.UUID,
        device_id: str,
        platform: DevicePlatform,
        push_token: str | None,
    ) -> DeviceRegistration:
        result = await self._session.execute(
            select(DeviceRegistration).where(
                DeviceRegistration.user_id == user_id, DeviceRegistration.device_id == device_id
            )
        )
        existing = result.scalar_one_or_none()
        if existing is not None:
            existing.platform = platform
            existing.push_token = push_token
            existing.is_active = True
            existing.last_seen_at = datetime.now(UTC)
            await self._session.flush()
            return existing

        record = DeviceRegistration(
            user_id=user_id, device_id=device_id, platform=platform, push_token=push_token
        )
        self._session.add(record)
        await self._session.flush()
        return record


class FavouriteRouteExistsError(Exception):
    """The user already saved this journey."""


@dataclass(frozen=True, slots=True)
class FavouriteRouteView:
    id: uuid.UUID
    origin_stop_id: uuid.UUID
    origin_stop_name: str
    destination_stop_id: uuid.UUID
    destination_stop_name: str
    label: str | None
    created_at: datetime


class FavouriteRouteRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def list_for_user(
        self, user_id: uuid.UUID, *, favourite_id: uuid.UUID | None = None
    ) -> list[FavouriteRouteView]:
        """The user's saved journeys with their stop names, oldest first."""
        origin = aliased(Stop, name="origin_stop")
        destination = aliased(Stop, name="destination_stop")
        stmt = (
            select(
                FavouriteRoute,
                origin.name.label("origin_stop_name"),
                destination.name.label("destination_stop_name"),
            )
            .join(origin, origin.id == FavouriteRoute.origin_stop_id)
            .join(destination, destination.id == FavouriteRoute.destination_stop_id)
            .where(FavouriteRoute.user_id == user_id)
            .order_by(FavouriteRoute.created_at, FavouriteRoute.id)
        )
        if favourite_id is not None:
            stmt = stmt.where(FavouriteRoute.id == favourite_id)
        result = await self._session.execute(stmt)
        return [
            FavouriteRouteView(
                id=favourite.id,
                origin_stop_id=favourite.origin_stop_id,
                origin_stop_name=origin_name,
                destination_stop_id=favourite.destination_stop_id,
                destination_stop_name=destination_name,
                label=favourite.label,
                created_at=favourite.created_at,
            )
            for favourite, origin_name, destination_name in result.all()
        ]

    async def count_for_user(self, user_id: uuid.UUID) -> int:
        result = await self._session.execute(
            select(func.count(FavouriteRoute.id)).where(FavouriteRoute.user_id == user_id)
        )
        return int(result.scalar_one())

    async def get_for_user(
        self, user_id: uuid.UUID, favourite_id: uuid.UUID
    ) -> FavouriteRoute | None:
        result = await self._session.execute(
            select(FavouriteRoute).where(
                FavouriteRoute.id == favourite_id, FavouriteRoute.user_id == user_id
            )
        )
        return result.scalar_one_or_none()

    async def create(
        self,
        *,
        user_id: uuid.UUID,
        origin_stop_id: uuid.UUID,
        destination_stop_id: uuid.UUID,
        label: str | None,
    ) -> FavouriteRoute:
        favourite = FavouriteRoute(
            user_id=user_id,
            origin_stop_id=origin_stop_id,
            destination_stop_id=destination_stop_id,
            label=label,
        )
        try:
            # A savepoint, so a duplicate does not poison the request's
            # transaction.
            async with self._session.begin_nested():
                self._session.add(favourite)
                await self._session.flush()
        except IntegrityError as exc:
            raise FavouriteRouteExistsError() from exc
        return favourite

    async def delete(self, favourite: FavouriteRoute) -> None:
        await self._session.delete(favourite)
        await self._session.flush()
