"""Load test scenarios (Locust).

Run against a disposable environment that has been seeded via
``python -m scripts.seed_load_test_data`` (a pool of pre-verified
passenger accounts + one bookable trip — see that script's docstring for
why a load generator can't just register through the normal OTP flow).
Never point this at production.

    locust -f tests/load/locustfile.py --host http://localhost:8000

Three user classes, weighted toward the traffic shape a launch would
actually see: mostly anonymous browsing, a meaningful chunk of
authenticated booking activity (the concurrency-sensitive path this whole
backend is built around — see ``docs/adr/0001-...md``), and a much
smaller number of driver GPS-ping streams (one connection per active
trip, not one per passenger).
"""

from __future__ import annotations

import random
from datetime import date, timedelta

from locust import HttpUser, between, task

_PASSENGER_COUNT = 50
_PASSENGER_PHONE_PREFIX = "+23320000"
_PASSENGER_PASSWORD = "LoadTestPass!2026"  # matches scripts/seed_load_test_data.py
_TRAVEL_DATE = (date.today() + timedelta(days=1)).isoformat()


class BrowsingUser(HttpUser):
    """Anonymous traffic: search and browse, never authenticates. The
    largest share of real-world traffic to a public transport search
    product — most visits don't end in a booking."""

    weight = 5
    wait_time = between(1, 4)

    @task(4)
    def search_trips(self) -> None:
        self.client.get(
            f"/api/v1/trips/search?travel_date={_TRAVEL_DATE}&limit=20",
            name="/trips/search",
        )

    @task(2)
    def list_stops(self) -> None:
        self.client.get("/api/v1/stops?limit=20", name="/stops")

    @task(1)
    def health_check(self) -> None:
        self.client.get("/health/live", name="/health/live")


class PassengerUser(HttpUser):
    """An authenticated passenger: logs in once, then repeatedly searches,
    checks seat availability, and attempts a booking — the exact path
    that races other concurrent `PassengerUser`s for the same seats,
    exercising the guarantee in ADR-0001 under real concurrent load
    rather than just the two-session integration test."""

    weight = 3
    wait_time = between(2, 6)

    def on_start(self) -> None:
        phone = f"{_PASSENGER_PHONE_PREFIX}{1000 + random.randrange(_PASSENGER_COUNT)}"
        response = self.client.post(
            "/api/v1/auth/login",
            json={"identifier": phone, "password": _PASSENGER_PASSWORD},
            name="/auth/login",
        )
        if response.status_code == 200:
            self.token = response.json()["access_token"]
        else:
            self.token = None

    def _auth_headers(self) -> dict[str, str]:
        return {"Authorization": f"Bearer {self.token}"} if self.token else {}

    @task(3)
    def browse_and_check_seats(self) -> None:
        search = self.client.get(
            f"/api/v1/trips/search?travel_date={_TRAVEL_DATE}&limit=5",
            name="/trips/search",
        )
        if search.status_code != 200:
            return
        items = search.json().get("items", [])
        if not items:
            return
        trip_id = random.choice(items)["trip_id"]
        self.client.get(f"/api/v1/trips/{trip_id}/seats", name="/trips/[id]/seats")

    @task(1)
    def attempt_booking(self) -> None:
        if not self.token:
            return
        search = self.client.get(
            f"/api/v1/trips/search?travel_date={_TRAVEL_DATE}&limit=5",
            name="/trips/search",
        )
        if search.status_code != 200:
            return
        items = search.json().get("items", [])
        if not items:
            return
        trip_id = random.choice(items)["trip_id"]

        seats_response = self.client.get(f"/api/v1/trips/{trip_id}/seats", name="/trips/[id]/seats")
        if seats_response.status_code != 200:
            return
        available = [s for s in seats_response.json().get("seats", []) if s.get("is_available")]
        if not available:
            return
        seat = random.choice(available)

        # A 409 here is not a failure of the load test — it's the exact,
        # expected outcome (ADR-0001) when another concurrent user won
        # the same seat first. Locust still records it as a non-2xx
        # response by default; that's informative (how often does
        # contention actually occur under this load profile?), not a bug
        # to chase.
        self.client.post(
            "/api/v1/bookings",
            json={
                "trip_id": trip_id,
                "passengers": [{"seat_id": seat["id"], "full_name": "Load Test Passenger"}],
            },
            headers=self._auth_headers(),
            name="/bookings [create]",
        )

    @task(2)
    def list_own_bookings(self) -> None:
        if not self.token:
            return
        self.client.get(
            "/api/v1/bookings", headers=self._auth_headers(), name="/bookings [list own]"
        )

    @task(1)
    def check_notifications(self) -> None:
        if not self.token:
            return
        self.client.get(
            "/api/v1/notifications", headers=self._auth_headers(), name="/notifications"
        )


class DriverGpsUser(HttpUser):
    """Simulates one driver's phone streaming GPS pings for an in-progress
    trip. Deliberately low-weight and slow-paced relative to the
    passenger classes — GPS pings are naturally rate-limited client-side
    (``GPS_UPDATE_MIN_INTERVAL_SECONDS``) and there is roughly one active
    stream per moving vehicle, not one per passenger. This class targets
    the rate limiter and the implausible-speed rejection path
    (``tracking:location_publish``, ADR — see
    ``app.services.tracking_service``) rather than a real authenticated
    driver login, since seeding an in-progress trip per simulated driver
    is significant extra setup for a scenario this narrow; wire in a real
    driver session (mirroring `PassengerUser.on_start`) if this needs to
    validate the authenticated path specifically rather than just the
    endpoint's throughput/rate-limit behavior.
    """

    weight = 1
    wait_time = between(4, 6)  # roughly GPS_UPDATE_MIN_INTERVAL_SECONDS's default

    @task
    def ping_unauthenticated(self) -> None:
        # No trip_id is known without a real driver session/assignment;
        # this intentionally exercises the 401 path's latency/throughput
        # under load (auth is checked before any DB work) rather than a
        # full successful ingest — see the class docstring.
        self.client.post(
            "/api/v1/driver-trips/00000000-0000-0000-0000-000000000000/location",
            json={"latitude": 5.6037, "longitude": -0.1870, "speed_kmh": "40.0"},
            name="/driver-trips/[id]/location",
        )
