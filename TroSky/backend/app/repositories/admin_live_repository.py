"""Queries behind the admin dashboard's alerts feed, global search, SOS
details and trip replay."""

from __future__ import annotations

import re
import uuid
from dataclasses import dataclass
from datetime import date, datetime
from decimal import Decimal
from typing import Any

from geoalchemy2 import Geometry
from sqlalchemy import (
    ColumnElement,
    Select,
    String,
    cast,
    func,
    literal,
    literal_column,
    or_,
    select,
)
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.bookings import Booking
from app.models.drivers import (
    ApprovalStatus,
    DocumentStatus,
    Driver,
    DriverDocument,
    DriverStatusHistory,
)
from app.models.identity import User, UserProfile
from app.models.payments import Payment
from app.models.routes import Route
from app.models.safety import SosAlert, SosAlertStatus, SosEscalation
from app.models.tracking import TripLocation
from app.models.trips import Trip
from app.models.vehicles import Fleet, FleetOwner, Vehicle, VehicleDocument, VehicleStatusHistory

WAITING_FOR_APPROVAL = (ApprovalStatus.PENDING, ApprovalStatus.UNDER_REVIEW)


def _contains(text: str) -> str:
    """An ILIKE pattern matching ``text`` anywhere, wildcards escaped."""
    escaped = text.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
    return f"%{escaped}%"


def _starts_with(text: str) -> str:
    escaped = text.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
    return f"{escaped}%"


def _phone_matches(column: Any, query: str) -> ColumnElement[bool] | None:
    """Digits typed in any format -- ``024 555 0201``, ``+233245550201`` --
    against the stored number, local ``0`` or international ``233``."""
    digits = re.sub(r"\D", "", query)
    if len(digits) < 3:
        return None
    stored = func.regexp_replace(column, r"\D", "", "g")
    forms = {digits}
    if digits.startswith("0"):
        forms.add("233" + digits[1:])
    return or_(*(stored.like(f"%{form}%") for form in forms))


def _uuid(query: str) -> uuid.UUID | None:
    try:
        return uuid.UUID(query)
    except ValueError:
        return None


@dataclass(frozen=True, slots=True)
class ActiveSos:
    id: uuid.UUID
    trip_id: uuid.UUID | None
    triggered_by: uuid.UUID
    name: str | None
    phone: str
    raised_at: datetime


@dataclass(frozen=True, slots=True)
class ExpiringDocument:
    owner_type: str  # "driver" or "vehicle"
    owner_id: uuid.UUID
    owner_label: str
    document_type: str
    expires_on: date


@dataclass(frozen=True, slots=True)
class WaitingApproval:
    kind: str  # "driver" or "vehicle"
    id: uuid.UUID
    label: str
    status: ApprovalStatus
    waiting_since: datetime


@dataclass(frozen=True, slots=True)
class Hit:
    id: uuid.UUID
    title: str
    subtitle: str | None
    status: str | None


@dataclass(frozen=True, slots=True)
class Point:
    latitude: float
    longitude: float
    speed_kmh: Decimal | None
    heading_degrees: Decimal | None
    accuracy_meters: Decimal | None
    recorded_at: datetime


def _driver_label() -> Any:
    return func.coalesce(UserProfile.full_name, User.phone_number)


class AdminLiveRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def _count(self, stmt: Select[Any]) -> int:
        return int(
            await self._session.scalar(select(func.count()).select_from(stmt.subquery())) or 0
        )

    # ------------------------------------------------------------- alerts
    async def active_sos(self, *, limit: int) -> tuple[list[ActiveSos], int]:
        """Alerts nobody has picked up yet, oldest first."""
        stmt = (
            select(
                SosAlert.id,
                SosAlert.trip_id,
                SosAlert.triggered_by,
                UserProfile.full_name,
                User.phone_number,
                SosAlert.created_at,
            )
            .join(User, User.id == SosAlert.triggered_by)
            .outerjoin(UserProfile, UserProfile.user_id == SosAlert.triggered_by)
            .where(SosAlert.status == SosAlertStatus.ACTIVE)
        )
        rows = await self._session.execute(stmt.order_by(SosAlert.created_at).limit(limit))
        return [ActiveSos(*row) for row in rows.all()], await self._count(stmt)

    async def expiring_documents(
        self, *, until: date, drivers: bool, vehicles: bool, limit: int
    ) -> tuple[list[ExpiringDocument], int]:
        """For each approved driver or vehicle, each kind of document whose
        latest approved copy expires by ``until`` -- or has expired. A
        renewed document (a newer approved copy) clears the alert."""
        selects: list[Select[Any]] = []
        if drivers:
            expires = func.max(DriverDocument.expiry_date)
            selects.append(
                select(
                    literal("driver").label("owner_type"),
                    Driver.id.label("owner_id"),
                    func.min(_driver_label()).label("owner_label"),
                    cast(DriverDocument.document_type, String).label("document_type"),
                    expires.label("expires_on"),
                )
                .join(Driver, Driver.id == DriverDocument.driver_id)
                .join(User, User.id == Driver.user_id)
                .outerjoin(UserProfile, UserProfile.user_id == Driver.user_id)
                .where(
                    DriverDocument.status == DocumentStatus.APPROVED,
                    DriverDocument.expiry_date.is_not(None),
                    Driver.status == ApprovalStatus.APPROVED,
                )
                .group_by(Driver.id, DriverDocument.document_type)
                .having(expires <= until)
            )
        if vehicles:
            expires = func.max(VehicleDocument.expiry_date)
            selects.append(
                select(
                    literal("vehicle").label("owner_type"),
                    Vehicle.id.label("owner_id"),
                    func.min(Vehicle.registration_number).label("owner_label"),
                    cast(VehicleDocument.document_type, String).label("document_type"),
                    expires.label("expires_on"),
                )
                .join(Vehicle, Vehicle.id == VehicleDocument.vehicle_id)
                .where(
                    VehicleDocument.status == DocumentStatus.APPROVED,
                    VehicleDocument.expiry_date.is_not(None),
                    Vehicle.status == ApprovalStatus.APPROVED,
                )
                .group_by(Vehicle.id, VehicleDocument.document_type)
                .having(expires <= until)
            )
        found: list[ExpiringDocument] = []
        total = 0
        for stmt in selects:
            rows = await self._session.execute(
                stmt.order_by(literal_column("expires_on")).limit(limit)
            )
            found.extend(ExpiringDocument(*row) for row in rows.all())
            total += await self._count(stmt)
        found.sort(key=lambda doc: doc.expires_on)
        return found[:limit], total

    async def waiting_approvals(
        self, *, waiting_before: datetime, drivers: bool, vehicles: bool, limit: int
    ) -> tuple[list[WaitingApproval], int]:
        """Drivers and vehicles waiting for a decision since before
        ``waiting_before``: since they last entered the queue, or since they
        registered."""
        found: list[WaitingApproval] = []
        total = 0
        if drivers:
            entered = (
                select(func.max(DriverStatusHistory.changed_at))
                .where(
                    DriverStatusHistory.driver_id == Driver.id,
                    DriverStatusHistory.to_status.in_(WAITING_FOR_APPROVAL),
                )
                .correlate(Driver)
                .scalar_subquery()
            )
            since = func.coalesce(entered, Driver.created_at)
            stmt = (
                select(
                    literal("driver"),
                    Driver.id,
                    _driver_label(),
                    Driver.status,
                    since.label("since"),
                )
                .join(User, User.id == Driver.user_id)
                .outerjoin(UserProfile, UserProfile.user_id == Driver.user_id)
                .where(Driver.status.in_(WAITING_FOR_APPROVAL), since < waiting_before)
            )
            rows = await self._session.execute(stmt.order_by(since).limit(limit))
            found.extend(WaitingApproval(*row) for row in rows.all())
            total += await self._count(stmt)
        if vehicles:
            entered = (
                select(func.max(VehicleStatusHistory.changed_at))
                .where(
                    VehicleStatusHistory.vehicle_id == Vehicle.id,
                    VehicleStatusHistory.to_status.in_(WAITING_FOR_APPROVAL),
                )
                .correlate(Vehicle)
                .scalar_subquery()
            )
            since = func.coalesce(entered, Vehicle.created_at)
            stmt = select(
                literal("vehicle"),
                Vehicle.id,
                Vehicle.registration_number,
                Vehicle.status,
                since.label("since"),
            ).where(Vehicle.status.in_(WAITING_FOR_APPROVAL), since < waiting_before)
            rows = await self._session.execute(stmt.order_by(since).limit(limit))
            found.extend(WaitingApproval(*row) for row in rows.all())
            total += await self._count(stmt)
        found.sort(key=lambda waiting: waiting.waiting_since)
        return found[:limit], total

    # ------------------------------------------------------------- search
    async def search_users(self, query: str, *, limit: int) -> list[Hit]:
        conditions: list[ColumnElement[bool]] = [
            UserProfile.full_name.ilike(_contains(query), escape="\\"),
            cast(User.email, String).ilike(_contains(query), escape="\\"),
        ]
        phone = _phone_matches(User.phone_number, query)
        if phone is not None:
            conditions.append(phone)
        if (exact := _uuid(query)) is not None:
            conditions.append(User.id == exact)
        rows = await self._session.execute(
            select(
                User.id,
                UserProfile.full_name,
                User.phone_number,
                User.email,
                User.is_suspended,
                User.is_active,
            )
            .outerjoin(UserProfile, UserProfile.user_id == User.id)
            .where(User.deleted_at.is_(None), or_(*conditions))
            .order_by(UserProfile.full_name, User.created_at.desc())
            .limit(limit)
        )
        return [
            Hit(
                id=user_id,
                title=name or phone_number,
                subtitle=" · ".join(part for part in (phone_number, email) if part),
                status="suspended" if suspended else ("active" if active else "inactive"),
            )
            for user_id, name, phone_number, email, suspended, active in rows.all()
        ]

    async def search_drivers(self, query: str, *, limit: int) -> list[Hit]:
        conditions: list[ColumnElement[bool]] = [
            UserProfile.full_name.ilike(_contains(query), escape="\\"),
            Driver.license_number.ilike(_contains(query), escape="\\"),
        ]
        phone = _phone_matches(User.phone_number, query)
        if phone is not None:
            conditions.append(phone)
        if (exact := _uuid(query)) is not None:
            conditions.append(Driver.id == exact)
        rows = await self._session.execute(
            select(Driver.id, _driver_label(), Driver.license_number, Driver.status)
            .join(User, User.id == Driver.user_id)
            .outerjoin(UserProfile, UserProfile.user_id == Driver.user_id)
            .where(or_(*conditions))
            .order_by(_driver_label())
            .limit(limit)
        )
        return [
            Hit(id=driver_id, title=name, subtitle=f"Licence {licence}", status=status.value)
            for driver_id, name, licence, status in rows.all()
        ]

    async def search_vehicles(self, query: str, *, limit: int) -> list[Hit]:
        """By plate, however it is spaced or dashed: ``GR 1234-24``,
        ``gr123424``."""
        plate = re.sub(r"[\s-]", "", query).upper()
        conditions: list[ColumnElement[bool]] = []
        if plate:
            stored = func.upper(func.regexp_replace(Vehicle.registration_number, r"[\s-]", "", "g"))
            conditions.append(stored.like(_contains(plate), escape="\\"))
        if (exact := _uuid(query)) is not None:
            conditions.append(Vehicle.id == exact)
        if not conditions:
            return []
        rows = await self._session.execute(
            select(
                Vehicle.id, Vehicle.registration_number, Vehicle.make, Vehicle.model, Vehicle.status
            )
            .where(or_(*conditions))
            .order_by(Vehicle.registration_number)
            .limit(limit)
        )
        return [
            Hit(
                id=vehicle_id,
                title=registration,
                subtitle=" ".join(part for part in (make, model) if part) or None,
                status=status.value,
            )
            for vehicle_id, registration, make, model, status in rows.all()
        ]

    async def search_trips(self, query: str, *, limit: int) -> list[Hit]:
        """By id (or its first characters, as the dashboard shows them), or
        by route name -- the most recent departures first."""
        conditions: list[ColumnElement[bool]] = [Route.name.ilike(_contains(query), escape="\\")]
        if re.fullmatch(r"[0-9a-fA-F-]{6,36}", query):
            conditions.append(cast(Trip.id, String).like(_starts_with(query.lower()), escape="\\"))
        rows = await self._session.execute(
            select(Trip.id, Route.name, Trip.scheduled_departure_at, Trip.status)
            .join(Route, Route.id == Trip.route_id)
            .where(or_(*conditions))
            .order_by(Trip.scheduled_departure_at.desc())
            .limit(limit)
        )
        return [
            Hit(
                id=trip_id,
                title=route_name,
                subtitle=f"Departs {departs:%Y-%m-%d %H:%M} UTC",
                status=status.value,
            )
            for trip_id, route_name, departs, status in rows.all()
        ]

    async def search_bookings(self, query: str, *, limit: int) -> list[Hit]:
        conditions: list[ColumnElement[bool]] = [
            Booking.booking_reference.ilike(_starts_with(query), escape="\\")
        ]
        if (exact := _uuid(query)) is not None:
            conditions.append(Booking.id == exact)
        rows = await self._session.execute(
            select(Booking.id, Booking.booking_reference, UserProfile.full_name, Booking.status)
            .outerjoin(UserProfile, UserProfile.user_id == Booking.passenger_id)
            .where(or_(*conditions))
            .order_by(Booking.created_at.desc())
            .limit(limit)
        )
        return [
            Hit(id=booking_id, title=reference, subtitle=passenger, status=status.value)
            for booking_id, reference, passenger, status in rows.all()
        ]

    async def search_payments(self, query: str, *, limit: int) -> list[Hit]:
        conditions: list[ColumnElement[bool]] = [
            Payment.internal_reference.ilike(_starts_with(query), escape="\\"),
            Payment.provider_reference.ilike(_starts_with(query), escape="\\"),
        ]
        if (exact := _uuid(query)) is not None:
            conditions.append(Payment.id == exact)
        rows = await self._session.execute(
            select(
                Payment.id,
                Payment.internal_reference,
                Payment.amount,
                Payment.currency,
                Payment.channel,
                Payment.status,
            )
            .where(or_(*conditions))
            .order_by(Payment.created_at.desc())
            .limit(limit)
        )
        return [
            Hit(
                id=payment_id,
                title=reference,
                subtitle=f"{amount} {currency} by {channel.value.replace('_', ' ')}",
                status=status.value,
            )
            for payment_id, reference, amount, currency, channel, status in rows.all()
        ]

    # -------------------------------------------------------- SOS details
    async def person(self, user_id: uuid.UUID) -> tuple[str | None, str] | None:
        row = (
            await self._session.execute(
                select(UserProfile.full_name, User.phone_number)
                .select_from(User)
                .outerjoin(UserProfile, UserProfile.user_id == User.id)
                .where(User.id == user_id)
            )
        ).first()
        return (row[0], row[1]) if row is not None else None

    async def fleet_owner(self, fleet_id: uuid.UUID) -> tuple[str, str] | None:
        """The business name and phone number of a fleet's owner."""
        row = (
            await self._session.execute(
                select(FleetOwner.business_name, User.phone_number)
                .select_from(Fleet)
                .join(FleetOwner, FleetOwner.id == Fleet.fleet_owner_id)
                .join(User, User.id == FleetOwner.user_id)
                .where(Fleet.id == fleet_id)
            )
        ).first()
        return (row[0], row[1]) if row is not None else None

    async def escalations(self, alert_id: uuid.UUID) -> list[tuple[SosEscalation, str | None]]:
        rows = await self._session.execute(
            select(SosEscalation, UserProfile.full_name)
            .outerjoin(UserProfile, UserProfile.user_id == SosEscalation.logged_by)
            .where(SosEscalation.sos_alert_id == alert_id)
            .order_by(SosEscalation.contacted_at, SosEscalation.id)
        )
        return list(rows.tuples().all())

    # -------------------------------------------------------------- track
    async def track(
        self,
        trip_id: uuid.UUID,
        *,
        since: datetime | None,
        until: datetime | None,
        limit: int,
    ) -> list[Point]:
        """Recorded positions, oldest first; up to ``limit`` + 1, so the
        caller can tell there were more."""
        point = cast(TripLocation.location, Geometry)
        stmt = select(
            func.ST_Y(point),
            func.ST_X(point),
            TripLocation.speed_kmh,
            TripLocation.heading_degrees,
            TripLocation.accuracy_meters,
            TripLocation.recorded_at,
        ).where(TripLocation.trip_id == trip_id)
        if since is not None:
            stmt = stmt.where(TripLocation.recorded_at >= since)
        if until is not None:
            stmt = stmt.where(TripLocation.recorded_at < until)
        rows = await self._session.execute(
            stmt.order_by(TripLocation.recorded_at, TripLocation.id).limit(limit + 1)
        )
        return [Point(*row) for row in rows.all()]

    async def last_point(self, trip_id: uuid.UUID) -> Point | None:
        point = cast(TripLocation.location, Geometry)
        row = (
            await self._session.execute(
                select(
                    func.ST_Y(point),
                    func.ST_X(point),
                    TripLocation.speed_kmh,
                    TripLocation.heading_degrees,
                    TripLocation.accuracy_meters,
                    TripLocation.recorded_at,
                )
                .where(TripLocation.trip_id == trip_id)
                .order_by(TripLocation.recorded_at.desc())
                .limit(1)
            )
        ).first()
        return Point(*row) if row is not None else None
