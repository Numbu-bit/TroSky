# TroSky — log / crash / breadcrumb redaction

H5 of the 21 Nov 2026 pre-launch audit.

## Scope

A single [`LogRedactor`](lib/src/log_redactor.dart) surface, exported
from `package:trosky_core/trosky_core.dart` as the const
`troskyRedactor`. Three methods:

| Method | Covers |
| --- | --- |
| `redactHeaders(Map)` | Authorization, Proxy-Authorization, Cookie, Set-Cookie, X-Refresh-Token, X-Api-Key, X-Access-Token, X-Auth-Token — case-insensitive. |
| `redactUri(Uri)` | query params `token`, `access_token`, `refresh_token`, `password`, `otp`, `code`, `api_key`, `bearer`. |
| `redactString(String)` | Ghana phone numbers (`+233…`, `0[2-5]…`), emails, 4+ decimal lat/lng pairs, Bearer-shaped tokens and JWTs. |

## What this does **not** do

- It is **not** a drop-in Sentry/Crashlytics integration. No crash
  SDK is installed yet; H5 ships the sanitiser so a future SDK
  wiring can plug the redactor into its `beforeSend` /
  `beforeBreadcrumb` hook and have one list to maintain.
- It is **not** the primary analytics guard. C5's per-event
  telemetry schema in `apps/mobile/lib/app/telemetry.dart` is the
  primary gate. The redactor runs below that, for free-form text
  like Dio exception messages and tracking-service errors.
- It does **not** anonymize PII — a hashed phone number is still
  PII. Redaction replaces sensitive runs with the literal
  `<phone-redacted>` / `<email-redacted>` / `<coord-redacted>` /
  `<bearer-redacted>` / `<redacted>`.
- It does **not** cover arbitrary user-generated strings (chat
  messages, report descriptions). Those must not reach a log in
  the first place.

## Where it's used today

- `apps/mobile/lib/passenger/tracking/data/trip_tracking_service.dart` —
  on `ws_connect_failed`, the error is `troskyRedactor.redactString`'d
  before `developer.log`, so a deprecated `?token=` WS URL cannot
  leak the token through the dev log channel.

## Where it must be wired next (follow-ups)

- When Sentry / Crashlytics ships, call `redactHeaders` on any
  captured HTTP header map, `redactUri` on any captured URL, and
  `redactString` on any captured exception message / breadcrumb.
- When the next Dio interceptor that logs error details lands,
  call `redactString` on `err.message` and `redactUri` on
  `err.requestOptions.uri`.

## Testing

9 cases in `packages/trosky_core/test/log_redactor_test.dart`
cover each shape. Add a case before adding a new redaction rule.

## Explicit non-examples

- A `dropIfContains("+233")` filter was considered and refused.
  The brief calls it out: it misses other phone forms (`+1`,
  `+44`), misses tokens entirely, and drops safe events that just
  happen to carry the substring.
- Dropping every event whose string length is > 200 was also
  refused — it hides real errors while letting short PII through.
