"""Parsing of ``REGISTRATION_EMAIL_DOMAINS``."""

from __future__ import annotations

from app.core.config import Settings, get_settings


def _parsed(raw: str) -> frozenset[str]:
    settings = get_settings().model_copy(update={"REGISTRATION_EMAIL_DOMAINS": raw})
    return settings.registration_email_domains


def test_gmail_is_required_unless_configured_otherwise() -> None:
    assert Settings.model_fields["REGISTRATION_EMAIL_DOMAINS"].default == (
        "gmail.com,googlemail.com"
    )


def test_entries_are_trimmed_lower_cased_and_may_carry_an_at_sign() -> None:
    assert _parsed(" Gmail.com, @googlemail.com ,,") == {"gmail.com", "googlemail.com"}


def test_empty_accepts_any_domain() -> None:
    assert _parsed("") == frozenset()
