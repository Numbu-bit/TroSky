"""``normalize_otp_target``: the one spelling OTP codes and cooldowns are
keyed on, so a code requested for "024..." can be used as "+233..."."""

from __future__ import annotations

import pytest

from app.services.otp_service import normalize_otp_target


@pytest.mark.parametrize(
    "raw",
    ["0241234567", "+233241234567", "+233 24 123 4567", "024-123-4567", " 0241234567 "],
)
def test_every_spelling_of_a_ghana_number_is_the_same_target(raw: str) -> None:
    assert normalize_otp_target(raw) == "+233241234567"


def test_an_email_is_trimmed_and_lower_cased() -> None:
    assert normalize_otp_target("  Ama.Mensah@Example.COM ") == "ama.mensah@example.com"


def test_something_that_is_neither_is_only_trimmed() -> None:
    assert normalize_otp_target(" not-a-number ") == "not-a-number"
