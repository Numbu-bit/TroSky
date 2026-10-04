"""SMTP connections are kept and reused: a verification code should not wait
for a connect, STARTTLS and login (~1.5 s to Gmail) on every send. Checked
against a fake mail server that counts what it is asked to do."""

from __future__ import annotations

import smtplib
from collections.abc import Iterator

import pytest

from app.core.config import Settings
from app.core.exceptions import ProviderError
from app.providers.email import smtp as smtp_module
from app.providers.email.smtp import SmtpEmailProvider


class FakeServer:
    """What the fake connections did, between them."""

    def __init__(self) -> None:
        self.connections: list[FakeConnection] = []
        self.sent: list[str] = []


class FakeConnection:
    server: FakeServer

    def __init__(self, host: str, port: int, timeout: float) -> None:
        self.logins = 0
        self.hung_up = False
        self.refuses: set[str] = set()
        self.server.connections.append(self)

    def starttls(self) -> None:
        pass

    def login(self, username: str, password: str) -> None:
        self.logins += 1

    def noop(self) -> tuple[int, bytes]:
        if self.hung_up:
            raise smtplib.SMTPServerDisconnected("Connection unexpectedly closed")
        return 250, b"OK"

    def sendmail(self, sender: str, recipients: list[str], message: str) -> dict[str, object]:
        if self.hung_up:
            raise smtplib.SMTPServerDisconnected("Connection unexpectedly closed")
        if recipients[0] in self.refuses:
            raise smtplib.SMTPRecipientsRefused({recipients[0]: (550, b"No such user")})
        self.server.sent.append(recipients[0])
        return {}

    def quit(self) -> None:
        pass

    def close(self) -> None:
        pass


@pytest.fixture
def server(monkeypatch: pytest.MonkeyPatch) -> Iterator[FakeServer]:
    fake = FakeServer()
    FakeConnection.server = fake
    monkeypatch.setattr(smtp_module.smtplib, "SMTP", FakeConnection)
    smtp_module._pools.clear()
    yield fake
    smtp_module._pools.clear()


def _settings() -> Settings:
    return Settings(
        EMAIL_SMTP_HOST="smtp.example.com",
        EMAIL_SMTP_PORT=587,
        EMAIL_SMTP_USERNAME="trosky@example.com",
        EMAIL_SMTP_PASSWORD="app-password",  # type: ignore[arg-type]
        EMAIL_SMTP_USE_TLS=True,
    )


async def test_one_login_for_many_messages(server: FakeServer) -> None:
    for to in ("ama@example.com", "kofi@example.com", "esi@example.com"):
        await SmtpEmailProvider(_settings()).send_email(to, "Your code", "123456")

    assert server.sent == ["ama@example.com", "kofi@example.com", "esi@example.com"]
    assert len(server.connections) == 1
    assert server.connections[0].logins == 1


async def test_a_connection_the_server_closed_is_replaced(server: FakeServer) -> None:
    provider = SmtpEmailProvider(_settings())
    await provider.send_email("ama@example.com", "Your code", "123456")
    server.connections[0].hung_up = True  # idle too long, say

    await provider.send_email("kofi@example.com", "Your code", "654321")

    assert server.sent == ["ama@example.com", "kofi@example.com"]
    assert len(server.connections) == 2


async def test_a_refused_address_is_not_retried(server: FakeServer) -> None:
    provider = SmtpEmailProvider(_settings())
    await provider.send_email("ama@example.com", "Your code", "123456")
    server.connections[0].refuses.add("nobody@example.com")

    with pytest.raises(ProviderError):
        await provider.send_email("nobody@example.com", "Your code", "123456")

    assert len(server.connections) == 1  # no second attempt


async def test_kept_warm_before_the_first_message(server: FakeServer) -> None:
    pool = smtp_module._pool_for(_settings())

    pool.keep_warm()  # at start-up: nothing open yet, so one is
    await SmtpEmailProvider(_settings()).send_email("ama@example.com", "Your code", "123456")

    assert len(server.connections) == 1
    assert server.sent == ["ama@example.com"]


async def test_a_dead_idle_connection_is_dropped_and_replaced(server: FakeServer) -> None:
    pool = smtp_module._pool_for(_settings())
    pool.keep_warm()
    server.connections[0].hung_up = True

    pool.keep_warm()

    assert len(server.connections) == 2
    await SmtpEmailProvider(_settings()).send_email("ama@example.com", "Your code", "123456")
    assert server.sent == ["ama@example.com"]
    assert len(server.connections) == 2  # the fresh one was used


async def test_an_old_idle_connection_is_checked_first(
    server: FakeServer, monkeypatch: pytest.MonkeyPatch
) -> None:
    provider = SmtpEmailProvider(_settings())
    await provider.send_email("ama@example.com", "Your code", "123456")
    server.connections[0].hung_up = True
    monkeypatch.setattr(smtp_module, "MAX_IDLE_SECONDS", -1)  # everything is old

    await provider.send_email("kofi@example.com", "Your code", "654321")

    assert server.sent == ["ama@example.com", "kofi@example.com"]
    assert len(server.connections) == 2
