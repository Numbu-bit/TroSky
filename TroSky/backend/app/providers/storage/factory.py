"""Object storage provider factory."""

from __future__ import annotations

from app.core.config import Settings, get_settings
from app.providers.storage.base import ObjectStorageProvider
from app.providers.storage.s3 import S3StorageProvider


def get_storage_provider(settings: Settings | None = None) -> ObjectStorageProvider:
    """Returns the S3-compatible storage provider (AWS S3 in production,
    MinIO in development/CI — same adapter, different endpoint)."""
    return S3StorageProvider(settings or get_settings())
