"""Make MTN MoMo sandbox credentials for TroSky from a subscription key.

    python -m scripts.momo_sandbox_setup --subscription-key <key> \\
        --callback-host trosky-api.onrender.com

The subscription key is the "Primary key" of your Collections subscription
on https://momodeveloper.mtn.com (Profile -> Subscriptions). This creates a
sandbox API user (whose callbacks may go to ``--callback-host``) and its API
key through MTN's provisioning API, checks them by asking for a token, and
prints the settings to give the backend (Render: the Environment tab).
The key may also come from MTN_MOMO_SUBSCRIPTION_KEY.

Sandbox only: in production MTN issues the API user and key itself.
"""

from __future__ import annotations

import argparse
import os
import sys
import uuid

import httpx

SANDBOX = "https://sandbox.momodeveloper.mtn.com"


class SetupError(Exception):
    pass


def provision(
    subscription_key: str,
    callback_host: str,
    *,
    base_url: str = SANDBOX,
    transport: httpx.BaseTransport | None = None,
) -> tuple[str, str]:
    """Create an API user and its key; return ``(api_user, api_key)`` once
    MTN has issued a token for them."""
    api_user = str(uuid.uuid4())
    headers = {"Ocp-Apim-Subscription-Key": subscription_key}
    with httpx.Client(base_url=base_url, timeout=30, transport=transport) as client:
        created = client.post(
            "/v1_0/apiuser",
            headers={**headers, "X-Reference-Id": api_user},
            json={"providerCallbackHost": callback_host},
        )
        if created.status_code != 201:
            raise SetupError(_why("Creating the API user", created))
        issued = client.post(f"/v1_0/apiuser/{api_user}/apikey", headers=headers)
        if issued.status_code != 201:
            raise SetupError(_why("Creating its API key", issued))
        api_key = str(issued.json()["apiKey"])
        token = client.post("/collection/token/", headers=headers, auth=(api_user, api_key))
        if token.status_code != 200:
            raise SetupError(_why("Checking them (a Collections token)", token))
    return api_user, api_key


def _why(step: str, response: httpx.Response) -> str:
    hint = ""
    if response.status_code == 401:
        hint = " Is this the Primary key of a Collections subscription?"
    return f"{step} failed: HTTP {response.status_code} {response.text[:200]}.{hint}"


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument(
        "--subscription-key", default=os.environ.get("MTN_MOMO_SUBSCRIPTION_KEY", "")
    )
    parser.add_argument(
        "--callback-host",
        required=True,
        help="The backend's host name, e.g. trosky-api.onrender.com (no https://).",
    )
    parser.add_argument("--base-url", default=SANDBOX)
    args = parser.parse_args(argv)
    if not args.subscription_key:
        parser.error("Give --subscription-key, or set MTN_MOMO_SUBSCRIPTION_KEY.")
    host = args.callback_host.removeprefix("https://").removeprefix("http://").strip("/")

    try:
        api_user, api_key = provision(args.subscription_key, host, base_url=args.base_url)
    except (SetupError, httpx.HTTPError) as error:
        sys.exit(str(error))

    print("Sandbox credentials made and checked. Give the backend these settings:\n")
    print("PAYMENTS_ACTIVE_PROVIDER=mtn_momo")
    print(f"PAYMENTS_MTN_MOMO_BASE_URL={args.base_url}")
    print("PAYMENTS_MTN_MOMO_TARGET_ENVIRONMENT=sandbox")
    print("PAYMENTS_MTN_MOMO_CURRENCY=EUR")
    print(f"PAYMENTS_MTN_MOMO_CALLBACK_URL=https://{host}/api/v1/payments/webhooks/mtn_momo")
    print(f"PAYMENTS_MTN_MOMO_SUBSCRIPTION_KEY={args.subscription_key}")
    print(f"PAYMENTS_MTN_MOMO_API_KEY={api_user}")
    print(f"PAYMENTS_MTN_MOMO_API_SECRET={api_key}")
    print("\nThe last three are secrets: the Environment tab, never render.yaml or git.")


if __name__ == "__main__":
    main()
