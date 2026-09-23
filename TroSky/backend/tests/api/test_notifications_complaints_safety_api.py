"""End-to-end HTTP auth checks for notifications, complaints, and safety
(incidents/SOS) endpoints — full happy-path flows are exercised at the
service-integration level, same scoping rationale as the other API test
modules in this suite."""

from __future__ import annotations

import uuid

import pytest
from httpx import AsyncClient

pytestmark = pytest.mark.integration


class TestNotificationsApiAuth:
    async def test_list_notifications_requires_authentication(self, client: AsyncClient) -> None:
        response = await client.get("/api/v1/notifications")
        assert response.status_code == 401

    async def test_mark_read_requires_authentication(self, client: AsyncClient) -> None:
        response = await client.post(f"/api/v1/notifications/{uuid.uuid4()}/read")
        assert response.status_code == 401

    async def test_register_device_requires_authentication(self, client: AsyncClient) -> None:
        response = await client.post(
            "/api/v1/users/me/devices",
            json={"device_id": "d1", "platform": "android"},
        )
        assert response.status_code == 401


class TestComplaintsApiAuth:
    async def test_file_complaint_requires_authentication(self, client: AsyncClient) -> None:
        response = await client.post(
            "/api/v1/complaints",
            json={"category": "other", "subject": "x", "description": "y"},
        )
        assert response.status_code == 401

    async def test_list_complaints_requires_authentication(self, client: AsyncClient) -> None:
        response = await client.get("/api/v1/complaints")
        assert response.status_code == 401


class TestSafetyApiAuth:
    async def test_report_incident_requires_authentication(self, client: AsyncClient) -> None:
        response = await client.post(
            f"/api/v1/trips/{uuid.uuid4()}/incidents",
            json={"incident_type": "other", "severity": "low", "description": "x"},
        )
        assert response.status_code == 401

    async def test_trigger_sos_requires_authentication(self, client: AsyncClient) -> None:
        response = await client.post(f"/api/v1/trips/{uuid.uuid4()}/sos", json={})
        assert response.status_code == 401

    async def test_get_incident_requires_authentication(self, client: AsyncClient) -> None:
        response = await client.get(f"/api/v1/incidents/{uuid.uuid4()}")
        assert response.status_code == 401

    async def test_get_sos_alert_requires_authentication(self, client: AsyncClient) -> None:
        response = await client.get(f"/api/v1/sos/{uuid.uuid4()}")
        assert response.status_code == 401
