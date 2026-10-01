"""Frontend requests G4 (favourite routes), G5 (profile photo upload) and
G13 (rating categories) -- against a real Postgres."""

from __future__ import annotations

import uuid
from decimal import Decimal

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.exceptions import ConflictError, FileValidationError, NotFoundError
from app.providers.storage.malware_scan import NoOpMalwareScanner
from app.providers.storage.sandbox import SandboxStorageProvider
from app.repositories.user_repository import UserRepository
from app.schemas.user import UserProfileUpdateRequest
from app.services.rating_service import RatingService
from app.services.route_service import RouteService
from app.services.user_service import UserService
from tests.integration.test_rating_service import _make_completed_booking

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]

PNG = b"\x89PNG\r\n\x1a\n" + b"\x00" * 64


async def _stops(db_session: AsyncSession, count: int = 2) -> list:
    service = RouteService(db_session)
    suffix = uuid.uuid4().hex[:6]
    return [
        await service.create_stop(
            name=f"{name}-{suffix}",
            code=None,
            latitude=5.6 + i / 10,
            longitude=-0.2,
            address=None,
            city=None,
            region=None,
        )
        for i, name in enumerate(["Madina", "Circle", "Kaneshie"][:count])
    ]


class TestFavouriteRoutes:
    async def test_add_list_and_delete(self, db_session: AsyncSession, make_user) -> None:
        user = await make_user()
        madina, circle = await _stops(db_session)
        users = UserService(db_session)

        added = await users.add_favourite_route(
            user.id, origin_stop_id=madina.id, destination_stop_id=circle.id, label="To work"
        )
        assert (added.origin_stop_name, added.destination_stop_name, added.label) == (
            madina.name,
            circle.name,
            "To work",
        )
        assert [f.id for f in await users.list_favourite_routes(user.id)] == [added.id]

        await users.delete_favourite_route(user.id, added.id)
        assert await users.list_favourite_routes(user.id) == []

    async def test_the_same_journey_cannot_be_saved_twice(
        self, db_session: AsyncSession, make_user
    ) -> None:
        user = await make_user()
        madina, circle = await _stops(db_session)
        users = UserService(db_session)
        await users.add_favourite_route(
            user.id, origin_stop_id=madina.id, destination_stop_id=circle.id, label=None
        )
        with pytest.raises(ConflictError) as exc_info:
            await users.add_favourite_route(
                user.id, origin_stop_id=madina.id, destination_stop_id=circle.id, label="Again"
            )
        assert exc_info.value.code == "FAVOURITE_ROUTE_EXISTS"
        # ...and the failed attempt left the session usable.
        assert len(await users.list_favourite_routes(user.id)) == 1

    async def test_the_number_of_favourites_is_capped(
        self, db_session: AsyncSession, make_user, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        monkeypatch.setattr(get_settings(), "FAVOURITE_ROUTES_MAX_PER_USER", 1)
        user = await make_user()
        madina, circle, kaneshie = await _stops(db_session, count=3)
        users = UserService(db_session)
        await users.add_favourite_route(
            user.id, origin_stop_id=madina.id, destination_stop_id=circle.id, label=None
        )
        with pytest.raises(ConflictError) as exc_info:
            await users.add_favourite_route(
                user.id, origin_stop_id=madina.id, destination_stop_id=kaneshie.id, label=None
            )
        assert exc_info.value.code == "FAVOURITE_ROUTES_LIMIT"

    async def test_unknown_stops_and_other_peoples_favourites(
        self, db_session: AsyncSession, make_user
    ) -> None:
        owner, stranger = await make_user(), await make_user()
        madina, circle = await _stops(db_session)
        users = UserService(db_session)
        with pytest.raises(NotFoundError):
            await users.add_favourite_route(
                owner.id, origin_stop_id=madina.id, destination_stop_id=uuid.uuid4(), label=None
            )
        favourite = await users.add_favourite_route(
            owner.id, origin_stop_id=madina.id, destination_stop_id=circle.id, label=None
        )
        with pytest.raises(NotFoundError):
            await users.delete_favourite_route(stranger.id, favourite.id)
        assert await users.list_favourite_routes(stranger.id) == []


class TestAvatar:
    @pytest.fixture(autouse=True)
    def _clear_storage(self):
        SandboxStorageProvider.clear()
        yield
        SandboxStorageProvider.clear()

    async def _upload(self, db_session: AsyncSession, user_id: uuid.UUID, **overrides) -> None:
        upload: dict = {
            "filename": "me.png",
            "content_type": "image/png",
            "data": PNG,
            "storage": SandboxStorageProvider(),
            "scanner": NoOpMalwareScanner(),
        }
        upload.update(overrides)
        await UserService(db_session).set_avatar(user_id, **upload)

    async def _storage_key(self, db_session: AsyncSession, user_id: uuid.UUID) -> str | None:
        user = await UserRepository(db_session).get_by_id(user_id)
        assert user is not None
        assert user.profile is not None
        return user.profile.avatar_storage_key

    async def test_an_upload_is_stored_and_replaces_the_previous_one(
        self, db_session: AsyncSession, make_user
    ) -> None:
        user = await make_user()
        await self._upload(db_session, user.id)
        first = await self._storage_key(db_session, user.id)
        assert first is not None
        assert first.startswith(f"avatars/{user.id}/")
        assert SandboxStorageProvider.get_object(first) == (PNG, "image/png")

        await self._upload(db_session, user.id, filename="new.jpg", content_type="image/jpeg")
        second = await self._storage_key(db_session, user.id)
        assert second != first
        assert SandboxStorageProvider.get_object(first) is None  # old photo deleted

    async def test_only_jpeg_or_png_within_the_size_limit(
        self, db_session: AsyncSession, make_user, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        user = await make_user()
        with pytest.raises(FileValidationError):
            await self._upload(
                db_session, user.id, filename="cv.pdf", content_type="application/pdf"
            )
        monkeypatch.setattr(get_settings(), "AVATAR_MAX_SIZE_BYTES", 10)
        with pytest.raises(FileValidationError):
            await self._upload(db_session, user.id)
        assert await self._storage_key(db_session, user.id) is None

    async def test_a_photo_url_set_by_hand_replaces_the_upload(
        self, db_session: AsyncSession, make_user
    ) -> None:
        user = await make_user()
        await self._upload(db_session, user.id)
        await UserService(db_session).update_profile(
            user.id, UserProfileUpdateRequest(avatar_url="https://example.com/me.png")
        )
        assert await self._storage_key(db_session, user.id) is None


class TestRatingCategories:
    async def test_categories_are_stored_and_averaged(
        self, db_session: AsyncSession, make_user
    ) -> None:
        ratings = RatingService(db_session)
        first_passenger = await make_user()
        first_booking, _ = await _make_completed_booking(
            db_session, passenger_id=first_passenger.id, make_user=make_user
        )
        rating = await ratings.rate_booking(
            first_booking,
            passenger_id=first_passenger.id,
            score=4,
            comment=None,
            categories={"safety": 5, "cleanliness": 3, "professionalism": None, "timeliness": 4},
        )
        assert (rating.safety, rating.cleanliness, rating.timeliness) == (5, 3, 4)
        assert rating.professionalism is None
        assert rating.driver_id is not None

        averages = await ratings.get_driver_category_averages(rating.driver_id)
        assert averages == {
            "safety": Decimal("5.00"),
            "cleanliness": Decimal("3.00"),
            "professionalism": None,
            "timeliness": Decimal("4.00"),
        }

    async def test_categories_are_optional(self, db_session: AsyncSession, make_user) -> None:
        passenger = await make_user()
        booking_id, _ = await _make_completed_booking(
            db_session, passenger_id=passenger.id, make_user=make_user
        )
        rating = await RatingService(db_session).rate_booking(
            booking_id, passenger_id=passenger.id, score=5, comment="Smooth"
        )
        assert (rating.safety, rating.cleanliness, rating.professionalism, rating.timeliness) == (
            None,
            None,
            None,
            None,
        )
