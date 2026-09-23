"""Local (no external API) ETA estimate: great-circle distance, a fixed
road-winding correction factor, and either the vehicle's current measured
speed or a fixed average-speed assumption.

This is a deliberately simple MVP heuristic, not real road-network
routing — it does not know about traffic, road closures, or actual route
geometry. A real ``MAPS_PROVIDER`` (Google/Mapbox/HERE) would replace this
with a routing-API call; none is wired up because doing so would need a
live, billed API key this codebase does not have and should not fabricate
a response shape for (same policy as the payment channels in
``app.providers.payments.unavailable``).
"""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from decimal import Decimal

from app.providers.maps.base import EtaResult
from app.utilities.geo import haversine_distance_km

# Straight-line (great-circle) distance underestimates real road distance
# on anything but a perfectly direct route; this fixed multiplier is a
# rough correction, not a routed-distance calculation.
_ROUTING_FACTOR = Decimal("1.3")

# Used only when no current speed is available (e.g. the trip hasn't sent
# a GPS ping yet) — a blended urban/intercity assumption for Ghana.
_DEFAULT_AVERAGE_SPEED_KMH = Decimal("40")

# Below this, a "current speed" reading is treated as stationary (traffic,
# a stop) rather than a meaningful travel rate to project forward.
_MIN_MEANINGFUL_SPEED_KMH = Decimal("5")


class LocalMapsProvider:
    async def estimate_eta(
        self,
        *,
        origin: tuple[float, float],
        destination: tuple[float, float],
        current_speed_kmh: Decimal | None,
    ) -> EtaResult:
        straight_line_km = Decimal(str(haversine_distance_km(*origin, *destination)))
        distance_km = (straight_line_km * _ROUTING_FACTOR).quantize(Decimal("0.01"))

        effective_speed = (
            current_speed_kmh
            if current_speed_kmh is not None and current_speed_kmh >= _MIN_MEANINGFUL_SPEED_KMH
            else _DEFAULT_AVERAGE_SPEED_KMH
        )
        duration_hours = distance_km / effective_speed
        duration_minutes = max(int(duration_hours * 60), 1)

        return EtaResult(
            distance_km=distance_km,
            duration_minutes=duration_minutes,
            eta_at=datetime.now(UTC) + timedelta(minutes=duration_minutes),
        )
