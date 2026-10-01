"""Parsing for list-valued query parameters written as ``a,b,c``."""

from __future__ import annotations

from enum import StrEnum
from typing import TypeVar

from app.core.exceptions import ValidationAppError

E = TypeVar("E", bound=StrEnum)


def parse_enum_list(raw: str | None, enum_cls: type[E], *, param: str) -> list[E] | None:
    """``"scheduled,boarding"`` -> ``[TripStatus.SCHEDULED, TripStatus.BOARDING]``.

    ``None`` when the parameter is absent or blank, meaning "no filter".
    Raises a 422 naming the allowed values if any entry is not one of them.
    """
    if raw is None or not raw.strip():
        return None
    allowed = {member.value: member for member in enum_cls}
    values = [part.strip() for part in raw.split(",") if part.strip()]
    unknown = [value for value in values if value not in allowed]
    if unknown:
        raise ValidationAppError(
            f"Unknown {param} value(s): {', '.join(unknown)}.",
            details={"param": param, "allowed": sorted(allowed)},
        )
    return [allowed[value] for value in dict.fromkeys(values)]
