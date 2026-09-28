"""End-to-end smoke test against a running TroSky API.

Exercises the critical path a real client walks: health -> registration ->
login -> authenticated reads -> admin reads. Every request hits the real
Supabase database, so a green run proves the whole stack (config, pooler,
PostGIS, enums, Redis, JWT, RBAC) is actually wired up -- not just importable.

Safe to run repeatedly: each run registers one throwaway passenger whose
phone/email are derived from the current timestamp.

Usage:
    .venv\\Scripts\\python -m scripts.smoke_test
    .venv\\Scripts\\python -m scripts.smoke_test --base-url http://127.0.0.1:8000
    .venv\\Scripts\\python -m scripts.smoke_test --passenger 0245550101:Passenger@2026
"""

from __future__ import annotations

import argparse
import json
import sys
import time
import urllib.error
import urllib.request
from typing import Any

DEFAULT_BASE_URL = "http://127.0.0.1:8000"
DEFAULT_INBOX = "troskynoreply@gmail.com"
ADMIN_PHONE = "+233200000000"
ADMIN_PASSWORD = "TroSkyDevAdmin!2026"  # noqa: S105 - local dev seed credential

_passed = 0
_failed = 0


def call(
    base: str,
    method: str,
    path: str,
    body: dict[str, Any] | None = None,
    token: str | None = None,
    timeout: int = 40,
) -> tuple[int | None, Any]:
    """Return ``(status_code, parsed_body)``; ``(None, {...})`` on transport error."""
    request = urllib.request.Request(base + path, method=method)  # noqa: S310 - local URL
    request.add_header("Content-Type", "application/json")
    if token:
        request.add_header("Authorization", f"Bearer {token}")
    payload = json.dumps(body).encode() if body is not None else None
    try:
        with urllib.request.urlopen(request, payload, timeout=timeout) as response:  # noqa: S310
            return response.status, json.loads(response.read() or b"{}")
    except urllib.error.HTTPError as exc:
        try:
            return exc.code, json.loads(exc.read() or b"{}")
        except json.JSONDecodeError:
            return exc.code, {}
    except Exception as exc:  # transport-level failure, reported as a test failure
        return None, {"transport_error": type(exc).__name__}


def check(label: str, status: int | None, expected: int, detail: str = "") -> bool:
    global _passed, _failed
    ok = status == expected
    if ok:
        _passed += 1
        print(f"  PASS  {label:<42} {status}  {detail}")
    else:
        _failed += 1
        print(f"  FAIL  {label:<42} got {status}, expected {expected}  {detail}")
    return ok


def wait_for_server(base: str, attempts: int = 30) -> bool:
    for _ in range(attempts):
        status, _ = call(base, "GET", "/health/live", timeout=5)
        if status == 200:
            return True
        time.sleep(1)
    return False


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-url", default=DEFAULT_BASE_URL)
    parser.add_argument(
        "--inbox",
        default=DEFAULT_INBOX,
        help="Gmail inbox that receives the throwaway account's code (as a +tag alias).",
    )
    parser.add_argument(
        "--passenger",
        metavar="IDENTIFIER:PASSWORD",
        help="A verified passenger for the signed-in checks. A brand-new account "
        "cannot log in until it enters its emailed code, so without this they are skipped.",
    )
    args = parser.parse_args()
    base = args.base_url.rstrip("/")

    print(f"\nTroSky API smoke test -> {base}\n" + "=" * 70)

    if not wait_for_server(base):
        print(f"\n  Server is not responding at {base}")
        print("  Start it with:  .\\scripts\\dev_up.ps1\n")
        return 1

    # --- infrastructure ------------------------------------------------
    print("\n[1/5] Infrastructure")
    status, body = call(base, "GET", "/health/ready")
    check("GET  /health/ready", status, 200, f"db={body.get('database')} redis={body.get('redis')}")
    if body.get("redis") is False:
        print("\n  Redis is unreachable -- this is the WSL relay quirk, not an app bug.")
        print("  Fix:  .\\scripts\\dev_up.ps1\n")

    status, body = call(base, "GET", "/openapi.json")
    check("GET  /openapi.json", status, 200, f"{len(body.get('paths', {}))} endpoints")

    # --- public reads --------------------------------------------------
    print("\n[2/5] Public endpoints (no auth)")
    status, body = call(base, "GET", "/api/v1/routes")
    check("GET  /api/v1/routes", status, 200, f"{len(body.get('items', []))} seeded routes")

    status, _ = call(base, "GET", "/api/v1/users/me")
    check("GET  /api/v1/users/me (unauthenticated)", status, 401, "correctly rejected")

    # --- registration + login -----------------------------------------
    print("\n[3/5] Registration and login")
    stamp = int(time.time())
    phone = f"+23324{stamp % 10_000_000:07d}"  # always a valid MTN number
    password = "SmokeTest123"  # noqa: S105 - throwaway test account
    # New accounts need a Gmail address. A +tag alias of our own inbox means
    # the verification email this run triggers reaches nobody else.
    user, _, domain = args.inbox.partition("@")
    email = f"{user}+smoke{stamp}@{domain}"

    status, body = call(
        base,
        "POST",
        "/api/v1/auth/register",
        {"phone_number": phone, "email": email, "password": password, "full_name": "Smoke Test"},
    )
    check("POST /api/v1/auth/register", status, 201, email)

    status, body = call(
        base, "POST", "/api/v1/auth/login", {"identifier": phone, "password": password}
    )
    token = body.get("access_token")
    if status == 403 and body.get("error", {}).get("code") == "ACCOUNT_NOT_VERIFIED":
        check("POST /api/v1/auth/login (not yet verified)", status, 403, "must verify first")
    else:
        check("POST /api/v1/auth/login", status, 200, "received JWT" if status == 200 else "")

    if not token and args.passenger:
        identifier, _, passenger_password = args.passenger.partition(":")
        status, body = call(
            base,
            "POST",
            "/api/v1/auth/login",
            {"identifier": identifier, "password": passenger_password},
        )
        check("POST /api/v1/auth/login (verified passenger)", status, 200, identifier)
        token = body.get("access_token")

    status, _ = call(
        base, "POST", "/api/v1/auth/login", {"identifier": phone, "password": "WrongPassword1"}
    )
    check("POST /api/v1/auth/login (bad password)", status, 401, "correctly rejected")

    # --- authenticated passenger surface -------------------------------
    print("\n[4/5] Authenticated passenger endpoints")
    if not token:
        print("  SKIP  no signed-in passenger -- pass --passenger IDENTIFIER:PASSWORD")
    else:
        for path in (
            "/api/v1/users/me",
            "/api/v1/bookings",
            "/api/v1/notifications",
            "/api/v1/wallet",
            "/api/v1/wallet/transactions",
        ):
            status, _ = call(base, "GET", path, token=token)
            check(f"GET  {path}", status, 200)

    # --- admin surface (RBAC) ------------------------------------------
    print("\n[5/5] Admin endpoints (seeded administrator)")
    status, body = call(
        base, "POST", "/api/v1/auth/login", {"identifier": ADMIN_PHONE, "password": ADMIN_PASSWORD}
    )
    check("POST /api/v1/auth/login (admin)", status, 200)
    admin_token = body.get("access_token")

    if token:
        status, _ = call(base, "GET", "/api/v1/admin/users", token=token)
        check("GET  /api/v1/admin/users (as passenger)", status, 403, "RBAC denied")

    if not admin_token:
        print("  SKIP  admin login failed")
    else:
        for path in (
            "/api/v1/admin/users",
            "/api/v1/admin/bookings",
            "/api/v1/admin/drivers/pending",
            "/api/v1/admin/reports/overview",
            "/api/v1/admin/complaints",
            "/api/v1/admin/sos-alerts",
        ):
            status, _ = call(base, "GET", path, token=admin_token)
            check(f"GET  {path}", status, 200)

    # --- summary --------------------------------------------------------
    print("\n" + "=" * 70)
    total = _passed + _failed
    if _failed == 0:
        print(f"ALL {total} CHECKS PASSED -- the backend is working end to end.\n")
        return 0
    print(f"{_failed} of {total} checks FAILED.\n")
    return 1


if __name__ == "__main__":
    sys.exit(main())
