"""Events recorded only for analytics.

``SearchEvent``: one row per trip search, for the conversion funnel (searches
-> bookings) and the demand heat maps, including searches that found
nothing. A GPS search keeps only a ~550 m grid cell of where the passenger
stood, never their position: enough for a heat map, not for tracking anyone.
"""

from __future__ import annotations

import uuid
from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import ForeignKey, Index
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.types import TIMESTAMP, Date, Integer, Numeric, String

from app.models.base import Base, UUIDPrimaryKeyMixin

# Grid cells are 0.005 degrees on a side: about 550 m in Ghana.
SEARCH_GRID_DEGREES = Decimal("0.005")


class SearchEvent(UUIDPrimaryKeyMixin, Base):
    __tablename__ = "search_events"

    searched_at: Mapped[datetime] = mapped_column(
        TIMESTAMP(timezone=True), nullable=False, server_default="now()"
    )
    travel_date: Mapped[date] = mapped_column(Date, nullable=False)
    origin_stop_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("stops.id", ondelete="SET NULL"), nullable=True
    )
    destination_stop_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("stops.id", ondelete="SET NULL"), nullable=True
    )
    # Centre of the grid cell the passenger searched from (GPS searches).
    cell_latitude: Mapped[Decimal | None] = mapped_column(Numeric(8, 3), nullable=True)
    cell_longitude: Mapped[Decimal | None] = mapped_column(Numeric(8, 3), nullable=True)
    # Trips found, and those that could still be booked (a free seat, and
    # not already past the pickup). Zero bookable is unmet demand.
    results_count: Mapped[int] = mapped_column(Integer, nullable=False)
    bookable_count: Mapped[int] = mapped_column(Integer, nullable=False)
    # "ok", or why nothing could be searched (e.g. "no_pickup_nearby").
    outcome: Mapped[str] = mapped_column(String(40), nullable=False, default="ok")

    __table_args__ = (Index("ix_search_events_searched_at", "searched_at"),)
