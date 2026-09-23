# ADR-0003: Sandbox-first provider adapters; unverified vendor integrations raise, never fabricate

## Status

Accepted (Phase 1, consistently applied through Phase 10).

## Context

This backend integrates with SMS, email, object storage, mobile-money
payment channels, push notifications, and mapping/routing providers — and
this environment has no real credentials for any of them. Two bad options
present themselves: (1) skip building the adapter entirely and leave a
`NotImplementedError` everywhere, or (2) guess at a vendor's request/
response shape from general knowledge and ship something that *looks*
like an integration but has never been checked against a real API
contract. Neither is acceptable — the first makes the codebase
untestable end-to-end, the second is the "fake implementation" the
project's own requirements explicitly rule out.

## Decision

Every external integration gets a `PROTOCOL` interface
(`app/providers/<category>/base.py`), and every category gets a
**sandbox** adapter — a real, working, in-memory implementation
(`SandboxSmsProvider`, `SandboxPaymentProvider`, `SandboxPushProvider`,
...) that behaves like the real thing from the calling code's
perspective (returns success/failure results, supports the same
lifecycle) but never makes a network call. Sandbox adapters are the
default in every environment this codebase has actually run in
(`.env.test`, local `docker-compose.yml` dev defaults).

Beyond that, a **real** adapter gets built only where the vendor's API
contract could actually be verified against public, current
documentation — Twilio (SMS), SES/SMTP (email), S3 (storage), MTN MoMo
Collections (payments), Firebase Cloud Messaging (push). Where a vendor's
contract *isn't* independently verifiable in this environment — Hubtel
SMS, Telecel Cash, AirtelTigo Money, a generic card gateway,
Google/Mapbox/HERE routing, MTN MoMo Disbursements — the adapter is a
named, documented skeleton that **raises `ProviderError` with a clear
message** pointing at what's missing, rather than guessing at request/
response shapes. See `app/providers/sms/production.py::HubtelSmsProvider`
(the original instance of this pattern, Phase 2) and
`app/providers/payments/unavailable.py` /
`app/providers/maps/unavailable.py` (the same pattern generalized,
Phases 6 and 8).

## Consequences

- Every domain feature built on top of a provider (booking payments,
  ticket QR codes, SOS SMS fan-out, driver push notifications) is fully
  implemented, tested, and demonstrably correct via its sandbox path —
  none of it is blocked on real credentials existing.
- Flipping `PAYMENTS_ACTIVE_PROVIDER` (or the equivalent per-category
  setting) from `sandbox` to a real provider in production is the *only*
  step needed to go live with that channel — no code changes, because
  the factory (`get_payment_provider`, `get_sms_provider`, ...) already
  resolves to the real adapter class when configured to.
- The explicit cost: three payment channels, one map/routing category,
  and MoMo disbursements are real, named gaps in production capability —
  not hidden ones. `docs/production-readiness-checklist.md` collects
  them in one place; each phase's `CHANGELOG.md` entry explains the
  specific reasoning at the point it was decided.
