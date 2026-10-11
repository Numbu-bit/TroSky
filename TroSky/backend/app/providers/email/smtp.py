"""SMTP email provider.

Uses the standard SMTP protocol (RFC 5321), so this single adapter is
genuinely production-capable against MailHog locally *and* against any real
SMTP relay in production (Amazon SES's SMTP interface, SendGrid, Postmark,
Mailgun, etc.) — no vendor-specific API guessing required.

Connections are kept open and reused. Opening one -- connect, STARTTLS,
login -- takes about 1.5 s to Gmail from Accra, three times as long as
sending a message on one already open, and every verification code waits on
it. Idle connections are kept alive with NOOP (``keep_smtp_warm``, run by the
app for as long as it is up); one the server has closed meanwhile is
replaced, once, transparently.

# PRODUCTION CREDENTIALS REQUIRED
Set EMAIL_SMTP_HOST / EMAIL_SMTP_PORT / EMAIL_SMTP_USERNAME /
EMAIL_SMTP_PASSWORD / EMAIL_SMTP_USE_TLS to your provider's SMTP relay
credentials.
"""

from __future__ import annotations

import asyncio
import smtplib
import threading
import time
import uuid
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

from app.core.config import Settings
from app.core.exceptions import ProviderError
from app.core.logging import get_logger
from app.providers.email.base import EmailSendResult

logger = get_logger(__name__)

# Open connections kept per server, beyond what is sending right now.
MAX_IDLE_CONNECTIONS = 2
# An idle connection older than this is not trusted without a NOOP first.
MAX_IDLE_SECONDS = 50


def _close(client: smtplib.SMTP) -> None:
    try:
        client.quit()
    except (OSError, smtplib.SMTPException):
        client.close()


def _server_hung_up(exc: Exception) -> bool:
    """A kept connection the server has since closed: worth one retry on a
    fresh connection. (Not a refused recipient or a bad login.)"""
    if isinstance(exc, smtplib.SMTPServerDisconnected | ConnectionError):
        return True
    return isinstance(exc, smtplib.SMTPResponseException) and exc.smtp_code == 421


class _Pool:
    """Logged-in connections to one server, for reuse across sends."""

    def __init__(self, host: str, port: int, username: str, password: str, use_tls: bool):
        self._host, self._port = host, port
        self._username, self._password = username, password
        self._use_tls = use_tls
        self._idle: list[tuple[smtplib.SMTP, float]] = []
        self._lock = threading.Lock()

    def connect(self) -> smtplib.SMTP:
        client = smtplib.SMTP(self._host, self._port, timeout=10)
        try:
            if self._use_tls:
                client.starttls()
            if self._username and self._password:
                client.login(self._username, self._password)
        except BaseException:
            client.close()
            raise
        return client

    def take(self) -> tuple[smtplib.SMTP, bool]:
        """A connection to send on, and whether it was kept from before."""
        with self._lock:
            kept = self._idle.pop() if self._idle else None
        if kept is not None:
            client, last_used = kept
            if time.monotonic() - last_used < MAX_IDLE_SECONDS or self._alive(client):
                return client, True
            _close(client)
        return self.connect(), False

    def give_back(self, client: smtplib.SMTP) -> None:
        with self._lock:
            if len(self._idle) < MAX_IDLE_CONNECTIONS:
                self._idle.append((client, time.monotonic()))
                return
        _close(client)

    @staticmethod
    def _alive(client: smtplib.SMTP) -> bool:
        try:
            return client.noop()[0] == 250
        except (OSError, smtplib.SMTPException):
            return False

    def keep_warm(self) -> None:
        """NOOP every idle connection (dropping the dead), and open one if
        none is left, so the next message need not wait for a login."""
        with self._lock:
            idle, self._idle = self._idle, []
        alive = []
        for client, _ in idle:
            if self._alive(client):
                alive.append((client, time.monotonic()))
            else:
                _close(client)
        if not alive:
            try:
                alive.append((self.connect(), time.monotonic()))
            except (OSError, smtplib.SMTPException) as exc:
                logger.warning("smtp_warm_up_failed", error=str(exc))
        with self._lock:
            self._idle.extend(alive)
            surplus = self._idle[MAX_IDLE_CONNECTIONS:]
            del self._idle[MAX_IDLE_CONNECTIONS:]
        for client, _ in surplus:
            _close(client)

    def close_all(self) -> None:
        with self._lock:
            idle, self._idle = self._idle, []
        for client, _ in idle:
            _close(client)


_pools: dict[tuple[str, int, str, bool], _Pool] = {}
_pools_lock = threading.Lock()


def _pool_for(settings: Settings) -> _Pool:
    key = (
        settings.EMAIL_SMTP_HOST,
        settings.EMAIL_SMTP_PORT,
        settings.EMAIL_SMTP_USERNAME,
        settings.EMAIL_SMTP_USE_TLS,
    )
    with _pools_lock:
        pool = _pools.get(key)
        if pool is None:
            pool = _pools[key] = _Pool(
                settings.EMAIL_SMTP_HOST,
                settings.EMAIL_SMTP_PORT,
                settings.EMAIL_SMTP_USERNAME,
                settings.EMAIL_SMTP_PASSWORD.get_secret_value(),
                settings.EMAIL_SMTP_USE_TLS,
            )
        return pool


async def keep_smtp_warm(settings: Settings, *, every_seconds: float) -> None:
    """Run for as long as the app is up: a logged-in connection is open
    before the first message, and kept from going stale between messages."""
    pool = _pool_for(settings)
    try:
        while True:
            await asyncio.to_thread(pool.keep_warm)
            await asyncio.sleep(every_seconds)
    finally:
        await asyncio.to_thread(pool.close_all)


class SmtpEmailProvider:
    def __init__(self, settings: Settings) -> None:
        self._pool = _pool_for(settings)
        self._from_address = settings.EMAIL_FROM_ADDRESS

    def _send_sync(self, to: str, subject: str, body_text: str, body_html: str | None) -> str:
        message: MIMEMultipart | MIMEText
        if body_html:
            message = MIMEMultipart("alternative")
            message.attach(MIMEText(body_text, "plain", "utf-8"))
            message.attach(MIMEText(body_html, "html", "utf-8"))
        else:
            message = MIMEText(body_text, "plain", "utf-8")
        message["Subject"] = subject
        message["From"] = self._from_address
        message["To"] = to
        message_id = f"<{uuid.uuid4().hex}@trosky.africa>"
        message["Message-ID"] = message_id
        payload = message.as_string()

        client, kept = self._pool.take()
        try:
            client.sendmail(self._from_address, [to], payload)
        except (OSError, smtplib.SMTPException) as exc:
            _close(client)
            if not (kept and _server_hung_up(exc)):
                raise
            # The server closed the kept connection meanwhile: once more, fresh.
            client = self._pool.connect()
            try:
                client.sendmail(self._from_address, [to], payload)
            except BaseException:
                _close(client)
                raise
        self._pool.give_back(client)
        return message_id

    async def send_email(
        self, to: str, subject: str, body_text: str, body_html: str | None = None
    ) -> EmailSendResult:
        try:
            message_id = await asyncio.to_thread(self._send_sync, to, subject, body_text, body_html)
        except (OSError, smtplib.SMTPException) as exc:
            logger.error("smtp_send_failed", to=to, error=str(exc))
            raise ProviderError("Failed to send email via SMTP.") from exc
        return EmailSendResult(success=True, provider_reference=message_id)
