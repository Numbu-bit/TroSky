"""Demo data for running the mobile apps against a real backend.

``make seed-demo`` (``python -m scripts.seed_demo_data``). Adds, on top of
the reference data:

* ten Accra stops with real coordinates and six routes stopping at them;
* a demo fleet owner with twelve approved vehicles (seat layouts included),
  two per route, and an approved driver for each -- three of them demo
  logins, the rest "pool" drivers so every trip has a driver;
* a trip every 30 minutes, 05:30-21:00 Ghana time, from now until seven
  days ahead, on every route;
* a verified demo passenger with GHS 200 in their wallet, three past trips
  (paid, completed, one rated) and one upcoming paid booking.

Idempotent: it adds only what is missing, so running it again tomorrow tops
the timetable up to seven days ahead. Logins are printed at the end; they
are demo credentials and the script refuses to run in production.
"""

from __future__ import annotations

import asyncio
import uuid
from dataclasses import dataclass
from datetime import UTC, date, datetime, time, timedelta
from decimal import Decimal

from sqlalchemy import insert, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import AppEnv, get_settings
from app.core.database import dispose_engine, transactional_session
from app.core.logging import configure_logging, get_logger
from app.core.permissions import SystemRole
from app.core.security import hash_password
from app.models.bookings import (
    Booking,
    BookingPassenger,
    BookingStatus,
    ReservationStatus,
    SeatReservation,
)
from app.models.drivers import ApprovalStatus, Driver
from app.models.identity import NotificationPreference, Role, User, UserProfile, UserRole
from app.models.payments import Payment, PaymentPurpose, PaymentStatus, WalletReferenceType
from app.models.routes import Route, Stop
from app.models.trips import Trip, TripDriverAssignment, TripStatus, TripVehicleAssignment
from app.models.vehicles import FleetOwner, Vehicle, VehicleSeat, VehicleSeatLayout, VehicleType
from app.providers.payments.base import PaymentChannel
from app.providers.storage.malware_scan import NoOpMalwareScanner
from app.providers.storage.sandbox import SandboxStorageProvider
from app.repositories.booking_repository import BookingRepository
from app.repositories.route_geometry import RouteGeometryRepository
from app.repositories.route_repository import StopRepository
from app.schemas.booking import BookingCreateRequest, PassengerInput
from app.schemas.driver import DriverRegisterRequest
from app.schemas.fleet import (
    FleetCreateRequest,
    FleetOwnerRegisterRequest,
    SeatInput,
    SeatLayoutRequest,
    VehicleCreateRequest,
)
from app.services.booking_acceptance_service import BookingAcceptanceService
from app.services.booking_service import BookingService
from app.services.driver_service import DriverService
from app.services.fare_service import FareService
from app.services.fleet_service import FleetService
from app.services.rating_service import RatingService
from app.services.route_service import RouteService
from app.services.wallet_service import WalletService
from scripts.seed_reference_data import ensure_roles, seed_reference_data

logger = get_logger(__name__)

DEMO_PASSWORD = "TroSkyDemo!2026"  # noqa: S105 - demo-only credential, printed on purpose
DAYS_AHEAD = 7
FIRST_DEPARTURE = time(5, 30)
LAST_DEPARTURE = time(21, 0)
EVERY_MINUTES = 30
VEHICLES_PER_ROUTE = 2
DEV_ADMIN_PHONE = "+233200000000"  # scripts.seed_dev_data's administrator

# (code, name, latitude, longitude). Codes match scripts.seed_dev_data where
# the stop already exists there, so the two seeds share stops.
STOPS = [
    ("ACC-MAD", "Accra Madina", 5.6687, -0.1664),
    ("ACC-CIR", "Accra Circle", 5.5713, -0.2051),
    ("ACC-LEG", "Accra Legon", 5.6510, -0.1830),
    ("ACC-OSU", "Accra Osu", 5.5565, -0.1800),
    ("ACC-ACH", "Accra Achimota", 5.6135, -0.2290),
    ("TEM-STN", "Tema Station", 5.6667, -0.0167),
    ("ACC-KAN", "Accra Kaneshie", 5.5558, -0.2361),
    ("ACC-LPZ", "Accra Lapaz", 5.6062, -0.2507),
    ("ACC-AIR", "Accra Airport Junction", 5.6052, -0.1718),
    ("ACC-37", "Accra 37 Station", 5.5875, -0.1830),
]


@dataclass(frozen=True)
class RouteSpec:
    name: str
    stops: tuple[str, ...]
    road_km: int
    minutes: int
    fare: Decimal
    vehicle: tuple[VehicleType, str, str, int]  # type, make, model, seats


ROUTES = [
    RouteSpec(
        "Madina → Circle",
        ("ACC-MAD", "ACC-LEG", "ACC-37", "ACC-CIR"),
        14,
        45,
        Decimal("8.00"),
        (VehicleType.MINIBUS, "Toyota", "Hiace", 15),
    ),
    RouteSpec(
        "Tema → Circle",
        ("TEM-STN", "ACC-AIR", "ACC-37", "ACC-CIR"),
        30,
        60,
        Decimal("15.00"),
        (VehicleType.BUS, "Yutong", "ZK6107", 30),
    ),
    RouteSpec(
        "Achimota → Osu",
        ("ACC-ACH", "ACC-CIR", "ACC-OSU"),
        12,
        40,
        Decimal("7.00"),
        (VehicleType.MINIBUS, "Toyota", "Hiace", 15),
    ),
    RouteSpec(
        "Kaneshie → Madina",
        ("ACC-KAN", "ACC-LPZ", "ACC-ACH", "ACC-LEG", "ACC-MAD"),
        22,
        60,
        Decimal("12.00"),
        (VehicleType.SHUTTLE, "Mercedes-Benz", "Sprinter", 20),
    ),
    RouteSpec(
        "Lapaz → Airport",
        ("ACC-LPZ", "ACC-ACH", "ACC-AIR"),
        13,
        35,
        Decimal("8.00"),
        (VehicleType.MINIBUS, "Toyota", "Hiace", 15),
    ),
    RouteSpec(
        "Osu → Legon",
        ("ACC-OSU", "ACC-37", "ACC-AIR", "ACC-LEG"),
        15,
        45,
        Decimal("9.00"),
        (VehicleType.SHUTTLE, "Mercedes-Benz", "Sprinter", 20),
    ),
]

# (local phone, name). The three demo drivers drive the first vehicle of
# the first three routes; pool drivers take every other vehicle.
PASSENGER = ("0245550201", "Ama Serwaa")
FLEET_OWNER = ("0245550202", "Kwesi Appiah")
DEMO_DRIVERS = [
    ("0245550211", "Kofi Mensah"),
    ("0245550212", "Abena Owusu"),
    ("0245550213", "Yaw Boateng"),
]


def departures(day: date) -> list[datetime]:
    """Every departure on ``day`` (UTC is Ghana time)."""
    moment = datetime.combine(day, FIRST_DEPARTURE, tzinfo=UTC)
    last = datetime.combine(day, LAST_DEPARTURE, tzinfo=UTC)
    out = []
    while moment <= last:
        out.append(moment)
        moment += timedelta(minutes=EVERY_MINUTES)
    return out


def vehicle_slot(departure: datetime) -> int:
    """Which of a route's vehicles runs this departure: they alternate."""
    start = datetime.combine(departure.date(), FIRST_DEPARTURE, tzinfo=UTC)
    return int((departure - start).total_seconds() // (EVERY_MINUTES * 60)) % VEHICLES_PER_ROUTE


def _e164(local: str) -> str:
    return "+233" + local[1:]


async def ensure_account(
    session: AsyncSession, local_phone: str, full_name: str, roles: dict[str, Role]
) -> User:
    """A verified passenger account with the demo password (existing ones
    are left as they are)."""
    phone = _e164(local_phone)
    found = await session.execute(select(User).where(User.phone_number == phone))
    user = found.scalar_one_or_none()
    if user is not None:
        return user
    user = User(
        phone_number=phone,
        password_hash=hash_password(DEMO_PASSWORD),
        is_active=True,
        phone_verified_at=datetime.now(UTC),
    )
    user.profile = UserProfile(full_name=full_name, preferred_language="en")
    session.add(user)
    await session.flush()
    session.add(UserRole(user_id=user.id, role_id=roles[SystemRole.PASSENGER.value].id))
    session.add(NotificationPreference(user_id=user.id))
    await session.flush()
    return user


async def ensure_stops(session: AsyncSession) -> dict[str, uuid.UUID]:
    stops = StopRepository(session)
    ids: dict[str, uuid.UUID] = {}
    for code, name, latitude, longitude in STOPS:
        found = await session.execute(select(Stop).where(Stop.code == code))
        stop = found.scalar_one_or_none()
        if stop is None:
            stop = await stops.create(
                name=name,
                code=code,
                latitude=latitude,
                longitude=longitude,
                address=None,
                city="Tema" if code.startswith("TEM") else "Accra",
                region="Greater Accra",
            )
        ids[code] = stop.id
    return ids


async def ensure_routes(session: AsyncSession, stop_ids: dict[str, uuid.UUID]) -> dict[str, Route]:
    service = RouteService(session)
    routes: dict[str, Route] = {}
    for spec in ROUTES:
        found = await session.execute(select(Route).where(Route.name == spec.name))
        route = found.scalar_one_or_none()
        if route is None:
            route = await service.create_route(
                name=spec.name,
                origin_stop_id=stop_ids[spec.stops[0]],
                destination_stop_id=stop_ids[spec.stops[-1]],
                distance_km=Decimal(spec.road_km),
                estimated_duration_minutes=spec.minutes,
                intermediate_stop_ids=[stop_ids[code] for code in spec.stops[1:-1]],
                created_by=None,
            )
        routes[spec.name] = route
    return routes


async def ensure_fleet(
    session: AsyncSession, owner: User, admin_reviewer: User, roles: dict[str, Role]
) -> dict[str, list[tuple[Vehicle, Driver]]]:
    """Two approved vehicles per route, each with an approved driver."""
    storage, scanner = SandboxStorageProvider(), NoOpMalwareScanner()
    fleets = FleetService(session, storage, scanner)
    drivers = DriverService(session, storage, scanner)

    found_owner = await session.execute(select(FleetOwner).where(FleetOwner.user_id == owner.id))
    fleet_owner = found_owner.scalar_one_or_none()
    if fleet_owner is None:
        fleet_owner = await fleets.register(
            owner.id, FleetOwnerRegisterRequest(business_name="Accra Demo Transport")
        )
    if fleet_owner.status != ApprovalStatus.APPROVED:
        await fleets.approve_fleet_owner(fleet_owner.id)
    own_fleets = await fleets.list_own_fleets(owner.id)
    fleet = (
        own_fleets[0]
        if own_fleets
        else await fleets.create_fleet(owner.id, FleetCreateRequest(name="Demo Fleet"))
    )

    pool = 0
    by_route: dict[str, list[tuple[Vehicle, Driver]]] = {}
    for route_index, spec in enumerate(ROUTES):
        pairs = []
        for slot in range(VEHICLES_PER_ROUTE):
            if slot == 0 and route_index < len(DEMO_DRIVERS):
                phone, name = DEMO_DRIVERS[route_index]
            else:
                pool += 1
                phone, name = f"02455503{pool:02d}", f"Pool Driver {pool}"
            user = await ensure_account(session, phone, name, roles)
            found_driver = await session.execute(select(Driver).where(Driver.user_id == user.id))
            driver = found_driver.scalar_one_or_none()
            if driver is None:
                driver = await drivers.register(
                    user.id,
                    DriverRegisterRequest(
                        license_number=f"DEMO-{phone[-4:]}",
                        license_expiry=date.today() + timedelta(days=730),
                    ),
                )
            if driver.status != ApprovalStatus.APPROVED:
                await drivers.approve(driver.id, reviewer_id=admin_reviewer.id, notes="Demo data")

            registration = f"GD-{route_index + 1}{slot + 1}-26"
            found_vehicle = await session.execute(
                select(Vehicle).where(Vehicle.registration_number == registration)
            )
            vehicle = found_vehicle.scalar_one_or_none()
            kind, make, model, seats = spec.vehicle
            if vehicle is None:
                vehicle = await fleets.create_vehicle(
                    owner.id,
                    fleet.id,
                    VehicleCreateRequest(
                        registration_number=registration,
                        vehicle_type=kind,
                        make=make,
                        model=model,
                        year=2021,
                        capacity=seats,
                    ),
                )
                await fleets.set_seat_layout(owner.id, vehicle.id, _layout(seats))
                await fleets.approve_vehicle(
                    vehicle.id, reviewer_id=admin_reviewer.id, notes="Demo data"
                )
                await fleets.assign_driver(owner.id, vehicle.id, driver.id)
            pairs.append((vehicle, driver))
        by_route[spec.name] = pairs
    return by_route


def _layout(seats: int) -> SeatLayoutRequest:
    """Rows of three (minibus) or four (bus, shuttle), labelled A1, A2, B1..."""
    columns = 3 if seats <= 15 else 4
    rows = -(-seats // columns)
    return SeatLayoutRequest(
        rows=rows,
        columns=columns,
        seats=[
            SeatInput(
                seat_number=f"{chr(ord('A') + i // columns)}{i % columns + 1}",
                row_number=i // columns + 1,
                column_number=i % columns + 1,
            )
            for i in range(seats)
        ],
    )


async def ensure_timetable(
    session: AsyncSession,
    routes: dict[str, Route],
    fleet: dict[str, list[tuple[Vehicle, Driver]]],
) -> int:
    """Trips from now until DAYS_AHEAD days out; returns how many were added."""
    now = datetime.now(UTC)
    first_day = now.date()
    horizon = datetime.combine(first_day + timedelta(days=DAYS_AHEAD + 1), time.min, tzinfo=UTC)
    route_ids = [route.id for route in routes.values()]
    existing = await session.execute(
        select(Trip.route_id, Trip.scheduled_departure_at).where(
            Trip.route_id.in_(route_ids),
            Trip.scheduled_departure_at >= now,
            Trip.scheduled_departure_at < horizon,
        )
    )
    have = {(row.route_id, row.scheduled_departure_at) for row in existing}

    trips, vehicles, drivers = [], [], []
    for spec in ROUTES:
        route = routes[spec.name]
        for offset in range(DAYS_AHEAD + 1):
            for departure in departures(first_day + timedelta(days=offset)):
                if departure <= now or (route.id, departure) in have:
                    continue
                trip_id = uuid.uuid4()
                vehicle, driver = fleet[spec.name][vehicle_slot(departure)]
                trips.append(
                    {
                        "id": trip_id,
                        "route_id": route.id,
                        "scheduled_departure_at": departure,
                        "scheduled_arrival_at": departure + timedelta(minutes=spec.minutes),
                        "status": TripStatus.SCHEDULED,
                        "fare_amount": spec.fare,
                    }
                )
                vehicles.append({"trip_id": trip_id, "vehicle_id": vehicle.id, "assigned_at": now})
                drivers.append({"trip_id": trip_id, "driver_id": driver.id, "assigned_at": now})
    if trips:
        # Bulk inserts: one round trip per thousand rows rather than per row.
        await session.execute(insert(Trip), trips)
        await session.execute(insert(TripVehicleAssignment), vehicles)
        await session.execute(insert(TripDriverAssignment), drivers)
    return len(trips)


async def ensure_passenger_history(
    session: AsyncSession,
    passenger: User,
    routes: dict[str, Route],
    fleet: dict[str, list[tuple[Vehicle, Driver]]],
) -> None:
    """GHS 200 in the wallet, three completed trips and one upcoming one."""
    await WalletService(session).credit(
        passenger.id,
        amount=Decimal("200.00"),
        reference_type=WalletReferenceType.WALLET_TOPUP,
        reference_id=None,
        description="Demo wallet top-up",
        idempotency_key="demo-wallet-topup",
    )
    already = await session.execute(
        select(Booking.id).where(Booking.passenger_id == passenger.id).limit(1)
    )
    if already.first() is not None:
        return

    fares = FareService()
    bookings = BookingRepository(session)
    history = [
        (ROUTES[0], 1, (1, 3)),  # Madina -> Circle, yesterday, Legon -> Circle
        (ROUTES[2], 3, (0, 2)),  # Achimota -> Osu, 3 days ago, end to end
        (ROUTES[3], 10, (1, 4)),  # Kaneshie -> Madina, 10 days ago, Lapaz -> Madina
    ]
    for spec, days_ago, (board, alight) in history:
        route = routes[spec.name]
        vehicle, driver = fleet[spec.name][0]
        departs = datetime.combine(
            datetime.now(UTC).date() - timedelta(days=days_ago), time(7, 30), tzinfo=UTC
        )
        trip = Trip(
            route_id=route.id,
            scheduled_departure_at=departs,
            scheduled_arrival_at=departs + timedelta(minutes=spec.minutes),
            actual_departure_at=departs + timedelta(minutes=3),
            actual_arrival_at=departs + timedelta(minutes=spec.minutes + 5),
            status=TripStatus.COMPLETED,
            fare_amount=spec.fare,
        )
        session.add(trip)
        await session.flush()
        session.add(TripVehicleAssignment(trip_id=trip.id, vehicle_id=vehicle.id))
        session.add(TripDriverAssignment(trip_id=trip.id, driver_id=driver.id))

        stop_ids = await _route_stop_ids(session, route)
        segment_share = Decimal(alight - board) / Decimal(len(spec.stops) - 1)
        segment_km = Decimal(spec.road_km) * segment_share
        # Four other riders on the whole route: a typical shared fare.
        quote = fares.quote(
            full_route_fare=spec.fare,
            segment_km=segment_km,
            route_km=Decimal(spec.road_km),
            total_passenger_km=segment_km + 4 * Decimal(spec.road_km),
        )
        fee = fares.platform_fee(quote.per_seat_fare, 1)
        booking = Booking(
            booking_reference=bookings.generate_booking_reference(),
            passenger_id=passenger.id,
            trip_id=trip.id,
            status=BookingStatus.COMPLETED,
            origin_stop_id=stop_ids[board],
            destination_stop_id=stop_ids[alight],
            passenger_count=1,
            fare_amount=quote.per_seat_fare,
            platform_fee=fee,
            total_amount=quote.per_seat_fare + fee,
            solo_fare_amount=quote.solo_fare,
        )
        session.add(booking)
        await session.flush()
        seat = await _first_seat(session, vehicle)
        session.add(BookingPassenger(booking_id=booking.id, seat_id=seat, full_name=PASSENGER[1]))
        session.add(
            SeatReservation(
                trip_id=trip.id,
                seat_id=seat,
                booking_id=booking.id,
                status=ReservationStatus.CONFIRMED,
                held_at=departs - timedelta(hours=2),
                confirmed_at=departs - timedelta(hours=2),
            )
        )
        session.add(
            Payment(
                user_id=passenger.id,
                booking_id=booking.id,
                purpose=PaymentPurpose.BOOKING_PAYMENT,
                channel=PaymentChannel.MTN_MOMO,
                status=PaymentStatus.SUCCESSFUL,
                amount=booking.total_amount,
                currency="GHS",
                payer_phone_number=passenger.phone_number,
                internal_reference=f"DEMO-{uuid.uuid4().hex[:16].upper()}",
                initiated_at=departs - timedelta(hours=2),
                completed_at=departs - timedelta(hours=2),
            )
        )
        await session.flush()
        if days_ago == 1:
            await RatingService(session).rate_booking(
                booking.id,
                passenger_id=passenger.id,
                score=5,
                comment="Smooth ride, friendly driver.",
                categories={"safety": 5, "cleanliness": 4, "professionalism": 5, "timeliness": 4},
            )

    # One upcoming paid upcoming tomorrow morning, booked the way the app does.
    route = routes[ROUTES[0].name]
    tomorrow = datetime.combine(
        datetime.now(UTC).date() + timedelta(days=1), time(8, 0), tzinfo=UTC
    )
    found = await session.execute(
        select(Trip).where(Trip.route_id == route.id, Trip.scheduled_departure_at == tomorrow)
    )
    upcoming = found.scalar_one_or_none()
    if upcoming is not None:
        vehicle, driver = fleet[ROUTES[0].name][vehicle_slot(tomorrow)]
        stop_ids = await _route_stop_ids(session, route)
        service = BookingService(session)
        booking = await service.create_booking(
            passenger.id,
            BookingCreateRequest(
                trip_id=upcoming.id,
                passengers=[
                    PassengerInput(
                        seat_id=await _first_seat(session, vehicle), full_name=PASSENGER[1]
                    )
                ],
                origin_stop_id=stop_ids[1],
                destination_stop_id=stop_ids[-1],
            ),
            idempotency_key=None,
        )
        if booking.status == BookingStatus.AWAITING_ACCEPTANCE:
            # Its driver says yes first, as in the app; then it is paid.
            await BookingAcceptanceService(session).accept(
                booking.id, actor_id=driver.user_id, as_admin=False, trip_id=upcoming.id
            )
        await service.confirm_booking(booking.id)


async def _route_stop_ids(session: AsyncSession, route: Route) -> list[uuid.UUID]:
    geometry = (await RouteGeometryRepository(session).for_routes([route.id]))[route.id]
    return [point.stop_id for point in geometry.points]


async def _first_seat(session: AsyncSession, vehicle: Vehicle) -> uuid.UUID:
    found = await session.execute(
        select(VehicleSeat.id)
        .join(VehicleSeatLayout, VehicleSeatLayout.id == VehicleSeat.layout_id)
        .where(VehicleSeatLayout.vehicle_id == vehicle.id)
        .order_by(VehicleSeat.row_number, VehicleSeat.column_number)
        .limit(1)
    )
    return found.scalar_one()


async def seed_demo_data() -> None:
    settings = get_settings()
    if settings.APP_ENV == AppEnv.PRODUCTION:
        raise SystemExit("Refusing to load demo accounts into a production database.")
    await seed_reference_data()
    async with transactional_session() as session:
        roles = await ensure_roles(session)
        passenger = await ensure_account(session, *PASSENGER, roles)
        owner = await ensure_account(session, *FLEET_OWNER, roles)
        # Approvals are credited to the dev admin when `make seed` created
        # one, else to the fleet owner (a fresh stack has no admin).
        found = await session.execute(select(User).where(User.phone_number == DEV_ADMIN_PHONE))
        reviewer = found.scalar_one_or_none() or owner
        stop_ids = await ensure_stops(session)
        routes = await ensure_routes(session, stop_ids)
        fleet = await ensure_fleet(session, owner, reviewer, roles)
        added = await ensure_timetable(session, routes, fleet)
        await ensure_passenger_history(session, passenger, routes, fleet)
    logger.info("demo_data_ready", trips_added=added)
    print(f"\nDemo data ready ({added} new trips). Password for every account: {DEMO_PASSWORD}")
    print(f"  passenger    {PASSENGER[0]}  {PASSENGER[1]}  (GHS 200 wallet, 4 bookings)")
    print(f"  fleet owner  {FLEET_OWNER[0]}  {FLEET_OWNER[1]}")
    for (phone, name), spec in zip(DEMO_DRIVERS, ROUTES, strict=False):
        print(f"  driver       {phone}  {name}  ({spec.name.replace('→', '->')})")


async def main() -> None:
    configure_logging(log_level="INFO", json_logs=False)
    try:
        await seed_demo_data()
    finally:
        await dispose_engine()


if __name__ == "__main__":
    asyncio.run(main())
