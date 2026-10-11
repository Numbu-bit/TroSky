"""Drive a trip along its route by sending GPS pings, the way the driver app
would, so live tracking, "vehicles nearby", search ETAs and shared trip links
show real movement.

    python -m scripts.simulate_gps                     # demo driver Kofi's next trip
    python -m scripts.simulate_gps --trip-id <uuid> --speedup 3 --end
    make simulate-gps ARGS="--driver-phone 0245550212"

It logs in as the driver, picks the trip (one already in progress, else the
soonest scheduled one), starts it, then moves along the route's stops in
straight lines, pinging every ``--interval`` seconds. ``--speedup`` covers
ground faster than real time; the backend rejects pings implying more than
140 km/h, so speed x speedup is capped below that. ``--end`` ends the trip
on arrival, which completes its bookings and credits the driver.

A trip already on the road carries on from where it was last reported, so
the simulator can be stopped and run again. ``--from-stop`` starts at a
given stop instead (its number along the route, from 1, or part of its
name). The access token lasts 15 minutes; it is refreshed as it runs out.

Talks only to the HTTP API (default http://127.0.0.1:8000/api/v1), so it
works against any running backend: local, docker or a hosted one.
"""

from __future__ import annotations

import argparse
import math
import sys
import time
from collections.abc import Generator
from datetime import UTC, datetime
from itertools import pairwise
from typing import Any

import httpx

DEMO_DRIVER_PHONE = "0245550211"
DEMO_PASSWORD = "TroSkyDemo!2026"  # noqa: S105 - the demo seed's documented password
MAX_APPARENT_KMH = 130.0  # the backend rejects pings implying more than 140 km/h
EARTH_RADIUS_KM = 6371.0088

Point = tuple[float, float]


def haversine_km(a: Point, b: Point) -> float:
    lat1, lng1, lat2, lng2 = map(math.radians, (*a, *b))
    h = (
        math.sin((lat2 - lat1) / 2) ** 2
        + math.cos(lat1) * math.cos(lat2) * math.sin((lng2 - lng1) / 2) ** 2
    )
    return 2 * EARTH_RADIUS_KM * math.asin(math.sqrt(h))


def bearing_degrees(a: Point, b: Point) -> float:
    lat1, lng1, lat2, lng2 = map(math.radians, (*a, *b))
    x = math.sin(lng2 - lng1) * math.cos(lat2)
    y = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(lng2 - lng1)
    return (math.degrees(math.atan2(x, y)) + 360) % 360


def point_along(path: list[Point], km: float) -> tuple[Point, float]:
    """The point ``km`` along ``path`` (straight lines between points), and
    the heading there. Past the end, the last point."""
    for a, b in pairwise(path):
        leg = haversine_km(a, b)
        if km <= leg and leg > 0:
            t = km / leg
            return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t), bearing_degrees(a, b)
        km -= leg
    return path[-1], bearing_degrees(path[-2], path[-1])


def path_length_km(path: list[Point]) -> float:
    return sum(haversine_km(a, b) for a, b in pairwise(path))


def km_along(path: list[Point], point: Point) -> float:
    """How far along ``path`` the point nearest ``point`` is: where a vehicle
    last reported there is on its route."""
    best_distance, best_km, start_km = math.inf, 0.0, 0.0
    for a, b in pairwise(path):
        leg = haversine_km(a, b)
        # Flat projection onto the leg: close enough over a few kilometres.
        scale = math.cos(math.radians(a[0]))
        ax, ay = (b[1] - a[1]) * scale, b[0] - a[0]
        px, py = (point[1] - a[1]) * scale, point[0] - a[0]
        length_sq = ax * ax + ay * ay
        t = 0.0 if length_sq == 0 else max(0.0, min(1.0, (px * ax + py * ay) / length_sq))
        nearest = (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)
        distance = haversine_km(nearest, point)
        if distance < best_distance:
            best_distance, best_km = distance, start_km + leg * t
        start_km += leg
    return best_km


class DriverAuth(httpx.Auth):
    """Signs each request in as the driver. When the access token has run
    out (401), it is refreshed, or failing that the driver signs in again,
    and the request is sent once more: a trip lasts longer than a token."""

    requires_response_body = True

    def __init__(self, base_url: str, phone: str, password: str) -> None:
        self._base_url = base_url.rstrip("/")
        self._phone, self._password = phone, password
        self._access = self._refresh = ""

    def sign_in(self) -> httpx.Request:
        return httpx.Request(
            "POST",
            f"{self._base_url}/auth/login",
            json={"identifier": self._phone, "password": self._password},
        )

    def keep(self, response: httpx.Response) -> bool:
        if response.status_code != 200:
            return False
        tokens = response.json()
        self._access, self._refresh = tokens["access_token"], tokens["refresh_token"]
        return True

    def auth_flow(self, request: httpx.Request) -> Generator[httpx.Request, httpx.Response, None]:
        if not self._access:
            self.keep((yield self.sign_in()))
        request.headers["Authorization"] = f"Bearer {self._access}"
        response = yield request
        if response.status_code != 401:
            return
        refreshed = yield httpx.Request(
            "POST", f"{self._base_url}/auth/refresh", json={"refresh_token": self._refresh}
        )
        if not self.keep(refreshed) and not self.keep((yield self.sign_in())):
            return  # the caller reports the failure
        print("  (signed in again: the access token had run out)")
        request.headers["Authorization"] = f"Bearer {self._access}"
        yield request


def stop_index(names: list[str], wanted: str) -> int:
    """A stop given by its number along the route (from 1) or part of its
    name."""
    if wanted.isdigit() and 1 <= int(wanted) <= len(names):
        return int(wanted) - 1
    matches = [i for i, name in enumerate(names) if wanted.lower() in name.lower()]
    if len(matches) != 1:
        sys.exit(f"--from-stop {wanted!r}: no single stop matches. Stops: {', '.join(names)}")
    return matches[0]


def _check(response: httpx.Response, what: str) -> Any:
    if response.status_code >= 300:
        sys.exit(f"{what} failed: {response.status_code} {response.text}")
    return response.json() if response.content else None


def pick_trip(client: httpx.Client, trip_id: str | None) -> dict[str, Any]:
    if trip_id:
        return {"trip_id": trip_id, **_check(client.get(f"/trips/{trip_id}"), "Loading the trip")}
    for statuses in ("in_progress,paused,boarding", "scheduled"):
        trips = _check(
            client.get(
                "/drivers/me/trips",
                params={"status": statuses, "date": datetime.now(UTC).date().isoformat()},
            ),
            "Listing the driver's trips",
        )["items"]
        upcoming = [
            trip
            for trip in trips
            if statuses != "scheduled"
            or _parse(trip["scheduled_departure_at"]) >= datetime.now(UTC)
        ]
        if upcoming:
            first: dict[str, Any] = upcoming[0]
            return first
    sys.exit("This driver has no trip left today. Pass --trip-id, or run `make seed-demo`.")


def _parse(value: str) -> datetime:
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--base-url", default="http://127.0.0.1:8000/api/v1")
    parser.add_argument("--driver-phone", default=DEMO_DRIVER_PHONE)
    parser.add_argument("--password", default=DEMO_PASSWORD)
    parser.add_argument("--trip-id", help="Default: the driver's current or next trip today.")
    parser.add_argument("--interval", type=float, default=5.0, help="Seconds between pings (>=2).")
    parser.add_argument("--speed", type=float, default=30.0, help="Vehicle speed in km/h.")
    parser.add_argument("--speedup", type=float, default=1.0, help="Cover ground N times faster.")
    parser.add_argument("--end", action="store_true", help="End the trip on arrival.")
    parser.add_argument(
        "--from-stop",
        help="Start at this stop (number from 1, or part of its name). Default: the first "
        "stop, or where a trip already on the road was last reported.",
    )
    args = parser.parse_args(argv)
    # Route names contain arrows; a Windows console or pipe may not print them.
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(errors="replace")

    if args.interval < 2:
        parser.error("--interval must be at least 2 seconds (30 pings a minute at most).")
    if args.speed * args.speedup > MAX_APPARENT_KMH:
        parser.error(
            f"--speed x --speedup is {args.speed * args.speedup:.0f} km/h; the backend rejects "
            f"anything above 140, so keep it under {MAX_APPARENT_KMH:.0f}."
        )

    client = httpx.Client(
        base_url=args.base_url,
        timeout=60,
        auth=DriverAuth(args.base_url, args.driver_phone, args.password),
    )
    _check(client.get("/users/me"), "Logging in as the driver")

    trip = pick_trip(client, args.trip_id)
    trip_id = trip["trip_id"]
    route = _check(client.get(f"/routes/{trip['route_id']}"), "Loading the route")
    path = [(stop["latitude"], stop["longitude"]) for stop in route["stops"]]
    names = [stop["name"] for stop in route["stops"]]
    total_km = path_length_km(path)
    print(f"Trip {trip_id}: {route['name']} ({' -> '.join(names)}), {total_km:.1f} km")

    # Where a trip already on the road was last reported: going anywhere far
    # from there at once is a jump the backend rejects as implausible.
    last_km: float | None = None
    if trip["status"] in ("in_progress", "paused"):
        last = client.get(f"/trips/{trip_id}/location")
        if last.status_code == 200:
            where = last.json()
            last_km = km_along(path, (where["latitude"], where["longitude"]))
            seconds = (datetime.now(UTC) - _parse(where["recorded_at"])).total_seconds()

    travelled = last_km or 0.0
    if args.from_stop:
        start = stop_index(names, args.from_stop)
        travelled = path_length_km(path[: start + 1])
        if last_km is not None:
            jump = abs(travelled - last_km)
            if jump / max(seconds, 1) * 3600 > MAX_APPARENT_KMH:
                sys.exit(
                    f"This trip is on the road, last reported {last_km:.2f} km along: jumping "
                    f"{jump:.2f} km to {names[start]} now would be rejected as implausible. "
                    "Leave out --from-stop to carry on from there, or use it on a trip that "
                    "has not started."
                )
        print(f"Starting at {names[start]}, {travelled:.2f} km along.")
    elif last_km is not None:
        print(f"Carrying on from the last position, {travelled:.2f} km along.")

    if trip["status"] in ("scheduled", "boarding"):
        _check(client.post(f"/driver-trips/{trip_id}/start"), "Starting the trip")
        print("Trip started.")
    elif trip["status"] == "paused":
        _check(client.post(f"/driver-trips/{trip_id}/resume"), "Resuming the trip")

    step_km = args.speed * args.speedup * args.interval / 3600
    next_stop = 1
    while next_stop < len(path) and travelled >= path_length_km(path[: next_stop + 1]):
        next_stop += 1  # stops already behind
    while True:
        (latitude, longitude), heading = point_along(path, travelled)
        response = client.post(
            f"/driver-trips/{trip_id}/location",
            json={
                "latitude": round(latitude, 6),
                "longitude": round(longitude, 6),
                "speed_kmh": f"{args.speed:.2f}",
                "heading_degrees": f"{heading:.2f}",
                "accuracy_meters": "8.00",
            },
        )
        if response.status_code == 429:
            print("Rate limited; slowing down.")
            time.sleep(args.interval * 2)
            continue
        _check(response, "Sending a location ping")
        while next_stop < len(path) and travelled >= path_length_km(path[: next_stop + 1]):
            print(f"  passing {names[next_stop]}")
            next_stop += 1
        print(f"  {travelled:5.2f} / {total_km:.2f} km  ({latitude:.5f}, {longitude:.5f})")
        if travelled >= total_km:
            break
        travelled = min(travelled + step_km, total_km)
        time.sleep(args.interval)

    print(f"Arrived at {names[-1]}.")
    if args.end:
        _check(
            client.post(
                f"/driver-trips/{trip_id}/end",
                json={"latitude": round(path[-1][0], 6), "longitude": round(path[-1][1], 6)},
            ),
            "Ending the trip",
        )
        print("Trip ended: bookings completed and the driver credited.")


if __name__ == "__main__":
    main()
