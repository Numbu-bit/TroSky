"""Upfront quotes, quote locking and the final fare.

A quote is priced from the predicted distance and time with the pickup zone's
surge, then locked: the rider pays the quoted fare unless the trip changes
materially. A later surge change never touches a locked quote; a reprice uses
the multiplier that was locked into the quote.
"""

from __future__ import annotations

import math
from dataclasses import dataclass
from datetime import datetime, timedelta
from decimal import Decimal

from .config import FareConfig
from .money import ZERO, to_decimal
from .pricing import FareBreakdown, price
from .surge import SurgeResult


class QuoteExpired(Exception):
    """The rider tried to confirm a quote after its time ran out."""


@dataclass(frozen=True)
class Quote:
    quote_id: str
    rider_id: str
    pickup_zone: str
    created_at: datetime
    expires_at: datetime
    predicted_distance_km: Decimal
    predicted_minutes: Decimal
    surge: SurgeResult
    breakdown: FareBreakdown
    config_version: str

    @property
    def fare(self) -> Decimal:
        return self.breakdown.fare


@dataclass(frozen=True)
class FinalFare:
    breakdown: FareBreakdown | None
    amount: Decimal
    basis: str  # quoted | repriced | cancelled_before_pickup | cancelled_mid_trip
    note: str


def create_quote(
    *,
    quote_id: str,
    rider_id: str,
    pickup_zone: str,
    distance_km: object,
    minutes: object,
    surge: SurgeResult,
    config: FareConfig,
    now: datetime,
) -> Quote:
    breakdown = price(distance_km, minutes, surge.multiplier, config)
    return Quote(
        quote_id=quote_id,
        rider_id=rider_id,
        pickup_zone=pickup_zone,
        created_at=now,
        expires_at=now + timedelta(seconds=config.quotes.ttl_seconds),
        predicted_distance_km=breakdown.distance_km,
        predicted_minutes=breakdown.minutes,
        surge=surge,
        breakdown=breakdown,
        config_version=config.config_version,
    )


def confirm_quote(quote: Quote, now: datetime) -> Quote:
    """Lock the quote for the rider; refused once it has expired."""
    if now > quote.expires_at:
        raise QuoteExpired(f"quote {quote.quote_id} expired at {quote.expires_at.isoformat()}")
    return quote


def _within(actual: Decimal, predicted: Decimal, tolerance: Decimal, floor: Decimal) -> bool:
    return abs(actual - predicted) <= max(predicted * tolerance, floor)


def final_fare(
    quote: Quote,
    actual_distance_km: object,
    actual_minutes: object,
    config: FareConfig,
    *,
    route_changed: bool = False,
) -> FinalFare:
    """Charge the locked quote, or reprice at the locked multiplier if the trip changed materially."""
    d = to_decimal(actual_distance_km, field="actual_distance_km")
    t = to_decimal(actual_minutes, field="actual_minutes")
    q = config.quotes
    ok = _within(d, quote.predicted_distance_km, q.reprice_distance_tolerance, q.reprice_min_km)
    if config.pricing.per_minute_rate > 0:
        ok = ok and _within(t, quote.predicted_minutes, q.reprice_time_tolerance, Decimal("1"))
    if ok and not route_changed:
        return FinalFare(quote.breakdown, quote.fare, "quoted", "Trip matched the quote: the rider pays the locked fare.")
    repriced = price(d, t, quote.surge.multiplier, config)
    reason = "the rider changed the route" if route_changed else "the trip differed materially from the quote"
    return FinalFare(repriced, repriced.fare, "repriced", f"Repriced at the locked x{quote.surge.multiplier} because {reason}.")


def cancelled_fare(
    quote: Quote,
    *,
    started: bool,
    travelled_km: object = "0",
    minutes: object = "0",
    config: FareConfig,
) -> FinalFare:
    """Before pickup: the cancellation fee. After the trip started: the distance travelled
    at the locked multiplier, with the minimum fare, never more than the quote."""
    if not started:
        fee = config.quotes.cancellation_fee
        return FinalFare(None, fee, "cancelled_before_pickup", "Cancellation fee from config (a placeholder).")
    partial = price(travelled_km, minutes, quote.surge.multiplier, config)
    amount = min(partial.fare, quote.fare)
    return FinalFare(partial, amount, "cancelled_mid_trip", "Charged for the distance travelled, capped at the quote.")


def measured_distance(gps_km: object | None, routed_km: object, config: FareConfig) -> tuple[Decimal, str]:
    """Distance to charge on: GPS when sane, the routed distance when GPS was lost,
    and never more than the routed distance plus the allowed overrun."""
    routed = to_decimal(routed_km, field="routed_km")
    if gps_km is None:
        return routed, "gps_lost_used_routed_distance"
    gps = to_decimal(gps_km, field="gps_km")
    ceiling = routed * (1 + config.quotes.gps_max_overrun)
    if gps > ceiling:
        return ceiling.quantize(Decimal("0.001")), "gps_capped_at_routed_plus_overrun"
    return max(gps, ZERO), "gps"


def gps_track_km(points: list[tuple[float, float, datetime]], config: FareConfig) -> Decimal:
    """Sum a GPS trace, dropping points that imply an impossible speed (GPS jumps)."""
    max_speed = float(config.quotes.gps_max_speed_kmh)
    total, last = 0.0, None
    for lat, lon, at in points:
        if last is None:
            last = (lat, lon, at)
            continue
        hours = (at - last[2]).total_seconds() / 3600
        step = _haversine(last[0], last[1], lat, lon)
        if hours <= 0 or step / hours > max_speed:
            continue  # drop the jump, keep the last good point
        total += step
        last = (lat, lon, at)
    return Decimal(str(round(total, 3)))


def _haversine(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    r = 6371.0088
    p1, p2 = math.radians(lat1), math.radians(lat2)
    a = math.sin((p2 - p1) / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(math.radians(lon2 - lon1) / 2) ** 2
    return 2 * r * math.asin(math.sqrt(a))
