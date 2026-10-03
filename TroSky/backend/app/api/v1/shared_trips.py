"""Live-trip links opened by family and friends: no account needed.

``GET /api/v1/shared-trips/{token}`` is the data; ``GET /share/{token}`` is a
small page that shows it in any browser, for people without the app. Both
answer 404 for a link that was never valid and 410 once it has expired or
the booking was cancelled.
"""

from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, Path
from fastapi.responses import HTMLResponse

from app.api.common_dependencies import DbSession, RedisClient
from app.core.config import get_settings
from app.core.ratelimit import rate_limit
from app.schemas.trip import SharedTripLocationResponse, SharedTripResponse, TripVehicleResponse
from app.services.trip_share_service import TripShareService, first_name

router = APIRouter()
page_router = APIRouter(include_in_schema=False)

Token = Annotated[str, Path(min_length=20, max_length=80, pattern=r"^[A-Za-z0-9_-]+$")]


def get_trip_share_service(db: DbSession, redis: RedisClient) -> TripShareService:
    return TripShareService(db, redis)


TripShareServiceDep = Annotated[TripShareService, Depends(get_trip_share_service)]


@router.get(
    "/{token}",
    response_model=SharedTripResponse,
    dependencies=[Depends(rate_limit("shared_trips:read"))],
)
async def get_shared_trip(token: Token, service: TripShareServiceDep) -> SharedTripResponse:
    """A shared trip as its link shows it. Public: the token is the key."""
    shared = await service.open_link(token)
    summary = shared.summary
    vehicle = None
    if summary.vehicle_registration_number and summary.vehicle_type:
        vehicle = TripVehicleResponse(
            registration_number=summary.vehicle_registration_number,
            type=summary.vehicle_type,
            make_model=summary.vehicle_make_model,
            capacity=summary.vehicle_capacity,
        )
    location = None
    if shared.location is not None:
        location = SharedTripLocationResponse(
            latitude=shared.location.latitude,
            longitude=shared.location.longitude,
            updated_at=shared.location.recorded_at,
            is_stale=shared.location.is_stale,
        )
    return SharedTripResponse(
        trip_id=summary.trip_id,
        status=summary.status,
        route_name=summary.route_name,
        passenger_first_name=shared.passenger_first_name,
        driver_first_name=first_name(summary.driver_name),
        boarding_stop_name=shared.boarding_stop_name,
        alighting_stop_name=shared.alighting_stop_name,
        scheduled_departure_at=summary.scheduled_departure_at,
        scheduled_arrival_at=summary.scheduled_arrival_at,
        vehicle=vehicle,
        location=location,
        minutes_to_dropoff=shared.minutes_to_dropoff,
        expires_at=shared.expires_at,
    )


@page_router.get("/share/{token}", response_class=HTMLResponse)
async def shared_trip_page(token: Token) -> HTMLResponse:
    # The token only reaches the page through the regex-checked path
    # parameter above, so it is safe to embed; everything shown is fetched
    # by the page and written with textContent, never as HTML.
    page = _PAGE.replace("__API__", get_settings().API_PREFIX).replace("__TOKEN__", token)
    return HTMLResponse(page)


_PAGE = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex">
<title>TroSky live trip</title>
<style>
  :root { --bg:#f6f7f9; --card:#fff; --ink:#14181f; --muted:#5b6472; --accent:#0a7d4f; }
  @media (prefers-color-scheme: dark) {
    :root { --bg:#0f1216; --card:#181c22; --ink:#e8ebf0; --muted:#9aa3b2; --accent:#3ccf8e; }
  }
  body { margin:0; font:16px/1.5 system-ui, sans-serif; background:var(--bg); color:var(--ink); }
  main { max-width:30rem; margin:0 auto; padding:1.25rem 1rem; }
  .card { background:var(--card); border-radius:14px; padding:1.1rem 1.2rem; margin-bottom:.9rem; }
  h1 { font-size:1.25rem; margin:.2rem 0 .1rem; }
  .muted { color:var(--muted); font-size:.92rem; }
  .big { font-size:2rem; font-weight:700; color:var(--accent); }
  dl { display:grid; grid-template-columns:auto 1fr; gap:.3rem .9rem; margin:0; }
  dt { color:var(--muted); }
  dd { margin:0; }
  a.button { display:inline-block; margin-top:.6rem; padding:.55rem .9rem; border-radius:10px;
             background:var(--accent); color:#fff; text-decoration:none; font-weight:600; }
</style>
</head>
<body>
<main>
  <div class="card">
    <div class="muted">TroSky live trip</div>
    <h1 id="headline">Loading&hellip;</h1>
    <div class="muted" id="route"></div>
  </div>
  <div class="card" id="eta-card" hidden>
    <div class="muted" id="eta-label"></div>
    <div class="big" id="eta"></div>
    <div class="muted" id="seen"></div>
    <a class="button" id="map" target="_blank" rel="noopener" hidden>Open in Google Maps</a>
  </div>
  <div class="card">
    <dl>
      <dt>From</dt><dd id="from"></dd>
      <dt>To</dt><dd id="to"></dd>
      <dt>Departs</dt><dd id="departs"></dd>
      <dt>Vehicle</dt><dd id="vehicle"></dd>
      <dt>Driver</dt><dd id="driver"></dd>
    </dl>
  </div>
  <p class="muted" id="footer"></p>
</main>
<script>
const token = "__TOKEN__";
const $ = (id) => document.getElementById(id);
const statusText = {
  scheduled: "hasn't set off yet", boarding: "is boarding", in_progress: "is on the way",
  paused: "has stopped for a moment", completed: "has arrived", cancelled: "was cancelled",
};
function time(iso) {
  return new Date(iso).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
}
async function refresh() {
  let response;
  try { response = await fetch("__API__/shared-trips/" + token, { cache: "no-store" }); }
  catch (e) { $("footer").textContent = "Can't reach TroSky. Retrying..."; return true; }
  if (response.status === 404 || response.status === 410) {
    $("headline").textContent = response.status === 410
      ? "This trip is no longer being shared." : "This link isn't valid.";
    $("route").textContent = ""; $("eta-card").hidden = true;
    return false;
  }
  if (!response.ok) { $("footer").textContent = "Couldn't refresh. Retrying..."; return true; }
  const trip = await response.json();
  const who = trip.passenger_first_name || "Your contact";
  $("headline").textContent = who + "'s trip " + (statusText[trip.status] || trip.status);
  $("route").textContent = trip.route_name;
  $("from").textContent = trip.boarding_stop_name;
  $("to").textContent = trip.alighting_stop_name;
  $("departs").textContent = time(trip.scheduled_departure_at);
  $("vehicle").textContent = trip.vehicle
    ? [trip.vehicle.make_model, trip.vehicle.registration_number].filter(Boolean).join(" · ")
    : "Not assigned yet";
  $("driver").textContent = trip.driver_first_name || "Not assigned yet";
  const where = trip.location;
  $("eta-card").hidden = !where;
  if (where) {
    $("eta-label").textContent = "Arrives at " + trip.alighting_stop_name + " in about";
    $("eta").textContent = trip.minutes_to_dropoff === null ? "—"
      : trip.minutes_to_dropoff + " min";
    $("seen").textContent = (where.is_stale ? "Last seen " : "Updated ") + time(where.updated_at);
    const map = $("map");
    map.href = "https://www.google.com/maps?q=" + where.latitude + "," + where.longitude;
    map.hidden = false;
  }
  $("footer").textContent = "Link valid until " + new Date(trip.expires_at).toLocaleString();
  return trip.status !== "completed" && trip.status !== "cancelled";
}
(async function loop() { if (await refresh()) setTimeout(loop, 15000); })();
</script>
</body>
</html>
"""
