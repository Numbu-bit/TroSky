"""Every protected route must declare the bearer token in the OpenAPI
document. Swagger's Authorize only sends the token to operations that
declare it, so an undeclared one answers 401 even for a logged-in admin."""

from __future__ import annotations

from typing import Any

from app.main import create_app

PUBLIC = {
    ("get", "/health/live"),
    ("get", "/health/ready"),
    ("get", "/health/details"),
    ("post", "/api/v1/auth/register"),
    ("post", "/api/v1/auth/verify-otp"),
    ("post", "/api/v1/auth/resend-otp"),
    ("post", "/api/v1/auth/login"),
    ("post", "/api/v1/auth/otp-login"),
    ("post", "/api/v1/auth/refresh"),
    ("post", "/api/v1/auth/password/forgot"),
    ("post", "/api/v1/auth/password/reset"),
    ("get", "/api/v1/stops"),
    ("get", "/api/v1/stops/nearby"),
    ("get", "/api/v1/routes"),
    ("get", "/api/v1/routes/{route_id}"),
    ("get", "/api/v1/trips/search"),
    ("get", "/api/v1/trips/{trip_id}"),
    ("get", "/api/v1/trips/{trip_id}/seats"),
    ("post", "/api/v1/payments/webhooks/{channel}"),
}


def _operations() -> dict[tuple[str, str], dict[str, Any]]:
    spec = create_app().openapi()
    return {
        (method, path): operation
        for path, operations in spec["paths"].items()
        for method, operation in operations.items()
    }


def test_every_protected_route_declares_the_bearer_token() -> None:
    undeclared = sorted(
        f"{method.upper()} {path}"
        for (method, path), operation in _operations().items()
        if (method, path) not in PUBLIC and not operation.get("security")
    )
    assert undeclared == []


def test_admin_routes_use_the_same_scheme_as_everything_else() -> None:
    operations = _operations()
    admin = [op for (_, path), op in operations.items() if path.startswith("/api/v1/admin/")]
    assert admin
    assert all(op["security"] == [{"HTTPBearer": []}] for op in admin)


def test_the_public_list_is_not_stale() -> None:
    operations = _operations()
    for key in PUBLIC:
        assert key in operations, key
        assert not operations[key].get("security"), key
