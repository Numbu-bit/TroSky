"""Money helpers. Decimal only, with explicit and configurable rounding.

Floats are refused everywhere money or rates enter the engine: 7.10 cannot be
represented exactly in binary floating point, and the error compounds.
"""

from __future__ import annotations

import decimal
from decimal import Decimal

ROUNDING_MODES = {
    name: getattr(decimal, name)
    for name in (
        "ROUND_HALF_UP",
        "ROUND_HALF_EVEN",
        "ROUND_HALF_DOWN",
        "ROUND_UP",
        "ROUND_DOWN",
        "ROUND_CEILING",
        "ROUND_FLOOR",
    )
}

ZERO = Decimal("0")
CENT = Decimal("0.01")


def to_decimal(value: object, *, field: str = "value") -> Decimal:
    """Convert an int, str or Decimal to Decimal. Floats and booleans are errors."""
    if isinstance(value, bool):
        raise TypeError(f"{field}: a boolean is not a number")
    if isinstance(value, float):
        raise TypeError(f"{field}: floats are not allowed; pass a string such as '7.10'")
    if isinstance(value, Decimal):
        result = value
    elif isinstance(value, int):
        result = Decimal(value)
    elif isinstance(value, str):
        try:
            result = Decimal(value.strip())
        except decimal.InvalidOperation as exc:
            raise ValueError(f"{field}: {value!r} is not a number") from exc
    else:
        raise TypeError(f"{field}: expected int, str or Decimal, got {type(value).__name__}")
    if not result.is_finite():
        raise ValueError(f"{field}: must be a finite number")
    return result


def round_to_step(amount: Decimal, step: Decimal, mode: str = "ROUND_HALF_UP") -> Decimal:
    """Round to the nearest multiple of ``step`` (0.10, 0.01, 0.50 ...) with ``mode``."""
    if step <= 0:
        raise ValueError("rounding step must be positive")
    if mode not in ROUNDING_MODES:
        raise ValueError(f"unknown rounding mode {mode!r}")
    units = (amount / step).to_integral_value(rounding=ROUNDING_MODES[mode])
    return (units * step).quantize(step)


def is_multiple_of(amount: Decimal, step: Decimal) -> bool:
    return (amount / step) == (amount / step).to_integral_value()


def show(amount: Decimal) -> str:
    """Exact value for display, at least two decimals: 0.44375, 3.55, 1.775, 10.00."""
    n = amount.normalize()
    if n.as_tuple().exponent > -2:  # type: ignore[operator]
        n = n.quantize(CENT)
    return format(n, "f")


def cedis(amount: Decimal) -> str:
    """GH¢ with two decimals; the value must already be rounded to the cent."""
    return f"GH¢{amount.quantize(CENT):,.2f}"
