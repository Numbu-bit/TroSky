"""The app's Step 20 backend gaps: favourite places, topic switches in the
notification preferences, and changing the password and the email
address -- against a real Postgres."""

from __future__ import annotations

import re
import uuid

import pytest
from redis.asyncio import Redis
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.exceptions import (
    ConflictError,
    InvalidCredentialsError,
    NotFoundError,
    OtpNotFoundError,
    ValidationAppError,
)
from app.core.security import hash_password, verify_password_async
from app.models.identity import FavouritePlaceKind
from app.models.notifications import NotificationTopic
from app.providers.email.sandbox import SandboxEmailProvider
from app.providers.sms.sandbox import SandboxSmsProvider
from app.repositories.session_repository import SessionRepository
from app.schemas.user import (
    FavouritePlaceCreateRequest,
    FavouritePlaceUpdateRequest,
    NotificationPreferencesUpdateRequest,
)
from app.services.auth_service import AuthService
from app.services.notification_service import NotificationService
from app.services.route_service import RouteService
from app.services.user_service import UserService

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]

PASSWORD = "Str0ngPass"


def _email(name: str) -> str:
    """Unique per test run: API tests commit their accounts."""
    return f"{name}.{_RUN}@gmail.com"


_RUN = uuid.uuid4().hex[:8]


@pytest.fixture(autouse=True)
def _clear_sandboxes():
    SandboxSmsProvider.clear()
    SandboxEmailProvider.clear()
    yield
    SandboxSmsProvider.clear()
    SandboxEmailProvider.clear()


def _auth(db_session: AsyncSession, **settings: object) -> AuthService:
    from app.core.redis import get_redis_client

    redis: Redis = get_redis_client()
    config = get_settings().model_copy(update=settings) if settings else None
    return AuthService(db_session, redis, SandboxSmsProvider(), SandboxEmailProvider(), config)


def _emailed_code(to: str) -> str:
    sent = SandboxEmailProvider.get_last_email(to)
    assert sent is not None, f"no email sent to {to}"
    found = re.search(r"\b(\d{4,10})\b", sent.body_text)
    assert found is not None, sent.body_text
    return found.group(1)


async def _stop(db_session: AsyncSession, latitude: float = 5.6, longitude: float = -0.2):
    return await RouteService(db_session).create_stop(
        name=f"Madina-{uuid.uuid4().hex[:6]}",
        code=None,
        latitude=latitude,
        longitude=longitude,
        address=None,
        city=None,
        region=None,
    )


def _place(kind: str, **fields: object) -> FavouritePlaceCreateRequest:
    return FavouritePlaceCreateRequest.model_validate({"kind": kind, **fields})


class TestFavouritePlaces:
    async def test_home_from_a_stop_work_from_a_point_listed_home_first(
        self, db_session: AsyncSession, make_user
    ) -> None:
        user = await make_user()
        madina = await _stop(db_session, 5.6, -0.2)
        users = UserService(db_session)

        gym = await users.add_favourite_place(
            user.id, _place("custom", label="Gym", latitude=5.61, longitude=-0.19)
        )
        work = await users.add_favourite_place(
            user.id, _place("work", latitude=5.55, longitude=-0.21)
        )
        home = await users.add_favourite_place(user.id, _place("home", stop_id=madina.id))

        assert (home.kind, home.label, home.stop_id, home.stop_name) == (
            FavouritePlaceKind.HOME,
            "Home",
            madina.id,
            madina.name,
        )
        assert (home.latitude, home.longitude) == pytest.approx((5.6, -0.2))
        assert (work.label, work.stop_id, work.stop_name) == ("Work", None, None)
        assert [p.id for p in await users.list_favourite_places(user.id)] == [
            home.id,
            work.id,
            gym.id,
        ]

    async def test_one_home_and_one_work_but_many_others(
        self, db_session: AsyncSession, make_user
    ) -> None:
        user = await make_user()
        users = UserService(db_session)
        await users.add_favourite_place(user.id, _place("home", latitude=5.6, longitude=-0.2))
        with pytest.raises(ConflictError) as exc_info:
            await users.add_favourite_place(user.id, _place("home", latitude=5.7, longitude=-0.2))
        assert exc_info.value.code == "FAVOURITE_PLACE_EXISTS"
        # ...the failed attempt left the session usable, and others can repeat.
        for label in ("Church", "School"):
            await users.add_favourite_place(
                user.id, _place("custom", label=label, latitude=5.6, longitude=-0.2)
            )
        assert len(await users.list_favourite_places(user.id)) == 3

    async def test_rename_and_move_from_a_stop_to_a_point(
        self, db_session: AsyncSession, make_user
    ) -> None:
        user = await make_user()
        madina = await _stop(db_session)
        users = UserService(db_session)
        home = await users.add_favourite_place(user.id, _place("home", stop_id=madina.id))

        renamed = await users.update_favourite_place(
            user.id, home.id, FavouritePlaceUpdateRequest(label="Our house")
        )
        assert (renamed.label, renamed.stop_id) == ("Our house", madina.id)
        moved = await users.update_favourite_place(
            user.id, home.id, FavouritePlaceUpdateRequest(latitude=5.65, longitude=-0.17)
        )
        assert (moved.label, moved.stop_id) == ("Our house", None)
        assert (moved.latitude, moved.longitude) == pytest.approx((5.65, -0.17))

    async def test_unknown_stops_and_other_peoples_places(
        self, db_session: AsyncSession, make_user
    ) -> None:
        owner, stranger = await make_user(), await make_user()
        users = UserService(db_session)
        with pytest.raises(NotFoundError):
            await users.add_favourite_place(owner.id, _place("home", stop_id=uuid.uuid4()))
        place = await users.add_favourite_place(
            owner.id, _place("work", latitude=5.6, longitude=-0.2)
        )
        with pytest.raises(NotFoundError):
            await users.update_favourite_place(
                stranger.id, place.id, FavouritePlaceUpdateRequest(label="Mine")
            )
        with pytest.raises(NotFoundError):
            await users.delete_favourite_place(stranger.id, place.id)
        await users.delete_favourite_place(owner.id, place.id)
        assert await users.list_favourite_places(owner.id) == []

    async def test_the_number_of_places_is_capped(
        self, db_session: AsyncSession, make_user, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        monkeypatch.setattr(get_settings(), "FAVOURITE_PLACES_MAX_PER_USER", 1)
        user = await make_user()
        users = UserService(db_session)
        await users.add_favourite_place(user.id, _place("home", latitude=5.6, longitude=-0.2))
        with pytest.raises(ConflictError) as exc_info:
            await users.add_favourite_place(user.id, _place("work", latitude=5.6, longitude=-0.2))
        assert exc_info.value.code == "FAVOURITE_PLACES_LIMIT"

    async def test_deleting_the_account_forgets_its_places(
        self, db_session: AsyncSession, make_user
    ) -> None:
        user = await make_user(password_hash=hash_password(PASSWORD))
        users = UserService(db_session)
        await users.add_favourite_place(user.id, _place("home", latitude=5.6, longitude=-0.2))
        await users.delete_account(user.id, PASSWORD)
        assert await users.list_favourite_places(user.id) == []


class TestTopicSwitches:
    async def test_new_switches_default_on_and_promotions_map_to_the_opt_in(
        self, db_session: AsyncSession, make_user
    ) -> None:
        user = await make_user()
        users = UserService(db_session)
        pref = await users.get_notification_preferences(user.id)
        assert (pref.booking_updates_enabled, pref.payment_enabled, pref.promotional_opt_in) == (
            True,
            True,
            False,
        )
        pref = await users.update_notification_preferences(
            user.id,
            NotificationPreferencesUpdateRequest(promotions_enabled=True, payment_enabled=False),
        )
        assert (pref.promotional_opt_in, pref.payment_enabled, pref.push_enabled) == (
            True,
            False,
            True,
        )


class TestChangePassword:
    async def test_keeps_this_session_signs_out_the_rest_and_tells_the_user(
        self, db_session: AsyncSession, make_user, seeded_roles, require_redis: None
    ) -> None:
        user = await make_user(password_hash=hash_password(PASSWORD))
        auth = _auth(db_session)
        sessions = SessionRepository(db_session)
        keep, other = [
            await sessions.create_session(
                user_id=user.id,
                device_id=device,
                device_name=None,
                ip_address=None,
                user_agent=None,
            )
            for device in ("phone", "tablet")
        ]

        await auth.change_password(
            user.id, session_id=keep.id, current_password=PASSWORD, new_password="N3wPassword"
        )

        assert [s.id for s in await auth.list_sessions(user.id)] == [keep.id]
        assert other.id != keep.id
        assert await verify_password_async("N3wPassword", user.password_hash)
        [notice], _ = await NotificationService(db_session).list_notifications(
            user.id, unread_only=False, limit=5, offset=0
        )
        assert (notice.title, notice.topic) == (
            "Your password was changed",
            NotificationTopic.ACCOUNT,
        )

    async def test_wrong_current_password_same_password_and_weak_password(
        self, db_session: AsyncSession, make_user, require_redis: None
    ) -> None:
        user = await make_user(password_hash=hash_password(PASSWORD))
        auth = _auth(db_session)
        session_id = uuid.uuid4()
        with pytest.raises(InvalidCredentialsError):
            await auth.change_password(
                user.id,
                session_id=session_id,
                current_password="Wr0ngPass",
                new_password="N3wPass1",
            )
        with pytest.raises(ConflictError) as same:
            await auth.change_password(
                user.id, session_id=session_id, current_password=PASSWORD, new_password=PASSWORD
            )
        assert same.value.code == "PASSWORD_UNCHANGED"
        with pytest.raises(ConflictError) as weak:
            await auth.change_password(
                user.id, session_id=session_id, current_password=PASSWORD, new_password="weakpass"
            )
        assert weak.value.code == "PASSWORD_POLICY_VIOLATION"
        assert await verify_password_async(PASSWORD, user.password_hash)


class TestChangeEmail:
    async def test_the_old_address_stays_until_the_code_is_confirmed(
        self, db_session: AsyncSession, make_user, require_redis: None
    ) -> None:
        user = await make_user(email=_email("old.address"), password_hash=hash_password(PASSWORD))
        auth = _auth(db_session)

        sent_to = await auth.start_email_change(
            user.id, new_email=_email("new.address"), current_password=PASSWORD
        )
        assert sent_to == _email("new.address")
        assert user.email == _email("old.address")

        changed = await auth.confirm_email_change(
            user.id, new_email=_email("new.address"), code=_emailed_code(sent_to)
        )
        assert changed.email == _email("new.address")
        assert changed.email_verified_at is not None
        notice = SandboxEmailProvider.get_last_email(_email("old.address"))
        assert notice is not None
        assert notice.subject == "Your TroSky email address was changed"
        [inbox], _ = await NotificationService(db_session).list_notifications(
            user.id, unread_only=False, limit=5, offset=0
        )
        assert inbox.data == {"type": "email_changed"}

    async def test_someone_elses_code_does_not_change_your_email(
        self, db_session: AsyncSession, make_user, require_redis: None
    ) -> None:
        asker = await make_user(password_hash=hash_password(PASSWORD))
        other = await make_user(email=_email("other"))
        auth = _auth(db_session)
        await auth.start_email_change(
            asker.id, new_email=_email("wanted"), current_password=PASSWORD
        )
        with pytest.raises(OtpNotFoundError):
            await auth.confirm_email_change(
                other.id, new_email=_email("wanted"), code=_emailed_code(_email("wanted"))
            )
        assert other.email == _email("other")

    async def test_refusals(self, db_session: AsyncSession, make_user, require_redis: None) -> None:
        user = await make_user(email=_email("me"), password_hash=hash_password(PASSWORD))
        await make_user(email=_email("taken"))
        auth = _auth(db_session)

        with pytest.raises(InvalidCredentialsError):
            await auth.start_email_change(
                user.id, new_email=_email("fresh"), current_password="Wr0ngPass"
            )
        with pytest.raises(ConflictError) as unchanged:
            await auth.start_email_change(
                user.id, new_email=_email("me").upper(), current_password=PASSWORD
            )
        assert unchanged.value.code == "EMAIL_UNCHANGED"
        with pytest.raises(ConflictError) as taken:
            await auth.start_email_change(
                user.id, new_email=_email("taken"), current_password=PASSWORD
            )
        assert taken.value.code == "EMAIL_ALREADY_REGISTERED"
        gmail_only = _auth(db_session, REGISTRATION_EMAIL_DOMAINS="gmail.com")
        with pytest.raises(ValidationAppError) as domain:
            await gmail_only.start_email_change(
                user.id, new_email=f"me.{_RUN}@example.com", current_password=PASSWORD
            )
        assert domain.value.code == "EMAIL_DOMAIN_NOT_ALLOWED"
        assert SandboxEmailProvider.get_sent_emails(_email("fresh")) == []
