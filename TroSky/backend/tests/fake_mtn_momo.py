"""A stand-in for MTN MoMo's sandbox (Collections): token, request-to-pay
and status, as it answers them. Shared by the adapter and payment tests."""

from __future__ import annotations

import json

import httpx


class FakeMtn:
    """Token, request-to-pay and status, as the sandbox answers them."""

    def __init__(self) -> None:
        self.requests: list[httpx.Request] = []
        self.tokens_issued = 0
        self.payments: dict[str, dict[str, object]] = {}

    def __call__(self, request: httpx.Request) -> httpx.Response:
        self.requests.append(request)
        path = request.url.path
        if path == "/collection/token/":
            self.tokens_issued += 1
            return httpx.Response(200, json={"access_token": "token-1", "expires_in": 3600})
        if path == "/collection/v1_0/requesttopay":
            reference = request.headers["X-Reference-Id"]
            if reference in self.payments:
                return httpx.Response(409, json={"code": "RESOURCE_ALREADY_EXIST"})
            self.payments[reference] = {**json.loads(request.content), "status": "PENDING"}
            return httpx.Response(202)
        reference = path.rsplit("/", 1)[-1]
        if reference not in self.payments:
            return httpx.Response(404, json={"code": "RESOURCE_NOT_FOUND"})
        return httpx.Response(200, json=self.payments[reference])
