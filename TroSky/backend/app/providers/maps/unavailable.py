"""Configuration-ready skeleton for real routing-API providers.

Google Maps, Mapbox, and HERE all have genuinely stable, well-documented
routing APIs — unlike the payment channels this codebase leaves as
skeletons, the *documentation gap* isn't the issue here. The blocker is
simply that no API key/billing account is available in this environment,
and fabricating a plausible-looking response shape for an unconfigured
paid API is exactly the kind of fake implementation this project does not
ship. Once real credentials exist, implementing this class's one method
against the chosen vendor's routing API is what actually turns
``MAPS_PROVIDER=google`` (etc.) on.
"""

from __future__ import annotations

from decimal import Decimal

from app.core.exceptions import ProviderError
from app.providers.maps.base import EtaResult


class UnavailableMapsProvider:
    def __init__(self, provider_label: str) -> None:
        self._provider_label = provider_label

    async def estimate_eta(
        self,
        *,
        origin: tuple[float, float],
        destination: tuple[float, float],
        current_speed_kmh: Decimal | None,
    ) -> EtaResult:
        raise ProviderError(
            f"{self._provider_label} is not configured (no API key/billing account "
            f"available) — set MAPS_PROVIDER=local for the straight-line estimate, or "
            f"configure MAPS_API_KEY and implement this adapter against a real account."
        )
