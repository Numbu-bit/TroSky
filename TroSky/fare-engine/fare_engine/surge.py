"""Surge multiplier: a static factor table now, a live demand/supply ratio later.

Static (a prior, until there is data):
    multiplier = min(cap, max(1.0, 1 + sum of active uplifts))

Live (Phase 3): per zone, every interval,
    target = piecewise-linear(demand / supply)
    next   = previous + alpha x (target - previous), moved at most max_step
    then the same floor, cap and kill switch.

In Phase 4 the demand forecast takes time, weather and events as model inputs;
the factor table is then retired, but the cap, smoothing and kill switch stay.
"""

from __future__ import annotations

import math
from dataclasses import dataclass, field
from datetime import datetime, time
from decimal import Decimal

from .config import CalendarEntry, FareConfig, SurgeFactor
from .money import round_to_step, to_decimal

ONE = Decimal("1")


@dataclass(frozen=True)
class SurgeContext:
    at: datetime  # local time at the pickup, in the configured timezone
    weather: str = "clear"  # clear | light_rain | heavy_rain | storm
    lat: Decimal | None = None
    lon: Decimal | None = None
    occasions: frozenset[str] | None = None  # set directly, or None to read the calendar


@dataclass(frozen=True)
class SurgeResult:
    multiplier: Decimal
    uncapped: Decimal
    capped: bool
    factors: tuple[str, ...] = ()
    reasons: tuple[str, ...] = field(default=())
    source: str = "static"

    @property
    def rider_message(self) -> str | None:
        """Plain-language reason shown to the rider when the price is raised."""
        if self.multiplier <= ONE:
            return None
        if not self.reasons:
            return "High demand nearby"
        return "High demand: " + ", ".join(self.reasons)


def no_surge() -> SurgeResult:
    return SurgeResult(multiplier=ONE, uncapped=ONE, capped=False, source="none")


def _in_window(t: time, start: time, end: time) -> bool:
    """Start inclusive, end exclusive; a window whose end is earlier wraps past midnight."""
    if start < end:
        return start <= t < end
    return t >= start or t < end


def _haversine_km(lat1: Decimal, lon1: Decimal, lat2: Decimal, lon2: Decimal) -> float:
    # Geometry, not money: floats are fine here.
    r = 6371.0088
    p1, p2 = math.radians(float(lat1)), math.radians(float(lat2))
    dp, dl = p2 - p1, math.radians(float(lon2) - float(lon1))
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.asin(math.sqrt(a))


def active_occasions(ctx: SurgeContext, calendar: tuple[CalendarEntry, ...]) -> frozenset[str]:
    if ctx.occasions is not None:
        return ctx.occasions
    active = set()
    for entry in calendar:
        if not (entry.start <= ctx.at < entry.end):
            continue
        if entry.kind == "major_event":
            if None in (ctx.lat, ctx.lon, entry.lat, entry.lon, entry.radius_km):
                continue
            if _haversine_km(ctx.lat, ctx.lon, entry.lat, entry.lon) > float(entry.radius_km):  # type: ignore[arg-type]
                continue
        active.add(entry.kind)
    return frozenset(active)


def _factor_applies(factor: SurgeFactor, ctx: SurgeContext, occasions: frozenset[str]) -> bool:
    day = ctx.at.date()
    if factor.valid_from and day < factor.valid_from:
        return False
    if factor.valid_to and day > factor.valid_to:
        return False
    if factor.kind == "time":
        if factor.days is not None and ctx.at.weekday() not in factor.days:
            return False
        return _in_window(ctx.at.time(), factor.start, factor.end)  # type: ignore[arg-type]
    if factor.kind == "weather":
        return ctx.weather in factor.conditions
    if factor.kind == "occasion":
        return factor.occasion in occasions
    return False


def clamp(multiplier: Decimal, config: FareConfig) -> tuple[Decimal, bool]:
    s = config.surge
    stepped = round_to_step(multiplier, s.multiplier_step)
    capped = stepped > s.cap
    return min(s.cap, max(s.floor, stepped)), capped


def static_surge(ctx: SurgeContext, config: FareConfig) -> SurgeResult:
    s = config.surge
    occasions = active_occasions(ctx, s.calendar)
    applied = [f for f in s.factors if _factor_applies(f, ctx, occasions)]
    uncapped = max(s.floor, ONE + sum((f.uplift for f in applied), Decimal("0")))
    if s.kill_switch:
        return SurgeResult(ONE, uncapped, False, tuple(f.id for f in applied), (), "kill_switch")
    multiplier, capped = clamp(uncapped, config)
    return SurgeResult(
        multiplier=multiplier,
        uncapped=uncapped,
        capped=capped,
        factors=tuple(f.id for f in applied),
        reasons=tuple(f.reason for f in applied),
        source="static",
    )


def target_from_ratio(demand: int, supply: int, config: FareConfig) -> Decimal:
    """Piecewise-linear map from demand/supply to a target multiplier. No supply counts as one driver."""
    points = config.surge.live.breakpoints
    ratio = Decimal(demand) / Decimal(max(supply, 1))
    if ratio <= points[0][0]:
        return points[0][1]
    for (r0, m0), (r1, m1) in zip(points, points[1:]):
        if ratio <= r1:
            return m0 + (m1 - m0) * (ratio - r0) / (r1 - r0)
    return points[-1][1]


def smooth(previous: Decimal, target: Decimal, alpha: Decimal, max_step: Decimal) -> Decimal:
    """Move part of the way to the target, and never more than max_step per interval."""
    proposed = previous + alpha * (target - previous)
    return max(previous - max_step, min(previous + max_step, proposed))


def live_surge(previous: object, demand: int, supply: int, config: FareConfig) -> SurgeResult:
    prev = to_decimal(previous, field="previous")
    live = config.surge.live
    target = target_from_ratio(demand, supply, config)
    if config.surge.kill_switch:
        return SurgeResult(ONE, target, False, ("live_ratio",), (), "kill_switch")
    nxt = smooth(prev, target, live.smoothing_alpha, live.max_step_per_interval)
    if abs(target - nxt) < config.surge.multiplier_step:
        nxt = target  # otherwise rounding each interval can stall one step short
    multiplier, capped = clamp(nxt, config)
    return SurgeResult(multiplier, nxt, capped, ("live_ratio",), (), "live")
