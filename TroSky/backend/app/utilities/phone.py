"""Phone number normalization helpers.

All phone numbers are normalized to E.164 (e.g. ``+233241234567``) before
storage or comparison, so uniqueness constraints and lookups are reliable
regardless of how a number was entered (local format, spaces, dashes).
"""

from __future__ import annotations

import phonenumbers
from phonenumbers import NumberParseException

DEFAULT_REGION = "GH"


class InvalidPhoneNumberError(ValueError):
    """Raised when a phone number cannot be parsed or is not a valid number."""


def normalize_phone_number(raw: str, *, default_region: str = DEFAULT_REGION) -> str:
    """Parse and normalize ``raw`` to E.164. Raises :class:`InvalidPhoneNumberError`
    if the number cannot be parsed or is not a valid, plausible number."""
    try:
        parsed = phonenumbers.parse(raw, default_region)
    except NumberParseException as exc:
        raise InvalidPhoneNumberError(f"'{raw}' is not a valid phone number") from exc

    if not phonenumbers.is_valid_number(parsed):
        raise InvalidPhoneNumberError(f"'{raw}' is not a valid phone number")

    return phonenumbers.format_number(parsed, phonenumbers.PhoneNumberFormat.E164)
