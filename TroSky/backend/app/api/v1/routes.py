"""Public route, stop, and trip search/browse endpoints.

These are intentionally unauthenticated (browsing routes/trips does not
require an account) — booking a seat, introduced in Phase 5, does.
"""

from __future__ import annotations

import uuid
from datetime import date, time

from fastapi import APIRouter, Query

from app.api.dependencies import Pagination, RouteServiceDep, TripServiceDep
from app.models.routes import Stop
from app.schemas.common import PaginatedResponse
from app.schemas.route import RouteDetailResponse, RouteResponse, StopResponse
from app.schemas.trip import (
    TripResponse,
    TripSearchResultResponse,
    TripSeatResponse,
    TripSeatsResponse,
)
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


@router.get("/stops", response_model=PaginatedResponse[StopResponse])
async def list_stops(
    service: RouteServiceDep, pagination: Pagination
) -> PaginatedResponse[StopResponse]:
    stops, total = await service.list_stops(limit=pagination.limit, offset=pagination.offset)
    return PaginatedResponse(
        items=[_stop_response(s) for s in stops],
        total=total,
        limit=pagination.limit,
        offset=pagination.offset,
    )


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
    origin_stop_id: uuid.UUID | None = Query(default=None),
    destination_stop_id: uuid.UUID | None = Query(default=None),
    travel_date: date = Query(...),
    departure_after: time | None = Query(default=None),
    departure_before: time | None = Query(default=None),
) -> PaginatedResponse[TripSearchResultResponse]:
    trips, total = await service.search_trips(
        origin_stop_id=origin_stop_id,
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
