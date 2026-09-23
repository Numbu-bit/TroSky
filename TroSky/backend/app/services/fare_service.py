"""Dynamic, distance-based fare sharing.

A single rider bearing the whole fare is the affordability problem TroSky
exists to solve (Table 2, row 1). Two ideas do the work here.

*Distance* — a passenger riding Madina→Circle on an Accra→Kumasi service
pays for the stops actually ridden, pro-rated from the operator's listed
full-route fare rather than from a separate price list. Keeping the
operator's fare as the input means pricing stays theirs; TroSky only
apportions it.

*Sharing* — the trip's cost is then divided between everyone aboard **in
proportion to how far each of them rides**. A passenger covering 200km of
a 200km service and one covering 100km contribute 200 and 100 of a 300km
total, so they carry two thirds and one third of the cost. Distance is the
only weight: it is the thing each passenger actually consumes, it is
already measured for the distance calculation above, and it gives the one
split a passenger can check for themselves.

Because the weights are shares of a single pot, every passenger's payment
falls as the bus fills — which is the affordability claim — while the
operator still collects the trip's fare. Two bounds keep it sane: nobody
pays more than they would riding alone (``solo_segment_fare``), and nobody
pays less than ``FARE_SHARING_MIN_RATIO`` of that, so a full 40-seat bus
cannot price a seat into pesewas and have the operator refuse the trip.

Everything here is pure arithmetic over values the caller supplies, so it
is unit-testable without a database and has no opinion about where
distances come from.
"""

from __future__ import annotations

from decimal import ROUND_HALF_UP, Decimal

from app.core.config import Settings, get_settings


class FareBreakdown:
    """The parts of a quote, kept separate so a client can show a passenger
    why they are paying what they are paying."""

    __slots__ = (
        "segment_km",
        "route_km",
        "solo_fare",
        "total_passenger_km",
        "per_seat_fare",
        "shared",
    )

    def __init__(
        self,
        *,
        segment_km: Decimal | None,
        route_km: Decimal | None,
        solo_fare: Decimal,
        total_passenger_km: Decimal,
        per_seat_fare: Decimal,
        shared: bool,
    ) -> None:
        self.segment_km = segment_km
        self.route_km = route_km
        self.solo_fare = solo_fare
        self.total_passenger_km = total_passenger_km
        self.per_seat_fare = per_seat_fare
        self.shared = shared


class FareService:
    def __init__(self, settings: Settings | None = None) -> None:
        self._settings = settings or get_settings()

    def _quantize(self, amount: Decimal) -> Decimal:
        exponent = Decimal(1).scaleb(-self._settings.payments_default_currency_minor_unit)
        return amount.quantize(exponent, rounding=ROUND_HALF_UP)

    def solo_segment_fare(
        self,
        *,
        full_route_fare: Decimal,
        segment_km: Decimal | None,
        route_km: Decimal | None,
    ) -> Decimal:
        """What one passenger alone would pay for this segment.

        Falls back to the full-route fare when either distance is unknown
        or non-positive — a route without measured stop distances must
        still be bookable, and charging the whole fare is the safe default
        (it never under-charges the operator).
        """
        if segment_km is None or route_km is None or route_km <= 0 or segment_km <= 0:
            return self._quantize(full_route_fare)
        ratio = min(segment_km / route_km, Decimal("1"))
        return self._quantize(max(full_route_fare * ratio, self._settings.FARE_MINIMUM_AMOUNT))

    def quote(
        self,
        *,
        full_route_fare: Decimal,
        segment_km: Decimal | None,
        route_km: Decimal | None,
        total_passenger_km: Decimal,
    ) -> FareBreakdown:
        """Price one seat.

        ``total_passenger_km`` is the sum, over every seat aboard the trip,
        of the distance that seat rides — *including* the seat being priced,
        so a solo traveller's own distance is the whole total and the
        division is never by zero.
        """
        solo = self.solo_segment_fare(
            full_route_fare=full_route_fare, segment_km=segment_km, route_km=route_km
        )
        # Written as an early return rather than a boolean so the narrowing
        # of `segment_km` to Decimal below is provable.
        if (
            not self._settings.FARE_SHARING_ENABLED
            or segment_km is None
            or segment_km <= 0
            or total_passenger_km <= segment_km  # nobody else aboard
        ):
            return FareBreakdown(
                segment_km=segment_km,
                route_km=route_km,
                solo_fare=solo,
                total_passenger_km=max(total_passenger_km, segment_km or Decimal("0")),
                per_seat_fare=solo,
                shared=False,
            )

        # This seat's share of the trip's cost, weighted by the distance it
        # rides against every passenger-kilometre aboard.
        share = full_route_fare * (segment_km / total_passenger_km)
        floor = solo * self._settings.FARE_SHARING_MIN_RATIO
        # Sharing may only reduce the price: a short hop on an otherwise
        # empty bus would otherwise be asked to carry the whole trip.
        per_seat = self._quantize(max(min(share, solo), floor))
        per_seat = min(per_seat, solo)
        return FareBreakdown(
            segment_km=segment_km,
            route_km=route_km,
            solo_fare=solo,
            total_passenger_km=total_passenger_km,
            per_seat_fare=per_seat,
            shared=True,
        )


def segment_distance_km(
    *,
    origin_distance_km: Decimal | None,
    destination_distance_km: Decimal | None,
    route_km: Decimal | None,
) -> Decimal | None:
    """Distance between two stops from their offsets along the route.

    Both offsets are measured from the route's origin, so the segment is
    their difference. ``abs`` covers a route travelled in reverse. Returns
    None when the data cannot support a distance-based price, which the
    caller treats as "charge the full fare".
    """
    if origin_distance_km is None or destination_distance_km is None:
        return route_km
    segment = abs(destination_distance_km - origin_distance_km)
    return segment if segment > 0 else None
