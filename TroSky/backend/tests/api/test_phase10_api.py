"""End-to-end HTTP auth checks for withdrawals, fleet analytics, and admin
user-management/reports endpoints — full happy-path flows are exercised at
the service-integration level, same scoping rationale as the other API
test modules in this suite."""

from __future__ import annotations

import uuid

import pytest
from httpx import AsyncClient

pytestmark = pytest.mark.integration


class TestWithdrawalApiAuth:
    async def test_request_withdrawal_requires_authentication(self, client: AsyncClient) -> None:
        response = await client.post(
            "/api/v1/wallet/withdrawals",
            json={
                "amount": "50.00",
                "channel": "mtn_momo",
                "destination_phone_number": "0244000001",
            },
        )
        assert response.status_code == 401

    async def test_list_withdrawals_requires_authentication(self, client: AsyncClient) -> None:
        response = await client.get("/api/v1/wallet/withdrawals")
        assert response.status_code == 401


class TestFleetAnalyticsApiAuth:
    async def test_fleet_analytics_requires_authentication(self, client: AsyncClient) -> None:
        response = await client.get(f"/api/v1/fleets/{uuid.uuid4()}/analytics")
        assert response.status_code == 401


class TestAdminApiAuth:
    async def test_list_users_requires_authentication(self, client: AsyncClient) -> None:
        response = await client.get("/api/v1/admin/users")
        assert response.status_code == 401

    async def test_suspend_user_requires_authentication(self, client: AsyncClient) -> None:
        response = await client.post(
            f"/api/v1/admin/users/{uuid.uuid4()}/suspend", json={"reason": "x"}
        )
        assert response.status_code == 401

    async def test_list_admin_withdrawals_requires_authentication(
        self, client: AsyncClient
    ) -> None:
        response = await client.get("/api/v1/admin/withdrawals")
        assert response.status_code == 401

    async def test_reports_overview_requires_authentication(self, client: AsyncClient) -> None:
        response = await client.get("/api/v1/admin/reports/overview")
        assert response.status_code == 401
