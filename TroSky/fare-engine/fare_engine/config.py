"""Load and validate the configuration file (TOML).

Money and rates must be written as strings so they become Decimal without
passing through floating point; a float in the file is rejected with a clear
message. The loaded configuration is immutable; tests and A/B experiments make
variants with :meth:`FareConfig.replace`.
"""

from __future__ import annotations

import dataclasses
import tomllib
from dataclasses import dataclass
from datetime import date, datetime, time
from decimal import Decimal
from pathlib import Path
from typing import Any

from .money import ROUNDING_MODES, is_multiple_of, to_decimal

DEFAULT_CONFIG_PATH = Path(__file__).resolve().parent.parent / "fare_config.toml"
WEEKDAYS = ("MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN")


class ConfigError(ValueError):
    """The configuration is missing a value or holds an invalid one."""


@dataclass(frozen=True)
class Band:
    max_km: Decimal
    fare: Decimal


@dataclass(frozen=True)
class PricingConfig:
    mode: str
    distance_pricing: str
    fare_reference: Decimal
    reference_distance_km: Decimal
    base_fare: Decimal
    per_minute_rate: Decimal
    minimum_fare: Decimal
    fare_rounding_step: Decimal
    fare_rounding_mode: str
    max_trip_km: Decimal
    mode_b_bands: tuple[Band, ...]

    @property
    def per_km_rate(self) -> Decimal:
        """Derived on every use (7.10 / 8 = 0.8875 exactly); never stored rounded."""
        return self.fare_reference / self.reference_distance_km


@dataclass(frozen=True)
class FeeConfig:
    service_fee_rate: Decimal
    platform_fee_step: Decimal
    platform_fee_rounding_mode: str


@dataclass(frozen=True)
class SurgeFactor:
    id: str
    kind: str  # time | weather | occasion
    uplift: Decimal
    reason: str
    start: time | None = None
    end: time | None = None
    days: frozenset[int] | None = None
    conditions: frozenset[str] = frozenset()
    occasion: str | None = None
    valid_from: date | None = None
    valid_to: date | None = None


@dataclass(frozen=True)
class CalendarEntry:
    kind: str  # public_holiday | festive_season | major_event
    name: str
    start: datetime
    end: datetime
    lat: Decimal | None = None
    lon: Decimal | None = None
    radius_km: Decimal | None = None


@dataclass(frozen=True)
class LiveSurgeConfig:
    smoothing_alpha: Decimal
    max_step_per_interval: Decimal
    interval_seconds: int
    breakpoints: tuple[tuple[Decimal, Decimal], ...]


@dataclass(frozen=True)
class SurgeConfig:
    floor: Decimal
    cap: Decimal
    multiplier_step: Decimal
    kill_switch: bool
    source: str
    factors: tuple[SurgeFactor, ...]
    calendar: tuple[CalendarEntry, ...]
    live: LiveSurgeConfig


@dataclass(frozen=True)
class QuoteConfig:
    ttl_seconds: int
    reprice_distance_tolerance: Decimal
    reprice_min_km: Decimal
    reprice_time_tolerance: Decimal
    gps_max_overrun: Decimal
    gps_max_speed_kmh: Decimal
    cancellation_fee: Decimal


@dataclass(frozen=True)
class PayoutConfig:
    schedule: str
    weekday: str
    minimum_payout: Decimal


@dataclass(frozen=True)
class TaxConfig:
    vat_on_service_fee_rate: Decimal
    vat_inclusive: bool
    vehicle_income_tax_per_period: Decimal
    vehicle_income_tax_period: str
    dvla_fees_per_year: Decimal


@dataclass(frozen=True)
class FareConfig:
    config_version: str
    currency: str
    timezone: str
    pricing: PricingConfig
    fees: FeeConfig
    surge: SurgeConfig
    quotes: QuoteConfig
    payouts: PayoutConfig
    taxes: TaxConfig

    def replace(self, section: str, **changes: Any) -> "FareConfig":
        """A validated copy with fields of one section changed, e.g. ``replace("fees", service_fee_rate=Decimal("0.25"))``."""
        updated = dataclasses.replace(getattr(self, section), **changes)
        config = dataclasses.replace(self, **{section: updated})
        validate(config)
        return config


# ---------------------------------------------------------------- parsing


def _dec(table: dict[str, Any], key: str, where: str, default: str | None = None) -> Decimal:
    if key not in table:
        if default is None:
            raise ConfigError(f"{where}.{key} is required")
        return Decimal(default)
    value = table[key]
    if isinstance(value, float):
        raise ConfigError(f"{where}.{key} is a float; write it as a string, for example '{value}'")
    try:
        return to_decimal(value, field=f"{where}.{key}")
    except (TypeError, ValueError) as exc:
        raise ConfigError(str(exc)) from exc


def _str(table: dict[str, Any], key: str, where: str, default: str | None = None) -> str:
    value = table.get(key, default)
    if not isinstance(value, str) or not value:
        raise ConfigError(f"{where}.{key} must be a non-empty string")
    return value


def _int(table: dict[str, Any], key: str, where: str) -> int:
    value = table.get(key)
    if not isinstance(value, int) or isinstance(value, bool):
        raise ConfigError(f"{where}.{key} must be a whole number")
    return value


def _time(value: Any, where: str) -> time:
    if isinstance(value, time):
        return value
    if isinstance(value, str):
        return time.fromisoformat(value)
    raise ConfigError(f"{where} must be a time such as 06:30:00")


def _date(value: Any, where: str) -> date | None:
    if value is None:
        return None
    if isinstance(value, date) and not isinstance(value, datetime):
        return value
    if isinstance(value, str):
        return date.fromisoformat(value)
    raise ConfigError(f"{where} must be a date such as 2026-01-01")


def _datetime(value: Any, where: str) -> datetime:
    if isinstance(value, datetime):
        return value
    if isinstance(value, str):
        return datetime.fromisoformat(value)
    raise ConfigError(f"{where} must be a local date-time such as 2026-12-15T00:00:00")


def _factor(raw: dict[str, Any], i: int) -> SurgeFactor:
    where = f"surge.factors[{i}]"
    kind = _str(raw, "kind", where)
    days = raw.get("days")
    factor = SurgeFactor(
        id=_str(raw, "id", where),
        kind=kind,
        uplift=_dec(raw, "uplift", where),
        reason=_str(raw, "reason", where),
        start=_time(raw["start"], f"{where}.start") if "start" in raw else None,
        end=_time(raw["end"], f"{where}.end") if "end" in raw else None,
        days=frozenset(WEEKDAYS.index(d) for d in days) if days else None,
        conditions=frozenset(raw.get("conditions", [])),
        occasion=raw.get("occasion"),
        valid_from=_date(raw.get("valid_from"), f"{where}.valid_from"),
        valid_to=_date(raw.get("valid_to"), f"{where}.valid_to"),
    )
    if kind == "time" and (factor.start is None or factor.end is None):
        raise ConfigError(f"{where}: a time factor needs start and end")
    if kind == "weather" and not factor.conditions:
        raise ConfigError(f"{where}: a weather factor needs conditions")
    if kind == "occasion" and not factor.occasion:
        raise ConfigError(f"{where}: an occasion factor needs occasion")
    if kind not in ("time", "weather", "occasion"):
        raise ConfigError(f"{where}.kind must be time, weather or occasion")
    return factor


def _calendar(raw: dict[str, Any], i: int) -> CalendarEntry:
    where = f"calendar[{i}]"
    return CalendarEntry(
        kind=_str(raw, "kind", where),
        name=_str(raw, "name", where),
        start=_datetime(raw.get("start"), f"{where}.start"),
        end=_datetime(raw.get("end"), f"{where}.end"),
        lat=_dec(raw, "lat", where) if "lat" in raw else None,
        lon=_dec(raw, "lon", where) if "lon" in raw else None,
        radius_km=_dec(raw, "radius_km", where) if "radius_km" in raw else None,
    )


def parse_config(data: dict[str, Any]) -> FareConfig:
    p, f, s, q, po, t = (data.get(k, {}) for k in ("pricing", "fees", "surge", "quotes", "payouts", "taxes"))
    live = s.get("live", {})
    breakpoints = []
    for i, pair in enumerate(live.get("breakpoints", [])):
        if not isinstance(pair, list) or len(pair) != 2:
            raise ConfigError(f"surge.live.breakpoints[{i}] must be [ratio, multiplier]")
        breakpoints.append((_dec({"v": pair[0]}, "v", "ratio"), _dec({"v": pair[1]}, "v", "multiplier")))
    config = FareConfig(
        config_version=_str(data, "config_version", "root"),
        currency=_str(data, "currency", "root"),
        timezone=_str(data, "timezone", "root"),
        pricing=PricingConfig(
            mode=_str(p, "mode", "pricing"),
            distance_pricing=_str(p, "distance_pricing", "pricing"),
            fare_reference=_dec(p, "fare_reference", "pricing"),
            reference_distance_km=_dec(p, "reference_distance_km", "pricing"),
            base_fare=_dec(p, "base_fare", "pricing", "0"),
            per_minute_rate=_dec(p, "per_minute_rate", "pricing", "0"),
            minimum_fare=_dec(p, "minimum_fare", "pricing"),
            fare_rounding_step=_dec(p, "fare_rounding_step", "pricing"),
            fare_rounding_mode=_str(p, "fare_rounding_mode", "pricing"),
            max_trip_km=_dec(p, "max_trip_km", "pricing"),
            mode_b_bands=tuple(
                Band(_dec(b, "max_km", f"pricing.mode_b_bands[{i}]"), _dec(b, "fare", f"pricing.mode_b_bands[{i}]"))
                for i, b in enumerate(p.get("mode_b_bands", []))
            ),
        ),
        fees=FeeConfig(
            service_fee_rate=_dec(f, "service_fee_rate", "fees"),
            platform_fee_step=_dec(f, "platform_fee_step", "fees"),
            platform_fee_rounding_mode=_str(f, "platform_fee_rounding_mode", "fees"),
        ),
        surge=SurgeConfig(
            floor=_dec(s, "floor", "surge"),
            cap=_dec(s, "cap", "surge"),
            multiplier_step=_dec(s, "multiplier_step", "surge"),
            kill_switch=bool(s.get("kill_switch", False)),
            source=_str(s, "source", "surge"),
            factors=tuple(_factor(raw, i) for i, raw in enumerate(s.get("factors", []))),
            calendar=tuple(_calendar(raw, i) for i, raw in enumerate(data.get("calendar", []))),
            live=LiveSurgeConfig(
                smoothing_alpha=_dec(live, "smoothing_alpha", "surge.live"),
                max_step_per_interval=_dec(live, "max_step_per_interval", "surge.live"),
                interval_seconds=_int(live, "interval_seconds", "surge.live"),
                breakpoints=tuple(breakpoints),
            ),
        ),
        quotes=QuoteConfig(
            ttl_seconds=_int(q, "ttl_seconds", "quotes"),
            reprice_distance_tolerance=_dec(q, "reprice_distance_tolerance", "quotes"),
            reprice_min_km=_dec(q, "reprice_min_km", "quotes"),
            reprice_time_tolerance=_dec(q, "reprice_time_tolerance", "quotes"),
            gps_max_overrun=_dec(q, "gps_max_overrun", "quotes"),
            gps_max_speed_kmh=_dec(q, "gps_max_speed_kmh", "quotes"),
            cancellation_fee=_dec(q, "cancellation_fee", "quotes"),
        ),
        payouts=PayoutConfig(
            schedule=_str(po, "schedule", "payouts"),
            weekday=_str(po, "weekday", "payouts"),
            minimum_payout=_dec(po, "minimum_payout", "payouts"),
        ),
        taxes=TaxConfig(
            vat_on_service_fee_rate=_dec(t, "vat_on_service_fee_rate", "taxes", "0"),
            vat_inclusive=bool(t.get("vat_inclusive", True)),
            vehicle_income_tax_per_period=_dec(t, "vehicle_income_tax_per_period", "taxes", "0"),
            vehicle_income_tax_period=_str(t, "vehicle_income_tax_period", "taxes", "quarter"),
            dvla_fees_per_year=_dec(t, "dvla_fees_per_year", "taxes", "0"),
        ),
    )
    validate(config)
    return config


def load_config(path: str | Path | None = None) -> FareConfig:
    with open(path or DEFAULT_CONFIG_PATH, "rb") as fh:
        return parse_config(tomllib.load(fh))


# ---------------------------------------------------------------- validation


def validate(c: FareConfig) -> None:
    p, f, s = c.pricing, c.fees, c.surge
    errors: list[str] = []
    if p.mode not in ("A", "B"):
        errors.append("pricing.mode must be 'A' or 'B'")
    if p.distance_pricing not in ("linear", "per_block"):
        errors.append("pricing.distance_pricing must be 'linear' or 'per_block'")
    if p.reference_distance_km <= 0:
        errors.append("pricing.reference_distance_km must be positive")
    for name in ("fare_reference", "base_fare", "per_minute_rate", "minimum_fare"):
        if getattr(p, name) < 0:
            errors.append(f"pricing.{name} cannot be negative")
    if p.fare_rounding_step <= 0:
        errors.append("pricing.fare_rounding_step must be positive")
    elif not is_multiple_of(p.minimum_fare, p.fare_rounding_step):
        # Otherwise rounding after the minimum could push a fare below or above it.
        errors.append("pricing.minimum_fare must be a multiple of fare_rounding_step")
    for mode_name in (p.fare_rounding_mode, f.platform_fee_rounding_mode):
        if mode_name not in ROUNDING_MODES:
            errors.append(f"unknown rounding mode {mode_name!r}")
    previous = Decimal("0")
    for band in p.mode_b_bands:
        if band.max_km <= previous:
            errors.append("pricing.mode_b_bands must have strictly increasing max_km")
        if band.fare < 0:
            errors.append("pricing.mode_b_bands fares cannot be negative")
        previous = band.max_km
    if p.mode == "B" and not p.mode_b_bands:
        errors.append("pricing.mode 'B' needs mode_b_bands")
    if not (Decimal("0") <= f.service_fee_rate < Decimal("1")):
        errors.append("fees.service_fee_rate must be at least 0 and below 1")
    if s.floor != Decimal("1"):
        errors.append("surge.floor must be 1.0: the multiplier never discounts the fare")
    if s.cap < s.floor:
        errors.append("surge.cap must be at least the floor")
    if s.source not in ("static", "live"):
        errors.append("surge.source must be 'static' or 'live'")
    if not (Decimal("0") < s.live.smoothing_alpha <= Decimal("1")):
        errors.append("surge.live.smoothing_alpha must be in (0, 1]")
    ratios = [r for r, _ in s.live.breakpoints]
    if ratios != sorted(ratios) or len(set(ratios)) != len(ratios):
        errors.append("surge.live.breakpoints must have strictly increasing ratios")
    weather_conditions: list[str] = []
    for factor in s.factors:
        if factor.uplift < 0:
            errors.append(f"surge factor {factor.id} has a negative uplift")
        weather_conditions.extend(factor.conditions)
    if len(weather_conditions) != len(set(weather_conditions)):
        errors.append("a weather condition may belong to only one surge factor")
    if c.payouts.weekday not in WEEKDAYS:
        errors.append("payouts.weekday must be MON..SUN")
    if not (Decimal("0") <= c.taxes.vat_on_service_fee_rate < Decimal("1")):
        errors.append("taxes.vat_on_service_fee_rate must be at least 0 and below 1")
    if errors:
        raise ConfigError("; ".join(errors))
