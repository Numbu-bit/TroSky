"""Maps provider factory: resolves the configured ETA provider."""

from __future__ import annotations

from app.core.config import MapsProviderName, Settings, get_settings
from app.providers.maps.base import MapsProvider
from app.providers.maps.local import LocalMapsProvider
from app.providers.maps.unavailable import UnavailableMapsProvider


def get_maps_provider(settings: Settings | None = None) -> MapsProvider:
    settings = settings or get_settings()
    match settings.MAPS_PROVIDER:
        case MapsProviderName.LOCAL:
            return LocalMapsProvider()
        case MapsProviderName.GOOGLE:
            return UnavailableMapsProvider("Google Maps")
        case MapsProviderName.MAPBOX:
            return UnavailableMapsProvider("Mapbox")
        case MapsProviderName.HERE:
            return UnavailableMapsProvider("HERE")
