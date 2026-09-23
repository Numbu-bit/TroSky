"""Object storage provider interface (S3-compatible).

Used for driver/vehicle verification documents and other private media.
Storage is always private (no public bucket ACLs); access is only ever via
a time-limited signed download URL generated per-request and audit-logged
by the caller (see ``app.services.document_service``).
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Protocol


@dataclass(frozen=True, slots=True)
class UploadedObject:
    storage_key: str
    size_bytes: int
    content_type: str


class ObjectStorageProvider(Protocol):
    """Interface every object storage adapter implements."""

    async def put_object(self, key: str, data: bytes, content_type: str) -> UploadedObject:
        """Upload ``data`` to ``key`` in the private documents bucket."""
        ...

    async def generate_download_url(self, key: str, *, expires_in_seconds: int) -> str:
        """Generate a time-limited, signed GET URL for ``key``."""
        ...

    async def delete_object(self, key: str) -> None:
        """Delete the object at ``key``. Idempotent — deleting a missing
        key must not raise."""
        ...
