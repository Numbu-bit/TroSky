"""In-memory object storage provider for tests.

Never makes a network call. Used by the test suite in place of
``S3StorageProvider`` so document-upload tests don't require a running
MinIO/S3 endpoint — the same pattern as the SMS/email sandbox providers.
"""

from __future__ import annotations

from typing import ClassVar

from app.providers.storage.base import UploadedObject


class SandboxStorageProvider:
    _objects: ClassVar[dict[str, tuple[bytes, str]]] = {}

    async def put_object(self, key: str, data: bytes, content_type: str) -> UploadedObject:
        self._objects[key] = (data, content_type)
        return UploadedObject(storage_key=key, size_bytes=len(data), content_type=content_type)

    async def generate_download_url(self, key: str, *, expires_in_seconds: int) -> str:
        return f"https://sandbox-storage.local/{key}?expires_in={expires_in_seconds}"

    async def delete_object(self, key: str) -> None:
        self._objects.pop(key, None)

    @classmethod
    def get_object(cls, key: str) -> tuple[bytes, str] | None:
        return cls._objects.get(key)

    @classmethod
    def clear(cls) -> None:
        cls._objects.clear()
