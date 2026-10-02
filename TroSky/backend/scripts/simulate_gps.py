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

Talks only to the HTTP API (default http://127.0.0.1:8000/api/v1), so it
works against any running backend: local, docker or a hosted one.
"""

from __future__ import annotations

import argparse
import math
import sys
import time
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

    client = httpx.Client(base_url=args.base_url, timeout=60)
    login = _check(
        client.post(
            "/auth/login", json={"identifier": args.driver_phone, "password": args.password}
        ),
        "Logging in as the driver",
    )
    client.headers["Authorization"] = f"Bearer {login['access_token']}"

    trip = pick_trip(client, args.trip_id)
    trip_id = trip["trip_id"]
    route = _check(client.get(f"/routes/{trip['route_id']}"), "Loading the route")
    path = [(stop["latitude"], stop["longitude"]) for stop in route["stops"]]
    names = [stop["name"] for stop in route["stops"]]
    total_km = path_length_km(path)
    print(f"Trip {trip_id}: {route['name']} ({' -> '.join(names)}), {total_km:.1f} km")

    if trip["status"] in ("scheduled", "boarding"):
        _check(client.post(f"/driver-trips/{trip_id}/start"), "Starting the trip")
        print("Trip started.")
    elif trip["status"] == "paused":
        _check(client.post(f"/driver-trips/{trip_id}/resume"), "Resuming the trip")

    step_km = args.speed * args.speedup * args.interval / 3600
    travelled = 0.0
    next_stop = 1
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
