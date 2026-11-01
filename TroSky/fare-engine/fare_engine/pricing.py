"""Price the rider: Mode A (flat-rate formula) and Mode B (tapered bands).

Mode A, linear:     fare = round(max(minimum, (base + ref x d / ref_d + per_min x t) x surge))
Mode A, per_block:  the distance term becomes ref x ceil(d / ref_d)
Mode B:             fare = round(max(minimum, band_fare(d) x surge))

The distance term is computed as ``fare_reference x d / reference_distance_km``
(multiply first, then divide), so a rate that does not divide evenly is never
rounded before it is used.
"""

from __future__ import annotations

from dataclasses import dataclass
from decimal import ROUND_CEILING, Decimal

from .config import FareConfig
from .money import ZERO, round_to_step, to_decimal


class PricingError(ValueError):
    """The inputs cannot be priced."""


class DistanceOutOfRange(PricingError):
    """Longer than the configured maximum or beyond the last Mode B band."""


@dataclass(frozen=True)
class FareBreakdown:
    mode: str
    distance_pricing: str | None
    distance_km: Decimal
    minutes: Decimal
    base_fare: Decimal
    distance_charge: Decimal
    time_charge: Decimal
    subtotal: Decimal  # before surge
    surge_multiplier: Decimal
    raw_fare: Decimal  # subtotal x surge, unrounded
    minimum_fare: Decimal
    minimum_applied: bool
    fare: Decimal  # after the minimum and rounding: what the rider is charged
    fare_before_surge: Decimal  # the same trip at multiplier 1.0, for the receipt
    blocks: int | None = None  # per_block only
    band_max_km: Decimal | None = None  # Mode B only

    @property
    def surge_amount(self) -> Decimal:
        """What surge added to the rounded fare, as shown on the rider's breakdown."""
        return self.fare - self.fare_before_surge

    @property
    def rounding_adjustment(self) -> Decimal:
        return self.fare - max(self.raw_fare, self.minimum_fare)


def price(
    distance_km: object,
    minutes: object,
    surge_multiplier: object,
    config: FareConfig,
    *,
    mode: str | None = None,
    distance_pricing: str | None = None,
) -> FareBreakdown:
    """Price one trip. Arguments are str, int or Decimal; floats are refused."""
    p = config.pricing
    d = to_decimal(distance_km, field="distance_km")
    t = to_decimal(minutes, field="minutes")
    s = to_decimal(surge_multiplier, field="surge_multiplier")
    mode = mode or p.mode
    distance_pricing = distance_pricing or p.distance_pricing

    if d < 0:
        raise PricingError("distance_km cannot be negative")
    if t < 0:
        raise PricingError("minutes cannot be negative")
    if d > p.max_trip_km:
        raise DistanceOutOfRange(f"{d} km is longer than the {p.max_trip_km} km maximum")
    if not (config.surge.floor <= s <= config.surge.cap):
        raise PricingError(f"surge multiplier {s} is outside {config.surge.floor}–{config.surge.cap}")

    blocks: int | None = None
    band_max: Decimal | None = None
    if mode == "A":
        if distance_pricing == "linear":
            distance_charge = p.fare_reference * d / p.reference_distance_km
        elif distance_pricing == "per_block":
            blocks = int((d / p.reference_distance_km).to_integral_value(rounding=ROUND_CEILING))
            distance_charge = p.fare_reference * blocks
        else:
            raise PricingError(f"unknown distance_pricing {distance_pricing!r}")
        base = p.base_fare
        time_charge = p.per_minute_rate * t
    elif mode == "B":
        band = next((b for b in p.mode_b_bands if d <= b.max_km), None)
        if band is None:
            last = p.mode_b_bands[-1].max_km if p.mode_b_bands else ZERO
            raise DistanceOutOfRange(f"{d} km is beyond the last Mode B band ({last} km)")
        base, distance_charge, time_charge, band_max = ZERO, band.fare, ZERO, band.max_km
        distance_pricing = None  # bands are all-in
    else:
        raise PricingError(f"unknown pricing mode {mode!r}")

    subtotal = base + distance_charge + time_charge
    raw = subtotal * s
    minimum_applied = raw < p.minimum_fare
    fare = round_to_step(max(raw, p.minimum_fare), p.fare_rounding_step, p.fare_rounding_mode)
    fare_before_surge = round_to_step(max(subtotal, p.minimum_fare), p.fare_rounding_step, p.fare_rounding_mode)
    return FareBreakdown(
        mode=mode,
        distance_pricing=distance_pricing,
        distance_km=d,
        minutes=t,
        base_fare=base,
        distance_charge=distance_charge,
        time_charge=time_charge,
        subtotal=subtotal,
        surge_multiplier=s,
        raw_fare=raw,
        minimum_fare=p.minimum_fare,
        minimum_applied=minimum_applied,
        fare=fare,
        fare_before_surge=fare_before_surge,
        blocks=blocks,
        band_max_km=band_max,
    )


def minimum_fare_reach_km(config: FareConfig) -> tuple[Decimal, Decimal]:
    """Mode A linear, no surge: (distance where the raw fare reaches the minimum,
    distance where the rounded fare first rises above it)."""
    p = config.pricing
    reach = (p.minimum_fare - p.base_fare) * p.reference_distance_km / p.fare_reference
    # The rounded fare stays at the minimum until the raw fare reaches minimum + half a step.
    rise = (p.minimum_fare + p.fare_rounding_step / 2 - p.base_fare) * p.reference_distance_km / p.fare_reference
    return reach, rise
