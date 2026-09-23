"""Database access for the raw GPS ping log."""

from __future__ import annotations

import uuid
from datetime import datetime
from decimal import Decimal

from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.tracking import TripLocation
from app.utilities.geo import latlng_to_wkt


class TripLocationRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def create(
        self,
        *,
        trip_id: uuid.UUID,
        latitude: float,
        longitude: float,
        speed_kmh: Decimal | None,
        heading_degrees: Decimal | None,
        accuracy_meters: Decimal | None,
        recorded_at: datetime,
    ) -> TripLocation:
        location = TripLocation(
            trip_id=trip_id,
            location=latlng_to_wkt(latitude, longitude),
            speed_kmh=speed_kmh,
            heading_degrees=heading_degrees,
            accuracy_meters=accuracy_meters,
            recorded_at=recorded_at,
        )
        self._session.add(location)
        await self._session.flush()
        return location

    async def get_latest_for_trip(self, trip_id: uuid.UUID) -> TripLocation | None:
        result = await self._session.execute(
            select(TripLocation)
            .where(TripLocation.trip_id == trip_id)
            .order_by(TripLocation.recorded_at.desc())
            .limit(1)
        )
        return result.scalar_one_or_none()

    async def purge_older_than(self, cutoff: datetime, *, limit: int = 5000) -> int:
        """Deletes raw pings older than ``cutoff`` in bounded batches so a
        single sweep never holds a long-running transaction against a
        high-volume table."""
        result = await self._session.execute(
            select(TripLocation.id).where(TripLocation.recorded_at < cutoff).limit(limit)
        )
        ids = list(result.scalars().all())
        if not ids:
            return 0
        await self._session.execute(delete(TripLocation).where(TripLocation.id.in_(ids)))
        await self._session.flush()
        return len(ids)
