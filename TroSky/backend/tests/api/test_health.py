"""Tests for the unversioned /health/* infrastructure endpoints."""

from __future__ import annotations

import pytest
from httpx import AsyncClient

pytestmark = pytest.mark.asyncio


class TestLiveness:
    async def test_liveness_returns_200_with_no_dependencies(self, client: AsyncClient) -> None:
        response = await client.get("/health/live")
        assert response.status_code == 200
        assert response.json() == {"status": "alive"}


@pytest.mark.integration
class TestReadiness:
    async def test_readiness_reports_database_and_redis(
        self, client: AsyncClient, require_postgres, require_redis
    ) -> None:
        response = await client.get("/health/ready")
        body = response.json()
        assert response.status_code == 200
        assert body["status"] == "ready"
        assert body["database"] is True
        assert body["redis"] is True

    async def test_health_details_exposed_when_configured(
        self, client: AsyncClient, require_postgres, require_redis
    ) -> None:
        response = await client.get("/health/details")
        assert response.status_code == 200
        body = response.json()
        assert body["app_env"] == "test"
        # Health details must never leak secrets/config values.
        assert "secret" not in str(body).lower()
        assert "password" not in str(body).lower()
