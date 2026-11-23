# TroSky — optional app lock

H3 of the 21 Nov 2026 pre-launch audit. This runbook describes the
controller that ships in this PR and the UI integration that lands
in a stacked follow-up.

## Ships in this PR

- `apps/mobile/lib/app/app_lock.dart`: `AppLockController`
  (Riverpod `Notifier`), `AppLockState`, `appLockProvider`.
- Per-user `SharedPreferences` key `app_lock.enabled.<userId>`.
- `local_auth: ^2.3.0` dependency added.
- Policy:
  - Default off.
  - Enabling or disabling requires a successful biometric prompt
    (a thief cannot simply toggle it off).
  - 30 s resume grace — a casual notification tap doesn't
    re-prompt, but a 30 s hand-off does.
  - Lock state never persists an "unlocked" flag.
  - `onSignOut()` resets to `disabled` immediately. Full per-user
    pref cleanup is M4's job.
  - `supported` returns false where the OS can't prompt (iOS
    simulator, web, rooted device without biometrics).

## Deferred to the stacked follow-up PR

- The lock screen widget that paints over the subtree when
  `state == locked` and offers an unlock button + SOS shortcut.
- Wiring the controller to `AppLifecycleState` via a
  `WidgetsBindingObserver` at the app root.
- Profile → Preferences → "App lock" toggle row.
- Localized strings for the prompts.

The follow-up PR is scoped to touch only presentation; this PR
owns the controller so a reviewer can evaluate the policy before
the UI lands.

## Scope limits per brief

- **Not a substitute for backend auth.** The backend is
  authoritative for money movements, session validity, and
  anything else that matters. The lock is a local-device hurdle.
- **SOS reachability.** The gate widget (follow-up) exposes a
  "Call 112" shortcut that works without unlocking. Nothing in
  this controller blocks SOS.
- **No bypass by local boolean.** `onSignOut()` is the only way
  to clear the per-user pref outside the biometric-gated
  `enable()`/`disable()` methods.

## Testing

Covered in a widget test in the stacked follow-up (the controller
alone can't be unit-tested without mocking `LocalAuthentication`,
which is the follow-up's job to wire).

CI in this PR asserts:
- the file exists with the required public API,
- `local_auth` is declared in the mobile pubspec,
- the runbook ships.
