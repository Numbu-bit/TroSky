# TroSky — sensitive-screen capture protection

H1 of the 21 Nov 2026 pre-launch audit.

## What this covers

- **Android**: `FLAG_SECURE` set on the activity window while a
  `TroskySecureScreen` widget is mounted. Screenshots, screen
  recordings, and the app-switcher thumbnail are blanked out. The
  flag is reference-counted so a nested sensitive screen popping
  does not strip protection from its sensitive parent.
- **iOS**: app-switcher snapshots are covered by an opaque navy
  view attached in `AppDelegate.applicationWillResignActive` and
  removed on `applicationDidBecomeActive`. iOS has **no**
  screenshot-prevention API; Apple's recommendation is snapshot
  masking only. A device recording screen capture while the user
  is in the app will still record.
- **Shell overlay**: `TroskyPrivacyCover` at the app root watches
  `AppLifecycleState` and paints a second navy cover whenever the
  app is backgrounding AND at least one `TroskySecureScreen` is
  mounted. This catches the Flutter frame between
  `applicationWillResignActive` and the OS snapshot.

## What this does *not* cover

- A separate recording device filming the phone screen.
- iOS screenshots taken from inside the running app (impossible to
  block on iOS).
- Rooted / jailbroken devices.
- Content captured before `TroskySecureScreen` mounts (the widget
  acquires the flag in a `postFrameCallback`, so the first frame
  can still be captured if the OS snapshot fires in the <16 ms
  window). Mitigated in practice by the shell's lifecycle cover.

## Screens covered in this PR

- `apps/mobile/lib/passenger/trips/presentation/ticket_screen.dart` — offline QR tickets
- `apps/mobile/lib/entry/auth/presentation/verify_code_screen.dart` — OTP entry
- `apps/mobile/lib/passenger/account/presentation/reset_password_screen.dart` — Request + New Password
- `apps/mobile/lib/passenger/account/presentation/personal_info_screen.dart` — PII edit
- `apps/mobile/lib/passenger/booking/presentation/payment_screen.dart` — Payment flow

## Screens to add in a follow-up

- Wallet `+ Add method` sheet (modal; needs a sheet-level wrapper
  that participates in the reference count so parent wallet screen
  isn't prematurely unprotected).
- Any future secrets flow (change-password, 2FA setup).

## Adding a new sensitive screen

1. Add the import:
   ```dart
   import '../../../app/secure_window.dart';
   ```
2. Wrap the top-level `build` return with
   `TroskySecureScreen(child: …)`. Close the extra `)` at the end
   of the method.
3. Done — no other wiring required. The flag is
   reference-counted; nested wraps are safe.

## Verifying on device

Android (needs `adb`, `com.trosky.app` installed):

```sh
# Open a sensitive screen (e.g. Ticket QR). Then:
adb shell screencap -p /sdcard/t.png && adb pull /sdcard/t.png
# Expect: a black image, not the QR.

# App switcher thumbnail:
adb shell input keyevent KEYCODE_APP_SWITCH
# Expect: black card, not a visible thumbnail.
```

iOS (needs a device, cannot verify in Simulator):

1. Open a sensitive screen.
2. Swipe up / double-tap home to open the switcher.
3. Expect: the TroSky card is a solid navy, not the sensitive
   content.

## Interaction with other audit items

- **H3** (optional app lock): depends on this file. The biometric
  prompt is always shown over a protected window.
- **M4** (per-user cleanup on sign-out): orthogonal; this covers
  snapshots, M4 covers persisted state.

## Native integration details

- Android channel name: `com.trosky.app/secure_window`
- Android channel methods: `"on"` and `"off"`, each returns
  `null`. See `MainActivity.kt`.
- iOS: no channel. The native cover view uses a private tag
  `1_729_364_215` so it's distinct from any Flutter-owned view.
- No pub.dev dependency added. Rolling our own avoids the churn
  of maintaining an external plugin and keeps the surface narrow.
