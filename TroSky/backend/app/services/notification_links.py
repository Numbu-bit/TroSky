"""Where tapping a notification should take the person in the app.

``deep_link_for`` turns a notification's ``data`` into a path in the mobile
app's router form (``/bookings/{id}``), or ``None`` when there is nowhere
better than the inbox. It is worked out when the notification is read (and
when its push goes out), so notifications stored before this existed get
links too. Every notification type, its ``data`` keys and its link are
listed in ``docs/notifications.md``; keep the two in step.

A ``deep_link`` key in ``data`` wins, for notifications written with one
(demo data, and announcements that point somewhere specific).
"""

from __future__ import annotations

from collections.abc import Mapping
from typing import Any
from urllib.parse import urlencode


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
        stop_id = data.get("stop_id")
        return f"/search?{urlencode({'origin_stop_id': stop_id})}" if stop_id else "/search"
    if action == "search_again":
        return "/search"

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
