"""The frontend works from ``/openapi.json``: every endpoint, parameter and
field it asked for (requests G1-G16) must be documented there."""

from __future__ import annotations

from typing import Any

import pytest

from app.main import create_app

NEW_OPERATIONS = [
    ("post", "/api/v1/auth/password/reset"),  # G1, now also takes target + code
    ("get", "/api/v1/drivers/me/trips"),  # G2
    ("get", "/api/v1/driver-trips/{trip_id}/passengers"),  # G3
    ("get", "/api/v1/users/me/favourite-routes"),  # G4
    ("post", "/api/v1/users/me/favourite-routes"),
    ("delete", "/api/v1/users/me/favourite-routes/{favourite_id}"),
    ("post", "/api/v1/users/me/avatar"),  # G5
    ("get", "/api/v1/drivers/me/earnings"),  # G7
    ("get", "/api/v1/admin/trips"),  # G8
    ("get", "/api/v1/admin/live-trips"),
    ("get", "/api/v1/fleets/{fleet_id}/live-trips"),
    ("patch", "/api/v1/admin/stops/{stop_id}"),  # G9
    ("delete", "/api/v1/admin/stops/{stop_id}"),
    ("patch", "/api/v1/admin/routes/{route_id}"),
    ("delete", "/api/v1/admin/routes/{route_id}"),
    ("get", "/api/v1/fleets/{fleet_id}/drivers"),  # G10
    ("get", "/api/v1/fleets/driver-lookup"),
    ("get", "/api/v1/vehicles/nearby"),  # G16
]


@pytest.fixture(scope="module")
def spec() -> dict[str, Any]:
    return create_app().openapi()


def _params(spec: dict[str, Any], method: str, path: str) -> set[str]:
    return {p["name"] for p in spec["paths"][path][method].get("parameters", [])}


def _fields(spec: dict[str, Any], schema: str) -> set[str]:
    return set(spec["components"]["schemas"][schema]["properties"])


@pytest.mark.parametrize(("method", "path"), NEW_OPERATIONS)
def test_endpoint_is_documented(spec: dict[str, Any], method: str, path: str) -> None:
    assert method in spec["paths"].get(path, {}), f"{method.upper()} {path} missing"


def test_new_query_parameters_are_documented(spec: dict[str, Any]) -> None:
    assert {"status", "upcoming"} <= _params(spec, "get", "/api/v1/bookings")  # G12
    assert "reference_type" in _params(spec, "get", "/api/v1/wallet/transactions")  # G7
    assert {"status", "date"} <= _params(spec, "get", "/api/v1/drivers/me/trips")
    assert {"period", "from", "to"} <= _params(spec, "get", "/api/v1/drivers/me/earnings")
    assert {"status", "date", "route_id", "driver_id"} <= _params(
        spec, "get", "/api/v1/admin/trips"
    )
    assert {"latitude", "longitude", "radius_m"} <= _params(spec, "get", "/api/v1/vehicles/nearby")


def test_new_fields_are_documented(spec: dict[str, Any]) -> None:
    assert {"trip", "boarding_stop_name", "alighting_stop_name"} <= _fields(
        spec, "BookingResponse"
    )  # G12
    assert {"target", "code", "token"} <= _fields(spec, "ResetPasswordRequest")  # G1
    assert {"safety", "cleanliness", "professionalism", "timeliness"} <= _fields(
        spec, "RateBookingRequest"
    )  # G13
    assert {"seats_total", "seats_booked", "boarded_count"} <= _fields(
        spec, "TripSummaryResponse"
    )  # G2
