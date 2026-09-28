"""Public route, stop, and trip search/browse endpoints.

These are intentionally unauthenticated (browsing routes/trips does not
require an account) — booking a seat, introduced in Phase 5, does.
"""

from __future__ import annotations

import uuid
from datetime import date, time
from typing import Literal

from fastapi import APIRouter, Query

from app.api.dependencies import Pagination, RouteServiceDep, TripServiceDep
from app.core.exceptions import ValidationAppError
from app.models.routes import Stop
from app.schemas.common import PaginatedResponse
from app.schemas.route import (
    NearbyStopResponse,
    RouteDetailResponse,
    RouteResponse,
    StopResponse,
)
from app.schemas.trip import (
    TripResponse,
    TripSearchResultResponse,
    TripSeatResponse,
    TripSeatsResponse,
)
from app.utilities.geo import haversine_distance_km, wkb_to_latlng

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
    service: RouteServiceDep,
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
) -> PaginatedResponse[TripSearchResultResponse]:
    """Trips a passenger can take, and where they would board each one.

    The pickup defaults to the passenger's GPS position: send
    ``pickup_latitude``/``pickup_longitude`` and every stop within walking
    distance becomes a candidate boarding point. Send ``origin_stop_id``
    instead, or as well, when the passenger has chosen a pickup by hand;
    a manual choice always overrides the coordinates.
    """
    _require_both(pickup_latitude, pickup_longitude)
    candidates = None
    manual_stop = None
    origin_stop_ids: list[uuid.UUID] | None = None
    if origin_stop_id is not None:
        origin_stop_ids = [origin_stop_id]
        manual_stop = await service.find_stop(origin_stop_id)
    elif pickup_latitude is not None and pickup_longitude is not None:
        candidates = await service.pickup_candidates(
            latitude=pickup_latitude, longitude=pickup_longitude
        )
        origin_stop_ids = [stop.id for stop, _ in candidates]

    trips, total = await service.search_trips(
        origin_stop_ids=origin_stop_ids,
        destination_stop_id=destination_stop_id,
        travel_date=travel_date,
        departure_after=departure_after,
        departure_before=departure_before,
        limit=pagination.limit,
        offset=pagination.offset,
    )

    results: list[TripSearchResultResponse] = []
    for trip in trips:
        route = await service.get_route(trip.route_id)
        vehicle = await service.get_vehicle_for_trip(trip.id)
        available_seats = (
            await service.get_available_seats_count(trip.id, vehicle) if vehicle is not None else 0
        )
        pickup_stop: Stop | None = None
        pickup_distance: float | None = None
        pickup_source: Literal["gps", "manual"] | None = None
        if manual_stop is not None:
            pickup_stop, pickup_source = manual_stop, "manual"
            where = wkb_to_latlng(manual_stop.location)
            if pickup_latitude is not None and pickup_longitude is not None and where:
                km = haversine_distance_km(pickup_latitude, pickup_longitude, *where)
                pickup_distance = round(km * 1000, 1)
        elif candidates is not None:
            chosen = await service.pickup_for_trip(trip, candidates, destination_stop_id)
            if chosen is not None:
                pickup_stop, pickup_source = chosen[0], "gps"
                pickup_distance = round(chosen[1], 1)
        results.append(
            TripSearchResultResponse(
                trip_id=trip.id,
                route_id=route.id,
                route_name=route.name,
                origin_stop_id=route.origin_stop_id,
                destination_stop_id=route.destination_stop_id,
                scheduled_departure_at=trip.scheduled_departure_at,
                scheduled_arrival_at=trip.scheduled_arrival_at,
                estimated_duration_minutes=route.estimated_duration_minutes,
                distance_km=route.distance_km,
                fare_amount=trip.fare_amount,
                status=trip.status,
                available_seats=available_seats,
                vehicle_registration_number=vehicle.registration_number if vehicle else None,
                vehicle_type=vehicle.vehicle_type if vehicle else None,
                pickup_stop_id=pickup_stop.id if pickup_stop else None,
                pickup_stop_name=pickup_stop.name if pickup_stop else None,
                pickup_distance_m=pickup_distance,
                pickup_source=pickup_source,
            )
        )

    return PaginatedResponse(
        items=results, total=total, limit=pagination.limit, offset=pagination.offset
    )


@router.get("/trips/{trip_id}", response_model=TripResponse)
async def get_trip(trip_id: uuid.UUID, service: TripServiceDep) -> TripResponse:
    trip = await service.get_trip(trip_id)
    return TripResponse.model_validate(trip)


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
