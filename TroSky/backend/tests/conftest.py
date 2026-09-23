"""Shared pytest fixtures.

Loads ``.env.test`` (committed, non-secret placeholder values) *before* any
``app.*`` module is imported, so ``Settings`` is constructed from the test
configuration rather than a developer's local ``.env``.
"""

from __future__ import annotations

import os
import secrets
import uuid
from collections.abc import AsyncGenerator, AsyncIterator, Awaitable, Callable
from pathlib import Path

import pytest
import pytest_asyncio
from dotenv import load_dotenv
from httpx import ASGITransport, AsyncClient
from sqlalchemy import delete as sa_delete
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

_ENV_TEST_PATH = Path(__file__).resolve().parent.parent / ".env.test"
load_dotenv(_ENV_TEST_PATH, override=True)

# ``override=True`` above is deliberate: it stops a developer's exported
# DATABASE_URL (production, staging, a shared Supabase instance) from being
# picked up by a suite that truncates tables. The escape hatch is explicit
# and test-specific, so pointing the suite at a scratch database is a
# conscious act rather than an accident of the ambient environment.
_TEST_DB_URL = os.environ.get("TROSKY_TEST_DATABASE_URL")
if _TEST_DB_URL:
    os.environ["DATABASE_URL"] = _TEST_DB_URL
    os.environ["DATABASE_URL_SYNC"] = _TEST_DB_URL.replace("+asyncpg", "+psycopg")

os.environ.setdefault("APP_ENV", "test")

from app.core.config import get_settings  # noqa: E402
from app.core.database import dispose_engine, get_engine  # noqa: E402
from app.core.redis import close_redis, get_redis_client  # noqa: E402
from app.main import create_app  # noqa: E402
from app.models import Base  # noqa: E402
from app.models.identity import User, UserProfile  # noqa: E402


@pytest.fixture(scope="session", autouse=True)
def settings_session():
    get_settings.cache_clear()
    settings = get_settings()
    assert settings.APP_ENV.value == "test"
    return settings


@pytest_asyncio.fixture(autouse=True)
async def _reset_engine_between_tests() -> AsyncGenerator[None, None]:
    """Dispose the cached engine and Redis client after every test.

    ``asyncio_mode = "auto"`` with pytest-asyncio's default function-scoped
    event loop means each test runs on a NEW loop, while ``get_engine()`` /
    ``get_redis_client()`` cache one client at module level. A pooled
    asyncpg connection opened on a previous (now-closed) loop fails with
    ``AttributeError: 'NoneType' object has no attribute 'send'`` when
    reused — which ``postgres_is_reachable`` swallowed, so affected tests
    were reported as "Postgres is not reachable" and silently SKIPPED
    rather than run. Disposing per test keeps every loop with its own
    connections.
    """
    yield
    await dispose_engine()
    await close_redis()


@pytest_asyncio.fixture
async def app_instance():
    from app.api import dependencies as api_dependencies
    from app.providers.storage.sandbox import SandboxStorageProvider

    application = create_app()
    # Never let API-level tests touch a real S3/MinIO endpoint.
    application.dependency_overrides[api_dependencies.get_storage_provider_dep] = (
        SandboxStorageProvider
    )
    yield application
    await dispose_engine()
    await close_redis()


@pytest_asyncio.fixture
async def client(app_instance) -> AsyncIterator[AsyncClient]:
    transport = ASGITransport(app=app_instance)
    async with AsyncClient(transport=transport, base_url="http://testserver") as ac:
        yield ac


async def postgres_is_reachable() -> bool:
    try:
        from sqlalchemy import text

        engine = get_engine()
        async with engine.connect() as conn:
            await conn.execute(text("SELECT 1"))
        return True
    except Exception:  # reachability probe, not a real handler
        return False


async def redis_is_reachable() -> bool:
    try:
        client = get_redis_client()
        return bool(await client.ping())
    except Exception:  # reachability probe, not a real handler
        return False


@pytest_asyncio.fixture
async def require_postgres() -> AsyncGenerator[None, None]:
    if not await postgres_is_reachable():
        pytest.skip("Postgres is not reachable; start it via `docker compose up postgres`.")
    # Belt-and-braces for local ad-hoc runs where `alembic upgrade head`
    # hasn't been run yet; CI always runs migrations first (see ci.yml).
    # `create_all(checkfirst=True)` is a no-op against an already-migrated
    # database.
    engine = get_engine()
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield


@pytest_asyncio.fixture
async def require_redis() -> AsyncGenerator[None, None]:
    if not await redis_is_reachable():
        pytest.skip("Redis is not reachable; start it via `docker compose up redis`.")
    client = get_redis_client()
    await client.flushdb()
    yield
    await client.flushdb()


@pytest_asyncio.fixture
async def db_session(require_postgres: None) -> AsyncIterator[AsyncSession]:
    """A database session bound to a real transaction that is always rolled
    back at test teardown, so each test starts from a clean, isolated state
    even though the service layer under test calls ``session.flush()`` /
    relies on autocommit-on-request-completion in production."""
    engine = get_engine()
    async with engine.connect() as connection:
        outer_transaction = await connection.begin()
        session = AsyncSession(
            bind=connection, expire_on_commit=False, join_transaction_mode="create_savepoint"
        )
        try:
            yield session
        finally:
            await session.close()
            await outer_transaction.rollback()


@pytest_asyncio.fixture
async def seeded_roles(db_session: AsyncSession) -> dict[str, object]:
    """Seeds roles/permissions inside the same rolled-back transaction as
    ``db_session`` — for service-level tests that don't go through HTTP."""
    from scripts.seed_dev_data import ensure_permissions, ensure_roles

    roles = await ensure_roles(db_session)
    await ensure_permissions(db_session)
    return roles


@pytest_asyncio.fixture
async def seed_identity_data(require_postgres: None) -> AsyncIterator[None]:
    """Seeds roles/permissions with a real, committed transaction — for
    API-level tests that exercise the app's own (separately-committing)
    request-scoped sessions via the ``client`` fixture. Idempotent, so
    running it once per test is cheap and side-effect-free across runs."""
    from scripts.seed_dev_data import ensure_permissions, ensure_roles

    from app.core.database import get_session_factory

    session_factory = get_session_factory()
    async with session_factory() as session:
        await ensure_roles(session)
        await ensure_permissions(session)
        await session.commit()
    yield


def _unique_phone() -> str:
    """A distinct, well-formed Ghanaian number per call. Phone numbers are
    globally unique (``uq_users_phone_number``), so committed fixtures must
    not collide across tests or across runs."""
    return f"+233{secrets.randbelow(900_000_000) + 100_000_000}"


def _build_user(**overrides: object) -> User:
    user = User(
        phone_number=overrides.pop("phone_number", _unique_phone()),
        email=overrides.pop("email", None),
        password_hash=overrides.pop("password_hash", "not-a-real-hash"),
        **overrides,
    )
    user.profile = UserProfile(full_name="Test User", preferred_language="en")
    return user


@pytest_asyncio.fixture
def make_user(db_session: AsyncSession) -> Callable[..., Awaitable[User]]:
    """Factory creating real ``users`` rows inside the test's rolled-back
    transaction.

    ``wallets``, ``drivers``, ``fleet_owners`` and friends all carry a
    foreign key to ``users.id`` (e.g. ``fk_wallets_user_id_users``), so a
    fabricated ``uuid.uuid4()`` cannot stand in for an owner — the insert
    fails with ForeignKeyViolationError before the code under test is
    reached. Use this for anything that must reference a real account, and
    keep ``uuid.uuid4()`` only where the test *wants* an id that does not
    exist.
    """

    async def _make(**overrides: object) -> User:
        user = _build_user(**overrides)
        db_session.add(user)
        await db_session.flush()
        return user

    return _make


@pytest_asyncio.fixture
async def committed_make_user(
    require_postgres: None,
) -> AsyncIterator[Callable[..., Awaitable[User]]]:
    """Like ``make_user``, but each account is committed.

    Tests that open their own sessions through ``get_session_factory`` —
    the concurrency races — cannot see rows written inside the
    SAVEPOINT-isolated ``db_session`` transaction, so they need accounts
    that really exist for the foreign keys to resolve.
    """
    from app.core.database import get_session_factory

    session_factory = get_session_factory()
    created: list[uuid.UUID] = []

    async def _make(**overrides: object) -> User:
        async with session_factory() as session, session.begin():
            user = _build_user(**overrides)
            session.add(user)
            await session.flush()
            await session.refresh(user)
            created.append(user.id)
            return user

    yield _make
    for user_id in created:
        # Best-effort, for the reason given on ``committed_user``.
        try:
            async with session_factory() as session, session.begin():
                await session.execute(sa_delete(User).where(User.id == user_id))
        except IntegrityError:
            pass


@pytest_asyncio.fixture
async def committed_user(require_postgres: None) -> AsyncIterator[User]:
    """A real, committed user for tests that open their own sessions via
    ``get_session_factory`` (concurrency races, which cannot use the
    SAVEPOINT-isolated ``db_session``). Removed again at teardown so runs
    stay repeatable."""
    from app.core.database import get_session_factory

    session_factory = get_session_factory()
    async with session_factory() as session, session.begin():
        user = _build_user()
        session.add(user)
        await session.flush()
        await session.refresh(user)
        user_id = user.id
    yield user
    # Best-effort: rows this user now owns (wallets, drivers, ...) are
    # ``ondelete="RESTRICT"``, so the delete is refused once a test has
    # created any. Leaving the row behind is harmless — phone numbers are
    # random, so nothing collides on a later run.
    try:
        async with session_factory() as session, session.begin():
            await session.execute(sa_delete(User).where(User.id == user_id))
    except IntegrityError:
        pass
