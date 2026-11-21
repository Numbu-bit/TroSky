# TroSky — TLS and certificate pinning

C6 of the 21 Nov 2026 pre-launch audit. This file explains what TLS
posture the app ships with on day one, what pinning would add, and why
pinning is deliberately **not** turned on in the first store release.

## What the app enforces today

- **TLS is required.** `res/xml/network_security_config.xml` sets
  `cleartextTrafficPermitted="false"`, and the manifest also carries
  `android:usesCleartextTraffic="false"` as a second belt. Any HTTP
  or `ws://` connection is refused by the Android networking stack
  regardless of which plugin opens it.
- **Trust anchors are the system CA store only.** User-installed CAs
  are **not** honoured in release. A corporate MITM proxy or a
  sideloaded root cannot silently decrypt bearer tokens.
- **Chain and hostname verification run normally.** The default Dio
  path uses `dart:io` `HttpClient`, which checks the certificate
  chain against the trust anchors, verifies the hostname (SNI),
  rejects expired certs, and refuses weak ciphers. The Dio client
  factory `createApiClient` has no `badCertificateCallback`, no
  `SecurityContext` override, no `allowBadCertificates` flag. The
  WebSocket path uses `web_socket_channel.connect`, which goes
  through the same `HttpClient` plumbing.
- **iOS is governed by ATS.** The Info.plist has no
  `NSAppTransportSecurity` key and no `NSAllowsArbitraryLoads`
  exception. Apple's default ATS requires TLS 1.2+, forward
  secrecy, SHA-256, and 2048-bit RSA / 256-bit ECC — stricter than
  our Android config, and inherited for free.
- **Debug overrides apply only to debug builds.** The config's
  `<debug-overrides>` section trusts user-installed CAs so an engineer
  can run against mitmproxy or Charles for a local repro. Release
  builds ignore this section entirely.

## Threats this closes

| Threat | Mitigation |
| --- | --- |
| Unencrypted HTTP intercept on hostel/campus/airport Wi-Fi | Cleartext refused at the OS level. |
| User-installed corporate MITM root | `trust-anchors` listed as `system` only. |
| Expired / wrong-host / self-signed cert | Default chain + hostname validation. |
| Downgrade to TLS 1.0 / weak ciphers | ATS on iOS; Android P+ default on Android. |
| A plugin that opens its own `HttpClient` | Same OS network stack, same config. |

## Threats this does **not** close

| Threat | Why pinning would help |
| --- | --- |
| Compromise of a public CA that then mis-issues a cert for our origin. | A pinned app refuses any cert the attacker produces, even one signed by a trusted CA. |
| Compelled-order MITM against our hosting provider. | Same. |

Pinning is the standard mitigation for both. It is also operationally
expensive to get wrong.

## Why pinning is deferred

The brief for C6 says: *"If key custody or validation is unavailable,
complete TLS hardening and record pinning as a decision/blocker, not a
fake implementation."* That is this section.

To ship pinning safely we need:

1. **The actual SPKI SHA-256 pins of our live and backup leaves**,
   produced by the service operator from the current certificates on
   the server — not inferred from a `curl` run against a Render URL
   that could be served by a shared edge. We don't have provenance
   for those pins yet.
2. **A rotation procedure** that the backend developer and the owner
   both understand. A pin lands in the app's APK; rotating it needs
   a store release. Without staged backup pins baked in, any cert
   rotation on the server bricks the app for every user until a new
   release ships.
3. **A kill switch** — not an unauthenticated remote one (an
   attacker who controls the network can flip it), and not a
   compile-time flag either (a bad pin still bricks the app for a
   store release's lifetime). The common safe pattern is
   "pin-validate with a 24-hour grace on first failure, fall back to
   normal TLS with an alert" — complex to implement, needs a
   maintained library, needs tests on a rotated real cert.

Rolling out pinning without any of (1)-(3) risks a global outage
every time the backend renews its Render cert (60–90 days on free
plan). The current cost-benefit is not worth it until the service
operator owns the pin rotation.

## When pinning becomes required

Pinning should land before the first of the following:

- TroSky moves off Render's shared edge to a managed cert we rotate
  on a known cadence.
- Mobile Money / wallet-cash-out is turned on. Direct-debit against
  a user's MoMo account raises the per-session value enough that a
  CA-compromise + replay attack becomes worth attempting.
- Regulators mandate it. Ghana's Data Protection Act doesn't today;
  some EU-equivalent regimes do for financial apps.

Each is independent; whichever comes first triggers the C6 follow-up.

## Implementation outline for the follow-up PR

When the trigger lands, the follow-up (`sec/c6.1-tls-pinning`) does:

1. Add the `ssl_pinning_plugin` or `dio_certificate_pinning` package
   (whichever the owner picks). Avoid rolling our own — the pattern
   that pins only through `badCertificateCallback` **is wrong**:
   that callback only fires when the OS has *already* rejected the
   cert, so it never sees a valid-chain unpinned cert, which is the
   case that matters.
2. Register **two** SPKI pins per host: active + next-rotation
   backup. The service operator produces both.
3. Pin the API host (`api.trosky.africa`) and the WS host (same
   origin for us today). Any tile/CDN hosts we use remain
   unpinned — they serve public content.
4. Add rotation rehearsal: a staging test where the server swaps
   active↔backup, the app still opens, and a backend alert fires
   when the backup pin becomes the active one.
5. Add a staged rollout — 10% of installs first, 100% after one
   normal cert renewal cycle.

No part of the app is written speculatively today, so there is no
dead code in C6 for a reader to think is "the pinning" after reading
this doc.

## Verifying the current TLS posture

```sh
# Confirm the manifest + XML are wired
aapt dump xmltree app-release.apk AndroidManifest.xml \
  | grep -E "usesCleartextTraffic|networkSecurityConfig"
unzip -p app-release.apk res/xml/network_security_config.xml

# From a device with mitmproxy user CA installed, attempt
# /api/v1/users/me — the request must fail with a TLS error, not
# surface the bearer token. (Release build only.)

# Manually try an http:// swap in env/staging.json locally; Dio
# raises a network error at startup because cleartext is refused.
```
