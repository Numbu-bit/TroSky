"""Database access for trips, their driver/vehicle assignments, status
history, and domain events.

``get_for_update`` uses ``SELECT ... FOR UPDATE`` so trip state transitions
are safe under concurrent requests (e.g. an admin cancelling a trip at the
same moment a driver starts it) — the database row lock, not application
logic alone, is what prevents the race.
"""

from __future__ import annotations

import uuid
from collections.abc import Collection
from datetime import datetime
from decimal import Decimal

from sqlalchemy import exists, func, literal, select, union_all
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.sql.selectable import Subquery

from app.models.drivers import Driver
from app.models.routes import Route, RouteStop
from app.models.trips import (
    Trip,
    TripDriverAssignment,
    TripEvent,
    TripEventType,
    TripStatus,
    TripStatusHistory,
    TripVehicleAssignment,
)
from app.models.vehicles import Vehicle

# Sits after any real sequence number, so a route's destination always
# orders last even when it is missing from route_stops.
_LAST_POSITION = 2_147_483_647


def _route_stop_positions() -> Subquery:
    """Every stop a route serves, with its order along the route.

    Routes created through the admin API list origin, intermediates and
    destination in ``route_stops``; routes inserted directly may carry only
    their endpoints on ``routes``. Taking the union of both makes the order
    well defined either way. A stop appearing twice (origin at -1 and again
    at sequence 0) is harmless, because callers only ask whether *some*
    valid ordering exists.
    """
    first = select(
        Route.id.label("route_id"),
        Route.origin_stop_id.label("stop_id"),
        literal(-1).label("position"),
    )
    middle = select(
        RouteStop.route_id.label("route_id"),
        RouteStop.stop_id.label("stop_id"),
        RouteStop.sequence_number.label("position"),
    )
    last = select(
        Route.id.label("route_id"),
        Route.destination_stop_id.label("stop_id"),
        literal(_LAST_POSITION).label("position"),
    )
    return union_all(first, middle, last).subquery("route_stop_positions")


class TripRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get_by_id(self, trip_id: uuid.UUID) -> Trip | None:
        result = await self._session.execute(select(Trip).where(Trip.id == trip_id))
        return result.scalar_one_or_none()

    async def get_for_update(self, trip_id: uuid.UUID) -> Trip | None:
        result = await self._session.execute(
            select(Trip).where(Trip.id == trip_id).with_for_update()
        )
        return result.scalar_one_or_none()

    async def create(
        self,
        *,
        route_id: uuid.UUID,
        route_schedule_id: uuid.UUID | None,
        scheduled_departure_at: datetime,
        scheduled_arrival_at: datetime | None,
        fare_amount: Decimal,
        created_by: uuid.UUID | None,
    ) -> Trip:
        trip = Trip(
            route_id=route_id,
            route_schedule_id=route_schedule_id,
            scheduled_departure_at=scheduled_departure_at,
            scheduled_arrival_at=scheduled_arrival_at,
            fare_amount=fare_amount,
            created_by=created_by,
        )
        self._session.add(trip)
        await self._session.flush()
        return trip

    async def search(
        self,
        *,
        origin_stop_ids: Collection[uuid.UUID] | None,
        destination_stop_id: uuid.UUID | None,
        departure_after: datetime,
        departure_before: datetime,
        statuses: list[TripStatus],
        limit: int,
        offset: int,
    ) -> tuple[list[Trip], int]:
        """Trips a passenger can board at one of ``origin_stop_ids`` and
        leave at ``destination_stop_id``.

        A stop only has to lie *along* the route, not be its terminal —
        a passenger at Madina can board an Accra-Kumasi service there — and
        boarding must come before alighting. Several origins are accepted
        because a GPS pickup resolves to every stop within walking
        distance, and the nearest one is not always served by the route
        the passenger needs.
        """
        stmt = (
            select(Trip)
            .join(Route, Route.id == Trip.route_id)
            .where(
                Trip.scheduled_departure_at >= departure_after,
                Trip.scheduled_departure_at <= departure_before,
                Trip.status.in_(statuses),
            )
        )
        if origin_stop_ids is not None or destination_stop_id is not None:
            positions = _route_stop_positions()
            board = positions.alias("board")
            alight = positions.alias("alight")
            conditions = [
                board.c.route_id == Trip.route_id,
                alight.c.route_id == Trip.route_id,
                board.c.position < alight.c.position,
                board.c.stop_id != alight.c.stop_id,
            ]
            if origin_stop_ids is not None:
                conditions.append(board.c.stop_id.in_(list(origin_stop_ids)))
            if destination_stop_id is not None:
                conditions.append(alight.c.stop_id == destination_stop_id)
            stmt = stmt.where(exists().where(*conditions))

        count_result = await self._session.execute(
            select(func.count()).select_from(stmt.subquery())
        )
        total = count_result.scalar_one()

        result = await self._session.execute(
            stmt.order_by(Trip.scheduled_departure_at).limit(limit).offset(offset)
        )
        return list(result.scalars().all()), total

    async def count_unfinished_for_route(self, route_id: uuid.UUID) -> int:
        """Trips on the route that are yet to run or still running."""
        result = await self._session.execute(
            select(func.count(Trip.id)).where(
                Trip.route_id == route_id,
                Trip.status.in_(
                    [
                        TripStatus.SCHEDULED,
                        TripStatus.BOARDING,
                        TripStatus.IN_PROGRESS,
                        TripStatus.PAUSED,
                    ]
                ),
            )
        )
        return int(result.scalar_one())

    async def set_status(
        self,
        trip: Trip,
        *,
        new_status: TripStatus,
        changed_by: uuid.UUID | None,
        reason: str | None,
        latitude: Decimal | None = None,
        longitude: Decimal | None = None,
    ) -> None:
        previous = trip.status
        trip.status = new_status
        self._session.add(
            TripStatusHistory(
                trip_id=trip.id,
                from_status=previous,
                to_status=new_status,
                changed_by=changed_by,
                reason=reason,
                latitude=latitude,
                longitude=longitude,
            )
        )
        await self._session.flush()

    async def record_event(
        self,
        trip_id: uuid.UUID,
        event_type: TripEventType,
        payload: dict[str, object] | None = None,
    ) -> TripEvent:
        event = TripEvent(trip_id=trip_id, event_type=event_type, payload=payload)
        self._session.add(event)
        await self._session.flush()
        return event

    # --- Driver / vehicle assignment ------------------------------------
    async def assign_driver(
        self, trip_id: uuid.UUID, driver_id: uuid.UUID, assigned_by: uuid.UUID | None
    ) -> TripDriverAssignment:
        assignment = TripDriverAssignment(
            trip_id=trip_id, driver_id=driver_id, assigned_by=assigned_by
        )
        self._session.add(assignment)
        await self._session.flush()
        return assignment

    async def get_active_driver_assignment(self, trip_id: uuid.UUID) -> TripDriverAssignment | None:
        result = await self._session.execute(
            select(TripDriverAssignment).where(
                TripDriverAssignment.trip_id == trip_id,
                TripDriverAssignment.is_active.is_(True),
            )
        )
        return result.scalar_one_or_none()

    async def unassign_driver(self, assignment: TripDriverAssignment) -> None:
        assignment.is_active = False
        await self._session.flush()

    async def assign_vehicle(
        self, trip_id: uuid.UUID, vehicle_id: uuid.UUID, assigned_by: uuid.UUID | None
    ) -> TripVehicleAssignment:
        assignment = TripVehicleAssignment(
            trip_id=trip_id, vehicle_id=vehicle_id, assigned_by=assigned_by
        )
        self._session.add(assignment)
        await self._session.flush()
        return assignment

    async def get_active_vehicle_assignment(
        self, trip_id: uuid.UUID
    ) -> TripVehicleAssignment | None:
        result = await self._session.execute(
            select(TripVehicleAssignment).where(
                TripVehicleAssignment.trip_id == trip_id,
                TripVehicleAssignment.is_active.is_(True),
            )
        )
        return result.scalar_one_or_none()

    async def unassign_vehicle(self, assignment: TripVehicleAssignment) -> None:
        assignment.is_active = False
        await self._session.flush()

    async def find_conflicting_active_trip_for_driver(
        self, driver_id: uuid.UUID, *, exclude_trip_id: uuid.UUID
    ) -> Trip | None:
        """A driver cannot operate two trips at once — used by ``start`` to
        reject a conflicting active assignment."""
        active_statuses = [TripStatus.BOARDING, TripStatus.IN_PROGRESS, TripStatus.PAUSED]
        result = await self._session.execute(
            select(Trip)
            .join(
                TripDriverAssignment,
                TripDriverAssignment.trip_id == Trip.id,
            )
            .where(
                TripDriverAssignment.driver_id == driver_id,
                TripDriverAssignment.is_active.is_(True),
                Trip.status.in_(active_statuses),
                Trip.id != exclude_trip_id,
            )
        )
        return result.scalars().first()

    async def get_driver_for_trip(self, trip_id: uuid.UUID) -> Driver | None:
        assignment = await self.get_active_driver_assignment(trip_id)
        if assignment is None:
            return None
        result = await self._session.execute(
            select(Driver).where(Driver.id == assignment.driver_id)
        )
        return result.scalar_one_or_none()

    async def get_vehicle_for_trip(self, trip_id: uuid.UUID) -> Vehicle | None:
        assignment = await self.get_active_vehicle_assignment(trip_id)
        if assignment is None:
            return None
        result = await self._session.execute(
            select(Vehicle).where(Vehicle.id == assignment.vehicle_id)
        )
        return result.scalar_one_or_none()
