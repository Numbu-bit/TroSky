"""GPS tracking domain model: the raw, high-volume ping log.

This table is the durable, queryable history (retained for
``GPS_RAW_RETENTION_DAYS``, purged by a Celery beat task); it is
deliberately **not** the read path for "where is this trip right now" —
that's Redis (see ``app.services.tracking_service``), which every ping
also updates. Postgres here exists for audit/replay/analytics, not for
live-tracking latency.
"""

from __future__ import annotations

import uuid
from datetime import datetime
from decimal import Decimal
from typing import Any

from geoalchemy2 import Geography
from sqlalchemy import CheckConstraint, ForeignKey, Index
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.types import TIMESTAMP, Numeric

from app.models.base import UUIDAuditBase


class TripLocation(UUIDAuditBase):
    __tablename__ = "trip_locations"

    trip_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("trips.id", ondelete="CASCADE"), nullable=False
    )
    # See app.models.routes.Stop for the spatial_index=False rationale —
    # applied identically here.
    location: Mapped[Any] = mapped_column(
        Geography(geometry_type="POINT", srid=4326, spatial_index=False), nullable=False
    )
    speed_kmh: Mapped[Decimal | None] = mapped_column(Numeric(6, 2), nullable=True)
    heading_degrees: Mapped[Decimal | None] = mapped_column(Numeric(5, 2), nullable=True)
    accuracy_meters: Mapped[Decimal | None] = mapped_column(Numeric(8, 2), nullable=True)
    recorded_at: Mapped[datetime] = mapped_column(TIMESTAMP(timezone=True), nullable=False)

    __table_args__ = (
        CheckConstraint("speed_kmh IS NULL OR speed_kmh >= 0", name="speed_kmh_non_negative"),
        Index("ix_trip_locations_location", "location", postgresql_using="gist"),
        Index("ix_trip_locations_trip_id_recorded_at", "trip_id", "recorded_at"),
    )
