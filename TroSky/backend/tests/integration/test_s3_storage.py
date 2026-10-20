"""Uploads against a real S3-compatible store: MinIO locally, or Cloudflare R2
when pointed at it. Skipped unless TROSKY_TEST_S3_ENDPOINT,
TROSKY_TEST_S3_ACCESS_KEY and TROSKY_TEST_S3_SECRET_KEY are set (and
optionally TROSKY_TEST_S3_BUCKET, TROSKY_TEST_S3_REGION); the bucket is made
if missing.
"""

from __future__ import annotations

import os
import uuid

import boto3
import httpx
import pytest
from botocore.exceptions import ClientError
from pydantic import SecretStr

from app.core.config import get_settings
from app.providers.storage.s3 import S3StorageProvider

pytestmark = pytest.mark.integration

_ENDPOINT = os.environ.get("TROSKY_TEST_S3_ENDPOINT")
_ACCESS = os.environ.get("TROSKY_TEST_S3_ACCESS_KEY")
_SECRET = os.environ.get("TROSKY_TEST_S3_SECRET_KEY")
_BUCKET = os.environ.get("TROSKY_TEST_S3_BUCKET", "trosky-test-uploads")
_REGION = os.environ.get("TROSKY_TEST_S3_REGION", "us-east-1")


@pytest.fixture
def storage() -> S3StorageProvider:
    if not (_ENDPOINT and _ACCESS and _SECRET):
        pytest.skip("No S3-compatible store configured (TROSKY_TEST_S3_ENDPOINT, ...).")
    client = boto3.client(
        "s3",
        endpoint_url=_ENDPOINT,
        region_name=_REGION,
        aws_access_key_id=_ACCESS,
        aws_secret_access_key=_SECRET,
    )
    try:
        # Not list_buckets: a token scoped to one bucket (R2) may not list them all.
        client.head_bucket(Bucket=_BUCKET)
    except ClientError:
        client.create_bucket(Bucket=_BUCKET)
    settings = get_settings().model_copy(
        update={
            "S3_ENDPOINT": _ENDPOINT,
            "S3_REGION": _REGION,
            "S3_BUCKET": _BUCKET,
            "S3_ACCESS_KEY": _ACCESS,
            "S3_SECRET_KEY": SecretStr(_SECRET),
            "S3_USE_SSL": _ENDPOINT.startswith("https://"),
        }
    )
    return S3StorageProvider(settings)


async def test_a_driver_document_goes_up_comes_back_and_goes(storage: S3StorageProvider) -> None:
    key = f"tests/{uuid.uuid4()}/licence.png"
    data = b"\x89PNG\r\n\x1a\n" + uuid.uuid4().bytes * 64

    stored = await storage.put_object(key, data, "image/png")
    assert (stored.storage_key, stored.size_bytes) == (key, len(data))

    link = await storage.generate_download_url(key, expires_in_seconds=60)
    async with httpx.AsyncClient(timeout=30) as client:
        fetched = await client.get(link)
        assert fetched.status_code == 200
        assert fetched.content == data
        assert fetched.headers["content-type"] == "image/png"

        # Private: without the signature the object can't be read.
        bare = await client.get(link.split("?")[0])
        assert bare.status_code in (400, 401, 403)

        await storage.delete_object(key)
        assert (await client.get(link)).status_code == 404
    await storage.delete_object(key)  # deleting again is harmless
