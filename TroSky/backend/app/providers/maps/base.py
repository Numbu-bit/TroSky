"""Maps/ETA provider interface.

Every ETA computation goes through this interface so the active provider
can be swapped via configuration (``MAPS_PROVIDER``) without touching
callers — the same shape as every other provider category in this codebase.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from decimal import Decimal
from typing import Protocol


@dataclass(frozen=True, slots=True)
class EtaResult:
    distance_km: Decimal
    duration_minutes: int
    eta_at: datetime


class MapsProvider(Protocol):
    async def estimate_eta(
        self,
        *,
        origin: tuple[float, float],
        destination: tuple[float, float],
        current_speed_kmh: Decimal | None,
    ) -> EtaResult:
        """Estimate arrival at ``destination`` from ``origin`` (both
        ``(latitude, longitude)``), optionally informed by the vehicle's
        current measured speed."""
        ...
