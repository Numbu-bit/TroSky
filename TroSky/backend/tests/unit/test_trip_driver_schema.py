"""Schema-level guarantees for the Step 17 driver fields.

These unit tests exercise the Pydantic layer only — no DB, no app
startup. They lock in the OpenAPI shape and the default values the
``TripDriverResponse`` constructor accepts.
"""

from __future__ import annotations

import uuid
from decimal import Decimal

from app.models.drivers import VerificationStatus
from app.schemas.trip import TripDriverResponse


def _base() -> dict[str, object]:
    return {
        "id": uuid.UUID("00000000-0000-4000-8000-000000000001"),
        "full_name": "Kwame Owusu",
        "avatar_url": None,
        "average_rating": Decimal("4.8"),
        "rating_count": 112,
    }


class TestTripDriverResponseDefaults:
    def test_phone_number_defaults_to_null(self) -> None:
        driver = TripDriverResponse(**_base())
        assert driver.phone_number is None

    def test_verification_status_defaults_to_unverified(self) -> None:
        driver = TripDriverResponse(**_base())
        assert driver.verification_status is VerificationStatus.UNVERIFIED

    def test_openapi_example_for_phone_stays_null(self) -> None:
        # The response example in OpenAPI is what external integrators
        # see first. A non-null example here would suggest the field is
        # publicly visible — override explicitly to null.
        field = TripDriverResponse.model_fields["phone_number"]
        examples = field.examples or []
        assert examples == [None]


class TestTripDriverResponsePopulatedFields:
    def test_phone_and_verification_round_trip(self) -> None:
        driver = TripDriverResponse(
            **_base(),
            phone_number="+233245550201",
            verification_status=VerificationStatus.VERIFIED,
        )
        dumped = driver.model_dump(mode="json")
        assert dumped["phone_number"] == "+233245550201"
        assert dumped["verification_status"] == "verified"
