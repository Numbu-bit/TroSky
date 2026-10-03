"""Public route, stop, and trip search/browse endpoints.

These are intentionally unauthenticated (browsing routes/trips does not
require an account) — booking a seat, introduced in Phase 5, does.
"""

from __future__ import annotations

import uuid
from datetime import date, time

from fastapi import APIRouter, Query

from app.api.dependencies import (
    Pagination,
    RouteServiceDep,
    StorageProviderDep,
    TripServiceDep,
)
from app.api.trip_dependencies import TripSearchServiceDep
from app.api.v1.views import avatar_url
from app.core.exceptions import ValidationAppError
from app.models.routes import Stop
from app.models.vehicles import VehicleType
from app.schemas.common import PaginatedResponse
from app.schemas.route import (
    NearbyStopResponse,
    RouteDetailResponse,
    RouteResponse,
    StopResponse,
)
from app.schemas.trip import (
    FareQuoteResponse,
    FareSummaryResponse,
    TripDetailResponse,
    TripDriverResponse,
    TripResponse,
    TripSearchResultResponse,
    TripSeatResponse,
    TripSeatsResponse,
    TripVehicleResponse,
)
from app.services.fare_quote_service import FareQuote
from app.services.trip_search_service import SearchSort, TripOffer
from app.utilities.geo import wkb_to_latlng

router = APIRouter()


def _stop_response(stop: Stop) -> StopResponse:
    latlng = wkb_to_latlng(stop.location)
    latitude, longitude = latlng if latlng is not None else (0.0, 0.0)
    return StopResponse(
        id=stop.id,
        name=stop.name,
        code=stop.code,
        address=stop.address,
        city=stop.city,
        region=stop.region,
        latitude=latitude,
        longitude=longitude,
    )


def _require_both(latitude: float | None, longitude: float | None) -> bool:
    """True when a point was supplied. Half a coordinate is a client bug,
    and guessing the other half would silently search the wrong place."""
    if (latitude is None) != (longitude is None):
        raise ValidationAppError(
            "Provide both a latitude and a longitude, or neither.",
            details={"latitude": latitude, "longitude": longitude},
        )
    return latitude is not None


@router.get("/stops", response_model=PaginatedResponse[StopResponse])
async def list_stops(
    service: RouteServiceDep,
    pagination: Pagination,
    q: str | None = Query(
        default=None,
        min_length=2,
        max_length=100,
        description="Search stops by name: how a passenger picks a pickup by hand.",
    ),
) -> PaginatedResponse[StopResponse]:
    if q is not None:
        found = await service.search_stops(q, limit=pagination.limit)
        return PaginatedResponse(
            items=[_stop_response(s) for s in found],
            total=len(found),
            limit=pagination.limit,
            offset=0,
        )
    stops, total = await service.list_stops(limit=pagination.limit, offset=pagination.offset)
    return PaginatedResponse(
        items=[_stop_response(s) for s in stops],
        total=total,
        limit=pagination.limit,
        offset=pagination.offset,
    )


@router.get("/stops/nearby", response_model=list[NearbyStopResponse])
async def list_nearby_stops(
    service: RouteServiceDep,
    latitude: float = Query(..., ge=-90, le=90),
    longitude: float = Query(..., ge=-180, le=180),
    radius_m: int | None = Query(
        default=None,
        gt=0,
        le=20_000,
        description="Search radius in metres. Defaults to PICKUP_MAX_WALK_METERS.",
    ),
    limit: int | None = Query(default=None, gt=0, le=50),
) -> list[NearbyStopResponse]:
    """Stops near the passenger, nearest first.

    The app calls this with the device's GPS position to show a default
    pickup point the moment it opens. An empty list is a normal answer
    here (the passenger is simply far from any stop), and the app should
    then offer name search via ``GET /stops?q=``.
    """
    nearby = await service.find_nearby_stops(
        latitude=latitude, longitude=longitude, radius_m=radius_m, limit=limit
    )
    return [
        NearbyStopResponse(**_stop_response(stop).model_dump(), distance_m=round(distance, 1))
        for stop, distance in nearby
    ]


@router.get("/routes", response_model=PaginatedResponse[RouteResponse])
async def list_routes(
    service: RouteServiceDep, pagination: Pagination
) -> PaginatedResponse[RouteResponse]:
    routes, total = await service.list_routes(limit=pagination.limit, offset=pagination.offset)
    return PaginatedResponse(
        items=[RouteResponse.model_validate(r) for r in routes],
        total=total,
        limit=pagination.limit,
        offset=pagination.offset,
    )


@router.get("/routes/{route_id}", response_model=RouteDetailResponse)
async def get_route(route_id: uuid.UUID, service: RouteServiceDep) -> RouteDetailResponse:
    route = await service.get_route(route_id)
    stops = await service.get_route_stops(route_id)
    return RouteDetailResponse(
        **RouteResponse.model_validate(route).model_dump(),
        stops=[_stop_response(s) for s in stops],
    )


@router.get("/trips/search", response_model=PaginatedResponse[TripSearchResultResponse])
async def search_trips(
    service: TripSearchServiceDep,
    pagination: Pagination,
    origin_stop_id: uuid.UUID | None = Query(
        default=None,
        description="A pickup the passenger chose by hand. Always wins over GPS coordinates.",
    ),
    destination_stop_id: uuid.UUID | None = Query(default=None),
    travel_date: date = Query(...),
    departure_after: time | None = Query(default=None),
    departure_before: time | None = Query(default=None),
    pickup_latitude: float | None = Query(
        default=None, ge=-90, le=90, description="Device GPS latitude: the default pickup."
    ),
    pickup_longitude: float | None = Query(default=None, ge=-180, le=180),
    sort: SearchSort = Query(
        default="departure",
        description=(
            "departure: soonest first. cheapest: lowest current fare. fastest: shortest "
            "scheduled ride. Vehicles that have already passed the pickup always come last."
        ),
    ),
    vehicle_type: VehicleType | None = Query(default=None),
    seats: int = Query(default=1, ge=1, le=10, description="Seats to price each result for."),
) -> PaginatedResponse[TripSearchResultResponse]:
    """Trips a passenger can take, where they would board each one, and what
    it costs from there.

    The pickup defaults to the passenger's GPS position: send
    ``pickup_latitude``/``pickup_longitude`` and every stop within walking
    distance becomes a candidate boarding point. Send ``origin_stop_id``
    instead, or as well, when the passenger has chosen a pickup by hand;
    a manual choice always overrides the coordinates.

    Trips already on the road are included: a trotro picks people up along
    its route. ``has_passed_pickup`` says when it is too late to catch one,
    and ``vehicle_eta_to_pickup_minutes`` how far away it is otherwise.
    """
    _require_both(pickup_latitude, pickup_longitude)
    offers, total = await service.search(
        origin_stop_id=origin_stop_id,
        destination_stop_id=destination_stop_id,
        travel_date=travel_date,
        departure_after=departure_after,
        departure_before=departure_before,
        pickup_latitude=pickup_latitude,
        pickup_longitude=pickup_longitude,
        vehicle_type=vehicle_type,
        sort=sort,
        seats=seats,
        limit=pagination.limit,
        offset=pagination.offset,
    )
    return PaginatedResponse(
        items=[_search_result(offer) for offer in offers],
        total=total,
        limit=pagination.limit,
        offset=pagination.offset,
    )


def _fare_summary(quote: FareQuote) -> FareSummaryResponse:
    return FareSummaryResponse(
        current=quote.current,
        solo=quote.solo,
        minimum=quote.minimum,
        platform_fee=quote.platform_fee,
        total=quote.total,
        currency=quote.currency,
        riders_count=quote.riders_count,
        seats=quote.seats,
    )


def _search_result(offer: TripOffer) -> TripSearchResultResponse:
    summary, geometry, pickup = offer.summary, offer.geometry, offer.pickup
    return TripSearchResultResponse(
        trip_id=summary.trip_id,
        route_id=summary.route_id,
        route_name=summary.route_name,
        origin_stop_id=geometry.origin_stop_id,
        destination_stop_id=geometry.destination_stop_id,
        scheduled_departure_at=summary.scheduled_departure_at,
        scheduled_arrival_at=summary.scheduled_arrival_at,
        estimated_duration_minutes=geometry.duration_minutes,
        distance_km=geometry.route_km,
        fare_amount=summary.fare_amount,
        status=summary.status,
        available_seats=summary.available_seats if summary.vehicle_id else 0,
        vehicle_registration_number=summary.vehicle_registration_number,
        vehicle_type=summary.vehicle_type,
        pickup_stop_id=pickup.stop_id if pickup else None,
        pickup_stop_name=pickup.name if pickup else None,
        pickup_distance_m=pickup.distance_m if pickup else None,
        pickup_source=pickup.source if pickup else None,
        fare=_fare_summary(offer.fare),
        ride_minutes=offer.ride_minutes,
        vehicle_eta_to_pickup_minutes=offer.vehicle_eta_to_pickup_minutes,
        has_passed_pickup=offer.has_passed_pickup,
    )


@router.get("/trips/{trip_id}", response_model=TripDetailResponse)
async def get_trip(
    trip_id: uuid.UUID,
    trips: TripServiceDep,
    search: TripSearchServiceDep,
    storage: StorageProviderDep,
) -> TripDetailResponse:
    """A trip with its route, vehicle, driver and how full it is."""
    trip = await trips.get_trip(trip_id)
    details = await search.trip_details(trip_id)
    summary = details.summary
    vehicle = None
    if summary.vehicle_registration_number and summary.vehicle_type:
        vehicle = TripVehicleResponse(
            registration_number=summary.vehicle_registration_number,
            type=summary.vehicle_type,
            make_model=summary.vehicle_make_model,
            capacity=summary.vehicle_capacity,
        )
    driver = None
    if summary.driver_id is not None:
        profile = details.driver_profile
        driver = TripDriverResponse(
            id=summary.driver_id,
            full_name=summary.driver_name,
            avatar_url=await avatar_url(profile, storage) if profile is not None else None,
            average_rating=details.driver_average_rating,
            rating_count=details.driver_rating_count,
        )
    return TripDetailResponse(
        **TripResponse.model_validate(trip).model_dump(),
        route_name=summary.route_name,
        origin_stop_id=summary.origin_stop_id,
        origin_stop_name=summary.origin_stop_name,
        destination_stop_id=summary.destination_stop_id,
        destination_stop_name=summary.destination_stop_name,
        vehicle=vehicle,
        driver=driver,
        riders_count=summary.seats_taken,
        seats_total=summary.seats_total,
        available_seats=summary.available_seats,
    )


@router.get("/trips/{trip_id}/fare-quote", response_model=FareQuoteResponse)
async def get_fare_quote(
    trip_id: uuid.UUID,
    service: TripSearchServiceDep,
    origin_stop_id: uuid.UUID | None = Query(
        default=None, description="Where the passenger boards. Default: the route's start."
    ),
    destination_stop_id: uuid.UUID | None = Query(
        default=None, description="Where they get off. Default: the route's end."
    ),
    seats: int = Query(default=1, ge=1, le=10),
) -> FareQuoteResponse:
    """What booking these seats between these stops costs right now: the
    amount ``POST /bookings`` would charge. Refresh it to show a live fare --
    it falls as riders join, but a passenger's own fare is fixed once they
    book."""
    quote, origin, destination = await service.fare_quote(
        trip_id, origin_stop_id=origin_stop_id, destination_stop_id=destination_stop_id, seats=seats
    )
    return FareQuoteResponse(
        **_fare_summary(quote).model_dump(),
        trip_id=trip_id,
        origin_stop_id=origin,
        destination_stop_id=destination,
    )


@router.get("/trips/{trip_id}/seats", response_model=TripSeatsResponse)
async def get_trip_seats(trip_id: uuid.UUID, service: RouteServiceDep) -> TripSeatsResponse:
    """Seat layout for a trip's assigned vehicle, with real-time
    availability reflecting active (held or confirmed) reservations."""
    vehicle, seats, taken_seat_ids = await service.get_trip_seats(trip_id)
    return TripSeatsResponse(
        trip_id=trip_id,
        vehicle_id=vehicle.id,
        total_seats=len(seats),
        available_seats=len(seats) - len(taken_seat_ids),
        seats=[
            TripSeatResponse(
                id=s.id,
                seat_number=s.seat_number,
                row_number=s.row_number,
                column_number=s.column_number,
                seat_type=s.seat_type,
                is_available=s.id not in taken_seat_ids,
            )
            for s in seats
        ],
    )
