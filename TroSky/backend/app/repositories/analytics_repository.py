"""Read-only aggregate queries for fleet analytics and the admin platform
overview. Deliberately separate from the domain repositories (bookings,
trips, payments, ...) — nothing here mutates state, and grouping every
cross-domain aggregate query in one place keeps the domain repositories
themselves free of reporting concerns."""

from __future__ import annotations

import uuid
from dataclasses import dataclass
from decimal import Decimal

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.bookings import Booking, BookingStatus
from app.models.feedback import Complaint, ComplaintStatus, Rating
from app.models.identity import Role, User, UserRole
from app.models.payments import Payment, PaymentStatus
from app.models.safety import SosAlert, SosAlertStatus
from app.models.trips import Trip, TripStatus, TripVehicleAssignment


@dataclass(frozen=True, slots=True)
class FleetSummary:
    vehicle_count: int
    total_trips: int
    completed_trips: int
    total_revenue: Decimal
    average_rating: Decimal | None
    rating_count: int


@dataclass(frozen=True, slots=True)
class PlatformOverview:
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


class AnalyticsRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get_fleet_summary(self, vehicle_ids: list[uuid.UUID]) -> FleetSummary:
        if not vehicle_ids:
            return FleetSummary(0, 0, 0, Decimal("0.00"), None, 0)

        trip_ids_result = await self._session.execute(
            select(TripVehicleAssignment.trip_id).where(
                TripVehicleAssignment.vehicle_id.in_(vehicle_ids)
            )
        )
        trip_ids = list(set(trip_ids_result.scalars().all()))
        if not trip_ids:
            return FleetSummary(len(vehicle_ids), 0, 0, Decimal("0.00"), None, 0)

        total_trips_result = await self._session.execute(
            select(func.count(Trip.id)).where(Trip.id.in_(trip_ids))
        )
        total_trips = total_trips_result.scalar_one()

        completed_trips_result = await self._session.execute(
            select(func.count(Trip.id)).where(
                Trip.id.in_(trip_ids), Trip.status == TripStatus.COMPLETED
            )
        )
        completed_trips = completed_trips_result.scalar_one()

        # The fleet's revenue is the fare it earns, not what the passenger
        # paid: total_amount also carries TroSky's platform fee.
        revenue_result = await self._session.execute(
            select(func.coalesce(func.sum(Booking.fare_amount), 0)).where(
                Booking.trip_id.in_(trip_ids), Booking.status == BookingStatus.COMPLETED
            )
        )
        total_revenue = Decimal(str(revenue_result.scalar_one()))

        rating_result = await self._session.execute(
            select(func.avg(Rating.score), func.count(Rating.id)).where(
                Rating.trip_id.in_(trip_ids)
            )
        )
        average_score, rating_count = rating_result.one()
        average_rating = (
            Decimal(str(round(average_score, 2))) if average_score is not None else None
        )

        return FleetSummary(
            vehicle_count=len(vehicle_ids),
            total_trips=total_trips,
            completed_trips=completed_trips,
            total_revenue=total_revenue,
            average_rating=average_rating,
            rating_count=rating_count,
        )

    async def _count_users_with_role(self, role_slug: str) -> int:
        result = await self._session.execute(
            select(func.count(UserRole.user_id.distinct()))
            .select_from(UserRole)
            .join(Role, Role.id == UserRole.role_id)
            .join(User, User.id == UserRole.user_id)
            .where(Role.slug == role_slug, User.deleted_at.is_(None))
        )
        return result.scalar_one()

    async def get_platform_overview(self) -> PlatformOverview:
        total_users_result = await self._session.execute(
            select(func.count(User.id)).where(User.deleted_at.is_(None))
        )
        total_users = total_users_result.scalar_one()

        total_passengers = await self._count_users_with_role("passenger")
        total_drivers = await self._count_users_with_role("driver")
        total_fleet_owners = await self._count_users_with_role("fleet_owner")

        total_bookings_result = await self._session.execute(select(func.count(Booking.id)))
        total_bookings = total_bookings_result.scalar_one()

        completed_bookings_result = await self._session.execute(
            select(func.count(Booking.id)).where(Booking.status == BookingStatus.COMPLETED)
        )
        completed_bookings = completed_bookings_result.scalar_one()

        revenue_result = await self._session.execute(
            select(func.coalesce(func.sum(Payment.amount), 0)).where(
                Payment.status.in_([PaymentStatus.SUCCESSFUL, PaymentStatus.PARTIALLY_REFUNDED])
            )
        )
        total_revenue = Decimal(str(revenue_result.scalar_one()))

        active_trips_result = await self._session.execute(
            select(func.count(Trip.id)).where(
                Trip.status.in_([TripStatus.BOARDING, TripStatus.IN_PROGRESS, TripStatus.PAUSED])
            )
        )
        active_trips = active_trips_result.scalar_one()

        open_complaints_result = await self._session.execute(
            select(func.count(Complaint.id)).where(
                Complaint.status.in_([ComplaintStatus.OPEN, ComplaintStatus.IN_REVIEW])
            )
        )
        open_complaints = open_complaints_result.scalar_one()

        active_sos_result = await self._session.execute(
            select(func.count(SosAlert.id)).where(
                SosAlert.status.in_([SosAlertStatus.ACTIVE, SosAlertStatus.ACKNOWLEDGED])
            )
        )
        active_sos_alerts = active_sos_result.scalar_one()

        return PlatformOverview(
            total_users=total_users,
            total_passengers=total_passengers,
            total_drivers=total_drivers,
            total_fleet_owners=total_fleet_owners,
            total_bookings=total_bookings,
            completed_bookings=completed_bookings,
            total_revenue=total_revenue,
            active_trips=active_trips,
            open_complaints=open_complaints,
            active_sos_alerts=active_sos_alerts,
        )
