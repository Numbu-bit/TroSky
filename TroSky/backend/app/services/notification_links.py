"""Where tapping a notification should take the person in the app.

``deep_link_for`` turns a notification's ``data`` into a path in the mobile
app's router form (``/bookings/{id}``), or ``None`` when there is nowhere
better than the inbox. It is worked out when the notification is read (and
when its push goes out), so notifications stored before this existed get
links too. Every notification type, its ``data`` keys and its link are
listed in ``docs/notifications.md``; keep the two in step.

A ``deep_link`` key in ``data`` wins, for notifications written with one
(demo data, and announcements that point somewhere specific).

Search links carry each stop's name beside its id, so the app can fill in
the Search form without looking the stops up. Notifications stored before
the names were added link with the ids alone.
"""

from __future__ import annotations

from collections.abc import Mapping
from typing import Any
from urllib.parse import quote, urlencode


def deep_link_for(data: Mapping[str, Any]) -> str | None:
    explicit = data.get("deep_link")
    if isinstance(explicit, str) and explicit.startswith("/"):
        return explicit

    action = data.get("action")
    kind = data.get("type")
    booking_id = data.get("booking_id")
    trip_id = data.get("trip_id")

    # Passengers
    if action == "onward_trips":
        # They've arrived, so there's no destination to fill in.
        return _search_link(origin=(data.get("stop_id"), data.get("stop_name")))
    if action == "search_again":
        return _search_link(
            origin=(data.get("origin_stop_id"), data.get("origin_stop_name")),
            destination=(data.get("destination_stop_id"), data.get("destination_stop_name")),
        )

    # Drivers
    if action in ("booking_request", "trip_assignment", "trip_cancelled") and trip_id:
        return f"/driver/trips/{trip_id}"
    if isinstance(action, str) and action.startswith("insurance_"):
        # A fleet owner's copy names the driver; fleet owners use the
        # fleet portal, which is not this app.
        return None if "driver_id" in data else "/driver/insurance"
    if kind == "documents_requested":
        # Vehicle documents go to whoever uploaded them, often a fleet owner.
        return "/driver/documents" if "driver_id" in data else None

    # Anyone
    if kind == "complaint_message" and data.get("complaint_id"):
        return f"/complaints/{data['complaint_id']}"
    if booking_id:
        return f"/bookings/{booking_id}"
    return None


def _search_link(*, origin: tuple[Any, Any], destination: tuple[Any, Any] = (None, None)) -> str:
    """``/search`` with whichever stops are known, each as its id and name
    (``origin_stop_id``, ``origin_stop_name``, then the same for the
    destination). A name is only sent with its id. Spaces are ``%20``, not
    ``+``, so every URL parser reads them the same way."""
    query: dict[str, str] = {}
    for end, (stop_id, name) in (("origin", origin), ("destination", destination)):
        if not stop_id:
            continue
        query[f"{end}_stop_id"] = str(stop_id)
        if isinstance(name, str) and name:
            query[f"{end}_stop_name"] = name
    return f"/search?{urlencode(query, quote_via=quote)}" if query else "/search"
