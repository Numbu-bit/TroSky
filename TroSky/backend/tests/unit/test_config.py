"""Unit tests for settings validation / production safety checks."""

from __future__ import annotations

from decimal import Decimal

import pytest
from pydantic import ValidationError

from app.core.config import (
    AppEnv,
    PaymentProviderName,
    Settings,
    from_minor_units,
    redact_secrets,
    to_minor_units,
)


def _base_env(**overrides: object) -> dict[str, object]:
    env: dict[str, object] = {
        "SECRET_KEY": "a" * 40,
        "PAYMENTS_WEBHOOK_SIGNING_SECRET": "b" * 40,
        "TICKET_QR_SIGNING_SECRET": "c" * 40,
        "DATABASE_URL": "postgresql+asyncpg://u:p@localhost:5432/db",
        "DATABASE_URL_SYNC": "postgresql+psycopg://u:p@localhost:5432/db",
    }
    env.update(overrides)
    return env


class TestProductionSafety:
    def test_production_rejects_debug_true(self) -> None:
        with pytest.raises(ValidationError, match="DEBUG must be false"):
            Settings(APP_ENV=AppEnv.PRODUCTION, DEBUG=True, **_base_env())  # type: ignore[arg-type]

    def test_production_rejects_short_secret(self) -> None:
        with pytest.raises(ValidationError, match="at least 32 characters"):
            Settings(
                APP_ENV=AppEnv.PRODUCTION,
                DEBUG=False,
                EXPOSE_HEALTH_DETAILS=False,
                **_base_env(SECRET_KEY="short"),
            )  # type: ignore[arg-type]

    def test_production_rejects_placeholder_secret(self) -> None:
        with pytest.raises(ValidationError, match="development placeholder"):
            Settings(
                APP_ENV=AppEnv.PRODUCTION,
                DEBUG=False,
                EXPOSE_HEALTH_DETAILS=False,
                **_base_env(SECRET_KEY="change-me-" + "x" * 30),
            )  # type: ignore[arg-type]

    def test_production_rejects_live_provider_without_credentials(self) -> None:
        with pytest.raises(ValidationError, match="requires provider"):
            Settings(
                APP_ENV=AppEnv.PRODUCTION,
                DEBUG=False,
                EXPOSE_HEALTH_DETAILS=False,
                PAYMENTS_ACTIVE_PROVIDER=PaymentProviderName.MTN_MOMO,
                **_base_env(),
            )  # type: ignore[arg-type]

    def test_development_allows_debug_and_short_secrets(self) -> None:
        settings = Settings(APP_ENV=AppEnv.DEVELOPMENT, DEBUG=True, **_base_env())  # type: ignore[arg-type]
        assert settings.APP_ENV == AppEnv.DEVELOPMENT

    def test_only_ghs_currency_accepted(self) -> None:
        with pytest.raises(ValidationError, match="Only GHS"):
            Settings(PAYMENTS_DEFAULT_CURRENCY="USD", **_base_env())  # type: ignore[arg-type]


class TestMoneyHelpers:
    def test_to_minor_units(self) -> None:
        assert to_minor_units(Decimal("12.50")) == 1250

    def test_from_minor_units(self) -> None:
        assert from_minor_units(1250) == Decimal("12.50")

    def test_round_trip(self) -> None:
        amount = Decimal("99.99")
        assert from_minor_units(to_minor_units(amount)) == amount


class TestRedaction:
    def test_redacts_known_sensitive_keys(self) -> None:
        result = redact_secrets({"password": "hunter2", "otp": "123456", "name": "Ama"})
        assert result["password"] == "***REDACTED***"
        assert result["otp"] == "***REDACTED***"
        assert result["name"] == "Ama"

    def test_redacts_nested_dicts(self) -> None:
        result = redact_secrets({"user": {"api_key": "abc123", "email": "a@b.com"}})
        assert result["user"]["api_key"] == "***REDACTED***"
        assert result["user"]["email"] == "a@b.com"


class TestRateLimitOverrides:
    """``RATE_LIMIT_OVERRIDES`` lets an environment loosen (or tighten) a
    named rule without a code change — see app.core.ratelimit."""

    def test_empty_value_yields_no_overrides(self) -> None:
        settings = Settings(RATE_LIMIT_OVERRIDES="", **_base_env())  # type: ignore[arg-type]
        assert settings.rate_limit_overrides == {}

    def test_parses_rule_names_containing_a_colon(self) -> None:
        settings = Settings(  # type: ignore[arg-type]
            RATE_LIMIT_OVERRIDES="auth:register:100:3600, auth:login:50:300",
            **_base_env(),
        )
        assert settings.rate_limit_overrides == {
            "auth:register": (100, 3600),
            "auth:login": (50, 300),
        }

    @pytest.mark.parametrize(
        "value",
        ["nonsense", "auth:register:abc:3600", "auth:register:100", "100:3600"],
    )
    def test_rejects_malformed_entries(self, value: str) -> None:
        with pytest.raises(ValueError, match="Malformed RATE_LIMIT_OVERRIDES"):
            _ = Settings(RATE_LIMIT_OVERRIDES=value, **_base_env()).rate_limit_overrides  # type: ignore[arg-type]

    @pytest.mark.parametrize("value", ["auth:register:0:3600", "auth:register:5:0"])
    def test_rejects_non_positive_values(self, value: str) -> None:
        with pytest.raises(ValueError, match="must be positive"):
            _ = Settings(RATE_LIMIT_OVERRIDES=value, **_base_env()).rate_limit_overrides  # type: ignore[arg-type]
