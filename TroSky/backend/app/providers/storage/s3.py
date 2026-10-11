"""S3-compatible object storage adapter (boto3).

Works unmodified against real AWS S3 in production, Cloudflare R2 (the
staging server's storage: ``docs/deploy-render.md``, "File uploads") and
MinIO in local development / CI (``S3_ENDPOINT`` points at MinIO in
``docker-compose.yml``) — the same adapter, just different endpoint
configuration, which is the point of the S3 API being a de-facto standard.

# PRODUCTION CREDENTIALS REQUIRED
Set S3_ENDPOINT / S3_REGION / S3_BUCKET / S3_ACCESS_KEY / S3_SECRET_KEY to
a real bucket's credentials. The bucket must be private (no public read)
— this adapter never sets a public ACL.
"""

from __future__ import annotations

import asyncio
from typing import Any

import boto3
from botocore.client import Config as BotoConfig
from botocore.exceptions import BotoCoreError, ClientError

from app.core.config import Settings
from app.core.exceptions import ProviderError
from app.core.logging import get_logger
from app.providers.storage.base import UploadedObject

logger = get_logger(__name__)


class S3StorageProvider:
    def __init__(self, settings: Settings) -> None:
        self._bucket = settings.S3_BUCKET
        self._client: Any = boto3.client(
            "s3",
            endpoint_url=settings.S3_ENDPOINT,
            region_name=settings.S3_REGION,
            aws_access_key_id=settings.S3_ACCESS_KEY,
            aws_secret_access_key=settings.S3_SECRET_KEY.get_secret_value(),
            config=BotoConfig(
                signature_version="s3v4",
                # Checksums only where an operation requires them: newer boto3
                # adds them to every upload by default, which S3-compatible
                # stores such as R2 have refused. AWS and MinIO are unaffected.
                request_checksum_calculation="when_required",
                response_checksum_validation="when_required",
            ),
            use_ssl=settings.S3_USE_SSL,
        )

    def _put_object_sync(self, key: str, data: bytes, content_type: str) -> None:
        self._client.put_object(
            Bucket=self._bucket,
            Key=key,
            Body=data,
            ContentType=content_type,
            # Private by default: no ACL is set, so the object inherits the
            # bucket's (private) access policy. Never pass ACL="public-read".
        )

    async def put_object(self, key: str, data: bytes, content_type: str) -> UploadedObject:
        try:
            await asyncio.to_thread(self._put_object_sync, key, data, content_type)
        except (BotoCoreError, ClientError) as exc:
            logger.error("s3_put_object_failed", key=key, error=str(exc))
            raise ProviderError("Failed to store the uploaded file.") from exc
        return UploadedObject(storage_key=key, size_bytes=len(data), content_type=content_type)

    def _generate_download_url_sync(self, key: str, expires_in_seconds: int) -> str:
        url: str = self._client.generate_presigned_url(
            "get_object",
            Params={"Bucket": self._bucket, "Key": key},
            ExpiresIn=expires_in_seconds,
        )
        return url

    async def generate_download_url(self, key: str, *, expires_in_seconds: int) -> str:
        try:
            return await asyncio.to_thread(
                self._generate_download_url_sync, key, expires_in_seconds
            )
        except (BotoCoreError, ClientError) as exc:
            logger.error("s3_presign_failed", key=key, error=str(exc))
            raise ProviderError("Failed to generate a download link.") from exc

    def _delete_object_sync(self, key: str) -> None:
        self._client.delete_object(Bucket=self._bucket, Key=key)

    async def delete_object(self, key: str) -> None:
        try:
            await asyncio.to_thread(self._delete_object_sync, key)
        except (BotoCoreError, ClientError) as exc:
            logger.error("s3_delete_object_failed", key=key, error=str(exc))
            raise ProviderError("Failed to delete the stored file.") from exc
