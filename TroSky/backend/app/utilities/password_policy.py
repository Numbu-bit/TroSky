"""Configurable password policy, enforced at registration and password reset."""

from __future__ import annotations

from app.core.config import Settings


class PasswordPolicyError(ValueError):
    """Raised when a password fails the configured policy. Carries a list of
    human-readable violation messages (never the offending password)."""

    def __init__(self, violations: list[str]) -> None:
        self.violations = violations
        super().__init__("; ".join(violations))


def validate_password_policy(password: str, settings: Settings) -> None:
    """Validate ``password`` against the configured policy. Raises
    :class:`PasswordPolicyError` listing every unmet requirement."""
    violations: list[str] = []

    if len(password) < settings.PASSWORD_MIN_LENGTH:
        violations.append(f"Password must be at least {settings.PASSWORD_MIN_LENGTH} characters.")
    if settings.PASSWORD_REQUIRE_UPPERCASE and not any(c.isupper() for c in password):
        violations.append("Password must contain at least one uppercase letter.")
    if settings.PASSWORD_REQUIRE_LOWERCASE and not any(c.islower() for c in password):
        violations.append("Password must contain at least one lowercase letter.")
    if settings.PASSWORD_REQUIRE_DIGIT and not any(c.isdigit() for c in password):
        violations.append("Password must contain at least one digit.")
    if settings.PASSWORD_REQUIRE_SYMBOL and password.isalnum():
        violations.append("Password must contain at least one symbol.")

    if violations:
        raise PasswordPolicyError(violations)
