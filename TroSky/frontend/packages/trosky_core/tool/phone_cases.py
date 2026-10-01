"""Writes test/fixtures/phone_cases.json: what the backend's
normalize_phone_number (backend/app/utilities/phone.py) returns for each
input, so the Dart port is tested against the real thing.

Run from TroSky/frontend/packages/trosky_core with the backend's virtualenv:

    ../../../backend/.venv312/Scripts/python.exe tool/phone_cases.py
"""

from __future__ import annotations

import json
import pathlib
import sys

BACKEND = pathlib.Path(__file__).resolve().parents[4] / "backend"
sys.path.insert(0, str(BACKEND))

from app.utilities.phone import InvalidPhoneNumberError, normalize_phone_number  # noqa: E402

# (input, region). The first six are backend/tests/unit/test_phone_utilities.py.
CASES: list[tuple[str, str]] = [
    ("0241234567", "GH"),
    ("+233241234567", "GH"),
    ("024 123-4567", "GH"),
    ("not-a-phone-number", "GH"),
    ("123", "GH"),
    ("6502530000", "US"),
    # The three forms the app accepts: 024..., 24..., +233...
    ("241234567", "GH"),
    ("+233 24 123 4567", "GH"),
    ("+233-24-123-4567", "GH"),
    # Other ways people type a Ghanaian number
    (" 0241234567 ", "GH"),
    ("(024) 123 4567", "GH"),
    ("024.123.4567", "GH"),
    ("00233241234567", "GH"),
    ("233241234567", "GH"),
    ("+2330241234567", "GH"),
    ("+233 (0) 24 123 4567", "GH"),
    ("0241234567 ext. 12", "GH"),
    # Each mobile network prefix
    ("0201234567", "GH"),
    ("0231234567", "GH"),
    ("0241234567", "GH"),
    ("0251234567", "GH"),
    ("0261234567", "GH"),
    ("0271234567", "GH"),
    ("0281234567", "GH"),
    ("0501234567", "GH"),
    ("0531234567", "GH"),
    ("0541234567", "GH"),
    ("0551234567", "GH"),
    ("0561234567", "GH"),
    ("0571234567", "GH"),
    ("0591234567", "GH"),
    # Landlines (Accra, Kumasi)
    ("0302123456", "GH"),
    ("0322012345", "GH"),
    # Wrong lengths and prefixes
    ("02412345", "GH"),
    ("024123456", "GH"),
    ("02412345678", "GH"),
    ("0991234567", "GH"),
    ("0001234567", "GH"),
    ("+233 99 123 4567", "GH"),
    ("1234567890", "GH"),
    # Foreign numbers
    ("+447911123456", "GH"),
    ("+1 650 253 0000", "GH"),
    ("6502530000", "GH"),
    ("+2348031234567", "GH"),
    # Junk
    ("", "GH"),
    ("   ", "GH"),
    ("+", "GH"),
    ("abc", "GH"),
    ("024-ABC-4567", "GH"),
    ("++233241234567", "GH"),
    # libphonenumber's clean-up of typed text
    ("Tel: 0241234567", "GH"),
    ("0241234567#", "GH"),
    ("024-123-4567.", "GH"),
    ("0241234567 x 12", "GH"),
    ("0241234567;ext=12", "GH"),
    ("+233 24 123 4567 ext 5", "GH"),
    ("(024) 123-4567 x302/x2303", "GH"),
    ("+(233) 24 123 4567", "GH"),
    ("+ 233 24 123 4567", "GH"),
    ("＋233241234567", "GH"),
    ("０２４１２３４５６７", "GH"),
    ("٠٢٤١٢٣٤٥٦٧", "GH"),
    ("024 1234567 / 0201234567", "GH"),
    ("1-800-FLOWERS", "US"),
    ("0800 FLOWERS", "GH"),
    ("024AB34567", "GH"),
    ("0241234567;isub=123", "GH"),
]


def main() -> None:
    results = []
    for raw, region in CASES:
        try:
            expected: str | None = normalize_phone_number(raw, default_region=region)
        except InvalidPhoneNumberError:
            expected = None
        results.append({"input": raw, "region": region, "e164": expected})
    out = pathlib.Path(__file__).resolve().parents[1] / "test" / "fixtures" / "phone_cases.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(results, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"wrote {len(results)} cases to {out}")


if __name__ == "__main__":
    main()
