"""Response schemas for fleet analytics and the admin platform overview."""

from __future__ import annotations

from decimal import Decimal

from app.schemas.common import ApiModel


class FleetSummaryResponse(ApiModel):
    vehicle_count: int
    total_trips: int
    completed_trips: int
    total_revenue: Decimal
    average_rating: Decimal | None
    rating_count: int


class PlatformOverviewResponse(ApiModel):
    total_users: int
    total_passengers: int
    total_drivers: int
    total_fleet_owners: int
    total_bookings: int
    completed_bookings: int
    total_revenue: Decimal
    active_trips: int
    open_complaints: int
    active_sos_alerts: int
