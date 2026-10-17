"""The Gmail refresh-token script's parts that don't need a browser: PKCE,
the consent link, and trading the code for tokens."""

from __future__ import annotations

import base64
import hashlib
import threading
from urllib.parse import parse_qs, urlparse

import httpx
import pytest
from scripts.gmail_refresh_token import (
    AUTH_URL,
    SCOPE,
    SetupError,
    _Callback,
    _CallbackServer,
    _wait_for_redirect,
    consent_url,
    exchange_code,
    pkce_pair,
)

_REDIRECT = "http://127.0.0.1:53682"


def test_the_pkce_challenge_is_the_s256_of_the_verifier() -> None:
    verifier, challenge = pkce_pair()

    assert 43 <= len(verifier) <= 128
    digest = hashlib.sha256(verifier.encode("ascii")).digest()
    assert challenge == base64.urlsafe_b64encode(digest).decode("ascii").rstrip("=")


def test_the_consent_link_asks_only_to_send_mail_and_for_a_refresh_token() -> None:
    url = urlparse(consent_url("client-1", _REDIRECT, "state-1", "challenge-1"))

    assert f"{url.scheme}://{url.netloc}{url.path}" == AUTH_URL
    assert parse_qs(url.query) == {
        "client_id": ["client-1"],
        "redirect_uri": [_REDIRECT],
        "response_type": ["code"],
        "scope": [SCOPE],
        "access_type": ["offline"],
        "prompt": ["consent"],
        "state": ["state-1"],
        "code_challenge": ["challenge-1"],
        "code_challenge_method": ["S256"],
    }


def _google(status: int, body: object, seen: list[httpx.Request]) -> httpx.MockTransport:
    def answer(request: httpx.Request) -> httpx.Response:
        seen.append(request)
        return httpx.Response(status, json=body)

    return httpx.MockTransport(answer)


def test_the_code_is_traded_for_the_refresh_token() -> None:
    seen: list[httpx.Request] = []
    transport = _google(200, {"access_token": "at", "refresh_token": "1//rt", "scope": SCOPE}, seen)

    token = exchange_code(
        "client-1", "secret-1", "code-1", "verifier-1", _REDIRECT, transport=transport
    )

    assert token == "1//rt"
    [request] = seen
    assert parse_qs(request.content.decode()) == {
        "client_id": ["client-1"],
        "client_secret": ["secret-1"],
        "code": ["code-1"],
        "code_verifier": ["verifier-1"],
        "grant_type": ["authorization_code"],
        "redirect_uri": [_REDIRECT],
    }


def test_send_permission_left_unticked_is_refused() -> None:
    transport = _google(200, {"access_token": "at", "refresh_token": "1//rt", "scope": ""}, [])

    with pytest.raises(SetupError, match="Send email on your behalf"):
        exchange_code(
            "client-1", "secret-1", "code-1", "verifier-1", _REDIRECT, transport=transport
        )


def test_googles_refusal_is_reported() -> None:
    body = {"error": "invalid_grant", "error_description": "Malformed auth code."}
    transport = _google(400, body, [])

    with pytest.raises(SetupError, match="HTTP 400.*invalid_grant: Malformed auth code"):
        exchange_code(
            "client-1", "secret-1", "code-1", "verifier-1", _REDIRECT, transport=transport
        )


def _browser(port: int, query: str) -> threading.Thread:
    """What the browser does after Google's page: a favicon request, then
    the redirect carrying the answer."""

    def visit() -> None:
        httpx.get(f"http://127.0.0.1:{port}/favicon.ico", timeout=5)
        httpx.get(f"http://127.0.0.1:{port}/?{query}", timeout=5)

    thread = threading.Thread(target=visit)
    thread.start()
    return thread


def test_the_redirect_back_to_this_machine_is_caught() -> None:
    server = _CallbackServer(("127.0.0.1", 0), _Callback)
    browser = _browser(server.server_address[1], "state=state-1&code=code-1")

    with server:
        assert _wait_for_redirect(server, "state-1") == "code-1"
    browser.join()


def test_an_answer_for_another_request_is_refused() -> None:
    server = _CallbackServer(("127.0.0.1", 0), _Callback)
    browser = _browser(server.server_address[1], "state=forged&code=code-1")

    with server, pytest.raises(SetupError, match="didn't match"):
        _wait_for_redirect(server, "state-1")
    browser.join()
