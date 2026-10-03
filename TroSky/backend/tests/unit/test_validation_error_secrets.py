"""A rejected request must not put a submitted password or one-time code
into the logs or echo it back: pydantic copies the raw value into each
validation error's ``input``."""

from __future__ import annotations

from app.core.exceptions import _without_secrets
from app.core.logging import REDACTED


def _error(loc: tuple, value: object) -> dict:
    return {"type": "string_too_short", "loc": loc, "msg": "too short", "input": value, "ctx": {}}


def test_a_rejected_password_is_masked() -> None:
    cleaned = _without_secrets(_error(("body", "password"), "Short12"))
    assert cleaned["input"] == REDACTED
    assert cleaned["msg"] == "too short"  # the reason is kept
    assert "ctx" not in cleaned


def test_new_passwords_and_one_time_codes_are_masked() -> None:
    for field in ("new_password", "code", "token", "refresh_token", "qr_token"):
        assert _without_secrets(_error(("body", field), "secret-ish"))["input"] == REDACTED


def test_ordinary_fields_keep_their_value() -> None:
    assert _without_secrets(_error(("body", "full_name"), "A"))["input"] == "A"


def test_a_whole_body_input_has_its_secrets_masked() -> None:
    body = {"phone_number": "0241234567", "password": "Short12"}
    cleaned = _without_secrets(_error(("body",), body))
    assert cleaned["input"] == {"phone_number": "0241234567", "password": REDACTED}
