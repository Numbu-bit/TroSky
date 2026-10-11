"""The GPS simulator: where along the route a reported position is, which
stop ``--from-stop`` means, and staying signed in past the 15-minute access
token."""

from __future__ import annotations

import json

import httpx
import pytest
from scripts.simulate_gps import DriverAuth, km_along, path_length_km, stop_index

# Due north from Madina to Circle, about 11 km a leg.
PATH = [(5.6, -1.0), (5.7, -1.0), (5.8, -1.0)]
NAMES = ["Madina", "Legon", "Circle"]


def test_a_position_on_the_route_is_that_far_along() -> None:
    assert km_along(PATH, PATH[0]) == pytest.approx(0, abs=0.01)
    assert km_along(PATH, (5.75, -1.0)) == pytest.approx(path_length_km(PATH) * 0.75, abs=0.05)
    assert km_along(PATH, PATH[-1]) == pytest.approx(path_length_km(PATH), abs=0.01)


def test_a_position_beside_the_route_counts_where_it_is_nearest() -> None:
    beside_legon = (5.7, -0.995)  # about 550 m east of it
    assert km_along(PATH, beside_legon) == pytest.approx(path_length_km(PATH[:2]), abs=0.05)


@pytest.mark.parametrize(("wanted", "index"), [("1", 0), ("3", 2), ("leg", 1), ("CIRCLE", 2)])
def test_a_stop_by_number_or_name(wanted: str, index: int) -> None:
    assert stop_index(NAMES, wanted) == index


@pytest.mark.parametrize("wanted", ["4", "e", "Kumasi"])  # out of range, ambiguous, unknown
def test_an_unclear_stop_is_refused(wanted: str) -> None:
    with pytest.raises(SystemExit, match="no single stop"):
        stop_index(NAMES, wanted)


class FakeApi:
    """Signs in, refreshes (rotating the refresh token), and answers 401 once
    the access token has expired."""

    def __init__(self) -> None:
        self.serial = 0
        self.valid_access: set[str] = set()
        self.valid_refresh: set[str] = set()
        self.signed_in = self.refreshed = 0

    def _tokens(self) -> httpx.Response:
        self.serial += 1
        access, refresh = f"access-{self.serial}", f"refresh-{self.serial:0>20}"
        self.valid_access, self.valid_refresh = {access}, {refresh}
        return httpx.Response(200, json={"access_token": access, "refresh_token": refresh})

    def expire_access(self) -> None:
        self.valid_access.clear()

    def __call__(self, request: httpx.Request) -> httpx.Response:
        if request.url.path.endswith("/auth/login"):
            self.signed_in += 1
            return self._tokens()
        if request.url.path.endswith("/auth/refresh"):
            if json.loads(request.content).get("refresh_token") not in self.valid_refresh:
                return httpx.Response(401, json={"error": {"code": "REFRESH_TOKEN_INVALID"}})
            self.refreshed += 1
            return self._tokens()
        token = request.headers.get("Authorization", "").removeprefix("Bearer ")
        if token not in self.valid_access:
            return httpx.Response(401, json={"error": {"code": "TOKEN_EXPIRED"}})
        return httpx.Response(200, json={"ok": True})


def _client(api: FakeApi) -> httpx.Client:
    return httpx.Client(
        base_url="http://api.test/api/v1",
        transport=httpx.MockTransport(api),
        auth=DriverAuth("http://api.test/api/v1", "0245550211", "secret"),
    )


def test_it_signs_in_once_and_keeps_the_token() -> None:
    api = FakeApi()
    client = _client(api)
    for _ in range(3):
        assert client.get("/users/me").status_code == 200
    assert (api.signed_in, api.refreshed) == (1, 0)


def test_an_expired_token_is_refreshed_and_the_ping_sent_again() -> None:
    api = FakeApi()
    client = _client(api)
    client.get("/users/me")

    api.expire_access()  # 15 minutes later
    response = client.post("/driver-trips/t/location", json={"latitude": 5.6})

    assert response.status_code == 200
    assert (api.signed_in, api.refreshed) == (1, 1)
    api.expire_access()  # and again: the rotated refresh token was kept
    assert client.get("/users/me").status_code == 200
    assert (api.signed_in, api.refreshed) == (1, 2)


def test_without_a_working_refresh_token_it_signs_in_again() -> None:
    api = FakeApi()
    client = _client(api)
    client.get("/users/me")

    api.expire_access()
    api.valid_refresh.clear()  # say, the server restarted with a new key

    assert client.get("/users/me").status_code == 200
    assert (api.signed_in, api.refreshed) == (2, 0)
