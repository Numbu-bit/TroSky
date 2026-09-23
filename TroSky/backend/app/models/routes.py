"""Route, stop, and schedule domain models.

Routes are defined independently of scheduled trips (see ``app.models.trips``
for the trip itself — a scheduled or active run of a route).
"""

from __future__ import annotations

import uuid
from datetime import time
from decimal import Decimal
from enum import StrEnum
from typing import Any

from geoalchemy2 import Geography
from sqlalchemy import CheckConstraint, ForeignKey, Index, UniqueConstraint
from sqlalchemy import Enum as PgEnum
from sqlalchemy.dialects.postgresql import ARRAY
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.types import TIME, Boolean, Integer, Numeric, String

from app.models.base import UUIDAuditBase, enum_values


class DayOfWeek(StrEnum):
    MONDAY = "monday"
    TUESDAY = "tuesday"
    WEDNESDAY = "wednesday"
    THURSDAY = "thursday"
    FRIDAY = "friday"
    SATURDAY = "saturday"
    SUNDAY = "sunday"


class Stop(UUIDAuditBase):
    __tablename__ = "stops"

    name: Mapped[str] = mapped_column(String(200), nullable=False)
    code: Mapped[str | None] = mapped_column(String(20), nullable=True)
    description: Mapped[str | None] = mapped_column(String(500), nullable=True)
    # WGS84 geography point (SRID 4326) — the standard for lat/lng storage.
    # Written as a WKT string ("POINT(lng lat)"); read back as a WKBElement
    # (see app.utilities.geo for conversion helpers). `spatial_index=False`
    # because the GIST index is created explicitly below (and in the
    # hand-written migration) rather than via GeoAlchemy2's automatic DDL
    # event, so every index in this schema is declared in exactly one place.
    location: Mapped[Any] = mapped_column(
        Geography(geometry_type="POINT", srid=4326, spatial_index=False), nullable=False
    )
    address: Mapped[str | None] = mapped_column(String(500), nullable=True)
    city: Mapped[str | None] = mapped_column(String(100), nullable=True)
    region: Mapped[str | None] = mapped_column(String(100), nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)

    __table_args__ = (
        UniqueConstraint("code", name="uq_stops_code"),
        Index("ix_stops_location", "location", postgresql_using="gist"),
        Index("ix_stops_city", "city"),
    )


class Route(UUIDAuditBase):
    __tablename__ = "routes"

    name: Mapped[str] = mapped_column(String(200), nullable=False)
    origin_stop_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("stops.id", ondelete="RESTRICT"), nullable=False
    )
    destination_stop_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("stops.id", ondelete="RESTRICT"), nullable=False
    )
    distance_km: Mapped[Decimal | None] = mapped_column(Numeric(8, 2), nullable=True)
    estimated_duration_minutes: Mapped[int | None] = mapped_column(Integer, nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    created_by: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )

    __table_args__ = (
        UniqueConstraint("name", name="uq_routes_name"),
        CheckConstraint(
            "origin_stop_id != destination_stop_id", name="origin_destination_distinct"
        ),
        Index("ix_routes_origin_destination", "origin_stop_id", "destination_stop_id"),
    )


class RouteStop(UUIDAuditBase):
    """An ordered stop along a route (including origin at sequence 0 and
    destination at the final sequence number)."""

    __tablename__ = "route_stops"

    route_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("routes.id", ondelete="CASCADE"), nullable=False
    )
    stop_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("stops.id", ondelete="RESTRICT"), nullable=False
    )
    sequence_number: Mapped[int] = mapped_column(Integer, nullable=False)
    distance_from_origin_km: Mapped[Decimal | None] = mapped_column(Numeric(8, 2), nullable=True)
    estimated_offset_minutes: Mapped[int | None] = mapped_column(Integer, nullable=True)

    __table_args__ = (
        UniqueConstraint("route_id", "sequence_number", name="uq_route_stops_route_sequence"),
        UniqueConstraint("route_id", "stop_id", name="uq_route_stops_route_stop"),
        CheckConstraint("sequence_number >= 0", name="sequence_number_non_negative"),
        Index("ix_route_stops_route_id", "route_id"),
    )


class RouteSchedule(UUIDAuditBase):
    """A recurring departure pattern for a route (e.g. "daily at 08:00").
    Used to inform/generate trips — it is not itself a trip."""

    __tablename__ = "route_schedules"

    route_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("routes.id", ondelete="CASCADE"), nullable=False
    )
    departure_time: Mapped[time] = mapped_column(TIME(timezone=False), nullable=False)
    days_of_week: Mapped[list[DayOfWeek]] = mapped_column(
        ARRAY(PgEnum(DayOfWeek, name="day_of_week", native_enum=True, values_callable=enum_values)),
        nullable=False,
    )
    fare_amount: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)

    __table_args__ = (
        CheckConstraint("fare_amount >= 0", name="fare_amount_non_negative"),
        Index("ix_route_schedules_route_id", "route_id"),
    )
