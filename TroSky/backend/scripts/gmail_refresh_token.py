"""Make the Gmail refresh token the backend sends verification codes with.

    python -m scripts.gmail_refresh_token --client-id <id> --test-to you@gmail.com

The client ID and secret are those of the "Desktop app" OAuth client made in
Google Cloud for TroSky's sending account (docs/deploy-render.md, "Sending
real email"). They may also come from GMAIL_CLIENT_ID and GMAIL_CLIENT_SECRET;
the secret is asked for if neither gives it.

This opens Google's consent page in the browser: sign in as the sending
account (troskynoreply@gmail.com) and allow "Send email on your behalf".
Google sends the browser back to a one-off server on this machine
(127.0.0.1), the code is traded for tokens, and the refresh token is printed
for the backend (Render: the service's Environment tab). It lets anyone send
mail as the account: never put it in git or a chat.

With --test-to, one email goes to that address through the new token, the
way the backend will send codes.
"""

from __future__ import annotations

import argparse
import asyncio
import base64
import getpass
import hashlib
import os
import secrets
import sys
import time
import webbrowser
from email.utils import formataddr
from http.server import BaseHTTPRequestHandler, HTTPServer
from typing import Any, cast
from urllib.parse import parse_qs, urlencode, urlparse

import httpx

from app.providers.email.gmail_api import TOKEN_URL, GmailApiEmailProvider

AUTH_URL = "https://accounts.google.com/o/oauth2/v2/auth"
SCOPE = "https://www.googleapis.com/auth/gmail.send"
DEFAULT_SENDER = "troskynoreply@gmail.com"
_WAIT_SECONDS = 300

_DONE_PAGE = (
    b"<!doctype html><meta charset=utf-8><title>TroSky</title>"
    b"<p style='font:16px sans-serif'>Done. You can close this tab and go back to the terminal."
)


class SetupError(Exception):
    pass


def pkce_pair() -> tuple[str, str]:
    """``(verifier, challenge)`` for PKCE with S256 (RFC 7636)."""
    verifier = secrets.token_urlsafe(64)
    digest = hashlib.sha256(verifier.encode("ascii")).digest()
    challenge = base64.urlsafe_b64encode(digest).decode("ascii").rstrip("=")
    return verifier, challenge


def consent_url(client_id: str, redirect_uri: str, state: str, challenge: str) -> str:
    """Google's consent page, asking to send mail only, with a refresh token
    (``access_type=offline``) issued even if the account allowed it before
    (``prompt=consent``)."""
    query = {
        "client_id": client_id,
        "redirect_uri": redirect_uri,
        "response_type": "code",
        "scope": SCOPE,
        "access_type": "offline",
        "prompt": "consent",
        "state": state,
        "code_challenge": challenge,
        "code_challenge_method": "S256",
    }
    return f"{AUTH_URL}?{urlencode(query)}"


def exchange_code(
    client_id: str,
    client_secret: str,
    code: str,
    verifier: str,
    redirect_uri: str,
    *,
    transport: httpx.BaseTransport | None = None,
) -> str:
    """Trade the consent page's code for tokens; return the refresh token."""
    with httpx.Client(timeout=30, transport=transport) as client:
        response = client.post(
            TOKEN_URL,
            data={
                "client_id": client_id,
                "client_secret": client_secret,
                "code": code,
                "code_verifier": verifier,
                "grant_type": "authorization_code",
                "redirect_uri": redirect_uri,
            },
        )
    try:
        body = response.json()
    except ValueError:
        body = {}
    if not response.is_success:
        raise SetupError(
            f"Google refused the code (HTTP {response.status_code}): "
            f"{body.get('error')}: {body.get('error_description')}"
        )
    if SCOPE not in str(body.get("scope", "")).split():
        raise SetupError(
            "Permission to send email wasn't given. Run this again and tick \"Send email on "
            "your behalf\" on Google's page."
        )
    refresh_token = body.get("refresh_token")
    if not refresh_token:
        raise SetupError("Google sent no refresh token. Run this again.")
    return str(refresh_token)


class _CallbackServer(HTTPServer):
    params: dict[str, str] | None = None


class _Callback(BaseHTTPRequestHandler):
    def do_GET(self) -> None:  # noqa: N802 - BaseHTTPRequestHandler's name for it
        params = {key: values[0] for key, values in parse_qs(urlparse(self.path).query).items()}
        if "code" not in params and "error" not in params:
            self.send_response(404)  # the browser's favicon request, say
            self.end_headers()
            return
        cast(_CallbackServer, self.server).params = params
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.end_headers()
        self.wfile.write(_DONE_PAGE)

    def log_message(self, format: str, *args: Any) -> None:  # noqa: A002 - stdlib signature
        pass  # keep the terminal for the instructions


def _wait_for_redirect(server: _CallbackServer, state: str) -> str:
    server.timeout = 1
    deadline = time.monotonic() + _WAIT_SECONDS
    while server.params is None:
        if time.monotonic() > deadline:
            raise SetupError("No answer from Google's page within 5 minutes.")
        server.handle_request()
    params = server.params
    if params.get("state") != state:
        raise SetupError("The answer from the browser didn't match this request. Run this again.")
    if "error" in params:
        raise SetupError(f"Google's page ended with: {params['error']}")
    return params["code"]


def _parse_args(argv: list[str] | None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Make the Gmail refresh token for EMAIL_PROVIDER=gmail_api."
    )
    parser.add_argument("--client-id", default=os.environ.get("GMAIL_CLIENT_ID", ""))
    parser.add_argument("--client-secret", default=os.environ.get("GMAIL_CLIENT_SECRET", ""))
    parser.add_argument("--test-to", help="Send one test email to this address.")
    parser.add_argument(
        "--from-address",
        default=os.environ.get("EMAIL_FROM_ADDRESS") or DEFAULT_SENDER,
        help="The sending Gmail address, for the test email (default: %(default)s).",
    )
    parser.add_argument(
        "--no-browser", action="store_true", help="Print the consent page's link only."
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = _parse_args(argv)
    client_id = args.client_id.strip()
    if not client_id:
        print("Give --client-id (or set GMAIL_CLIENT_ID).", file=sys.stderr)
        return 2
    client_secret = args.client_secret.strip() or getpass.getpass("OAuth client secret: ").strip()

    server = _CallbackServer(("127.0.0.1", 0), _Callback)
    redirect_uri = f"http://127.0.0.1:{server.server_address[1]}"
    verifier, challenge = pkce_pair()
    state = secrets.token_urlsafe(16)
    url = consent_url(client_id, redirect_uri, state, challenge)
    print("Sign in as the sending account and allow 'Send email on your behalf':")
    print(f"  {url}\n")
    if not args.no_browser:
        webbrowser.open(url)

    try:
        with server:
            code = _wait_for_redirect(server, state)
        refresh_token = exchange_code(client_id, client_secret, code, verifier, redirect_uri)
    except (SetupError, httpx.HTTPError) as exc:
        print(f"Failed: {exc}", file=sys.stderr)
        return 1

    if args.test_to:
        provider = GmailApiEmailProvider(
            client_id=client_id,
            client_secret=client_secret,
            refresh_token=refresh_token,
            sender=formataddr(("TroSky", args.from_address)),
        )
        result = asyncio.run(
            provider.send_email(
                args.test_to,
                "TroSky: Gmail sending works",
                "This is a test from scripts/gmail_refresh_token.py. Verification codes "
                "will arrive like this.",
            )
        )
        if not result.success:
            print(f"The test email failed: {result.error}", file=sys.stderr)
            return 1
        print(f"Test email sent to {args.test_to}.\n")

    print("Give the backend these settings (Render: the service's Environment tab;")
    print("this machine: .env, which git ignores):\n")
    print("  EMAIL_PROVIDER=gmail_api")
    print(f"  EMAIL_FROM_ADDRESS={args.from_address}")
    print(f"  GMAIL_CLIENT_ID={client_id}")
    print("  GMAIL_CLIENT_SECRET=<the client secret you used>")
    print(f"  GMAIL_REFRESH_TOKEN={refresh_token}\n")
    print("The refresh token lets anyone send mail as the account: never put it in git or a chat.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
