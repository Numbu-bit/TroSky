"""Infrastructure dependencies shared by every bounded context: the database
session, Redis, pagination, idempotency keys, and external providers."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Annotated
from uuid import UUID

from fastapi import Depends, Header, Query
from redis.asyncio import Redis
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.redis import get_redis
from app.providers.email.base import EmailProvider
from app.providers.email.factory import get_email_provider
from app.providers.sms.base import SmsProvider
from app.providers.sms.factory import get_sms_provider
from app.providers.storage.base import ObjectStorageProvider
from app.providers.storage.factory import get_storage_provider
from app.providers.storage.malware_scan import MalwareScanner, NoOpMalwareScanner

# Standard idiom: `db: DbSession` in a route signature resolves an
# AsyncSession via `get_db` without repeating `Depends(get_db)` everywhere.
DbSession = Annotated[AsyncSession, Depends(get_db)]
RedisClient = Annotated[Redis, Depends(get_redis)]


@dataclass(frozen=True, slots=True)
class PaginationParams:
    """Standard limit/offset pagination, validated and capped."""

    limit: int = 20
    offset: int = 0


def _pagination_params(
    limit: Annotated[int, Query(ge=1, le=100)] = 20,
    offset: Annotated[int, Query(ge=0)] = 0,
) -> PaginationParams:
    return PaginationParams(limit=limit, offset=offset)


Pagination = Annotated[PaginationParams, Depends(_pagination_params)]


def _extract_idempotency_key(
    value: Annotated[UUID | None, Header(alias="Idempotency-Key")] = None,
) -> UUID | None:
    """Extracts the optional ``Idempotency-Key`` header for high-risk
    commands (bookings, payments). ``None`` means the caller did not supply
    one; services that require idempotency for correctness enforce that
    explicitly rather than defaulting silently."""
    return value


OptionalIdempotencyKey = Annotated[UUID | None, Depends(_extract_idempotency_key)]


def get_sms_provider_dep() -> SmsProvider:
    return get_sms_provider()


def get_email_provider_dep() -> EmailProvider:
    return get_email_provider()


SmsProviderDep = Annotated[SmsProvider, Depends(get_sms_provider_dep)]
EmailProviderDep = Annotated[EmailProvider, Depends(get_email_provider_dep)]


def get_storage_provider_dep() -> ObjectStorageProvider:
    return get_storage_provider()


def get_malware_scanner_dep() -> MalwareScanner:
    return NoOpMalwareScanner()


StorageProviderDep = Annotated[ObjectStorageProvider, Depends(get_storage_provider_dep)]
MalwareScannerDep = Annotated[MalwareScanner, Depends(get_malware_scanner_dep)]
