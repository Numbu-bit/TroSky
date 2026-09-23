"""Unit tests for the configurable password policy."""

from __future__ import annotations

import pytest

from app.core.config import Settings
from app.utilities.password_policy import PasswordPolicyError, validate_password_policy


def _settings(**overrides: object) -> Settings:
    base = {
        "SECRET_KEY": "a" * 40,
        "PAYMENTS_WEBHOOK_SIGNING_SECRET": "b" * 40,
        "TICKET_QR_SIGNING_SECRET": "c" * 40,
        "DATABASE_URL": "postgresql+asyncpg://u:p@localhost:5432/db",
        "DATABASE_URL_SYNC": "postgresql+psycopg://u:p@localhost:5432/db",
    }
    base.update(overrides)
    return Settings(**base)  # type: ignore[arg-type]


class TestPasswordPolicy:
    def test_accepts_a_compliant_password(self) -> None:
        validate_password_policy("Str0ngPass", _settings())

    def test_rejects_too_short(self) -> None:
        with pytest.raises(PasswordPolicyError) as exc_info:
            validate_password_policy("Ab1", _settings())
        assert any("at least" in v for v in exc_info.value.violations)

    def test_rejects_missing_uppercase(self) -> None:
        with pytest.raises(PasswordPolicyError) as exc_info:
            validate_password_policy("lowercase1", _settings())
        assert any("uppercase" in v for v in exc_info.value.violations)

    def test_rejects_missing_lowercase(self) -> None:
        with pytest.raises(PasswordPolicyError) as exc_info:
            validate_password_policy("UPPERCASE1", _settings())
        assert any("lowercase" in v for v in exc_info.value.violations)

    def test_rejects_missing_digit(self) -> None:
        with pytest.raises(PasswordPolicyError) as exc_info:
            validate_password_policy("NoDigitsHere", _settings())
        assert any("digit" in v for v in exc_info.value.violations)

    def test_symbol_not_required_by_default(self) -> None:
        validate_password_policy("NoSymbol1", _settings())

    def test_symbol_required_when_configured(self) -> None:
        settings = _settings(PASSWORD_REQUIRE_SYMBOL=True)
        with pytest.raises(PasswordPolicyError) as exc_info:
            validate_password_policy("NoSymbol1", settings)
        assert any("symbol" in v for v in exc_info.value.violations)

    def test_reports_multiple_violations_at_once(self) -> None:
        with pytest.raises(PasswordPolicyError) as exc_info:
            validate_password_policy("short", _settings())
        assert len(exc_info.value.violations) > 1
