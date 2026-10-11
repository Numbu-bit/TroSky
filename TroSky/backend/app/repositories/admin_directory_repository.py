"""Read models for the admin directory: every vehicle, driver and fleet.

Each list is one query per page (plus one count): the per-row facts -- who
drives a vehicle, whether it is out on a trip, when its insurance expires,
a driver's rating -- are correlated subqueries, so filtering and sorting on
them happens in the database.

Live status, for vehicles and drivers alike:

* ``on_trip`` -- assigned to a trip that is boarding, under way or paused;
* ``idle`` -- not on a trip now, but with a trip still to run today;
* ``offline`` -- neither.

"Today" is the UTC date, which is Ghana's (Africa/Accra is UTC+0 all year).
"""

from __future__ import annotations

import uuid
from collections.abc import Collection
from dataclasses import dataclass
from datetime import UTC, date, datetime, time, timedelta
from decimal import Decimal
from typing import Any, Literal

from sqlalchemy import (
    ColumnElement,
    Select,
    String,
    case,
    cast,
    exists,
    func,
    literal,
    or_,
    select,
)
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import aliased

from app.models.bookings import Booking, BookingStatus
from app.models.drivers import (
    ApprovalStatus,
    DocumentStatus,
    DocumentType,
    Driver,
    DriverAssignment,
    DriverDocument,
)
from app.models.feedback import Rating
from app.models.identity import User, UserProfile
from app.models.routes import Route, Stop
from app.models.safety import Incident
from app.models.trips import Trip, TripDriverAssignment, TripStatus, TripVehicleAssignment
from app.models.vehicles import Fleet, FleetOwner, Vehicle, VehicleDocument, VehicleType

LiveStatus = Literal["on_trip", "idle", "offline"]
_ACTIVE = (TripStatus.BOARDING, TripStatus.IN_PROGRESS, TripStatus.PAUSED)
# Trips that tie a vehicle or driver to a city: recent and upcoming ones.
_CITY_WINDOW_BACK = timedelta(days=30)
_CITY_WINDOW_AHEAD = timedelta(days=7)


def _today_bounds() -> tuple[datetime, datetime]:
    start = datetime.combine(datetime.now(UTC).date(), time.min, tzinfo=UTC)
    return start, start + timedelta(days=1)


# ---------------------------------------------------------------- vehicles
@dataclass(frozen=True, slots=True)
class VehicleRow:
    vehicle_id: uuid.UUID
    registration_number: str
    vehicle_type: VehicleType
    make: str | None
    model: str | None
    year: int | None
    capacity: int
    status: ApprovalStatus
    fleet_id: uuid.UUID
    fleet_name: str
    fleet_owner_id: uuid.UUID
    fleet_owner_name: str
    driver_id: uuid.UUID | None
    driver_name: str | None
    live_status: LiveStatus
    current_trip_id: uuid.UUID | None
    insurance_expiry: date | None
    roadworthy_expiry: date | None
    created_at: datetime


@dataclass(frozen=True, slots=True)
class VehicleFilters:
    vehicle_id: uuid.UUID | None = None
    statuses: Collection[ApprovalStatus] | None = None
    live_statuses: Collection[str] | None = None
    fleet_id: uuid.UUID | None = None
    fleet_owner_id: uuid.UUID | None = None
    city: str | None = None
    expiring_within_days: int | None = None
    query: str | None = None


def _approved_expiry(document_type: DocumentType) -> Any:
    return (
        select(func.max(VehicleDocument.expiry_date))
        .where(
            VehicleDocument.vehicle_id == Vehicle.id,
            VehicleDocument.document_type == document_type,
            VehicleDocument.status == DocumentStatus.APPROVED,
        )
        .correlate(Vehicle)
        .scalar_subquery()
    )


def _vehicle_trip(statuses: Collection[TripStatus], *, today_only: bool = False) -> Any:
    conditions: list[ColumnElement[bool]] = [
        TripVehicleAssignment.vehicle_id == Vehicle.id,
        TripVehicleAssignment.is_active.is_(True),
        Trip.status.in_(list(statuses)),
    ]
    if today_only:
        now = datetime.now(UTC)
        _, end = _today_bounds()
        conditions += [Trip.scheduled_departure_at >= now, Trip.scheduled_departure_at < end]
    return (
        select(Trip.id)
        .join(TripVehicleAssignment, TripVehicleAssignment.trip_id == Trip.id)
        .where(*conditions)
        .order_by(Trip.scheduled_departure_at)
        .limit(1)
        .correlate(Vehicle)
        .scalar_subquery()
    )


def _vehicle_columns() -> Select[Any]:
    current_trip = _vehicle_trip(_ACTIVE)
    next_today = _vehicle_trip([TripStatus.SCHEDULED], today_only=True)
    assignment = (
        select(DriverAssignment.driver_id)
        .where(DriverAssignment.vehicle_id == Vehicle.id, DriverAssignment.is_active.is_(True))
        .order_by(DriverAssignment.assigned_at.desc())
        .limit(1)
        .correlate(Vehicle)
        .scalar_subquery()
    )
    return (
        select(
            Vehicle.id.label("vehicle_id"),
            Vehicle.registration_number,
            Vehicle.vehicle_type,
            Vehicle.make,
            Vehicle.model,
            Vehicle.year,
            Vehicle.capacity,
            Vehicle.status,
            Fleet.id.label("fleet_id"),
            Fleet.name.label("fleet_name"),
            FleetOwner.id.label("fleet_owner_id"),
            FleetOwner.business_name.label("fleet_owner_name"),
            assignment.label("driver_id"),
            current_trip.label("current_trip_id"),
            case(
                (current_trip.is_not(None), literal("on_trip")),
                (next_today.is_not(None), literal("idle")),
                else_=literal("offline"),
            ).label("live_status"),
            _approved_expiry(DocumentType.VEHICLE_INSURANCE).label("insurance_expiry"),
            _approved_expiry(DocumentType.ROADWORTHINESS_CERTIFICATE).label("roadworthy_expiry"),
            Vehicle.created_at,
        )
        .select_from(Vehicle)
        .join(Fleet, Fleet.id == Vehicle.fleet_id)
        .join(FleetOwner, FleetOwner.id == Fleet.fleet_owner_id)
    )


def _serves_city(
    assignment: type[TripVehicleAssignment] | type[TripDriverAssignment],
    key: Any,
    owner: Any,
    city: str,
) -> ColumnElement[bool]:
    """Has a recent or upcoming trip starting in ``city``."""
    now = datetime.now(UTC)
    origin = aliased(Stop)
    return exists(
        select(1)
        .select_from(assignment)
        .join(Trip, Trip.id == assignment.trip_id)
        .join(Route, Route.id == Trip.route_id)
        .join(origin, origin.id == Route.origin_stop_id)
        .where(
            key == owner,
            Trip.scheduled_departure_at >= now - _CITY_WINDOW_BACK,
            Trip.scheduled_departure_at < now + _CITY_WINDOW_AHEAD,
            func.lower(origin.city) == city.strip().lower(),
        )
    )


@dataclass(frozen=True, slots=True)
class DriverRow:
    driver_id: uuid.UUID
    user_id: uuid.UUID
    full_name: str | None
    phone_number: str
    email: str | None
    status: ApprovalStatus
    license_number: str
    license_expiry: date
    fleet_id: uuid.UUID | None
    fleet_name: str | None
    vehicle_id: uuid.UUID | None
    vehicle_registration_number: str | None
    live_status: LiveStatus
    current_trip_id: uuid.UUID | None
    average_rating: Decimal | None
    rating_count: int
    last_active_at: datetime | None
    created_at: datetime


@dataclass(frozen=True, slots=True)
class DriverFilters:
    driver_id: uuid.UUID | None = None
    statuses: Collection[ApprovalStatus] | None = None
    live_statuses: Collection[str] | None = None
    fleet_id: uuid.UUID | None = None
    city: str | None = None
    expiring_within_days: int | None = None
    query: str | None = None


@dataclass(frozen=True, slots=True)
class FleetRow:
    fleet_id: uuid.UUID
    fleet_name: str
    is_active: bool
    fleet_owner_id: uuid.UUID
    business_name: str
    owner_status: ApprovalStatus
    owner_name: str | None
    owner_phone: str
    vehicle_count: int
    approved_vehicles: int
    active_now: int
    driver_count: int
    vehicles_used_7d: int
    revenue_30d: Decimal
    average_rating: Decimal | None
    created_at: datetime

    @property
    def utilization_7d(self) -> Decimal | None:
        """Share of approved vehicles that completed a trip in the last week."""
        if not self.approved_vehicles:
            return None
        return (Decimal(self.vehicles_used_7d) / self.approved_vehicles).quantize(Decimal("0.01"))


class AdminDirectoryRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    # ------------------------------------------------------------ vehicles
    async def list_vehicles(
        self,
        filters: VehicleFilters,
        *,
        sort: str,
        descending: bool,
        limit: int,
        offset: int,
    ) -> tuple[list[VehicleRow], int]:
        rows = _vehicle_columns()
        conditions: list[ColumnElement[bool]] = []
        if filters.vehicle_id is not None:
            conditions.append(Vehicle.id == filters.vehicle_id)
        if filters.statuses:
            conditions.append(Vehicle.status.in_(list(filters.statuses)))
        if filters.fleet_id is not None:
            conditions.append(Vehicle.fleet_id == filters.fleet_id)
        if filters.fleet_owner_id is not None:
            conditions.append(FleetOwner.id == filters.fleet_owner_id)
        if filters.query:
            conditions.append(Vehicle.registration_number.ilike(f"%{filters.query.strip()}%"))
        if filters.city:
            conditions.append(
                _serves_city(
                    TripVehicleAssignment,
                    TripVehicleAssignment.vehicle_id,
                    Vehicle.id,
                    filters.city,
                )
            )
        page = rows.where(*conditions).subquery("vehicle_rows")
        outer: list[ColumnElement[bool]] = []
        if filters.live_statuses:
            outer.append(page.c.live_status.in_(list(filters.live_statuses)))
        if filters.expiring_within_days is not None:
            horizon = datetime.now(UTC).date() + timedelta(days=filters.expiring_within_days)
            outer.append(
                or_(page.c.insurance_expiry <= horizon, page.c.roadworthy_expiry <= horizon)
            )
        total = await self._count(page, outer)
        order = page.c[sort].desc().nulls_last() if descending else page.c[sort].asc().nulls_last()
        result = await self._session.execute(
            select(page)
            .where(*outer)
            .order_by(order, page.c.vehicle_id)
            .limit(limit)
            .offset(offset)
        )
        found = result.mappings().all()
        names = await self.driver_names({row["driver_id"] for row in found if row["driver_id"]})
        return [
            VehicleRow(**{**row, "driver_name": names.get(row["driver_id"])}) for row in found
        ], total

    async def _count(self, page: Any, outer: list[ColumnElement[bool]]) -> int:
        result = await self._session.execute(select(func.count()).select_from(page).where(*outer))
        return int(result.scalar_one())

    async def driver_names(self, driver_ids: Collection[uuid.UUID]) -> dict[uuid.UUID, str | None]:
        if not driver_ids:
            return {}
        result = await self._session.execute(
            select(Driver.id, UserProfile.full_name)
            .outerjoin(UserProfile, UserProfile.user_id == Driver.user_id)
            .where(Driver.id.in_(list(driver_ids)))
        )
        return {row.id: row.full_name for row in result}

    async def vehicle_documents(self, vehicle_id: uuid.UUID) -> list[VehicleDocument]:
        result = await self._session.execute(
            select(VehicleDocument)
            .where(VehicleDocument.vehicle_id == vehicle_id)
            .order_by(VehicleDocument.created_at.desc())
        )
        return list(result.scalars().all())

    async def vehicle_activity(
        self, vehicle_id: uuid.UUID, *, since: datetime
    ) -> tuple[int, int, Decimal]:
        """``(trips, completed trips, fare revenue)`` for trips departing since."""
        trips = (
            select(Trip.id, Trip.status)
            .join(TripVehicleAssignment, TripVehicleAssignment.trip_id == Trip.id)
            .where(
                TripVehicleAssignment.vehicle_id == vehicle_id,
                TripVehicleAssignment.is_active.is_(True),
                Trip.scheduled_departure_at >= since,
                Trip.scheduled_departure_at <= datetime.now(UTC),
            )
            .subquery()
        )
        counts = (
            await self._session.execute(
                select(
                    func.count(trips.c.id),
                    func.count(trips.c.id).filter(trips.c.status == TripStatus.COMPLETED),
                )
            )
        ).one()
        revenue = await self._session.scalar(
            select(func.coalesce(func.sum(Booking.fare_amount), 0)).where(
                Booking.trip_id.in_(select(trips.c.id)),
                Booking.status == BookingStatus.COMPLETED,
            )
        )
        return int(counts[0]), int(counts[1]), Decimal(str(revenue or 0))

    async def vehicle_incidents(self, vehicle_id: uuid.UUID, *, limit: int) -> list[Incident]:
        result = await self._session.execute(
            select(Incident)
            .join(TripVehicleAssignment, TripVehicleAssignment.trip_id == Incident.trip_id)
            .where(TripVehicleAssignment.vehicle_id == vehicle_id)
            .order_by(Incident.created_at.desc())
            .limit(limit)
        )
        return list(result.scalars().unique().all())

    # ------------------------------------------------------------- drivers
    async def list_drivers(
        self,
        filters: DriverFilters,
        *,
        sort: str,
        descending: bool,
        limit: int,
        offset: int,
    ) -> tuple[list[DriverRow], int]:
        def trip_for(statuses: Collection[TripStatus], *, today_only: bool = False) -> Any:
            conditions: list[ColumnElement[bool]] = [
                TripDriverAssignment.driver_id == Driver.id,
                TripDriverAssignment.is_active.is_(True),
                Trip.status.in_(list(statuses)),
            ]
            if today_only:
                _, end = _today_bounds()
                conditions += [
                    Trip.scheduled_departure_at >= datetime.now(UTC),
                    Trip.scheduled_departure_at < end,
                ]
            return (
                select(Trip.id)
                .join(TripDriverAssignment, TripDriverAssignment.trip_id == Trip.id)
                .where(*conditions)
                .order_by(Trip.scheduled_departure_at)
                .limit(1)
                .correlate(Driver)
                .scalar_subquery()
            )

        current_trip = trip_for(_ACTIVE)
        next_today = trip_for([TripStatus.SCHEDULED], today_only=True)
        latest_assignment = (
            select(DriverAssignment.id)
            .where(DriverAssignment.driver_id == Driver.id, DriverAssignment.is_active.is_(True))
            .order_by(DriverAssignment.assigned_at.desc())
            .limit(1)
            .correlate(Driver)
            .scalar_subquery()
        )
        last_trip = (
            select(func.max(func.coalesce(Trip.actual_arrival_at, Trip.actual_departure_at)))
            .join(TripDriverAssignment, TripDriverAssignment.trip_id == Trip.id)
            .where(TripDriverAssignment.driver_id == Driver.id)
            .correlate(Driver)
            .scalar_subquery()
        )
        earliest_document_expiry = (
            select(func.min(DriverDocument.expiry_date))
            .where(
                DriverDocument.driver_id == Driver.id,
                DriverDocument.status == DocumentStatus.APPROVED,
            )
            .correlate(Driver)
            .scalar_subquery()
        )
        ratings = (
            select(
                Rating.driver_id, func.avg(Rating.score).label("average"), func.count().label("n")
            )
            .group_by(Rating.driver_id)
            .subquery("driver_ratings")
        )
        rows = (
            select(
                Driver.id.label("driver_id"),
                Driver.user_id,
                UserProfile.full_name,
                User.phone_number,
                cast(User.email, String).label("email"),
                Driver.status,
                Driver.license_number,
                Driver.license_expiry,
                DriverAssignment.fleet_id,
                Fleet.name.label("fleet_name"),
                DriverAssignment.vehicle_id,
                Vehicle.registration_number.label("vehicle_registration_number"),
                current_trip.label("current_trip_id"),
                case(
                    (current_trip.is_not(None), literal("on_trip")),
                    (next_today.is_not(None), literal("idle")),
                    else_=literal("offline"),
                ).label("live_status"),
                func.round(ratings.c.average, 2).label("average_rating"),
                func.coalesce(ratings.c.n, 0).label("rating_count"),
                func.greatest(User.last_login_at, last_trip).label("last_active_at"),
                func.least(Driver.license_expiry, earliest_document_expiry).label(
                    "earliest_expiry"
                ),
                Driver.created_at,
            )
            .select_from(Driver)
            .join(User, User.id == Driver.user_id)
            .outerjoin(UserProfile, UserProfile.user_id == Driver.user_id)
            .outerjoin(DriverAssignment, DriverAssignment.id == latest_assignment)
            .outerjoin(Fleet, Fleet.id == DriverAssignment.fleet_id)
            .outerjoin(Vehicle, Vehicle.id == DriverAssignment.vehicle_id)
            .outerjoin(ratings, ratings.c.driver_id == Driver.id)
        )
        conditions: list[ColumnElement[bool]] = [User.deleted_at.is_(None)]
        if filters.driver_id is not None:
            conditions.append(Driver.id == filters.driver_id)
        if filters.statuses:
            conditions.append(Driver.status.in_(list(filters.statuses)))
        if filters.fleet_id is not None:
            conditions.append(DriverAssignment.fleet_id == filters.fleet_id)
        if filters.query:
            needle = f"%{filters.query.strip()}%"
            conditions.append(
                or_(
                    UserProfile.full_name.ilike(needle),
                    User.phone_number.ilike(needle),
                    Driver.license_number.ilike(needle),
                )
            )
        if filters.city:
            conditions.append(
                _serves_city(
                    TripDriverAssignment, TripDriverAssignment.driver_id, Driver.id, filters.city
                )
            )
        page = rows.where(*conditions).subquery("driver_rows")
        outer: list[ColumnElement[bool]] = []
        if filters.live_statuses:
            outer.append(page.c.live_status.in_(list(filters.live_statuses)))
        if filters.expiring_within_days is not None:
            horizon = datetime.now(UTC).date() + timedelta(days=filters.expiring_within_days)
            outer.append(page.c.earliest_expiry <= horizon)
        total = await self._count(page, outer)
        order = page.c[sort].desc().nulls_last() if descending else page.c[sort].asc().nulls_last()
        result = await self._session.execute(
            select(page).where(*outer).order_by(order, page.c.driver_id).limit(limit).offset(offset)
        )
        return [
            DriverRow(**{k: v for k, v in row.items() if k != "earliest_expiry"})
            for row in result.mappings().all()
        ], total

    async def driver_documents(self, driver_id: uuid.UUID) -> list[DriverDocument]:
        result = await self._session.execute(
            select(DriverDocument)
            .where(DriverDocument.driver_id == driver_id)
            .order_by(DriverDocument.created_at.desc())
        )
        return list(result.scalars().all())

    async def driver_assignments(
        self, driver_id: uuid.UUID
    ) -> list[tuple[DriverAssignment, Vehicle]]:
        result = await self._session.execute(
            select(DriverAssignment, Vehicle)
            .join(Vehicle, Vehicle.id == DriverAssignment.vehicle_id)
            .where(DriverAssignment.driver_id == driver_id, DriverAssignment.is_active.is_(True))
            .order_by(DriverAssignment.assigned_at.desc())
        )
        return [(row[0], row[1]) for row in result.all()]

    # -------------------------------------------------------------- fleets
    async def list_fleets(
        self,
        *,
        owner_statuses: Collection[ApprovalStatus] | None,
        query: str | None,
        sort: str,
        descending: bool,
        limit: int,
        offset: int,
        fleet_id: uuid.UUID | None = None,
    ) -> tuple[list[FleetRow], int]:
        now = datetime.now(UTC)
        fleet_vehicle = Vehicle.fleet_id == Fleet.id

        def count_vehicles(*conditions: ColumnElement[bool]) -> Any:
            return (
                select(func.count(Vehicle.id))
                .where(fleet_vehicle, *conditions)
                .correlate(Fleet)
                .scalar_subquery()
            )

        fleet_trips = (
            select(Trip.id)
            .join(TripVehicleAssignment, TripVehicleAssignment.trip_id == Trip.id)
            .join(Vehicle, Vehicle.id == TripVehicleAssignment.vehicle_id)
            .where(fleet_vehicle, TripVehicleAssignment.is_active.is_(True))
            # Nested two levels down: correlate explicitly, or Fleet would be
            # pulled into this subquery's own FROM and match every fleet.
            .correlate(Fleet)
        )
        on_trip_now = exists(
            select(1)
            .select_from(TripVehicleAssignment)
            .join(Trip, Trip.id == TripVehicleAssignment.trip_id)
            .where(
                TripVehicleAssignment.vehicle_id == Vehicle.id,
                TripVehicleAssignment.is_active.is_(True),
                Trip.status.in_(list(_ACTIVE)),
            )
        )
        used_recently = exists(
            select(1)
            .select_from(TripVehicleAssignment)
            .join(Trip, Trip.id == TripVehicleAssignment.trip_id)
            .where(
                TripVehicleAssignment.vehicle_id == Vehicle.id,
                Trip.status == TripStatus.COMPLETED,
                Trip.scheduled_departure_at >= now - timedelta(days=7),
            )
        )
        revenue = (
            select(func.coalesce(func.sum(Booking.fare_amount), 0))
            .where(
                Booking.status == BookingStatus.COMPLETED,
                Booking.trip_id.in_(
                    fleet_trips.where(Trip.scheduled_departure_at >= now - timedelta(days=30))
                ),
            )
            .correlate(Fleet)
            .scalar_subquery()
        )
        rating = (
            select(func.round(func.avg(Rating.score), 2))
            .where(Rating.trip_id.in_(fleet_trips))
            .correlate(Fleet)
            .scalar_subquery()
        )
        drivers = (
            select(func.count(func.distinct(DriverAssignment.driver_id)))
            .where(DriverAssignment.fleet_id == Fleet.id, DriverAssignment.is_active.is_(True))
            .correlate(Fleet)
            .scalar_subquery()
        )
        rows = (
            select(
                Fleet.id.label("fleet_id"),
                Fleet.name.label("fleet_name"),
                Fleet.is_active,
                FleetOwner.id.label("fleet_owner_id"),
                FleetOwner.business_name,
                FleetOwner.status.label("owner_status"),
                UserProfile.full_name.label("owner_name"),
                User.phone_number.label("owner_phone"),
                count_vehicles().label("vehicle_count"),
                count_vehicles(Vehicle.status == ApprovalStatus.APPROVED).label(
                    "approved_vehicles"
                ),
                count_vehicles(on_trip_now).label("active_now"),
                drivers.label("driver_count"),
                count_vehicles(Vehicle.status == ApprovalStatus.APPROVED, used_recently).label(
                    "vehicles_used_7d"
                ),
                revenue.label("revenue_30d"),
                rating.label("average_rating"),
                Fleet.created_at,
            )
            .select_from(Fleet)
            .join(FleetOwner, FleetOwner.id == Fleet.fleet_owner_id)
            .join(User, User.id == FleetOwner.user_id)
            .outerjoin(UserProfile, UserProfile.user_id == FleetOwner.user_id)
        )
        conditions: list[ColumnElement[bool]] = []
        if fleet_id is not None:
            conditions.append(Fleet.id == fleet_id)
        if owner_statuses:
            conditions.append(FleetOwner.status.in_(list(owner_statuses)))
        if query:
            needle = f"%{query.strip()}%"
            conditions.append(or_(Fleet.name.ilike(needle), FleetOwner.business_name.ilike(needle)))
        page = rows.where(*conditions).subquery("fleet_rows")
        total = await self._count(page, [])
        order = page.c[sort].desc().nulls_last() if descending else page.c[sort].asc().nulls_last()
        result = await self._session.execute(
            select(page).order_by(order, page.c.fleet_id).limit(limit).offset(offset)
        )
        return [
            FleetRow(**{**row, "revenue_30d": Decimal(str(row["revenue_30d"]))})
            for row in result.mappings().all()
        ], total


__all__ = [
    "AdminDirectoryRepository",
    "DriverFilters",
    "DriverRow",
    "FleetRow",
    "LiveStatus",
    "VehicleFilters",
    "VehicleRow",
]
