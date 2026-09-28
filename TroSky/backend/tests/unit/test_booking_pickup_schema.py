"""Unit tests for the pickup fields on BookingCreateRequest."""

from __future__ import annotations

import uuid

import pytest
from pydantic import ValidationError

from app.schemas.booking import BookingCreateRequest, PassengerInput


def _request(**pickup: object) -> BookingCreateRequest:
    return BookingCreateRequest(
        trip_id=uuid.uuid4(),
        passengers=[PassengerInput(seat_id=uuid.uuid4(), full_name="Ama Mensah")],
        **pickup,  # type: ignore[arg-type]
    )


class TestPickupCoordinates:
    def test_both_coordinates_are_accepted(self) -> None:
        request = _request(pickup_latitude=5.6804, pickup_longitude=-0.1654)
        assert (request.pickup_latitude, request.pickup_longitude) == (5.6804, -0.1654)

    def test_neither_coordinate_is_accepted(self) -> None:
        """Clients that never send a location keep working unchanged."""
        request = _request()
        assert request.pickup_latitude is None
        assert request.pickup_longitude is None

    @pytest.mark.parametrize("field", ["pickup_latitude", "pickup_longitude"])
    def test_half_a_coordinate_is_rejected(self, field: str) -> None:
        with pytest.raises(ValidationError, match="both pickup_latitude and pickup_longitude"):
            _request(**{field: 5.6})

    @pytest.mark.parametrize(
        ("latitude", "longitude"), [(90.1, 0.0), (-90.1, 0.0), (0.0, 180.1), (0.0, -180.1)]
    )
    def test_impossible_coordinates_are_rejected(self, latitude: float, longitude: float) -> None:
        with pytest.raises(ValidationError):
            _request(pickup_latitude=latitude, pickup_longitude=longitude)

    def test_a_manual_stop_and_coordinates_may_be_sent_together(self) -> None:
        """The app sends its location by default and adds a stop when the
        passenger picks one by hand; the service decides the stop wins."""
        stop = uuid.uuid4()
        request = _request(origin_stop_id=stop, pickup_latitude=5.6, pickup_longitude=-0.2)
        assert request.origin_stop_id == stop
