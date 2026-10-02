"""Trip search: every trip a passenger can take between two places, with its
price, how full it is, and -- for a vehicle already on the road -- how far
it is from the passenger's pickup.

A trotro on its way picks people up along the route, so search includes
trips already in progress. Each says whether it has passed the pickup
(``has_passed_pickup``) and, if not, roughly when it gets there
(``vehicle_eta_to_pickup_minutes``); booking one is allowed only from a stop
still ahead of it (``BookingService._assert_pickup_ahead``).

Results can be sorted by price or ride time, which depend on the pickup and
on who has already booked, so matching trips are fetched in one go (at most
``TRIP_SEARCH_MAX_CANDIDATES``), priced and ranked here, then paged. Every
lookup is batched across the whole candidate list: a handful of queries per
search, however many trips match.
"""

from __future__ import annotations

import math
import uuid
from collections.abc import Sequence
from dataclasses import dataclass
from datetime import UTC, date, datetime, time, timedelta
from decimal import Decimal
from typing import Literal

from redis.asyncio import Redis
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings, get_settings
from app.core.exceptions import NotFoundError, StopNotOnRouteError
from app.models.identity import UserProfile
from app.models.routes import Stop
from app.models.trips import TripStatus
from app.models.vehicles import VehicleType
from app.repositories.route_geometry import (
    PASSED_STOP_TOLERANCE_KM,
    RouteGeometry,
    RouteGeometryRepository,
    nearest_pickup,
)
from app.repositories.trip_repository import TripRepository
from app.repositories.trip_view_repository import TripSummary, TripViewRepository
from app.repositories.user_repository import UserRepository
from app.services.fare_quote_service import FareQuote, FareQuoteService, QuoteRequest
from app.services.rating_service import RatingService
from app.services.route_service import RouteService
from app.services.tracking_service import LiveLocation, TrackingService
from app.utilities.geo import haversine_distance_km, travel_minutes, wkb_to_latlng

SearchSort = Literal["departure", "cheapest", "fastest"]
PickupSource = Literal["gps", "manual"]

SEARCHABLE_TRIP_STATUSES = (TripStatus.SCHEDULED, TripStatus.BOARDING, TripStatus.IN_PROGRESS)
_ON_THE_ROAD = (TripStatus.BOARDING, TripStatus.IN_PROGRESS)
# Favourite routes show the soonest trip within this window, looking at this
# many departures per journey for one with a free seat.
_NEXT_DEPARTURE_HORIZON_DAYS = 7
_NEXT_DEPARTURE_CANDIDATES = 10


@dataclass(frozen=True, slots=True)
class Pickup:
    stop_id: uuid.UUID
    name: str
    distance_m: float | None
    source: PickupSource


@dataclass(frozen=True, slots=True)
class TripDetails:
    summary: TripSummary
    driver_profile: UserProfile | None
    driver_average_rating: Decimal | None
    driver_rating_count: int


@dataclass(frozen=True, slots=True)
class NextDeparture:
    trip_id: uuid.UUID
    scheduled_departure_at: datetime
    available_seats: int
    fare: FareQuote


@dataclass(frozen=True, slots=True)
class TripOffer:
    summary: TripSummary
    geometry: RouteGeometry
    fare: FareQuote
    pickup: Pickup | None
    ride_minutes: int | None
    vehicle_eta_to_pickup_minutes: int | None
    has_passed_pickup: bool


class TripSearchService:
    def __init__(
        self, session: AsyncSession, redis: Redis, settings: Settings | None = None
    ) -> None:
        self._settings = settings or get_settings()
        self._route_service = RouteService(session, redis, self._settings)
        self._views = TripViewRepository(session)
        self._geometries = RouteGeometryRepository(session)
        self._quotes = FareQuoteService(session, self._settings)
        self._tracking = TrackingService(session, redis, self._settings)
        self._ratings = RatingService(session)
        self._trips = TripRepository(session)
        self._users = UserRepository(session)

    async def _summary(self, trip_id: uuid.UUID) -> TripSummary:
        summary = (await self._views.summaries_by_ids([trip_id])).get(trip_id)
        if summary is None:
            raise NotFoundError("Trip not found.")
        return summary

    async def trip_details(self, trip_id: uuid.UUID) -> TripDetails:
        summary = await self._summary(trip_id)
        profile = None
        average, count = None, 0
        if summary.driver_id is not None and summary.driver_user_id is not None:
            driver = await self._users.get_by_id(summary.driver_user_id)
            profile = driver.profile if driver is not None else None
            average, count = await self._ratings.get_driver_average_rating(summary.driver_id)
        return TripDetails(summary, profile, average, count)

    async def next_departures(
        self, journeys: Sequence[tuple[uuid.UUID, uuid.UUID]]
    ) -> dict[tuple[uuid.UUID, uuid.UUID], NextDeparture | None]:
        """For each ``(board at, get off at)`` journey, the soonest trip in
        the next week that still has a free seat, priced for one seat."""
        now = datetime.now(UTC)
        horizon = now + timedelta(days=_NEXT_DEPARTURE_HORIZON_DAYS)
        candidates: dict[tuple[uuid.UUID, uuid.UUID], list[uuid.UUID]] = {}
        for origin, destination in set(journeys):
            trips, _ = await self._trips.search(
                origin_stop_ids=[origin],
                destination_stop_id=destination,
                departure_after=now,
                departure_before=horizon,
                statuses=[TripStatus.SCHEDULED, TripStatus.BOARDING],
                limit=_NEXT_DEPARTURE_CANDIDATES,
                offset=0,
                with_total=False,
            )
            candidates[(origin, destination)] = [trip.id for trip in trips]

        summaries = await self._views.summaries_by_ids(
            {trip_id for ids in candidates.values() for trip_id in ids}
        )
        chosen: dict[tuple[uuid.UUID, uuid.UUID], TripSummary] = {}
        for journey, ids in candidates.items():
            for trip_id in ids:
                summary = summaries.get(trip_id)
                if summary is not None and summary.vehicle_id and summary.available_seats:
                    chosen[journey] = summary
                    break

        geometries = await self._geometries.for_routes({s.route_id for s in chosen.values()})
        requests = [
            QuoteRequest(
                trip_id=summary.trip_id,
                route_id=summary.route_id,
                full_route_fare=summary.fare_amount,
                seats_total=summary.seats_total,
                origin_stop_id=origin,
                destination_stop_id=destination,
            )
            for (origin, destination), summary in chosen.items()
        ]
        # Two favourites can land on the same trip; quote each journey.
        quotes = {
            (request.origin_stop_id, request.destination_stop_id): (
                await self._quotes.quote([request], geometries)
            )[request.trip_id]
            for request in requests
        }
        return {
            journey: (
                NextDeparture(
                    trip_id=summary.trip_id,
                    scheduled_departure_at=summary.scheduled_departure_at,
                    available_seats=summary.available_seats,
                    fare=quotes[journey],
                )
                if (summary := chosen.get(journey)) is not None
                else None
            )
            for journey in candidates
        }

    async def fare_quote(
        self,
        trip_id: uuid.UUID,
        *,
        origin_stop_id: uuid.UUID | None,
        destination_stop_id: uuid.UUID | None,
        seats: int,
    ) -> tuple[FareQuote, uuid.UUID, uuid.UUID]:
        """The price of ``seats`` between two stops of the trip right now --
        the amount a booking made now would be charged. Missing stops mean
        the route's own start and end."""
        summary = await self._summary(trip_id)
        geometry = (await self._geometries.for_routes([summary.route_id]))[summary.route_id]
        origin = origin_stop_id or geometry.origin_stop_id
        destination = destination_stop_id or geometry.destination_stop_id
        order = geometry.order
        for stop_id, role in ((origin, "origin"), (destination, "destination")):
            if stop_id not in order:
                raise StopNotOnRouteError(details={"stop_id": str(stop_id), "role": role})
        if order[origin] >= order[destination]:
            raise StopNotOnRouteError(
                "The pickup must come before the destination on this route.",
                details={"origin_stop_id": str(origin), "destination_stop_id": str(destination)},
            )
        request = QuoteRequest(
            trip_id=trip_id,
            route_id=summary.route_id,
            full_route_fare=summary.fare_amount,
            seats_total=summary.seats_total,
            origin_stop_id=origin,
            destination_stop_id=destination,
            seats=seats,
        )
        quotes = await self._quotes.quote([request], {summary.route_id: geometry})
        return quotes[trip_id], origin, destination

    async def search(
        self,
        *,
        origin_stop_id: uuid.UUID | None,
        destination_stop_id: uuid.UUID | None,
        travel_date: date,
        departure_after: time | None,
        departure_before: time | None,
        pickup_latitude: float | None,
        pickup_longitude: float | None,
        vehicle_type: VehicleType | None,
        sort: SearchSort,
        seats: int,
        limit: int,
        offset: int,
    ) -> tuple[list[TripOffer], int]:
        manual_stop: Stop | None = None
        candidates: list[tuple[Stop, float]] | None = None
        origin_stop_ids: list[uuid.UUID] | None = None
        if origin_stop_id is not None:
            manual_stop = await self._route_service.find_stop(origin_stop_id)
            origin_stop_ids = [origin_stop_id]
        elif pickup_latitude is not None and pickup_longitude is not None:
            candidates = await self._route_service.pickup_candidates(
                latitude=pickup_latitude, longitude=pickup_longitude
            )
            origin_stop_ids = [stop.id for stop, _ in candidates]

        trips, _ = await self._route_service.search_trips(
            origin_stop_ids=origin_stop_ids,
            destination_stop_id=destination_stop_id,
            travel_date=travel_date,
            departure_after=departure_after,
            departure_before=departure_before,
            limit=self._settings.TRIP_SEARCH_MAX_CANDIDATES,
            offset=0,
            statuses=SEARCHABLE_TRIP_STATUSES,
            with_total=False,
        )
        found = await self._views.summaries_by_ids([trip.id for trip in trips])
        summaries = [
            found[trip.id]
            for trip in trips
            if trip.id in found
            and (vehicle_type is None or found[trip.id].vehicle_type == vehicle_type)
        ]
        geometries = await self._geometries.for_routes({s.route_id for s in summaries})

        pickups: dict[uuid.UUID, Pickup | None] = {}
        for summary in summaries:
            pickups[summary.trip_id] = self._pickup_for(
                geometries[summary.route_id],
                manual_stop=manual_stop,
                candidates=candidates,
                destination_stop_id=destination_stop_id,
                pickup_latitude=pickup_latitude,
                pickup_longitude=pickup_longitude,
            )

        quotes = await self._quotes.quote(
            [
                QuoteRequest(
                    trip_id=s.trip_id,
                    route_id=s.route_id,
                    full_route_fare=s.fare_amount,
                    seats_total=s.seats_total,
                    origin_stop_id=pickup.stop_id if (pickup := pickups[s.trip_id]) else None,
                    destination_stop_id=destination_stop_id,
                    seats=seats,
                )
                for s in summaries
            ],
            geometries,
        )
        positions = await self._tracking.get_live_locations(
            [s.trip_id for s in summaries if s.status in _ON_THE_ROAD]
        )

        offers = [
            self._offer(
                summary,
                geometries[summary.route_id],
                quotes[summary.trip_id],
                pickups[summary.trip_id],
                destination_stop_id,
                positions.get(summary.trip_id),
            )
            for summary in summaries
        ]
        offers.sort(key=lambda offer: _sort_key(offer, sort))
        return offers[offset : offset + limit], len(offers)

    @staticmethod
    def _pickup_for(
        geometry: RouteGeometry,
        *,
        manual_stop: Stop | None,
        candidates: list[tuple[Stop, float]] | None,
        destination_stop_id: uuid.UUID | None,
        pickup_latitude: float | None,
        pickup_longitude: float | None,
    ) -> Pickup | None:
        if manual_stop is not None:
            distance_m = None
            where = wkb_to_latlng(manual_stop.location)
            if pickup_latitude is not None and pickup_longitude is not None and where:
                km = haversine_distance_km(pickup_latitude, pickup_longitude, *where)
                distance_m = round(km * 1000, 1)
            return Pickup(manual_stop.id, manual_stop.name, distance_m, "manual")
        if candidates is not None:
            chosen = nearest_pickup(geometry, candidates, destination_stop_id)
            if chosen is not None:
                stop, distance = chosen
                return Pickup(stop.id, stop.name, round(distance, 1), "gps")
        return None

    def _offer(
        self,
        summary: TripSummary,
        geometry: RouteGeometry,
        fare: FareQuote,
        pickup: Pickup | None,
        destination_stop_id: uuid.UUID | None,
        position: LiveLocation | None,
    ) -> TripOffer:
        boards_at = pickup.stop_id if pickup is not None else geometry.origin_stop_id
        eta_minutes: int | None = None
        has_passed = False
        if position is not None and summary.status in _ON_THE_ROAD:
            km = geometry.km_until(boards_at, position.latitude, position.longitude)
            if km is not None:
                has_passed = summary.status == TripStatus.IN_PROGRESS and (
                    km < -PASSED_STOP_TOLERANCE_KM
                )
                fresh = position.age_seconds <= self._settings.NEARBY_VEHICLES_MAX_AGE_SECONDS
                if fresh and not has_passed:
                    eta_minutes = self._minutes_to_cover(max(km, 0.0), position, summary)
        return TripOffer(
            summary=summary,
            geometry=geometry,
            fare=fare,
            pickup=pickup,
            ride_minutes=geometry.ride_minutes(
                boards_at, destination_stop_id or geometry.destination_stop_id
            ),
            vehicle_eta_to_pickup_minutes=eta_minutes,
            has_passed_pickup=has_passed,
        )

    def _minutes_to_cover(self, km: float, position: LiveLocation, summary: TripSummary) -> int:
        minutes = travel_minutes(
            km, position.speed_kmh, fallback_kmh=self._settings.PICKUP_ETA_AVERAGE_SPEED_KMH
        )
        if summary.status == TripStatus.BOARDING:
            # Still loading at its first stop: it leaves at departure time.
            wait = (summary.scheduled_departure_at - datetime.now(UTC)).total_seconds() / 60
            minutes += max(math.ceil(wait), 0)
        return minutes


def _sort_key(offer: TripOffer, sort: SearchSort) -> tuple[object, ...]:
    # A vehicle that has already gone past cannot be caught: always last.
    departure = offer.summary.scheduled_departure_at
    if sort == "cheapest":
        return (offer.has_passed_pickup, offer.fare.current, departure)
    if sort == "fastest":
        minutes = offer.ride_minutes if offer.ride_minutes is not None else math.inf
        return (offer.has_passed_pickup, minutes, departure)
    return (offer.has_passed_pickup, departure)
