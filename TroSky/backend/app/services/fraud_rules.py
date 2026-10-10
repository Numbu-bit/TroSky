"""The fraud rules: what each looks for, its defaults, and the query that
finds it.

Each rule has a threshold, a time window and a severity, all of which an
admin can change (``/admin/fraud/rules``). A detector returns what crossed
the threshold within the window as ``Detection``s; ``FraudService`` turns
those into flags. Every detection names its incident with a fingerprint --
this ticket, this user on this day, this trip -- so finding it again updates
the same flag instead of raising another.
"""

from __future__ import annotations

import uuid
from collections.abc import Awaitable, Callable
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from decimal import Decimal
from typing import Any

from sqlalchemy import Numeric, cast, distinct, func, select, union
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.bookings import Booking, BookingStatus, BookingStatusHistory
from app.models.drivers import Driver
from app.models.fraud import FraudSeverity, TicketScanAttempt, TicketScanOutcome
from app.models.identity import DeviceRegistration, UserSession
from app.models.payments import (
    Payment,
    PaymentMethod,
    PaymentStatus,
    Wallet,
    WalletEntryType,
    WalletReferenceType,
    WalletTransaction,
)
from app.models.tickets import Ticket, TicketStatus
from app.models.tracking import TripLocation
from app.models.trips import Trip, TripDriverAssignment, TripStatus
from app.providers.payments.base import PaymentChannel
from app.utilities.geo import haversine_distance_km

PAID_BOOKINGS = (
    BookingStatus.CONFIRMED,
    BookingStatus.COMPLETED,
    BookingStatus.REFUND_PENDING,
    BookingStatus.REFUNDED,
)
REFUNDED_BOOKINGS = (BookingStatus.REFUND_PENDING, BookingStatus.REFUNDED)
MOBILE_MONEY = (
    PaymentChannel.MTN_MOMO,
    PaymentChannel.TELECEL_CASH,
    PaymentChannel.AIRTELTIGO_MONEY,
)
# Too few to judge a share by.
MIN_BOOKINGS_FOR_REFUND_SHARE = 4
MIN_PASSENGERS_FOR_SCAN_SHARE = 10
# A trip with fewer positions than this was not tracked enough to judge.
MIN_POINTS_FOR_MOVEMENT = 5
# Ids linked from a flag, per kind.
MAX_LINKS = 20


@dataclass(frozen=True, slots=True)
class RuleDefinition:
    key: str
    title: str
    threshold_means: str
    threshold: Decimal
    window_minutes: int
    severity: FraudSeverity
    # True when falling below the threshold is the warning sign.
    below: bool = False


@dataclass(frozen=True, slots=True)
class RuleConfig:
    key: str
    enabled: bool
    threshold: Decimal
    window_minutes: int
    severity: FraudSeverity


@dataclass(frozen=True, slots=True)
class Detection:
    fingerprint: str
    entity_type: str
    entity_id: str
    subject_user_id: uuid.UUID | None
    summary: str
    observed: Decimal
    amount_at_risk: Decimal | None = None
    evidence: dict[str, Any] = field(default_factory=dict)


RULES: dict[str, RuleDefinition] = {
    rule.key: rule
    for rule in (
        RuleDefinition(
            "ticket_reused",
            "A ticket scanned again after boarding, or on another trip",
            "refused scans",
            Decimal("1"),
            24 * 60,
            FraudSeverity.HIGH,
        ),
        RuleDefinition(
            "payment_failures",
            "Repeated payment failures in a short time",
            "failed payments",
            Decimal("5"),
            60,
            FraudSeverity.MEDIUM,
        ),
        RuleDefinition(
            "shared_device",
            "Several accounts signing in on one device",
            "accounts",
            Decimal("3"),
            30 * 24 * 60,
            FraudSeverity.HIGH,
        ),
        RuleDefinition(
            "shared_momo_number",
            "Several accounts paying with one mobile money number",
            "accounts",
            Decimal("3"),
            30 * 24 * 60,
            FraudSeverity.HIGH,
        ),
        RuleDefinition(
            "expired_reservations",
            "Seat reservations repeatedly left to expire unpaid",
            "expired reservations",
            Decimal("5"),
            7 * 24 * 60,
            FraudSeverity.LOW,
        ),
        RuleDefinition(
            "refund_share",
            "A high share of a passenger's bookings refunded",
            "share of paid bookings refunded (0-1)",
            Decimal("0.5"),
            30 * 24 * 60,
            FraudSeverity.MEDIUM,
        ),
        RuleDefinition(
            "stationary_trip",
            "A completed trip whose vehicle barely moved",
            "km moved, at most",
            Decimal("0.2"),
            24 * 60,
            FraudSeverity.MEDIUM,
            below=True,
        ),
        RuleDefinition(
            "impossible_speed",
            "A jump between GPS positions faster than a bus can go",
            "km/h",
            Decimal("150"),
            24 * 60,
            FraudSeverity.HIGH,
        ),
        RuleDefinition(
            "low_scan_compliance",
            "A driver scanning few of their paid passengers' tickets",
            "share of paid passengers scanned (0-1), at most",
            Decimal("0.5"),
            7 * 24 * 60,
            FraudSeverity.MEDIUM,
            below=True,
        ),
        RuleDefinition(
            "unusual_topups",
            "Unusually large wallet top-ups",
            "GHS topped up",
            Decimal("2000"),
            24 * 60,
            FraudSeverity.MEDIUM,
        ),
    )
}

_BASE_RISK = {
    FraudSeverity.LOW: 25,
    FraudSeverity.MEDIUM: 50,
    FraudSeverity.HIGH: 70,
    FraudSeverity.CRITICAL: 90,
}


def risk_score(rule: RuleDefinition, config: RuleConfig, observed: Decimal) -> int:
    """0-100: the severity's base, plus up to 20 for how far past the
    threshold the finding is (twice as far, or more, scores the most)."""
    if rule.below:
        ratio = config.threshold / observed if observed > 0 else Decimal(2)
    else:
        ratio = observed / config.threshold if config.threshold > 0 else Decimal(2)
    beyond = min(Decimal(1), max(Decimal(0), ratio - 1))
    return min(100, _BASE_RISK[config.severity] + int(beyond * 20))


def _links(**kinds: list[Any]) -> dict[str, list[str]]:
    return {
        kind: [str(value) for value in dict.fromkeys(values) if value is not None][:MAX_LINKS]
        for kind, values in kinds.items()
        if values
    }


def _window(config: RuleConfig, now: datetime) -> datetime:
    return now - timedelta(minutes=config.window_minutes)


def _iso_week(moment: datetime) -> str:
    year, week, _ = moment.isocalendar()
    return f"{year}-W{week:02d}"


def _trip_driver() -> Any:
    """Each trip's driver: their user id and driver id."""
    return (
        select(
            TripDriverAssignment.trip_id,
            Driver.id.label("driver_id"),
            Driver.user_id.label("driver_user_id"),
        )
        .join(Driver, Driver.id == TripDriverAssignment.driver_id)
        .where(TripDriverAssignment.is_active.is_(True))
        .subquery("trip_driver")
    )


def _trip_fares() -> Any:
    """Each trip's paid fares."""
    return (
        select(Booking.trip_id, func.sum(Booking.fare_amount).label("fares"))
        .where(Booking.status.in_(PAID_BOOKINGS))
        .group_by(Booking.trip_id)
        .subquery("trip_fares")
    )


# ---------------------------------------------------------------- detectors
async def _ticket_reused(
    session: AsyncSession, config: RuleConfig, now: datetime
) -> list[Detection]:
    attempts = (
        select(
            TicketScanAttempt.ticket_id,
            func.count().label("refused"),
            func.count()
            .filter(TicketScanAttempt.outcome == TicketScanOutcome.WRONG_TRIP)
            .label("wrong_trip"),
            func.array_agg(distinct(TicketScanAttempt.trip_id)).label("trips"),
            func.array_agg(distinct(TicketScanAttempt.scanned_by)).label("scanners"),
        )
        .where(TicketScanAttempt.created_at >= _window(config, now))
        .group_by(TicketScanAttempt.ticket_id)
        .having(func.count() >= config.threshold)
        .subquery("attempts")
    )
    rows = await session.execute(
        select(
            Ticket.id,
            Ticket.ticket_reference,
            Ticket.trip_id,
            Booking.id,
            Booking.booking_reference,
            Booking.passenger_id,
            Booking.fare_amount / Booking.passenger_count,
            attempts.c.refused,
            attempts.c.wrong_trip,
            attempts.c.trips,
            attempts.c.scanners,
        )
        .join(attempts, attempts.c.ticket_id == Ticket.id)
        .join(Booking, Booking.id == Ticket.booking_id)
    )
    found = []
    for (
        ticket_id,
        reference,
        trip_id,
        booking_id,
        booking_reference,
        passenger_id,
        fare,
        refused,
        wrong_trip,
        trips,
        scanners,
    ) in rows.all():
        found.append(
            Detection(
                fingerprint=f"ticket_reused:{ticket_id}",
                entity_type="ticket",
                entity_id=str(ticket_id),
                subject_user_id=passenger_id,
                summary=(
                    f"Ticket {reference} was refused {refused} time(s): "
                    f"{wrong_trip} on another trip, {refused - wrong_trip} after boarding."
                ),
                observed=Decimal(refused),
                amount_at_risk=Decimal(fare).quantize(Decimal("0.01")),
                evidence={
                    "ticket_reference": reference,
                    "booking_reference": booking_reference,
                    "refused_scans": refused,
                    "on_another_trip": wrong_trip,
                    "links": _links(
                        users=[passenger_id, *scanners],
                        trips=[trip_id, *trips],
                        bookings=[booking_id],
                    ),
                },
            )
        )
    return found


async def _payment_failures(
    session: AsyncSession, config: RuleConfig, now: datetime
) -> list[Detection]:
    rows = await session.execute(
        select(
            Payment.user_id,
            func.count(),
            func.sum(Payment.amount),
            func.array_agg(Payment.id),
            func.count(distinct(Payment.payer_phone_number)),
        )
        .where(Payment.status == PaymentStatus.FAILED, Payment.created_at >= _window(config, now))
        .group_by(Payment.user_id)
        .having(func.count() >= config.threshold)
    )
    return [
        Detection(
            fingerprint=f"payment_failures:{user_id}:{now.date()}",
            entity_type="user",
            entity_id=str(user_id),
            subject_user_id=user_id,
            summary=f"{failures} failed payments within {config.window_minutes} minutes.",
            observed=Decimal(failures),
            evidence={
                "failed_payments": failures,
                "amount_attempted": str(attempted),
                "payer_numbers": numbers,
                "links": _links(users=[user_id], payments=list(payments)),
            },
        )
        for user_id, failures, attempted, payments, numbers in rows.all()
    ]


async def _shared_device(
    session: AsyncSession, config: RuleConfig, now: datetime
) -> list[Detection]:
    since = _window(config, now)
    seen = union(
        select(UserSession.device_id, UserSession.user_id).where(
            UserSession.device_id.is_not(None), UserSession.created_at >= since
        ),
        select(DeviceRegistration.device_id, DeviceRegistration.user_id).where(
            DeviceRegistration.last_seen_at >= since
        ),
    ).subquery("seen")
    accounts = func.count(distinct(seen.c.user_id))
    rows = await session.execute(
        select(seen.c.device_id, accounts, func.array_agg(distinct(seen.c.user_id)))
        .group_by(seen.c.device_id)
        .having(accounts >= config.threshold)
    )
    return [
        Detection(
            fingerprint=f"shared_device:{device_id}",
            entity_type="device",
            entity_id=str(device_id),
            subject_user_id=None,
            summary=f"{count} accounts signed in on one device.",
            observed=Decimal(count),
            evidence={"accounts": count, "links": _links(users=list(users))},
        )
        for device_id, count, users in rows.all()
    ]


async def _shared_momo_number(
    session: AsyncSession, config: RuleConfig, now: datetime
) -> list[Detection]:
    since = _window(config, now)
    used = union(
        select(Payment.payer_phone_number.label("number"), Payment.user_id).where(
            Payment.payer_phone_number.is_not(None),
            Payment.channel.in_(MOBILE_MONEY),
            Payment.created_at >= since,
        ),
        select(PaymentMethod.phone_number, PaymentMethod.user_id).where(
            PaymentMethod.created_at >= since
        ),
    ).subquery("used")
    accounts = func.count(distinct(used.c.user_id))
    rows = await session.execute(
        select(used.c.number, accounts, func.array_agg(distinct(used.c.user_id)))
        .group_by(used.c.number)
        .having(accounts >= config.threshold)
    )
    return [
        Detection(
            fingerprint=f"shared_momo_number:{number}",
            entity_type="phone_number",
            entity_id=str(number),
            subject_user_id=None,
            summary=f"{count} accounts paying with one mobile money number.",
            observed=Decimal(count),
            evidence={"accounts": count, "links": _links(users=list(users))},
        )
        for number, count, users in rows.all()
    ]


async def _expired_reservations(
    session: AsyncSession, config: RuleConfig, now: datetime
) -> list[Detection]:
    expired = func.count(distinct(Booking.id))
    rows = await session.execute(
        select(
            Booking.passenger_id,
            expired,
            func.sum(Booking.passenger_count),
            func.array_agg(distinct(Booking.id)),
        )
        .join(BookingStatusHistory, BookingStatusHistory.booking_id == Booking.id)
        .where(
            BookingStatusHistory.to_status == BookingStatus.EXPIRED,
            BookingStatusHistory.changed_at >= _window(config, now),
        )
        .group_by(Booking.passenger_id)
        .having(expired >= config.threshold)
    )
    return [
        Detection(
            fingerprint=f"expired_reservations:{user_id}:{_iso_week(now)}",
            entity_type="user",
            entity_id=str(user_id),
            subject_user_id=user_id,
            summary=f"{count} reservations ({seats} seats) left to expire unpaid.",
            observed=Decimal(count),
            evidence={
                "expired_reservations": count,
                "seats_held": seats,
                "links": _links(users=[user_id], bookings=list(bookings)),
            },
        )
        for user_id, count, seats, bookings in rows.all()
    ]


async def _refund_share(
    session: AsyncSession, config: RuleConfig, now: datetime
) -> list[Detection]:
    paid = func.count().filter(Booking.status.in_(PAID_BOOKINGS))
    refunded = func.count().filter(Booking.status.in_(REFUNDED_BOOKINGS))
    share = cast(refunded, Numeric) / func.nullif(paid, 0)
    rows = await session.execute(
        select(
            Booking.passenger_id,
            paid,
            refunded,
            func.coalesce(
                func.sum(Booking.fare_amount).filter(Booking.status.in_(REFUNDED_BOOKINGS)), 0
            ),
            func.array_agg(Booking.id).filter(Booking.status.in_(REFUNDED_BOOKINGS)),
        )
        .where(Booking.created_at >= _window(config, now))
        .group_by(Booking.passenger_id)
        .having(paid >= MIN_BOOKINGS_FOR_REFUND_SHARE, share >= config.threshold)
    )
    found = []
    for user_id, paid_count, refunded_count, amount, bookings in rows.all():
        observed = (Decimal(refunded_count) / paid_count).quantize(Decimal("0.0001"))
        found.append(
            Detection(
                fingerprint=f"refund_share:{user_id}:{now:%Y-%m}",
                entity_type="user",
                entity_id=str(user_id),
                subject_user_id=user_id,
                summary=f"{refunded_count} of {paid_count} paid bookings refunded.",
                observed=observed,
                amount_at_risk=Decimal(amount).quantize(Decimal("0.01")),
                evidence={
                    "paid_bookings": paid_count,
                    "refunded_bookings": refunded_count,
                    "links": _links(users=[user_id], bookings=list(bookings or [])),
                },
            )
        )
    return found


async def _stationary_trip(
    session: AsyncSession, config: RuleConfig, now: datetime
) -> list[Detection]:
    point = func.geometry(TripLocation.location)
    ended = select(Trip.id).where(
        Trip.status == TripStatus.COMPLETED, Trip.actual_arrival_at >= _window(config, now)
    )
    track = (
        select(
            TripLocation.trip_id,
            func.count().label("points"),
            func.min(func.ST_Y(point)).label("south"),
            func.max(func.ST_Y(point)).label("north"),
            func.min(func.ST_X(point)).label("west"),
            func.max(func.ST_X(point)).label("east"),
        )
        .where(TripLocation.trip_id.in_(ended))
        .group_by(TripLocation.trip_id)
        .subquery("track")
    )
    driver, fares = _trip_driver(), _trip_fares()
    rows = await session.execute(
        select(
            Trip.id,
            track.c.points,
            track.c.south,
            track.c.north,
            track.c.west,
            track.c.east,
            driver.c.driver_user_id,
            fares.c.fares,
        )
        .join(track, track.c.trip_id == Trip.id)
        .outerjoin(driver, driver.c.trip_id == Trip.id)
        .outerjoin(fares, fares.c.trip_id == Trip.id)
        .where(
            Trip.status == TripStatus.COMPLETED,
            Trip.actual_arrival_at >= _window(config, now),
            track.c.points >= MIN_POINTS_FOR_MOVEMENT,
        )
    )
    found = []
    for trip_id, points, south, north, west, east, driver_user_id, paid in rows.all():
        # The diagonal of everywhere the vehicle was: the most it can have moved.
        moved = Decimal(str(round(haversine_distance_km(south, west, north, east), 3)))
        if moved > config.threshold:
            continue
        found.append(
            Detection(
                fingerprint=f"stationary_trip:{trip_id}",
                entity_type="trip",
                entity_id=str(trip_id),
                subject_user_id=driver_user_id,
                summary=f"The vehicle moved at most {moved} km across {points} GPS positions.",
                observed=moved,
                amount_at_risk=Decimal(paid).quantize(Decimal("0.01")) if paid else None,
                evidence={
                    "km_moved_at_most": str(moved),
                    "positions": points,
                    "links": _links(trips=[trip_id], users=[driver_user_id]),
                },
            )
        )
    return found


async def _impossible_speed(
    session: AsyncSession, config: RuleConfig, now: datetime
) -> list[Detection]:
    pings = (
        select(
            TripLocation.trip_id,
            TripLocation.recorded_at,
            func.ST_Distance(
                TripLocation.location,
                func.lag(TripLocation.location).over(
                    partition_by=TripLocation.trip_id, order_by=TripLocation.recorded_at
                ),
            ).label("metres"),
            func.lag(TripLocation.recorded_at)
            .over(partition_by=TripLocation.trip_id, order_by=TripLocation.recorded_at)
            .label("previous_at"),
        )
        .where(TripLocation.recorded_at >= _window(config, now))
        .subquery("pings")
    )
    hours = func.extract("epoch", pings.c.recorded_at - pings.c.previous_at) / 3600
    speed = pings.c.metres / 1000 / hours
    segments = (
        select(pings.c.trip_id, speed.label("kmh"))
        .where(pings.c.previous_at.is_not(None), pings.c.recorded_at > pings.c.previous_at)
        .subquery("segments")
    )
    top = func.max(segments.c.kmh)
    driver, fares = _trip_driver(), _trip_fares()
    rows = await session.execute(
        select(
            segments.c.trip_id,
            top,
            func.count().filter(segments.c.kmh > config.threshold),
            driver.c.driver_user_id,
            fares.c.fares,
        )
        .outerjoin(driver, driver.c.trip_id == segments.c.trip_id)
        .outerjoin(fares, fares.c.trip_id == segments.c.trip_id)
        .group_by(segments.c.trip_id, driver.c.driver_user_id, fares.c.fares)
        .having(top > config.threshold)
    )
    return [
        Detection(
            fingerprint=f"impossible_speed:{trip_id}",
            entity_type="trip",
            entity_id=str(trip_id),
            subject_user_id=driver_user_id,
            summary=f"{jumps} jump(s) between GPS positions, the fastest at {round(kmh)} km/h.",
            observed=Decimal(str(round(kmh, 1))),
            amount_at_risk=Decimal(paid).quantize(Decimal("0.01")) if paid else None,
            evidence={
                "fastest_kmh": round(kmh, 1),
                "jumps": jumps,
                "links": _links(trips=[trip_id], users=[driver_user_id]),
            },
        )
        for trip_id, kmh, jumps, driver_user_id, paid in rows.all()
    ]


async def _low_scan_compliance(
    session: AsyncSession, config: RuleConfig, now: datetime
) -> list[Detection]:
    driver = _trip_driver()
    passengers = func.count(Ticket.id)
    scanned = func.count(Ticket.id).filter(Ticket.status == TicketStatus.VALIDATED)
    rows = await session.execute(
        select(
            driver.c.driver_id,
            driver.c.driver_user_id,
            passengers,
            scanned,
            func.array_agg(distinct(Trip.id)),
        )
        .select_from(Trip)
        .join(driver, driver.c.trip_id == Trip.id)
        .join(Ticket, Ticket.trip_id == Trip.id)
        .join(Booking, Booking.id == Ticket.booking_id)
        .where(
            Trip.status == TripStatus.COMPLETED,
            Trip.actual_arrival_at >= _window(config, now),
            Booking.status.in_(PAID_BOOKINGS),
        )
        .group_by(driver.c.driver_id, driver.c.driver_user_id)
        .having(
            passengers >= MIN_PASSENGERS_FOR_SCAN_SHARE,
            cast(scanned, Numeric) / passengers <= config.threshold,
        )
    )
    found = []
    for driver_id, driver_user_id, total, valid, trips in rows.all():
        share = (Decimal(valid) / total).quantize(Decimal("0.0001"))
        found.append(
            Detection(
                fingerprint=f"low_scan_compliance:{driver_id}:{_iso_week(now)}",
                entity_type="driver",
                entity_id=str(driver_id),
                subject_user_id=driver_user_id,
                summary=f"Scanned {valid} of {total} paid passengers' tickets.",
                observed=share,
                evidence={
                    "paid_passengers": total,
                    "scanned": valid,
                    "links": _links(users=[driver_user_id], trips=list(trips)),
                },
            )
        )
    return found


async def _unusual_topups(
    session: AsyncSession, config: RuleConfig, now: datetime
) -> list[Detection]:
    total = func.sum(WalletTransaction.amount_minor_units)
    rows = await session.execute(
        select(Wallet.user_id, total, func.count())
        .join(Wallet, Wallet.id == WalletTransaction.wallet_id)
        .where(
            WalletTransaction.reference_type == WalletReferenceType.WALLET_TOPUP,
            WalletTransaction.entry_type == WalletEntryType.CREDIT,
            WalletTransaction.created_at >= _window(config, now),
        )
        .group_by(Wallet.user_id)
        .having(total >= config.threshold * 100)
    )
    found = []
    for user_id, minor_units, count in rows.all():
        amount = (Decimal(minor_units) / 100).quantize(Decimal("0.01"))
        found.append(
            Detection(
                fingerprint=f"unusual_topups:{user_id}:{now.date()}",
                entity_type="user",
                entity_id=str(user_id),
                subject_user_id=user_id,
                summary=f"GHS {amount} topped up in {count} top-up(s).",
                observed=amount,
                amount_at_risk=amount,
                evidence={"topups": count, "links": _links(users=[user_id])},
            )
        )
    return found


Detector = Callable[[AsyncSession, RuleConfig, datetime], Awaitable[list[Detection]]]

DETECTORS: dict[str, Detector] = {
    "ticket_reused": _ticket_reused,
    "payment_failures": _payment_failures,
    "shared_device": _shared_device,
    "shared_momo_number": _shared_momo_number,
    "expired_reservations": _expired_reservations,
    "refund_share": _refund_share,
    "stationary_trip": _stationary_trip,
    "impossible_speed": _impossible_speed,
    "low_scan_compliance": _low_scan_compliance,
    "unusual_topups": _unusual_topups,
}
