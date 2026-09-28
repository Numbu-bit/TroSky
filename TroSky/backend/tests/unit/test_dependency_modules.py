"""The split of ``app.api.dependencies`` into per-context modules.

What must hold for the split to be safe:

* every name the facade exports is the *same object* as in its context
  module -- FastAPI ``dependency_overrides`` are keyed by function identity,
  so a copy would silently stop overrides (as ``tests/conftest.py`` uses)
  from applying;
* an override registered through the old import path still reaches a route
  built from the new modules;
* context modules never import the facade, which would bring back the
  single hub the split exists to remove.
"""

from __future__ import annotations

import ast
import importlib
from pathlib import Path

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient

import app.api.dependencies as facade
from app.api.common_dependencies import StorageProviderDep

CONTEXT_MODULES = [
    "app.api.admin_dependencies",
    "app.api.auth_dependencies",
    "app.api.common_dependencies",
    "app.api.fleet_dependencies",
    "app.api.payment_dependencies",
    "app.api.support_dependencies",
    "app.api.tracking_dependencies",
    "app.api.trip_dependencies",
]


def _homes(name: str) -> list[str]:
    obj = getattr(facade, name)
    return [
        module
        for module in CONTEXT_MODULES
        if getattr(importlib.import_module(module), name, None) is obj
    ]


@pytest.mark.parametrize("name", facade.__all__)
def test_each_exported_name_is_the_context_modules_own_object(name: str) -> None:
    assert _homes(name), f"{name} is not the same object as any context module's"


def test_the_public_interface_is_unchanged_apart_from_resolve_principal() -> None:
    """The facade must not drop anything existing imports rely on."""
    expected = {
        "AdminServiceDep", "AnalyticsServiceDep", "AuthServiceDep", "BookingServiceDep",
        "ComplaintServiceDep", "CurrentPrincipal", "DbSession", "DriverServiceDep",
        "EmailProviderDep", "FleetServiceDep", "MalwareScannerDep", "NotificationServiceDep",
        "OptionalIdempotencyKey", "Pagination", "PaginationParams", "PaymentServiceDep",
        "RatingServiceDep", "RedisClient", "RefundServiceDep", "RouteServiceDep",
        "SafetyServiceDep", "SmsProviderDep", "StorageProviderDep", "TicketServiceDep",
        "TrackingServiceDep", "TripServiceDep", "UserServiceDep", "WalletServiceDep",
        "WithdrawalServiceDep", "get_admin_service", "get_analytics_service",
        "get_auth_service", "get_booking_service", "get_complaint_service",
        "get_current_principal", "get_driver_service", "get_email_provider_dep",
        "get_fleet_service", "get_malware_scanner_dep", "get_notification_service",
        "get_payment_service", "get_rating_service", "get_refund_service",
        "get_route_service", "get_safety_service", "get_sms_provider_dep",
        "get_storage_provider_dep", "get_ticket_service", "get_tracking_service",
        "get_trip_service", "get_user_service", "get_wallet_service",
        "get_withdrawal_service", "resolve_principal",
    }  # fmt: skip
    assert set(facade.__all__) == expected


def test_private_helpers_used_by_existing_tests_are_still_importable() -> None:
    from app.api.dependencies import _extract_idempotency_key, _pagination_params

    assert callable(_extract_idempotency_key)
    assert callable(_pagination_params)


@pytest.mark.asyncio
async def test_an_override_through_the_old_path_reaches_the_new_modules() -> None:
    """``tests/conftest.py`` overrides ``app.api.dependencies
    .get_storage_provider_dep``; routes now declare ``StorageProviderDep``
    from ``app.api.common_dependencies``. The override must still bite."""
    app = FastAPI()

    @app.get("/which")
    async def which(storage: StorageProviderDep) -> dict[str, str]:
        return {"storage": str(storage)}

    app.dependency_overrides[facade.get_storage_provider_dep] = lambda: "overridden"
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://t") as client:
        response = await client.get("/which")
    assert response.json() == {"storage": "overridden"}


def test_context_modules_do_not_import_the_facade() -> None:
    api_dir = Path(importlib.import_module("app.api").__file__).parent  # type: ignore[arg-type]
    offenders = []
    for module in CONTEXT_MODULES:
        source = (api_dir / f"{module.rsplit('.', 1)[1]}.py").read_text(encoding="utf-8")
        for node in ast.walk(ast.parse(source)):
            if isinstance(node, ast.ImportFrom) and node.module == "app.api.dependencies":
                offenders.append(module)
            if (
                isinstance(node, ast.ImportFrom)
                and node.module == "app.api"
                and any(alias.name == "dependencies" for alias in node.names)
            ):
                offenders.append(module)
    assert offenders == []
