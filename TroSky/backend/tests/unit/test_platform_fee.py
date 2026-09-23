"""Unit tests for the platform booking fee.

The fee is TroSky's per-booking revenue (business plan section 4A). It is
charged on top of the operator's fare, so the operator is always paid in
full and ``fare + fee == total`` must hold exactly for every booking.
"""

from __future__ import annotations

from decimal import Decimal

import pytest

from app.core.config import Settings
from app.services.booking_service import BookingService


def _service(**overrides: object) -> BookingService:
    settings = Settings(
        SECRET_KEY="a" * 40,
        PAYMENTS_WEBHOOK_SIGNING_SECRET="b" * 40,
        TICKET_QR_SIGNING_SECRET="c" * 40,
        DATABASE_URL="postgresql+asyncpg://u:p@localhost:5432/db",
        DATABASE_URL_SYNC="postgresql+psycopg://u:p@localhost:5432/db",
        **overrides,  # type: ignore[arg-type]
    )
    # The fee calculation is pure arithmetic over settings; it never touches
    # the session, so this needs no database.
    return BookingService(session=None, settings=settings)  # type: ignore[arg-type]


class TestPlatformFee:
    def test_default_is_fifty_pesewas_per_seat(self) -> None:
        assert _service()._platform_fee(Decimal("8.00"), 1) == Decimal("0.50")

    def test_flat_component_scales_with_seats(self) -> None:
        assert _service()._platform_fee(Decimal("24.00"), 3) == Decimal("1.50")

    def test_percentage_component_applies_to_the_fare(self) -> None:
        service = _service(
            PLATFORM_FEE_FLAT_PER_SEAT=Decimal("0"), PLATFORM_FEE_PERCENT=Decimal("10")
        )
        assert service._platform_fee(Decimal("20.00"), 1) == Decimal("2.00")

    def test_flat_and_percentage_combine(self) -> None:
        service = _service(
            PLATFORM_FEE_FLAT_PER_SEAT=Decimal("0.50"), PLATFORM_FEE_PERCENT=Decimal("5")
        )
        # 0.50 per seat x2, plus 5% of 20.00
        assert service._platform_fee(Decimal("20.00"), 2) == Decimal("2.00")

    def test_zero_fee_is_supported(self) -> None:
        service = _service(
            PLATFORM_FEE_FLAT_PER_SEAT=Decimal("0"), PLATFORM_FEE_PERCENT=Decimal("0")
        )
        assert service._platform_fee(Decimal("8.00"), 4) == Decimal("0.00")

    @pytest.mark.parametrize(
        ("fare", "percent", "expected"),
        [
            # .x5 boundaries: half-up, not banker's rounding, so the stored
            # amounts always reconcile.
            (Decimal("1.00"), Decimal("2.5"), Decimal("0.03")),
            (Decimal("3.00"), Decimal("2.5"), Decimal("0.08")),
            (Decimal("0.10"), Decimal("5"), Decimal("0.01")),
        ],
    )
    def test_rounds_half_up_to_the_minor_unit(
        self, fare: Decimal, percent: Decimal, expected: Decimal
    ) -> None:
        service = _service(PLATFORM_FEE_FLAT_PER_SEAT=Decimal("0"), PLATFORM_FEE_PERCENT=percent)
        assert service._platform_fee(fare, 1) == expected

    def test_result_is_always_quantized_to_two_places(self) -> None:
        service = _service(
            PLATFORM_FEE_FLAT_PER_SEAT=Decimal("0"), PLATFORM_FEE_PERCENT=Decimal("7.3")
        )
        assert service._platform_fee(Decimal("13.37"), 1).as_tuple().exponent == -2
