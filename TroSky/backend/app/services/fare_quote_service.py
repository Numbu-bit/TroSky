"""What a seat costs right now, and how low it could go.

One implementation behind every price a passenger sees: the fare on each
search result, the fare-quote endpoint, and the amount a booking is
actually charged. Keeping them on one code path is what guarantees the
price on the results screen is the price at checkout.

A passenger's fare is fixed when they book (decided 2 Oct 2026): someone
booking later gets their own, cheaper quote, and nobody is re-billed or
refunded as the vehicle fills. ``minimum`` is therefore for people still
deciding: the lowest this seat could cost if every remaining seat were
taken by someone riding the whole route.
"""

from __future__ import annotations

import uuid
from collections.abc import Mapping, Sequence
from dataclasses import dataclass
from decimal import Decimal

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings, get_settings
from app.repositories.booking_repository import BookingRepository
from app.repositories.route_geometry import RouteGeometry
from app.services.fare_service import FareService, passenger_km, segment_distance_km


@dataclass(frozen=True, slots=True)
class QuoteRequest:
    trip_id: uuid.UUID
    route_id: uuid.UUID
    full_route_fare: Decimal
    seats_total: int
    # None means the route's own start or end.
    origin_stop_id: uuid.UUID | None
    destination_stop_id: uuid.UUID | None
    seats: int = 1


@dataclass(frozen=True, slots=True)
class FareQuote:
    # Per seat, for this segment, excluding TroSky's platform fee.
    current: Decimal
    solo: Decimal
    minimum: Decimal
    # For all ``seats`` together; ``total`` is what a booking now is charged.
    platform_fee: Decimal
    total: Decimal
    currency: str
    # Seats already taken on the trip (paid or awaiting payment).
    riders_count: int
    seats: int


class FareQuoteService:
    def __init__(self, session: AsyncSession, settings: Settings | None = None) -> None:
        self._settings = settings or get_settings()
        self._bookings = BookingRepository(session)
        self._fares = FareService(self._settings)

    async def quote(
        self, requests: Sequence[QuoteRequest], geometries: Mapping[uuid.UUID, RouteGeometry]
    ) -> dict[uuid.UUID, FareQuote]:
        """A quote per trip, in two queries however many trips there are."""
        occupying = await self._bookings.occupying_seats_for_trips([r.trip_id for r in requests])
        return {
            request.trip_id: self._quote_one(
                request, geometries[request.route_id], occupying[request.trip_id]
            )
            for request in requests
        }

    def _quote_one(
        self,
        request: QuoteRequest,
        geometry: RouteGeometry,
        occupying: list[tuple[uuid.UUID | None, uuid.UUID | None, int]],
    ) -> FareQuote:
        distances = geometry.fare_distances
        route_km = geometry.route_km
        ends = {
            "route_origin_id": geometry.origin_stop_id,
            "route_destination_id": geometry.destination_stop_id,
        }
        segment_km = segment_distance_km(
            origin_distance_km=distances.get(request.origin_stop_id or geometry.origin_stop_id),
            destination_distance_km=distances.get(
                request.destination_stop_id or geometry.destination_stop_id
            ),
            route_km=route_km,
        )
        committed_km = passenger_km(occupying, stop_distances=distances, route_km=route_km, **ends)
        own_km = (segment_km or route_km or Decimal("0")) * request.seats
        now = self._fares.quote(
            full_route_fare=request.full_route_fare,
            segment_km=segment_km,
            route_km=route_km,
            total_passenger_km=committed_km + own_km,
        )

        riders = sum(seat_count for _, _, seat_count in occupying)
        minimum = now.per_seat_fare
        free_after = max(request.seats_total - riders - request.seats, 0)
        if self._settings.FARE_SHARING_ENABLED and route_km and free_after:
            full = self._fares.quote(
                full_route_fare=request.full_route_fare,
                segment_km=segment_km,
                route_km=route_km,
                total_passenger_km=committed_km + own_km + route_km * free_after,
            )
            minimum = min(full.per_seat_fare, minimum)

        fare_total = now.per_seat_fare * request.seats
        fee = self._fares.platform_fee(fare_total, request.seats)
        return FareQuote(
            current=now.per_seat_fare,
            solo=now.solo_fare,
            minimum=minimum,
            platform_fee=fee,
            total=fare_total + fee,
            currency=self._settings.PAYMENTS_DEFAULT_CURRENCY,
            riders_count=riders,
            seats=request.seats,
        )
