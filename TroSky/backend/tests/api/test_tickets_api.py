"""End-to-end HTTP tests for ticket-endpoint auth and validation.

Standing up a fully issued/validated ticket end-to-end over HTTP needs a
confirmed, paid booking plus an approved driver assigned to the trip —
exercised at the service-integration level
(``tests/integration/test_ticket_service.py``) for the same reason
``test_bookings_api.py``/``test_payments_api.py`` scope themselves down;
these tests focus on what's specific to the HTTP layer.
"""

from __future__ import annotations

import uuid

import pytest
from httpx import AsyncClient

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]


class TestTicketApiAuth:
    async def test_get_ticket_requires_authentication(self, client: AsyncClient) -> None:
        response = await client.get(f"/api/v1/tickets/{uuid.uuid4()}")
        assert response.status_code == 401

    async def test_list_booking_tickets_requires_authentication(self, client: AsyncClient) -> None:
        response = await client.get(f"/api/v1/bookings/{uuid.uuid4()}/tickets")
        assert response.status_code == 401

    async def test_validate_ticket_requires_authentication(self, client: AsyncClient) -> None:
        response = await client.post(
            f"/api/v1/driver-trips/{uuid.uuid4()}/tickets/validate",
            json={"qr_token": "anything"},
        )
        assert response.status_code == 401
