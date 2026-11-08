"""Pay the driver and calculate what the platform keeps.

platform_fee  = round(fare x service_fee_rate, to 0.01, ROUND_HALF_UP)   tolls and tips excluded
driver_payout = fare - platform_fee + tolls + tips + incentives
rider_pays    = fare - promo + tolls + tips                               promos are platform-funded
platform_net  = platform_fee - promo - incentives

Invariant, checked on every settlement:
    rider_pays + promo + incentives == driver_payout + platform_fee

The driver's share is always fare minus the rounded fee, so the two always add
back to the fare exactly and the ledger never carries a rounding remainder.
"""

from __future__ import annotations

from dataclasses import dataclass
from decimal import Decimal

from .config import ConfigError, FareConfig
from .money import CENT, ZERO, cedis, round_to_step, to_decimal
from .pricing import FareBreakdown
from .surge import SurgeResult


class SettlementError(ValueError):
    """The amounts cannot be settled."""


@dataclass(frozen=True)
class TripSettlement:
    fare: Decimal
    service_fee_rate: Decimal
    platform_fee: Decimal
    driver_fare_share: Decimal  # fare - platform_fee
    tolls: Decimal
    tips: Decimal
    incentives: Decimal
    promo: Decimal
    rider_pays: Decimal
    driver_payout: Decimal
    platform_net: Decimal
    vat_on_fee: Decimal
    platform_revenue_ex_vat: Decimal


def _money(value: object, field: str) -> Decimal:
    amount = to_decimal(value, field=field)
    if amount < 0:
        raise SettlementError(f"{field} cannot be negative")
    if amount != amount.quantize(CENT):
        raise SettlementError(f"{field} must be in whole pesewas (two decimals)")
    return amount


def platform_fee(fare: Decimal, config: FareConfig, service_fee_rate: object | None = None) -> Decimal:
    rate = config.fees.service_fee_rate if service_fee_rate is None else to_decimal(service_fee_rate, field="rate")
    if not (Decimal("0") <= rate < Decimal("1")):
        raise SettlementError("service_fee_rate must be at least 0 and below 1")
    return round_to_step(fare * rate, config.fees.platform_fee_step, config.fees.platform_fee_rounding_mode)


def settle(
    fare: object,
    config: FareConfig,
    *,
    tolls: object = "0",
    tips: object = "0",
    incentives: object = "0",
    promo: object = "0",
    service_fee_rate: object | None = None,
) -> TripSettlement:
    fare_d = _money(fare, "fare")
    tolls_d, tips_d = _money(tolls, "tolls"), _money(tips, "tips")
    incentives_d, promo_d = _money(incentives, "incentives"), _money(promo, "promo")
    if promo_d > fare_d:
        raise SettlementError("a promotion cannot exceed the fare")
    rate = config.fees.service_fee_rate if service_fee_rate is None else to_decimal(service_fee_rate, field="rate")
    fee = platform_fee(fare_d, config, rate)

    vat_rate = config.taxes.vat_on_service_fee_rate
    if vat_rate and not config.taxes.vat_inclusive:
        raise ConfigError("only VAT included in the fee is modelled; confirm the treatment with GRA first")
    vat = round_to_step(fee * vat_rate / (1 + vat_rate), CENT) if vat_rate else ZERO

    s = TripSettlement(
        fare=fare_d,
        service_fee_rate=rate,
        platform_fee=fee,
        driver_fare_share=fare_d - fee,
        tolls=tolls_d,
        tips=tips_d,
        incentives=incentives_d,
        promo=promo_d,
        rider_pays=fare_d - promo_d + tolls_d + tips_d,
        driver_payout=fare_d - fee + tolls_d + tips_d + incentives_d,
        platform_net=fee - promo_d - incentives_d,
        vat_on_fee=vat,
        platform_revenue_ex_vat=fee - vat,
    )
    if s.rider_pays + s.promo + s.incentives != s.driver_payout + s.platform_fee:
        raise SettlementError("settlement does not balance")  # unreachable by construction
    return s


def rider_breakdown(b: FareBreakdown, s: TripSettlement, surge: SurgeResult | None = None) -> list[tuple[str, str]]:
    """Lines shown to the rider before booking and on the receipt."""
    lines = [(f"Trip fare, {b.distance_km} km", cedis(b.fare_before_surge))]
    if b.surge_amount:
        reason = surge.rider_message if surge and surge.rider_message else "High demand"
        lines.append((f"{reason} (x{b.surge_multiplier})", cedis(b.surge_amount)))
    if b.minimum_applied:
        lines.append(("Minimum fare applies", ""))
    if s.tolls:
        lines.append(("Tolls", cedis(s.tolls)))
    if s.tips:
        lines.append(("Tip for your driver", cedis(s.tips)))
    if s.promo:
        lines.append(("Promotion", "-" + cedis(s.promo)))
    lines.append(("You pay", cedis(s.rider_pays)))
    return lines


def driver_receipt(b: FareBreakdown, s: TripSettlement) -> list[tuple[str, str]]:
    """Per-trip receipt shown to the driver."""
    pct = format((s.service_fee_rate * 100).normalize(), "f")
    lines = [
        ("Fare", cedis(s.fare)),
        (f"of which surge (x{b.surge_multiplier})", cedis(b.surge_amount)),
        (f"Platform fee ({pct}%)", "-" + cedis(s.platform_fee)),
    ]
    if s.tolls:
        lines.append(("Tolls (passed through)", cedis(s.tolls)))
    if s.tips:
        lines.append(("Tips (100% yours)", cedis(s.tips)))
    if s.incentives:
        lines.append(("Incentive", cedis(s.incentives)))
    if s.promo:
        lines.append(("Rider promotion (paid by the platform)", cedis(ZERO)))
    lines.append(("Your earnings", cedis(s.driver_payout)))
    return lines
