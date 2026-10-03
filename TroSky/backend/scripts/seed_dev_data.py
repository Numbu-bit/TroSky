"""Development/CI seed data: a dev administrator, stops and example routes,
on top of the reference data (roles and permissions) every database gets.

Run via ``make seed`` (``python -m scripts.seed_dev_data``). Idempotent —
safe to run repeatedly against the same database. Contains **no production
credentials**: the dev administrator's password is read from
``DEV_ADMIN_PASSWORD`` if set, otherwise falls back to a clearly-labeled
local-only default that is never suitable for a real deployment.

This script must never be pointed at a production database. It has no
built-in guard against that beyond the caller's own discipline — see
``docs/`` for the recommended CI/deploy safeguard (running it only in the
``development``/``test`` pipeline stage).
"""

from __future__ import annotations

import asyncio
import os
import uuid
from datetime import UTC, datetime, time
from decimal import Decimal

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import dispose_engine, transactional_session
from app.core.logging import configure_logging, get_logger
from app.core.permissions import SystemRole
from app.core.security import hash_password
from app.models.identity import (
    NotificationPreference,
    Role,
    User,
    UserProfile,
    UserRole,
)
from app.models.routes import DayOfWeek, Route
from app.repositories.route_repository import RouteRepository, StopRepository
from app.repositories.user_repository import UserRepository
from app.services.route_service import RouteService
from scripts.seed_reference_data import (
    ensure_admin_has_all_permissions,
    ensure_permissions,
    ensure_roles,
)

logger = get_logger(__name__)

_DEV_ADMIN_PHONE = "+233200000000"
_DEV_ADMIN_EMAIL = "admin@trosky.africa"
_DEV_ADMIN_PASSWORD_FALLBACK = "TroSkyDevAdmin!2026"  # noqa: S105 - local-dev-only fallback


async def ensure_dev_admin(session: AsyncSession, admin_role: Role) -> None:
    users = UserRepository(session)
    existing = await users.get_by_phone(_DEV_ADMIN_PHONE)
    if existing is not None:
        # Operator accounts are created here, not through registration, so
        # nobody is sent a code: mark the admin verified, or it could never
        # log in once verification is required.
        if not existing.is_verified:
            await users.mark_phone_verified(existing)
            logger.info("seed_dev_admin_marked_verified", user_id=str(existing.id))
        logger.info("seed_dev_admin_already_exists", user_id=str(existing.id))
        return

    password = os.environ.get("DEV_ADMIN_PASSWORD", _DEV_ADMIN_PASSWORD_FALLBACK)
    admin = User(
        phone_number=_DEV_ADMIN_PHONE,
        email=_DEV_ADMIN_EMAIL,
        password_hash=hash_password(password),
        is_active=True,
        phone_verified_at=datetime.now(UTC),
    )
    admin.profile = UserProfile(full_name="TroSky Dev Admin", preferred_language="en")
    session.add(admin)
    await session.flush()

    session.add(UserRole(user_id=admin.id, role_id=admin_role.id))
    session.add(NotificationPreference(user_id=admin.id))
    await session.flush()

    logger.info(
        "seed_dev_admin_created",
        user_id=str(admin.id),
        phone=_DEV_ADMIN_PHONE,
        password_from_env=bool(os.environ.get("DEV_ADMIN_PASSWORD")),
    )


_EXAMPLE_STOPS: list[dict[str, str | float]] = [
    {"name": "Accra Circle", "code": "ACC-CIR", "lat": 5.5713, "lng": -0.2051, "city": "Accra"},
    {"name": "Accra Kaneshie", "code": "ACC-KAN", "lat": 5.5558, "lng": -0.2361, "city": "Accra"},
    {"name": "Kumasi Kejetia", "code": "KUM-KEJ", "lat": 6.6935, "lng": -1.6291, "city": "Kumasi"},
    {
        "name": "Takoradi Market Circle",
        "code": "TKD-MKT",
        "lat": 4.8845,
        "lng": -1.7554,
        "city": "Takoradi",
    },
    # Pickup points along the main corridors. Coordinates are approximate
    # (good to a few hundred metres); an admin can refine them.
    {"name": "Accra Achimota", "code": "ACC-ACH", "lat": 5.6135, "lng": -0.2290, "city": "Accra"},
    {"name": "Accra Madina", "code": "ACC-MAD", "lat": 5.6687, "lng": -0.1664, "city": "Accra"},
    {"name": "Accra Legon", "code": "ACC-LEG", "lat": 5.6510, "lng": -0.1830, "city": "Accra"},
    {"name": "Accra 37 Station", "code": "ACC-37", "lat": 5.5875, "lng": -0.1830, "city": "Accra"},
    {"name": "Nsawam", "code": "NSW", "lat": 5.8089, "lng": -0.3503, "city": "Nsawam"},
    {"name": "Nkawkaw", "code": "NKW", "lat": 6.5513, "lng": -0.7663, "city": "Nkawkaw"},
    {"name": "Konongo", "code": "KNG", "lat": 6.6167, "lng": -1.2167, "city": "Konongo"},
    {"name": "Kasoa", "code": "KAS", "lat": 5.5343, "lng": -0.4243, "city": "Kasoa"},
    {"name": "Winneba Junction", "code": "WNB", "lat": 5.3830, "lng": -0.6280, "city": "Winneba"},
    {"name": "Mankessim", "code": "MNK", "lat": 5.2730, "lng": -1.0155, "city": "Mankessim"},
    {
        "name": "Cape Coast Kotokuraba",
        "code": "CC-KTK",
        "lat": 5.1060,
        "lng": -1.2440,
        "city": "Cape Coast",
    },
]

# Routes that stop along the way, so a passenger can board or alight at an
# intermediate stop and pay for their share of the distance.
# (name, stop codes in order, road km, minutes, fare)
_STOPPING_ROUTES: list[tuple[str, list[str], int, int, Decimal]] = [
    (
        "Accra - Kumasi (N6 Stopping)",
        ["ACC-CIR", "ACC-ACH", "NSW", "NKW", "KNG", "KUM-KEJ"],
        250,
        300,
        Decimal("120.00"),
    ),
    (
        "Accra - Takoradi (N1 Stopping)",
        ["ACC-KAN", "KAS", "WNB", "MNK", "CC-KTK", "TKD-MKT"],
        230,
        270,
        Decimal("100.00"),
    ),
    ("Madina - Circle", ["ACC-MAD", "ACC-LEG", "ACC-37", "ACC-CIR"], 14, 45, Decimal("8.00")),
]


async def ensure_example_routes(session: AsyncSession, admin_user_id: uuid.UUID | None) -> None:
    """Example stops/routes/schedules for local development — no example
    drivers/vehicles/trips, since those require a believable document
    approval trail rather than placeholder data."""
    stops = StopRepository(session)
    routes = RouteRepository(session)

    stop_ids: dict[str, uuid.UUID] = {}
    for spec in _EXAMPLE_STOPS:
        existing = await stops.search_by_name(str(spec["name"]), limit=1)
        if existing:
            stop_ids[str(spec["code"])] = existing[0].id
            continue
        stop = await stops.create(
            name=str(spec["name"]),
            code=str(spec["code"]),
            latitude=float(spec["lat"]),
            longitude=float(spec["lng"]),
            address=None,
            city=str(spec["city"]),
            region=None,
        )
        stop_ids[str(spec["code"])] = stop.id
        logger.info("seed_stop_created", name=spec["name"])

    example_routes = [
        ("Accra - Kumasi Express", "ACC-CIR", "KUM-KEJ", 250, 240, Decimal("60.00")),
        ("Accra - Takoradi Coastal", "ACC-KAN", "TKD-MKT", 230, 210, Decimal("55.00")),
    ]
    for name, origin_code, dest_code, distance_km, duration_min, fare in example_routes:
        result = await session.execute(select(Route).where(Route.name == name))
        if result.scalar_one_or_none() is not None:
            continue
        route = await routes.create(
            name=name,
            origin_stop_id=stop_ids[origin_code],
            destination_stop_id=stop_ids[dest_code],
            distance_km=Decimal(str(distance_km)),
            estimated_duration_minutes=duration_min,
            created_by=admin_user_id,
        )
        await routes.add_route_stop(
            route_id=route.id,
            stop_id=stop_ids[origin_code],
            sequence_number=0,
            distance_from_origin_km=None,
            estimated_offset_minutes=None,
        )
        await routes.add_route_stop(
            route_id=route.id,
            stop_id=stop_ids[dest_code],
            sequence_number=1,
            distance_from_origin_km=Decimal(str(distance_km)),
            estimated_offset_minutes=duration_min,
        )
        await routes.create_schedule(
            route_id=route.id,
            departure_time=time(8, 0),
            days_of_week=list(DayOfWeek),
            fare_amount=fare,
        )
        logger.info("seed_route_created", name=name)

    route_service = RouteService(session)
    for name, codes, road_km, minutes, fare in _STOPPING_ROUTES:
        result = await session.execute(select(Route).where(Route.name == name))
        if result.scalar_one_or_none() is not None:
            continue
        # The same path as POST /admin/routes, which works out how far along
        # the route each stop is.
        route = await route_service.create_route(
            name=name,
            origin_stop_id=stop_ids[codes[0]],
            destination_stop_id=stop_ids[codes[-1]],
            distance_km=Decimal(road_km),
            estimated_duration_minutes=minutes,
            intermediate_stop_ids=[stop_ids[code] for code in codes[1:-1]],
            created_by=admin_user_id,
        )
        await routes.create_schedule(
            route_id=route.id,
            departure_time=time(6, 30),
            days_of_week=list(DayOfWeek),
            fare_amount=fare,
        )
        logger.info("seed_route_created", name=name)


async def seed() -> None:
    async with transactional_session() as session:
        roles = await ensure_roles(session)
        permissions = await ensure_permissions(session)
        await ensure_admin_has_all_permissions(session, roles[SystemRole.ADMIN.value], permissions)
        await ensure_dev_admin(session, roles[SystemRole.ADMIN.value])

        users = UserRepository(session)
        admin = await users.get_by_phone(_DEV_ADMIN_PHONE)
        await ensure_example_routes(session, admin.id if admin else None)
    logger.info("seed_complete")


async def main() -> None:
    configure_logging(log_level="INFO", json_logs=False)
    try:
        await seed()
    finally:
        await dispose_engine()


if __name__ == "__main__":
    asyncio.run(main())
