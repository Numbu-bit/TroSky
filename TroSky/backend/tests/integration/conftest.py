"""Fixtures shared by the service-level integration tests.

Onboarding now grants roles (``app.services.role_service``), so creating a
driver or fleet-owner profile reads the ``roles`` table the way
registration always has. Seeding is committed rather than done inside the
caller's rolled-back transaction, so it is equally visible to tests using
the SAVEPOINT-isolated ``db_session`` and to the concurrency tests that
open their own sessions via ``get_session_factory``.
"""

from __future__ import annotations

import pytest


@pytest.fixture(autouse=True)
def _seed_roles(seed_identity_data: None) -> None:
    """Idempotent, so paying it per test is cheap."""
    return
