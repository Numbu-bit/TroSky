"""Unit tests for the local (non-API) ETA heuristic and provider factory
(pure logic, no network, no database)."""

from __future__ import annotations

from decimal import Decimal

import pytest

from app.core.config import MapsProviderName, Settings
from app.core.exceptions import ProviderError
from app.providers.maps.factory import get_maps_provider
from app.providers.maps.local import LocalMapsProvider
from app.providers.maps.unavailable import UnavailableMapsProvider

_ACCRA = (5.6037, -0.1870)
_KUMASI = (6.6885, -1.6244)


class TestLocalMapsProvider:
    async def test_estimate_eta_uses_current_speed_when_plausible(self) -> None:
        provider = LocalMapsProvider()
        result = await provider.estimate_eta(
            origin=_ACCRA, destination=_KUMASI, current_speed_kmh=Decimal("80")
        )
        assert result.distance_km > 0
        assert result.duration_minutes > 0
        assert result.eta_at is not None

    async def test_estimate_eta_falls_back_to_average_speed_when_stationary(self) -> None:
        provider = LocalMapsProvider()
        moving = await provider.estimate_eta(
            origin=_ACCRA, destination=_KUMASI, current_speed_kmh=Decimal("80")
        )
        stationary = await provider.estimate_eta(
            origin=_ACCRA, destination=_KUMASI, current_speed_kmh=Decimal("0")
        )
        # Same distance either way; a much faster current speed than the
        # fallback average must produce a shorter duration.
        assert moving.distance_km == stationary.distance_km
        assert moving.duration_minutes < stationary.duration_minutes

    async def test_estimate_eta_with_no_speed_reading(self) -> None:
        provider = LocalMapsProvider()
        result = await provider.estimate_eta(
            origin=_ACCRA, destination=_KUMASI, current_speed_kmh=None
        )
        assert result.duration_minutes > 0

    async def test_routing_factor_inflates_straight_line_distance(self) -> None:
        from app.utilities.geo import haversine_distance_km

        provider = LocalMapsProvider()
        result = await provider.estimate_eta(
            origin=_ACCRA, destination=_KUMASI, current_speed_kmh=None
        )
        straight_line = Decimal(str(haversine_distance_km(*_ACCRA, *_KUMASI)))
        assert result.distance_km > straight_line


class TestMapsProviderFactory:
    def _settings(self, provider_name: MapsProviderName) -> Settings:
        return Settings(
            SECRET_KEY="x" * 32,
            DATABASE_URL="postgresql+asyncpg://u:p@localhost/db",
            DATABASE_URL_SYNC="postgresql://u:p@localhost/db",
            PAYMENTS_WEBHOOK_SIGNING_SECRET="webhook-secret-value",
            TICKET_QR_SIGNING_SECRET="y" * 32,
            MAPS_PROVIDER=provider_name,
        )  # type: ignore[call-arg]

    def test_local_provider_selected_by_default(self) -> None:
        provider = get_maps_provider(self._settings(MapsProviderName.LOCAL))
        assert isinstance(provider, LocalMapsProvider)

    async def test_unconfigured_real_provider_raises_on_use(self) -> None:
        provider = get_maps_provider(self._settings(MapsProviderName.GOOGLE))
        assert isinstance(provider, UnavailableMapsProvider)
        with pytest.raises(ProviderError):
            await provider.estimate_eta(origin=_ACCRA, destination=_KUMASI, current_speed_kmh=None)
