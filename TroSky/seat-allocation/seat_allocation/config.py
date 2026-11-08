"""Load and validate the configuration file.

Weights become whole numbers of cost units (1.0 is 1000 units), so comparing two
seatings never depends on floating-point rounding. The loaded configuration is
immutable; tests and pilots make variants with :meth:`SeatConfig.replace`.
"""

from __future__ import annotations

import dataclasses
import tomllib
from dataclasses import dataclass
from decimal import Decimal, InvalidOperation
from pathlib import Path
from typing import Any

DEFAULT_CONFIG_PATH = Path(__file__).resolve().parent.parent / "seat_config.toml"
UNITS_PER_WEIGHT = 1000
CATEGORIES = ("standard", "elderly", "pregnant", "disabled", "child", "other_priority")


class ConfigError(ValueError):
    """The configuration is missing a value or holds an invalid one."""


@dataclass(frozen=True)
class Weights:
    """All in cost units: 1000 units is a weight of 1.0."""

    blocking: int
    boarding_blocking: int
    preference: int
    group_split: int
    same_stop_apart: int
    luggage: int
    depth_order: int
    seat_change: int
    child_apart: int


@dataclass(frozen=True)
class AssignmentConfig:
    mode: str
    allow_passenger_override: bool
    lock_minutes_before_departure: int
    tie_break: tuple[str, ...]
    same_stop_tolerance_km: float
    boarding_discipline: str
    single_passenger_near_driver: bool


@dataclass(frozen=True)
class PriorityConfig:
    categories: frozenset[str]
    default_reserved_count: int


@dataclass(frozen=True)
class GroupConfig:
    togetherness: str
    child_requires_adult: bool


@dataclass(frozen=True)
class SearchConfig:
    exact_max_seats: int
    exact_max_states: int
    interval_max_nodes: int
    max_constrained_mappings: int
    local_search_max_sweeps: int


@dataclass(frozen=True)
class OnlineConfig:
    reoptimise_on_booking: bool
    zones: int


@dataclass(frozen=True)
class RouteConfig:
    max_off_route_km: float
    min_lat: float
    max_lat: float
    min_lon: float
    max_lon: float


@dataclass(frozen=True)
class SeatConfig:
    config_version: str
    weights: Weights
    assignment: AssignmentConfig
    priority: PriorityConfig
    groups: GroupConfig
    search: SearchConfig
    online: OnlineConfig
    route: RouteConfig

    def replace(self, section: str, **changes: Any) -> SeatConfig:
        """A validated copy with fields of one section changed."""
        updated = dataclasses.replace(getattr(self, section), **changes)
        config = dataclasses.replace(self, **{section: updated})
        validate(config)
        return config


def _decimal(table: dict[str, Any], key: str, where: str) -> Decimal:
    if key not in table:
        raise ConfigError(f"{where}.{key} is required")
    value = table[key]
    if isinstance(value, float):
        raise ConfigError(f"{where}.{key} is a float; write it as a string, for example '{value}'")
    try:
        return Decimal(str(value))
    except InvalidOperation as exc:
        raise ConfigError(f"{where}.{key}: {value!r} is not a number") from exc


def _units(table: dict[str, Any], key: str) -> int:
    amount = _decimal(table, key, "weights") * UNITS_PER_WEIGHT
    if amount != amount.to_integral_value():
        raise ConfigError(f"weights.{key} has more than three decimal places")
    return int(amount)


def _required(table: dict[str, Any], key: str, where: str) -> Any:
    if key not in table:
        raise ConfigError(f"{where}.{key} is required")
    return table[key]


def parse_config(data: dict[str, Any]) -> SeatConfig:
    w, a, p = data.get("weights", {}), data.get("assignment", {}), data.get("priority", {})
    g, s, o = data.get("groups", {}), data.get("search", {}), data.get("online", {})
    r = data.get("route", {})
    area = r.get("service_area", {})
    config = SeatConfig(
        config_version=str(_required(data, "config_version", "root")),
        weights=Weights(
            blocking=_units(w, "blocking"),
            boarding_blocking=_units(w, "boarding_blocking"),
            preference=_units(w, "preference"),
            group_split=_units(w, "group_split"),
            same_stop_apart=_units(w, "same_stop_apart"),
            luggage=_units(w, "luggage"),
            depth_order=_units(w, "depth_order"),
            seat_change=_units(w, "seat_change"),
            child_apart=_units(w, "child_apart"),
        ),
        assignment=AssignmentConfig(
            mode=str(_required(a, "mode", "assignment")),
            allow_passenger_override=bool(_required(a, "allow_passenger_override", "assignment")),
            lock_minutes_before_departure=int(
                _required(a, "reassignment_lock_minutes_before_departure", "assignment")
            ),
            tie_break=tuple(_required(a, "tie_break", "assignment")),
            same_stop_tolerance_km=float(_decimal(a, "same_stop_tolerance_km", "assignment")),
            boarding_discipline=str(_required(a, "boarding_discipline", "assignment")),
            single_passenger_near_driver=bool(
                _required(a, "single_passenger_near_driver", "assignment")
            ),
        ),
        priority=PriorityConfig(
            categories=frozenset(_required(p, "categories", "priority")),
            default_reserved_count=int(_required(p, "default_reserved_count", "priority")),
        ),
        groups=GroupConfig(
            togetherness=str(_required(g, "togetherness", "groups")),
            child_requires_adult=bool(_required(g, "child_requires_adult", "groups")),
        ),
        search=SearchConfig(
            exact_max_seats=int(_required(s, "exact_max_seats", "search")),
            exact_max_states=int(_required(s, "exact_max_states", "search")),
            interval_max_nodes=int(_required(s, "interval_max_nodes", "search")),
            max_constrained_mappings=int(_required(s, "max_constrained_mappings", "search")),
            local_search_max_sweeps=int(_required(s, "local_search_max_sweeps", "search")),
        ),
        online=OnlineConfig(
            reoptimise_on_booking=bool(_required(o, "reoptimise_on_booking", "online")),
            zones=int(_required(o, "zones", "online")),
        ),
        route=RouteConfig(
            max_off_route_km=float(_decimal(r, "max_off_route_km", "route")),
            min_lat=float(_decimal(area, "min_lat", "route.service_area")),
            max_lat=float(_decimal(area, "max_lat", "route.service_area")),
            min_lon=float(_decimal(area, "min_lon", "route.service_area")),
            max_lon=float(_decimal(area, "max_lon", "route.service_area")),
        ),
    )
    validate(config)
    return config


def load_config(path: str | Path | None = None) -> SeatConfig:
    with open(path or DEFAULT_CONFIG_PATH, "rb") as handle:
        return parse_config(tomllib.load(handle))


def validate(config: SeatConfig) -> None:
    w, a = config.weights, config.assignment
    errors: list[str] = []
    if w.blocking <= 0:
        errors.append("weights.blocking must be positive")
    for field in dataclasses.fields(w):
        if getattr(w, field.name) < 0:
            errors.append(f"weights.{field.name} cannot be negative")
    if config.groups.togetherness == "soft" and w.group_split >= w.blocking:
        errors.append("weights.group_split must stay below weights.blocking for soft togetherness")
    if config.groups.togetherness not in ("soft", "hard"):
        errors.append("groups.togetherness must be 'soft' or 'hard'")
    if a.mode not in ("batch", "online"):
        errors.append("assignment.mode must be 'batch' or 'online'")
    if a.boarding_discipline not in ("called", "arrival"):
        errors.append("assignment.boarding_discipline must be 'called' or 'arrival'")
    if a.lock_minutes_before_departure < 0:
        errors.append("assignment.reassignment_lock_minutes_before_departure cannot be negative")
    if a.same_stop_tolerance_km < 0:
        errors.append("assignment.same_stop_tolerance_km cannot be negative")
    if not set(a.tie_break) <= {"group", "booking_time"} or len(set(a.tie_break)) != len(
        a.tie_break
    ):
        errors.append("assignment.tie_break may only list 'group' and 'booking_time', once each")
    unknown = config.priority.categories - set(CATEGORIES)
    if unknown:
        errors.append(f"priority.categories has unknown values: {sorted(unknown)}")
    if config.priority.default_reserved_count < 0:
        errors.append("priority.default_reserved_count cannot be negative")
    if config.online.zones < 1:
        errors.append("online.zones must be at least 1")
    for name in (
        "exact_max_seats",
        "exact_max_states",
        "interval_max_nodes",
        "max_constrained_mappings",
    ):
        if getattr(config.search, name) < 1:
            errors.append(f"search.{name} must be at least 1")
    if config.route.max_off_route_km <= 0:
        errors.append("route.max_off_route_km must be positive")
    if errors:
        raise ConfigError("; ".join(errors))
