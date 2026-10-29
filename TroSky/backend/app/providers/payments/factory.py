"""Payment provider factory: resolves the adapter for a given channel.

Unlike SMS/email (one active provider for the whole app), payments has
multiple concurrently-usable channels, so resolution is per-channel rather
than a single global switch. ``PAYMENTS_ACTIVE_PROVIDER=sandbox`` (the
default) forces *every* channel through :class:`SandboxPaymentProvider`
regardless of which channel the caller asked for — the correct behavior for
development and CI, where no real vendor call must ever happen. Only when
an operator explicitly sets ``PAYMENTS_ACTIVE_PROVIDER`` to a real provider
name does a channel resolve to its real adapter.

The wallet channel never goes through this factory — see
``app.providers.payments.base`` module docstring.
"""

from __future__ import annotations

from app.core.config import PaymentProviderName, Settings, get_settings
from app.providers.payments.base import PaymentChannel, PaymentProvider
from app.providers.payments.mtn_momo import MtnMomoPaymentProvider
from app.providers.payments.sandbox import SandboxPaymentProvider
from app.providers.payments.unavailable import UnavailablePaymentProvider

_UNAVAILABLE_HINTS: dict[PaymentChannel, str] = {
    PaymentChannel.TELECEL_CASH: "no stable public merchant-collection API documentation",
    PaymentChannel.AIRTELTIGO_MONEY: "no stable public merchant-collection API documentation",
    PaymentChannel.CARD: "processor-specific — depends on which card gateway is contracted",
}


def get_payment_provider(
    channel: PaymentChannel, settings: Settings | None = None
) -> PaymentProvider:
    settings = settings or get_settings()

    if settings.PAYMENTS_ACTIVE_PROVIDER == PaymentProviderName.SANDBOX:
        return SandboxPaymentProvider(
            auto_approve_seconds=None
            if settings.is_production
            else settings.PAYMENTS_SANDBOX_AUTO_APPROVE_SECONDS
        )

    if channel == PaymentChannel.MTN_MOMO:
        return MtnMomoPaymentProvider(settings)

    hint = _UNAVAILABLE_HINTS.get(channel, "vendor contract not verified")
    return UnavailablePaymentProvider(channel.value, hint)
