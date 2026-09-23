"""Unit tests for phone number normalization."""

from __future__ import annotations

import pytest

from app.utilities.phone import InvalidPhoneNumberError, normalize_phone_number


class TestNormalizePhoneNumber:
    def test_normalizes_local_ghana_format(self) -> None:
        assert normalize_phone_number("0241234567") == "+233241234567"

    def test_accepts_already_e164_format(self) -> None:
        assert normalize_phone_number("+233241234567") == "+233241234567"

    def test_normalizes_with_spaces_and_dashes(self) -> None:
        assert normalize_phone_number("024 123-4567") == "+233241234567"

    def test_rejects_garbage_input(self) -> None:
        with pytest.raises(InvalidPhoneNumberError):
            normalize_phone_number("not-a-phone-number")

    def test_rejects_too_short_number(self) -> None:
        with pytest.raises(InvalidPhoneNumberError):
            normalize_phone_number("123")

    def test_respects_explicit_region(self) -> None:
        # A US number should normalize correctly even with GH as the module
        # default, when explicitly told the number is a US number.
        assert normalize_phone_number("6502530000", default_region="US") == "+16502530000"
