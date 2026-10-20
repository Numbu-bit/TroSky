"""Making MTN MoMo sandbox credentials from a subscription key."""

from __future__ import annotations

import json
import uuid

import httpx
import pytest
from scripts.momo_sandbox_setup import SetupError, provision


class FakeProvisioning:
    def __init__(self, *, key: str = "sub-key") -> None:
        self.key = key
        self.users: dict[str, dict[str, str]] = {}

    def __call__(self, request: httpx.Request) -> httpx.Response:
        if request.headers.get("Ocp-Apim-Subscription-Key") != self.key:
            return httpx.Response(401, json={"message": "Access denied due to invalid key."})
        path = request.url.path
        if path == "/v1_0/apiuser":
            user = request.headers["X-Reference-Id"]
            self.users[user] = {"host": json.loads(request.content)["providerCallbackHost"]}
            return httpx.Response(201)
        if path.endswith("/apikey"):
            user = path.split("/")[3]
            self.users[user]["key"] = f"key-for-{user[:8]}"
            return httpx.Response(201, json={"apiKey": self.users[user]["key"]})
        if path == "/collection/token/":
            known = any(
                request.headers["Authorization"] == httpx.BasicAuth(u, d["key"])._auth_header
                for u, d in self.users.items()
            )
            return httpx.Response(200 if known else 401, json={"access_token": "t"})
        return httpx.Response(404)


def test_it_makes_an_api_user_and_key_that_get_a_token() -> None:
    mtn = FakeProvisioning()

    api_user, api_key = provision(
        "sub-key", "trosky-api.onrender.com", transport=httpx.MockTransport(mtn)
    )

    assert uuid.UUID(api_user).version == 4
    assert mtn.users[api_user] == {"host": "trosky-api.onrender.com", "key": api_key}


def test_a_wrong_key_says_what_to_check() -> None:
    mtn = FakeProvisioning(key="the-right-one")
    with pytest.raises(SetupError, match="HTTP 401.*Primary key of a Collections subscription"):
        provision("wrong", "trosky-api.onrender.com", transport=httpx.MockTransport(mtn))
