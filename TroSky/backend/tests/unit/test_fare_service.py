"""Unit tests for distance-based fare sharing.

Two levers, tested separately and together: pro-rating an operator's
full-route fare down to the segment actually ridden, then dividing the
trip's cost between everyone aboard in proportion to how far each rides.
"""

from __future__ import annotations

from decimal import Decimal

import pytest

from app.core.config import Settings
from app.services.fare_service import FareService, segment_distance_km


def _service(**overrides: object) -> FareService:
    settings = Settings(
        SECRET_KEY="a" * 40,
        PAYMENTS_WEBHOOK_SIGNING_SECRET="b" * 40,
        TICKET_QR_SIGNING_SECRET="c" * 40,
        DATABASE_URL="postgresql+asyncpg://u:p@localhost:5432/db",
        DATABASE_URL_SYNC="postgresql+psycopg://u:p@localhost:5432/db",
        **overrides,  # type: ignore[arg-type]
    )
    return FareService(settings)


FULL = Decimal("40.00")
ROUTE = Decimal("200")


class TestDistanceProRating:
    def test_half_the_route_costs_half_the_fare(self) -> None:
        fare = _service().solo_segment_fare(
            full_route_fare=FULL, segment_km=Decimal("100"), route_km=ROUTE
        )
        assert fare == Decimal("20.00")

    def test_full_route_costs_the_full_fare(self) -> None:
        fare = _service().solo_segment_fare(full_route_fare=FULL, segment_km=ROUTE, route_km=ROUTE)
        assert fare == FULL

    def test_segment_longer_than_route_is_capped_at_the_full_fare(self) -> None:
        """Defensive: bad stop data must never price above the operator's fare."""
        fare = _service().solo_segment_fare(
            full_route_fare=FULL, segment_km=Decimal("500"), route_km=ROUTE
        )
        assert fare == FULL

    def test_short_hop_is_floored_at_the_minimum(self) -> None:
        fare = _service(FARE_MINIMUM_AMOUNT=Decimal("2.00")).solo_segment_fare(
            full_route_fare=FULL, segment_km=Decimal("1"), route_km=ROUTE
        )
        assert fare == Decimal("2.00")

    @pytest.mark.parametrize(("segment", "route"), [(None, ROUTE), (Decimal("50"), None)])
    def test_unknown_distance_charges_the_full_fare(
        self, segment: Decimal | None, route: Decimal | None
    ) -> None:
        """A route without measured stop distances must still be bookable,
        and the safe default never under-charges the operator."""
        fare = _service().solo_segment_fare(
            full_route_fare=FULL, segment_km=segment, route_km=route
        )
        assert fare == FULL

    def test_zero_route_distance_does_not_divide_by_zero(self) -> None:
        fare = _service().solo_segment_fare(
            full_route_fare=FULL, segment_km=Decimal("10"), route_km=Decimal("0")
        )
        assert fare == FULL


class TestSharingByDistance:
    def test_a_lone_passenger_pays_their_own_distance_fare(self) -> None:
        quote = _service().quote(
            full_route_fare=FULL, segment_km=ROUTE, route_km=ROUTE, total_passenger_km=ROUTE
        )
        assert quote.per_seat_fare == FULL
        assert quote.shared is False

    def test_equal_distances_split_evenly(self) -> None:
        """Two passengers riding the whole route each carry half."""
        quote = _service().quote(
            full_route_fare=FULL,
            segment_km=ROUTE,
            route_km=ROUTE,
            total_passenger_km=Decimal("400"),
        )
        assert quote.per_seat_fare == Decimal("20.00")
        assert quote.shared is True

    def test_longer_rider_carries_proportionally_more(self) -> None:
        """200km and 100km of a 300km total: two thirds and one third.

        The split is the whole point of the model, so assert both sides and
        that together they still fund the operator's fare.
        """
        service = _service()
        total = Decimal("300")
        long_leg = service.quote(
            full_route_fare=FULL, segment_km=ROUTE, route_km=ROUTE, total_passenger_km=total
        )
        short_leg = service.quote(
            full_route_fare=FULL,
            segment_km=Decimal("100"),
            route_km=ROUTE,
            total_passenger_km=total,
        )
        assert long_leg.per_seat_fare == Decimal("26.67")
        assert short_leg.per_seat_fare == Decimal("13.33")
        assert long_leg.per_seat_fare + short_leg.per_seat_fare == FULL

    def test_twice_the_distance_is_twice_the_fare(self) -> None:
        service = _service()
        total = Decimal("300")
        long_leg = service.quote(
            full_route_fare=FULL, segment_km=ROUTE, route_km=ROUTE, total_passenger_km=total
        )
        short_leg = service.quote(
            full_route_fare=FULL,
            segment_km=Decimal("100"),
            route_km=ROUTE,
            total_passenger_km=total,
        )
        # 26.67 / 13.33 differ from exactly 2x only by the rounding needed
        # to keep both payable in pesewas.
        ratio = long_leg.per_seat_fare / short_leg.per_seat_fare
        assert Decimal("1.99") < ratio < Decimal("2.01")

    def test_a_fuller_bus_is_cheaper_for_everyone(self) -> None:
        service = _service()
        fares = [
            service.quote(
                full_route_fare=FULL,
                segment_km=ROUTE,
                route_km=ROUTE,
                total_passenger_km=ROUTE * n,
            ).per_seat_fare
            for n in (1, 2, 3, 4)
        ]
        assert fares == sorted(fares, reverse=True), fares

    def test_sharing_never_charges_above_the_solo_fare(self) -> None:
        """A short hop on a nearly empty bus: its distance share of the trip
        would exceed what it would pay riding alone, so the solo fare caps it."""
        quote = _service().quote(
            full_route_fare=FULL,
            segment_km=Decimal("20"),
            route_km=ROUTE,
            total_passenger_km=Decimal("25"),
        )
        assert quote.per_seat_fare == quote.solo_fare == Decimal("4.00")

    def test_floor_stops_a_full_bus_pricing_into_the_ground(self) -> None:
        quote = _service(FARE_SHARING_MIN_RATIO=Decimal("0.25")).quote(
            full_route_fare=FULL,
            segment_km=ROUTE,
            route_km=ROUTE,
            total_passenger_km=ROUTE * 40,
        )
        assert quote.per_seat_fare == Decimal("10.00")

    def test_sharing_can_be_switched_off(self) -> None:
        quote = _service(FARE_SHARING_ENABLED=False).quote(
            full_route_fare=FULL,
            segment_km=ROUTE,
            route_km=ROUTE,
            total_passenger_km=ROUTE * 10,
        )
        assert quote.per_seat_fare == FULL
        assert quote.shared is False

    def test_distance_and_sharing_compose(self) -> None:
        """Half the route, against 800 passenger-km aboard."""
        quote = _service().quote(
            full_route_fare=FULL,
            segment_km=Decimal("100"),
            route_km=ROUTE,
            total_passenger_km=Decimal("800"),
        )
        assert quote.solo_fare == Decimal("20.00")
        assert quote.per_seat_fare == Decimal("5.00")

    def test_result_is_quantized_to_the_minor_unit(self) -> None:
        quote = _service().quote(
            full_route_fare=Decimal("10.00"),
            segment_km=ROUTE,
            route_km=ROUTE,
            total_passenger_km=Decimal("600"),
        )
        assert quote.per_seat_fare.as_tuple().exponent == -2

    def test_unknown_segment_distance_does_not_share(self) -> None:
        """Without a measured distance there is no weight to share by, so the
        passenger pays the full fare rather than an arbitrary fraction."""
        quote = _service().quote(
            full_route_fare=FULL,
            segment_km=None,
            route_km=ROUTE,
            total_passenger_km=Decimal("600"),
        )
        assert quote.per_seat_fare == FULL
        assert quote.shared is False


class TestSegmentDistance:
    def test_difference_between_stop_offsets(self) -> None:
        assert segment_distance_km(
            origin_distance_km=Decimal("20"),
            destination_distance_km=Decimal("75"),
            route_km=ROUTE,
        ) == Decimal("55")

    def test_reverse_direction_is_the_same_distance(self) -> None:
        assert segment_distance_km(
            origin_distance_km=Decimal("75"),
            destination_distance_km=Decimal("20"),
            route_km=ROUTE,
        ) == Decimal("55")

    def test_missing_offsets_fall_back_to_the_whole_route(self) -> None:
        assert (
            segment_distance_km(
                origin_distance_km=None,
                destination_distance_km=Decimal("75"),
                route_km=ROUTE,
            )
            == ROUTE
        )

    def test_same_stop_twice_has_no_distance(self) -> None:
        assert (
            segment_distance_km(
                origin_distance_km=Decimal("20"),
                destination_distance_km=Decimal("20"),
                route_km=ROUTE,
            )
            is None
        )
