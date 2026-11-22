# TroSky — WebSocket credential transport

H4 of the 21 Nov 2026 pre-launch audit.

## Status: blocked on backend B5

See `docs/backend-requests.md` → **B5** for the detailed ask.
Until the backend accepts header-based or short-lived-ticket
auth on the tracking socket, the frontend cannot change the
transport without silently falling back to the raw bearer query
somewhere. The brief explicitly forbids a silent fallback.

## What exists today

- `apps/mobile/lib/passenger/tracking/data/trip_tracking_service.dart`
  opens `wss://…/ws/trips/{id}/track?token=<access_token>`. This
  is the documented contract on `frontend/CLAUDE.md`.
- H5's `LogRedactor.redactUri` already redacts `token`,
  `access_token`, `refresh_token` and `code` query params, so a
  crash breadcrumb cannot leak the value through the frontend's
  own logs. It does not help with proxy / CDN / edge logs.

## What H4 ships in this PR

- `docs/backend-requests.md` → **B5** detailing the ask, the
  rejected designs, and the frontend migration plan once the
  backend lands it.
- This runbook.
- A CI guardrail: `ws-transport-check` fails any future PR that
  spells a new `?token=` or `?access_token=` string inside a
  WebSocket URL outside the one documented call site. New code
  cannot add a second raw-bearer WS URL by accident.

## Frontend migration plan (after backend B5 lands)

1. Update `wsBaseUrl` consumers to call the agreed transport
   (header or ticket).
2. Delete the `?token=` line in `frontend/CLAUDE.md`'s "Key
   contracts" section.
3. Add a unit test proving a replayed ticket is refused.
4. Owner on-device: verify tracking still connects after the
   client migration.

## Scope boundaries, honestly

- `Sec-WebSocket-Protocol` is **less** logged than a query but
  still sometimes captured. H4 does not promise it is a complete
  fix; the short-lived ticket is the more resilient option.
- Rotating the access-token lifetime shorter (currently 15 min)
  reduces the blast radius if a URL does leak. That is an
  independent backend tune separate from B5.
