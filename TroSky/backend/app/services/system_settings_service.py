"""Settings and feature flags admins can change without a deploy.

Every setting has a default from the environment (``app.core.config``); an
admin's change is stored in ``system_settings`` and takes precedence. The
services that use these values get them through ``effective_settings``,
which applies the stored overrides (and the flags that switch settings) to
the environment ``Settings``.

Values are cached in each worker for ``CACHE_SECONDS``: a change takes
effect on the worker that made it at once, and on the others within that
time.
"""

from __future__ import annotations

import hashlib
import time
import uuid
from collections.abc import Collection, Mapping
from dataclasses import dataclass
from datetime import UTC, datetime
from decimal import Decimal
from typing import Any

from pydantic import BaseModel, Field, ValidationError, field_validator
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings, get_settings
from app.core.exceptions import NotFoundError, ValidationAppError
from app.core.logging import get_logger
from app.models.admin import FeatureFlag, SystemSetting

logger = get_logger(__name__)

CACHE_SECONDS = 30


COMPLAINT_PRIORITIES = ("low", "medium", "high", "urgent")


class EscalationContact(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    phone_number: str = Field(..., min_length=5, max_length=20)
    role: str = Field(..., min_length=1, max_length=60, examples=["police", "ambulance"])


class SettingsValues(BaseModel):
    """What admins can change, with the limits that keep the platform sane."""

    platform_fee_flat_per_seat: Decimal = Field(..., ge=0, le=100, decimal_places=2)
    platform_fee_percent: Decimal = Field(..., ge=0, le=100, decimal_places=2)
    driver_earnings_share_percent: Decimal = Field(..., ge=0, le=100, decimal_places=2)
    reservation_hold_seconds: int = Field(
        ..., ge=60, le=3600, description="How long a seat waits for payment (FR-007)."
    )
    live_update_interval_seconds: int = Field(
        ..., ge=2, le=60, description="How often a moving vehicle's position is saved."
    )
    complaint_sla_hours: dict[str, int] = Field(
        ..., description="Hours to resolve a complaint, by priority."
    )
    approval_target_hours: int = Field(
        ..., ge=1, le=720, description="A driver or vehicle approval waiting longer is overdue."
    )
    sos_escalation_contacts: list[EscalationContact] = Field(..., max_length=20)
    enabled_cities: list[str] = Field(
        ..., max_length=50, description="Cities TroSky operates in; empty means no restriction."
    )

    @field_validator("complaint_sla_hours")
    @classmethod
    def _every_priority(cls, value: dict[str, int]) -> dict[str, int]:
        if set(value) != set(COMPLAINT_PRIORITIES) or not all(
            1 <= hours <= 720 for hours in value.values()
        ):
            raise ValueError(f"needs 1-720 hours for each of {', '.join(COMPLAINT_PRIORITIES)}")
        return value


# Settings that override an environment setting of another name.
_ENV_FIELDS = {
    "platform_fee_flat_per_seat": "PLATFORM_FEE_FLAT_PER_SEAT",
    "platform_fee_percent": "PLATFORM_FEE_PERCENT",
    "driver_earnings_share_percent": "DRIVER_EARNINGS_SHARE_PERCENT",
    "reservation_hold_seconds": "SEAT_RESERVATION_HOLD_SECONDS",
    "live_update_interval_seconds": "GPS_UPDATE_MIN_INTERVAL_SECONDS",
}


def _defaults(settings: Settings) -> dict[str, Any]:
    return {
        "platform_fee_flat_per_seat": settings.PLATFORM_FEE_FLAT_PER_SEAT,
        "platform_fee_percent": settings.PLATFORM_FEE_PERCENT,
        "driver_earnings_share_percent": settings.DRIVER_EARNINGS_SHARE_PERCENT,
        "reservation_hold_seconds": settings.SEAT_RESERVATION_HOLD_SECONDS,
        "live_update_interval_seconds": settings.GPS_UPDATE_MIN_INTERVAL_SECONDS,
        "complaint_sla_hours": {"low": 72, "medium": 48, "high": 24, "urgent": 4},
        "approval_target_hours": 48,
        "sos_escalation_contacts": [],
        "enabled_cities": [],
    }


@dataclass(frozen=True, slots=True)
class FlagDefinition:
    description: str
    default: bool
    # A setting this flag switches for everyone (rollout does not apply).
    setting: str | None = None


FLAGS: dict[str, FlagDefinition] = {
    "fare_sharing": FlagDefinition(
        "Share each trip's fare between its riders by distance.", True, "FARE_SHARING_ENABLED"
    ),
    "book_moving_trips": FlagDefinition(
        "Show trips already on the road in search, bookable from stops ahead of the vehicle.",
        True,
        "BOOK_MOVING_TRIPS_ENABLED",
    ),
    "trip_share_links": FlagDefinition(
        "Let passengers share a live link to their trip with family and friends.", True
    ),
}


@dataclass(frozen=True, slots=True)
class SettingEntry:
    key: str
    value: Any
    overridden: bool
    updated_by: uuid.UUID | None
    updated_at: datetime | None


@dataclass(frozen=True, slots=True)
class _FlagState:
    enabled: bool
    rollout_percent: int


@dataclass(frozen=True, slots=True)
class _Snapshot:
    """Plain values only. Rows would outlive the session that loaded them,
    and a rollback there expires them: the next request to read a cached
    row would fail."""

    values: SettingsValues
    flags: dict[str, _FlagState]
    effective: Settings
    taken_at: float


_cache: _Snapshot | None = None


def clear_cache() -> None:
    """Forget cached values (after a change, and between tests)."""
    global _cache
    _cache = None


async def _snapshot(session: AsyncSession) -> _Snapshot:
    global _cache
    if _cache is not None and time.monotonic() - _cache.taken_at < CACHE_SECONDS:
        return _cache
    base = get_settings()
    # A Result has keys() (its columns), so dict() would take it for a mapping.
    stored = dict(
        (await session.execute(select(SystemSetting.key, SystemSetting.value))).tuples().all()
    )
    flags = {
        key: _FlagState(enabled, rollout_percent)
        for key, enabled, rollout_percent in (
            await session.execute(
                select(FeatureFlag.key, FeatureFlag.enabled, FeatureFlag.rollout_percent)
            )
        ).tuples()
    }
    values = _typed(base, stored)
    _cache = _Snapshot(
        values=values,
        flags=flags,
        effective=_apply(base, values, stored.keys(), flags),
        taken_at=time.monotonic(),
    )
    return _cache


def _typed(base: Settings, stored: Mapping[str, Any]) -> SettingsValues:
    """Every setting, stored or default, typed (they are JSON in the
    database). A stored value no longer valid -- the limits changed since --
    falls back to its default rather than breaking every request; an admin
    can then save a new one."""
    try:
        return SettingsValues.model_validate({**_defaults(base), **stored})
    except ValidationError as exc:
        invalid = {str(error["loc"][0]) for error in exc.errors() if error["loc"]}
        logger.error("stored_settings_invalid", keys=sorted(invalid))
        valid = {key: value for key, value in stored.items() if key not in invalid}
        return SettingsValues.model_validate({**_defaults(base), **valid})


def _apply(
    base: Settings,
    values: SettingsValues,
    overridden: Collection[str],
    flags: Mapping[str, _FlagState],
) -> Settings:
    """``base`` with the stored overrides and setting-switching flags,
    copied in without re-reading the environment."""
    update: dict[str, Any] = {
        env_field: getattr(values, key)
        for key, env_field in _ENV_FIELDS.items()
        if key in overridden
    }
    for key, definition in FLAGS.items():
        flag = flags.get(key)
        if definition.setting is not None and flag is not None:
            update[definition.setting] = flag.enabled
    # Only what differs: an override equal to the default changes nothing.
    update = {key: value for key, value in update.items() if getattr(base, key) != value}
    return base.model_copy(update=update) if update else base


def _in_rollout(key: str, subject: uuid.UUID | None, percent: int) -> bool:
    if percent >= 100:
        return True
    if subject is None or percent <= 0:
        return False
    digest = hashlib.sha256(f"{key}:{subject}".encode()).digest()
    return int.from_bytes(digest[:4], "big") % 100 < percent


async def effective_settings(session: AsyncSession) -> Settings:
    """The environment settings with admins' overrides and flags applied."""
    return (await _snapshot(session)).effective


async def admin_settings(session: AsyncSession) -> SettingsValues:
    """Every admin setting as it stands: stored, or the default."""
    return (await _snapshot(session)).values


async def is_enabled(session: AsyncSession, key: str, subject: uuid.UUID | None = None) -> bool:
    """Whether ``subject`` (a user) gets the feature: on, and within the
    flag's rollout share, decided the same way for the same user every
    time."""
    definition = FLAGS[key]
    flag = (await _snapshot(session)).flags.get(key)
    if flag is None:
        return definition.default
    return flag.enabled and _in_rollout(key, subject, flag.rollout_percent)


class SystemSettingsService:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def list_settings(self) -> list[SettingEntry]:
        stored = {
            row.key: row for row in (await self._session.execute(select(SystemSetting))).scalars()
        }
        values = _typed(get_settings(), {k: r.value for k, r in stored.items()}).model_dump(
            mode="json"
        )
        return [
            SettingEntry(
                key=key,
                value=value,
                overridden=key in stored,
                updated_by=stored[key].updated_by if key in stored else None,
                updated_at=stored[key].updated_at if key in stored else None,
            )
            for key, value in values.items()
        ]

    async def update_settings(self, changes: dict[str, Any], *, by: uuid.UUID) -> None:
        """Validate the changed settings together with the rest, then store
        them. ``None`` for a key puts it back to its environment default."""
        unknown = set(changes) - set(SettingsValues.model_fields)
        if unknown:
            raise ValidationAppError("Unknown settings.", details={"unknown": sorted(unknown)})
        stored = {
            row.key: row for row in (await self._session.execute(select(SystemSetting))).scalars()
        }
        # Checked against the settings as they apply now: a stored value no
        # longer valid counts as its default, and blocks no other change.
        candidate = _typed(get_settings(), {k: r.value for k, r in stored.items()}).model_dump()
        resets = {key for key, value in changes.items() if value is None}
        for key in resets:
            candidate[key] = _defaults(get_settings())[key]
        candidate.update({k: v for k, v in changes.items() if v is not None})
        try:
            validated = SettingsValues.model_validate(candidate).model_dump(mode="json")
        except ValidationError as exc:
            raise ValidationAppError(
                "Invalid setting.",
                details={
                    "errors": [{"loc": list(e["loc"]), "msg": e["msg"]} for e in exc.errors()]
                },
            ) from exc
        now = datetime.now(UTC)
        for key in changes:
            row = stored.get(key)
            if key in resets:
                if row is not None:
                    await self._session.delete(row)
                continue
            if row is None:
                self._session.add(
                    SystemSetting(key=key, value=validated[key], updated_by=by, updated_at=now)
                )
            else:
                row.value, row.updated_by, row.updated_at = validated[key], by, now
        await self._session.flush()
        clear_cache()

    async def list_flags(self) -> list[FeatureFlag]:
        await self.ensure_flags()
        result = await self._session.execute(select(FeatureFlag).order_by(FeatureFlag.key))
        return list(result.scalars().all())

    async def ensure_flags(self) -> None:
        """Every flag defined in code has a row (with its default)."""
        existing = set((await self._session.execute(select(FeatureFlag.key))).scalars())
        for key, definition in FLAGS.items():
            if key not in existing:
                self._session.add(
                    FeatureFlag(
                        key=key,
                        description=definition.description,
                        enabled=definition.default,
                        rollout_percent=100,
                    )
                )
        await self._session.flush()

    async def update_flag(
        self, key: str, *, enabled: bool | None, rollout_percent: int | None, by: uuid.UUID
    ) -> FeatureFlag:
        if key not in FLAGS:
            raise NotFoundError("No such feature flag.")
        await self.ensure_flags()
        flag = await self._session.get(FeatureFlag, key)
        assert flag is not None
        if (
            rollout_percent is not None
            and FLAGS[key].setting is not None
            and rollout_percent != 100
        ):
            raise ValidationAppError(
                "This flag switches a platform-wide setting: it is on or off for everyone.",
                details={"flag": key},
            )
        if enabled is not None:
            flag.enabled = enabled
        if rollout_percent is not None:
            flag.rollout_percent = rollout_percent
        flag.updated_by, flag.updated_at = by, datetime.now(UTC)
        await self._session.flush()
        clear_cache()
        return flag
