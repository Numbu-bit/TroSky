# Notifications

Every notification the backend sends, what its `data` carries, where tapping it should go, and
which switch silences it. For the mobile apps; keep it in step with
`app/services/notification_links.py` when a notification is added or changed.

## What a notification looks like

`GET /notifications` returns items like:

```json
{
  "id": "…",
  "topic": "booking_updates",
  "category": "transactional",
  "title": "Booking confirmed",
  "body": "Your booking TRK-6TYOVH1L is confirmed. Have a safe trip!",
  "data": { "booking_id": "8b0f…" },
  "deep_link": "/bookings/8b0f…",
  "channel_results": { "push": "sent", "sms": "sent", "email": "skipped_no_email" },
  "is_read": false,
  "read_at": null,
  "created_at": "2026-11-23T09:12:00Z"
}
```

- **`deep_link`** is a path in the app's router form (`/bookings/:bookingId` in
  `apps/mobile/lib/app/routes.dart`), or `null` when there is nowhere better than the inbox. Route
  it with `context.go(deepLink)`. A path with a query (`/search?origin_stop_id=…`) passes its
  values as query parameters. A push carries the same link as `data.deep_link` (FCM data values are
  strings).
- **`topic`** says which switch in `GET /users/me/notification-preferences` silences it.
  `category` is the older, coarser grouping; prefer `topic`.
- **`data`** keeps every id, so an app that would rather route itself still can.

## Who hears what

The in-app inbox gets every notification. Push, SMS and email go out only when **the channel's
switch and the topic's switch are both on**:

| Topic | Switch | Default | Covers |
| --- | --- | --- | --- |
| `booking_updates` | `booking_updates_enabled` | On | Bookings and trips, for passengers and drivers |
| `payment` | `payment_enabled` | On | Payments, refunds, top-ups, payouts (none sent yet) |
| `promotions` | `promotions_enabled` (`promotional_opt_in` is the same switch) | **Off** | Offers and news |
| `safety` | none: always on | On | SOS and incidents |
| `account` | none: always on | On | Password or email changed, documents, insurance, support replies |

`PATCH /users/me/notification-preferences` refuses `safety_enabled: false` and
`account_enabled: false` with a 422.

## Every notification

### Passengers

| Title | When | `data` | `deep_link` |
| --- | --- | --- | --- |
| Booking accepted | The driver accepted; pay now | `booking_id`, `action: "pay"` | `/bookings/{booking_id}` |
| Moved to another vehicle | The booking was moved to another trip | `booking_id`, `trip_id`, `action: "moved"` | `/bookings/{booking_id}` |
| Booking not accepted | No trip could take it | `booking_id`, `action: "search_again"` | `/search` |
| Booking confirmed | Payment went through | `booking_id` | `/bookings/{booking_id}` |
| Trip cancelled | The trip was cancelled | `booking_id`, `trip_id` | `/bookings/{booking_id}` |
| You're at {stop} | Got off; offers a ride on | `booking_id`, `stop_id`, `action: "onward_trips"` | `/search?origin_stop_id={stop_id}` |

All `booking_updates`.

### Drivers

| Title | When | `data` | `deep_link` |
| --- | --- | --- | --- |
| New booking request | A passenger asked for a seat | `booking_id`, `trip_id`, `action: "booking_request"` | `/driver/trips/{trip_id}` |
| New trip assigned | A trip was given to them | `trip_id`, `action: "trip_assignment"` | `/driver/trips/{trip_id}` |
| Trip accepted for you / Trip taken off you | An admin answered for them | `trip_id`, `action: "trip_assignment"` | `/driver/trips/{trip_id}` |
| Trip cancelled | A trip of theirs was cancelled | `trip_id`, `action: "trip_cancelled"` | `/driver/trips/{trip_id}` |
| Your insurance expires soon | 30, 14, 7, 3, 1 days before | `action: "insurance_reminder"`, `expiry_date`, `day` (days before) | `/driver/insurance` |
| Renew your insurance | Days 1 to 30 after expiry | `action: "insurance_warning"`, `expiry_date`, `day` (days after) | `/driver/insurance` |
| Your driver account is blocked | Day 31 after expiry | `action: "insurance_blocked"`, `expiry_date` | `/driver/insurance` |
| Your driver account is unblocked | A later date was confirmed | `action: "insurance_unblocked"`, `expiry_date` | `/driver/insurance` |
| TroSky needs new documents | An admin sent their documents back | `type: "documents_requested"`, `driver_id`, `document_types` | `/driver/documents` |

Trips and bookings are `booking_updates`; insurance and documents are `account`. The driver app has
no `/driver/trips/:tripId`, `/driver/insurance` or `/driver/documents` screens yet: these are the
paths to give them.

### Fleet owners

The insurance notifications above, about one of their drivers: the same `action` and `expiry_date`
plus `driver_id`, and `deep_link: null` (fleet owners use the fleet portal, not this app). "TroSky
needs new documents" about a vehicle carries `vehicle_id` instead of `driver_id`, also with no
link.

### Anyone

| Title | When | `data` | `deep_link` | Topic |
| --- | --- | --- | --- | --- |
| TroSky support: {subject} | Support replied to a complaint | `type: "complaint_message"`, `complaint_id`, `message_id` | `/complaints/{complaint_id}` | `account` |
| Your password was changed | `POST /users/me/change-password` | `type: "password_changed"` | null | `account` |
| Your email address was changed | `POST /users/me/change-email/confirm` | `type: "email_changed"` | null | `account` |

The app has no `/complaints/:complaintId` screen yet.

## Demo inbox on staging

The demo passenger (`0245550201`, password `TroSkyDemo!2026`, printed by
`scripts/seed_demo_data.py`) has a notification on every topic, each with a link, some read.
Their `data` also carries `"demo"`. Staging adds them on the next start after a deploy.
