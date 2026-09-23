"""Alembic environment configuration for Postgres/PostGIS.

The database URL comes from ``DATABASE_URL_SYNC`` — the psycopg (blocking)
DSN that ``docker-compose.yml``, ``.github/workflows/ci.yml`` and
``deployments/kubernetes/secret.example.yaml`` all already set for exactly
this purpose. Migrations are plain DDL, so they run on a synchronous engine;
the application's async ``DATABASE_URL`` is deliberately NOT used here.

That distinction is load-bearing. This module previously read
``DATABASE_URL`` while documenting ``DATABASE_URL_SYNC``, so overriding the
documented variable silently had no effect and migrations went to whichever
database ``.env`` happened to name — an easy way to alter the wrong one.
To make the target unmissable it is logged before any migration runs, and
``-x db_url=...`` overrides it explicitly:

    alembic -x db_url=postgresql+psycopg://user:pass@localhost:5432/db upgrade head
"""

from __future__ import annotations

from logging.config import fileConfig
from urllib.parse import urlsplit

from alembic import context
from sqlalchemy import Connection, engine_from_config, pool

from app.core.config import get_settings

# Importing `app.models` registers every model module's tables on
# Base.metadata before `autogenerate` inspects it (see app/models/__init__.py).
from app.models import Base

config = context.config

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

target_metadata = Base.metadata


def _resolve_url() -> str:
    """``-x db_url=...`` wins over settings, so a one-off run can target a
    scratch database without editing ``.env``."""
    override = context.get_x_argument(as_dictionary=True).get("db_url")
    return override or get_settings().DATABASE_URL_SYNC


def _describe(url: str) -> str:
    """host:port/database, without credentials — safe to print."""
    parts = urlsplit(url)
    return f"{parts.hostname or '?'}:{parts.port or 5432}{parts.path or ''}"


_url = _resolve_url()
config.set_main_option("sqlalchemy.url", _url)
print(f"alembic: migrating {_describe(_url)}")


def run_migrations_offline() -> None:
    """Generate SQL without a live DB connection (``alembic upgrade --sql``)."""
    context.configure(
        url=config.get_main_option("sqlalchemy.url"),
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        compare_type=True,
    )
    with context.begin_transaction():
        context.run_migrations()


def do_run_migrations(connection: Connection) -> None:
    context.configure(
        connection=connection,
        target_metadata=target_metadata,
        compare_type=True,
        compare_server_default=True,
    )
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    connectable = engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )
    with connectable.connect() as connection:
        do_run_migrations(connection)
    connectable.dispose()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
