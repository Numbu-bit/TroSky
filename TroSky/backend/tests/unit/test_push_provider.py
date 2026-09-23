"""Unit tests for the sandbox push provider and factory selection (pure
logic, no network, no database)."""

from __future__ import annotations

import pytest

from app.core.config import Settings
from app.providers.push.factory import get_push_provider
from app.providers.push.sandbox import SandboxPushProvider


@pytest.fixture(autouse=True)
def _clear_sandbox():
    SandboxPushProvider.clear()
    yield
    SandboxPushProvider.clear()


class TestSandboxPushProvider:
    async def test_send_records_in_outbox(self) -> None:
        provider = SandboxPushProvider()
        result = await provider.send(token="device-1", title="Hello", body="World", data={"k": "v"})
        assert result.success is True
        sent = SandboxPushProvider.get_sent("device-1")
        assert len(sent) == 1
        assert sent[0]["title"] == "Hello"
        assert sent[0]["data"] == {"k": "v"}

    async def test_clear_empties_outbox(self) -> None:
        provider = SandboxPushProvider()
        await provider.send(token="device-1", title="x", body="y", data={})
        SandboxPushProvider.clear()
        assert SandboxPushProvider.get_sent("device-1") == []


class TestPushProviderFactory:
    def _settings(self, *, firebase_enabled: bool) -> Settings:
        return Settings(
            SECRET_KEY="x" * 32,
            DATABASE_URL="postgresql+asyncpg://u:p@localhost/db",
            DATABASE_URL_SYNC="postgresql://u:p@localhost/db",
            PAYMENTS_WEBHOOK_SIGNING_SECRET="webhook-secret-value",
            TICKET_QR_SIGNING_SECRET="y" * 32,
            FIREBASE_ENABLED=firebase_enabled,
        )  # type: ignore[call-arg]

    def test_defaults_to_sandbox_when_firebase_disabled(self) -> None:
        provider = get_push_provider(self._settings(firebase_enabled=False))
        assert isinstance(provider, SandboxPushProvider)
