"""Async SQLAlchemy engine, session factory, and FastAPI dependencies.

The database is the single source of truth for all transactional state
(seat holds, bookings, wallet ledger, tickets). Redis is used only as an
acceleration layer (caching, TTL expiry hints, locks) — never as the sole
authority for anything financial or capacity-related.
"""

from __future__ import annotations

from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager
from typing import Final

from sqlalchemy.ext.asyncio import (
    AsyncEngine,
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.pool import NullPool

from app.core.admin_events import publish_announced
from app.core.audit import attach_to_session
from app.core.config import Settings, get_settings
from app.core.logging import get_logger
from app.models.base import Base

logger = get_logger(__name__)

_engine: AsyncEngine | None = None
_session_factory: async_sessionmaker[AsyncSession] | None = None


def create_engine(settings: Settings | None = None) -> AsyncEngine:
    """Create the async SQLAlchemy engine with production-sane pool settings."""
    settings = settings or get_settings()
    is_test_sqlite = settings.DATABASE_URL.startswith("sqlite")

    engine_kwargs: dict[str, object] = {
        "echo": settings.DATABASE_ECHO,
        "pool_pre_ping": True,
        "future": True,
    }
    if is_test_sqlite:
        # SQLite (in-memory) is used only for narrow unit tests that do not
        # exercise Postgres/PostGIS-specific features; pooling semantics
        # differ and NullPool avoids cross-connection state surprises.
        engine_kwargs["poolclass"] = NullPool
    else:
        engine_kwargs["pool_size"] = settings.DATABASE_POOL_SIZE
        engine_kwargs["max_overflow"] = settings.DATABASE_MAX_OVERFLOW
        engine_kwargs["pool_timeout"] = settings.DATABASE_POOL_TIMEOUT_SECONDS

    return create_async_engine(settings.DATABASE_URL, **engine_kwargs)


def get_engine() -> AsyncEngine:
    global _engine
    if _engine is None:
        _engine = create_engine()
    return _engine


def get_session_factory() -> async_sessionmaker[AsyncSession]:
    global _session_factory
    if _session_factory is None:
        _session_factory = async_sessionmaker(
            bind=get_engine(),
            expire_on_commit=False,
            autoflush=False,
            class_=AsyncSession,
        )
    return _session_factory


_KEEP_ON_FAILURE: Final = "trosky.keep_on_failure"


def keep_writes_on_failure(session: AsyncSession) -> None:
    """Keep this request's writes even though it is about to fail.

    For a safeguard that records a failure and then reports it: a wrong
    password counting towards a lockout, a wrong one-time code counting
    towards its limit, every session revoked after a refresh token is
    reused. ``get_db`` rolls back a failing request, which would undo the
    safeguard along with it. Call this straight after the write and before
    raising, so nothing else is caught up in the commit.
    """
    session.info[_KEEP_ON_FAILURE] = True


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """FastAPI dependency yielding a request-scoped AsyncSession.

    Commits on clean completion, then publishes what the request announced
    for the admin stream (:mod:`app.core.admin_events`); rolls back on any
    exception (unless a safeguard asked for its writes to be kept, see
    :func:`keep_writes_on_failure`), and always closes the session. Route
    handlers should not call ``commit()`` themselves for the "request"
    session — service-layer code that needs an explicit transaction
    boundary should use :func:`transactional_session`.
    """
    session_factory = get_session_factory()
    async with session_factory() as session:
        attach_to_session(session.sync_session)
        try:
            yield session
            await session.commit()
            await publish_announced(session)
        except Exception:
            if session.info.pop(_KEEP_ON_FAILURE, False):
                try:
                    await session.commit()
                except Exception:
                    logger.exception("keep_on_failure_commit_failed")
                    await session.rollback()
            else:
                await session.rollback()
            raise
        finally:
            await session.close()


@asynccontextmanager
async def transactional_session() -> AsyncGenerator[AsyncSession, None]:
    """Explicit transaction boundary for use outside the request lifecycle
    (background workers, scripts, event handlers). Like ``get_db``, it
    publishes what was announced for the admin stream once committed."""
    session_factory = get_session_factory()
    async with session_factory() as session:
        async with session.begin():
            yield session
        await publish_announced(session)


async def dispose_engine() -> None:
    """Dispose the engine's connection pool. Call on application shutdown."""
    global _engine, _session_factory
    if _engine is not None:
        await _engine.dispose()
        logger.info("database_engine_disposed")
    _engine = None
    _session_factory = None


async def check_database_connection() -> bool:
    """Lightweight liveness probe used by the readiness health check."""
    from sqlalchemy import text

    try:
        engine = get_engine()
        async with engine.connect() as conn:
            await conn.execute(text("SELECT 1"))
        return True
    except Exception:  # health check must never raise
        logger.warning("database_health_check_failed", exc_info=True)
        return False


TARGET_METADATA: Final = Base.metadata
