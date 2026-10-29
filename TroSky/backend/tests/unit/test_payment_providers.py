"""Unit tests for payment provider adapters: sandbox behavior, MTN MoMo's
signature verification / status mapping, and provider factory resolution —
all pure logic, no network call and no database required."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from decimal import Decimal

import pytest

from app.core.config import AppEnv, PaymentProviderName, Settings
from app.core.exceptions import ProviderError
from app.providers.payments.base import PaymentChannel, PaymentProviderStatus
from app.providers.payments.factory import get_payment_provider
from app.providers.payments.mtn_momo import MtnMomoPaymentProvider
from app.providers.payments.sandbox import SandboxPaymentProvider
from app.providers.payments.unavailable import UnavailablePaymentProvider


@pytest.fixture(autouse=True)
def _clear_sandbox():
    SandboxPaymentProvider.clear()
    yield
    SandboxPaymentProvider.clear()


class TestSandboxPaymentProvider:
    async def test_initialize_payment_is_pending_by_default(self) -> None:
        provider = SandboxPaymentProvider()
        result = await provider.initialize_payment(
            reference="PAY-1",
            amount=Decimal("10.00"),
            currency="GHS",
            payer_phone="0244000001",
            narration="test",
        )
        assert result.status == PaymentProviderStatus.PENDING

    async def test_initialize_payment_declines_magic_suffix(self) -> None:
        provider = SandboxPaymentProvider()
        result = await provider.initialize_payment(
            reference="PAY-2",
            amount=Decimal("10.00"),
            currency="GHS",
            payer_phone="0244000000",
            narration="test",
        )
        # Accepted, then declined at the first status check.
        assert result.status == PaymentProviderStatus.PENDING
        status = await provider.query_payment(result.provider_reference)
        assert status.status == PaymentProviderStatus.FAILED

    async def test_query_payment_reflects_resolved_state(self) -> None:
        provider = SandboxPaymentProvider()
        await provider.initialize_payment(
            reference="PAY-3",
            amount=Decimal("5.00"),
            currency="GHS",
            payer_phone="0200000001",
            narration="",
        )
        SandboxPaymentProvider.resolve("PAY-3", PaymentProviderStatus.SUCCESSFUL)
        status = await provider.query_payment("PAY-3")
        assert status.status == PaymentProviderStatus.SUCCESSFUL

    async def test_query_unknown_reference_is_failed(self) -> None:
        provider = SandboxPaymentProvider()
        status = await provider.query_payment("does-not-exist")
        assert status.status == PaymentProviderStatus.FAILED

    async def test_refund_succeeds_for_known_reference(self) -> None:
        provider = SandboxPaymentProvider()
        await provider.initialize_payment(
            reference="PAY-4",
            amount=Decimal("5.00"),
            currency="GHS",
            payer_phone="0200000001",
            narration="",
        )
        result = await provider.refund(
            provider_reference="PAY-4", amount=Decimal("5.00"), reason="test"
        )
        assert result.success is True

    async def test_simulate_webhook_payload_roundtrips_through_parse(self) -> None:
        provider = SandboxPaymentProvider()
        await provider.initialize_payment(
            reference="PAY-5",
            amount=Decimal("5.00"),
            currency="GHS",
            payer_phone="0200000001",
            narration="",
        )
        payload = SandboxPaymentProvider.simulate_webhook_payload(
            "PAY-5", PaymentProviderStatus.SUCCESSFUL
        )
        event = provider.parse_webhook_event({}, payload)
        assert event.provider_reference == "PAY-5"
        assert event.status == PaymentProviderStatus.SUCCESSFUL

    async def test_verify_webhook_signature_always_true(self) -> None:
        provider = SandboxPaymentProvider()
        assert provider.verify_webhook_signature({}, b"{}") is True


class TestMtnMomoPaymentProvider:
    def _settings(self, **overrides: object) -> Settings:
        defaults = {
            "SECRET_KEY": "x" * 32,
            "DATABASE_URL": "postgresql+asyncpg://u:p@localhost/db",
            "DATABASE_URL_SYNC": "postgresql://u:p@localhost/db",
            "PAYMENTS_WEBHOOK_SIGNING_SECRET": "webhook-secret-value",
            "TICKET_QR_SIGNING_SECRET": "y" * 32,
            "PAYMENTS_MTN_MOMO_BASE_URL": "https://sandbox.momodeveloper.mtn.com",
            "PAYMENTS_MTN_MOMO_API_KEY": "api-user",
            "PAYMENTS_MTN_MOMO_API_SECRET": "api-key",
            "PAYMENTS_MTN_MOMO_SUBSCRIPTION_KEY": "sub-key",
        }
        defaults.update(overrides)
        return Settings(**defaults)  # type: ignore[arg-type]

    def test_raises_if_unconfigured(self) -> None:
        with pytest.raises(ProviderError):
            MtnMomoPaymentProvider(self._settings(PAYMENTS_MTN_MOMO_BASE_URL=""))

    def test_a_callback_is_never_believed_only_checked(self) -> None:
        # MTN signs nothing: any callback is accepted as a prompt, and the
        # payment service asks MTN for the status (trusts_webhook_status).
        provider = MtnMomoPaymentProvider(self._settings())
        assert provider.verify_webhook_signature({}, b"{}")
        assert provider.trusts_webhook_status is False

    def test_parse_webhook_event_maps_status(self) -> None:
        provider = MtnMomoPaymentProvider(self._settings())
        event = provider.parse_webhook_event({}, {"status": "SUCCESSFUL", "externalId": "PAY-1"})
        assert event.status == PaymentProviderStatus.SUCCESSFUL
        assert event.provider_reference == "PAY-1"

    def test_parse_webhook_event_captures_failure_reason(self) -> None:
        provider = MtnMomoPaymentProvider(self._settings())
        event = provider.parse_webhook_event(
            {},
            {
                "status": "FAILED",
                "externalId": "PAY-1",
                "reason": {"message": "Insufficient funds"},
            },
        )
        assert event.status == PaymentProviderStatus.FAILED
        assert event.failure_reason == "Insufficient funds"

    async def test_refund_is_not_supported(self) -> None:
        provider = MtnMomoPaymentProvider(self._settings())
        with pytest.raises(ProviderError):
            await provider.refund(provider_reference="PAY-1", amount=Decimal("1.00"), reason="x")


class TestPaymentProviderFactory:
    def _settings(self, active: PaymentProviderName, **overrides: object) -> Settings:
        defaults: dict[str, object] = {
            "SECRET_KEY": "x" * 32,
            "DATABASE_URL": "postgresql+asyncpg://u:p@localhost/db",
            "DATABASE_URL_SYNC": "postgresql://u:p@localhost/db",
            "PAYMENTS_WEBHOOK_SIGNING_SECRET": "webhook-secret-value",
            "TICKET_QR_SIGNING_SECRET": "y" * 32,
            "PAYMENTS_ACTIVE_PROVIDER": active,
        }
        defaults.update(overrides)
        return Settings(**defaults)  # type: ignore[arg-type]

    def test_sandbox_active_provider_forces_sandbox_for_every_channel(self) -> None:
        settings = self._settings(PaymentProviderName.SANDBOX)
        for channel in PaymentChannel:
            if channel == PaymentChannel.WALLET:
                continue
            assert isinstance(get_payment_provider(channel, settings), SandboxPaymentProvider)

    def test_real_provider_mode_routes_mtn_momo_to_real_adapter(self) -> None:
        settings = self._settings(
            PaymentProviderName.MTN_MOMO,
            PAYMENTS_MTN_MOMO_BASE_URL="https://sandbox.momodeveloper.mtn.com",
            PAYMENTS_MTN_MOMO_API_KEY="u",
            PAYMENTS_MTN_MOMO_API_SECRET="k",
            PAYMENTS_MTN_MOMO_SUBSCRIPTION_KEY="s",
        )
        provider = get_payment_provider(PaymentChannel.MTN_MOMO, settings)
        assert isinstance(provider, MtnMomoPaymentProvider)

    def test_real_provider_mode_leaves_unverified_channels_unavailable(self) -> None:
        settings = self._settings(PaymentProviderName.TELECEL_CASH)
        provider = get_payment_provider(PaymentChannel.TELECEL_CASH, settings)
        assert isinstance(provider, UnavailablePaymentProvider)


class TestSandboxAutoApprove:
    """The state travels in the provider reference, so another process (the
    Celery worker, a server woken from sleep) answers the same."""

    t0 = datetime(2026, 10, 29, 9, 0, tzinfo=UTC)

    def _provider(self, at: datetime, *, seconds: int | None = 5) -> SandboxPaymentProvider:
        return SandboxPaymentProvider(auto_approve_seconds=seconds, clock=lambda: at)

    async def _start(self, phone: str, reference: str = "PAY-AA") -> str:
        result = await self._provider(self.t0).initialize_payment(
            reference=reference,
            amount=Decimal("8.50"),
            currency="GHS",
            payer_phone=phone,
            narration="",
        )
        return result.provider_reference

    async def test_approved_after_the_delay_in_any_process(self) -> None:
        reference = await self._start("0241234567")
        assert reference.endswith(":PAY-AA")
        early = await self._provider(self.t0 + timedelta(seconds=4)).query_payment(reference)
        assert early.status == PaymentProviderStatus.PENDING
        # Another process: this one's ledger is gone, the reference is enough.
        SandboxPaymentProvider.clear()
        late = await self._provider(self.t0 + timedelta(seconds=5)).query_payment(reference)
        assert late.status == PaymentProviderStatus.SUCCESSFUL

    async def test_a_number_ending_0000_is_declined(self) -> None:
        reference = await self._start("0240000000")
        SandboxPaymentProvider.clear()
        status = await self._provider(self.t0 + timedelta(minutes=1)).query_payment(reference)
        assert status.status == PaymentProviderStatus.FAILED
        assert status.failure_reason == "Customer declined the payment prompt."

    async def test_a_number_ending_9999_never_answers(self) -> None:
        reference = await self._start("0249999999")
        status = await self._provider(self.t0 + timedelta(hours=1)).query_payment(reference)
        assert status.status == PaymentProviderStatus.PENDING

    async def test_without_auto_approve_it_stays_pending(self) -> None:
        reference = await self._start("0241234567")
        status = await self._provider(self.t0 + timedelta(hours=1), seconds=None).query_payment(
            reference
        )
        assert status.status == PaymentProviderStatus.PENDING

    async def test_resolve_still_overrides_an_encoded_reference(self) -> None:
        reference = await self._start("0249999999", reference="PAY-RS")
        SandboxPaymentProvider.resolve("PAY-RS", PaymentProviderStatus.SUCCESSFUL)
        status = await self._provider(self.t0).query_payment(reference)
        assert status.status == PaymentProviderStatus.SUCCESSFUL

    async def test_refund_of_an_encoded_reference_needs_no_ledger(self) -> None:
        reference = await self._start("0241234567")
        SandboxPaymentProvider.clear()
        result = await self._provider(self.t0).refund(
            provider_reference=reference, amount=Decimal("8.50"), reason="test"
        )
        assert result.success is True

    def test_factory_passes_the_delay_but_never_in_production(self) -> None:
        settings = TestPaymentProviderFactory()._settings(
            PaymentProviderName.SANDBOX, PAYMENTS_SANDBOX_AUTO_APPROVE_SECONDS=7
        )
        provider = get_payment_provider(PaymentChannel.MTN_MOMO, settings)
        assert isinstance(provider, SandboxPaymentProvider)
        assert provider._auto_approve_seconds == 7
        production = settings.model_copy(update={"APP_ENV": AppEnv.PRODUCTION})
        provider = get_payment_provider(PaymentChannel.MTN_MOMO, production)
        assert isinstance(provider, SandboxPaymentProvider)
        assert provider._auto_approve_seconds is None
