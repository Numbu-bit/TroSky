"""The passenger journey: finding a trip, booking it, riding it, rating it."""

from __future__ import annotations

from typing import Annotated

from fastapi import Depends

from app.api.common_dependencies import DbSession, RedisClient
from app.services.booking_service import BookingService
from app.services.rating_service import RatingService
from app.services.route_service import RouteService
from app.services.ticket_service import TicketService
from app.services.trip_search_service import TripSearchService
from app.services.trip_service import TripService


def get_route_service(db: DbSession, redis: RedisClient) -> RouteService:
    return RouteService(db, redis)


def get_trip_service(db: DbSession) -> TripService:
    return TripService(db)


def get_booking_service(db: DbSession, redis: RedisClient) -> BookingService:
    return BookingService(db, redis)


def get_trip_search_service(db: DbSession, redis: RedisClient) -> TripSearchService:
    return TripSearchService(db, redis)


def get_ticket_service(db: DbSession) -> TicketService:
    return TicketService(db)


def get_rating_service(db: DbSession) -> RatingService:
    return RatingService(db)


RouteServiceDep = Annotated[RouteService, Depends(get_route_service)]
TripServiceDep = Annotated[TripService, Depends(get_trip_service)]
TripSearchServiceDep = Annotated[TripSearchService, Depends(get_trip_search_service)]
BookingServiceDep = Annotated[BookingService, Depends(get_booking_service)]
TicketServiceDep = Annotated[TicketService, Depends(get_ticket_service)]
RatingServiceDep = Annotated[RatingService, Depends(get_rating_service)]
