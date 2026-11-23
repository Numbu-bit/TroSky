// H3 of the 21 Nov 2026 pre-launch audit — optional local app lock.
//
// Design principles the brief pins us to:
//   - Default off; offered unobtrusively in Profile preferences.
//   - Authenticate BEFORE enabling or disabling the setting (so a
//     snatcher cannot simply turn the lock off).
//   - Per-user preference, persisted alongside the session.
//   - Cold-start requires unlock; resume requires unlock after a
//     grace period (short enough that a casual glance into the app
//     switcher isn't a free pass).
//   - No reusable "unlocked" boolean survives a sign-out; the
//     backend remains authoritative for anything that moves money.
//   - SOS must stay reachable from the lock screen — a passenger
//     mid-incident must not have to type a password to call for
//     help.
//
// This file ships the controller + per-user preference + resume
// clock. The subtree-level gate widget and the Profile → App lock
// row are wired by a stacked follow-up PR; the controller and its
// CI/runbook assertions are the ship-blocker piece H3 owns.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trosky_auth/trosky_auth.dart';

/// How long after a `resumed` → `inactive` → `resumed` round-trip the
/// app can stay unlocked without re-prompting. 30 s keeps a casual
/// notification tap from re-prompting, but blocks "opened the switcher
/// and someone else grabbed the phone" within the window.
const Duration _resumeGrace = Duration(seconds: 30);

/// The lock's effective state. `disabled` means the user turned the
/// toggle off (or never turned it on). `unlocked` means the user has
/// authenticated this session AND the resume grace hasn't elapsed.
/// `locked` means content is gated behind a biometric prompt.
enum AppLockState { disabled, locked, unlocked }

/// Shared-preferences key for the "app lock enabled" boolean, keyed by
/// user id. A sign-out clears every user-scoped pref (M4, separate PR)
/// — this file never persists an "unlocked" flag.
String _prefKey(String userId) => 'app_lock.enabled.$userId';

class AppLockController extends Notifier<AppLockState> {
  LocalAuthentication? _auth;
  Timer? _graceTimer;

  @override
  AppLockState build() {
    _auth = LocalAuthentication();
    // The initial state is derived from the per-user pref. Mounting
    // this provider after a successful sign-in re-reads the pref.
    final userId = _currentUserId(ref);
    if (userId == null) return AppLockState.disabled;
    // Start locked if the user turned it on previously; the UI's gate
    // widget prompts on first paint.
    unawaited(_hydrate(userId));
    return AppLockState.disabled;
  }

  /// Can the device prompt at all? false on rooted devices without a
  /// biometric enrolled, in the iOS simulator, on web/desktop, etc. The
  /// UI uses this to grey out the Profile toggle instead of leaving it
  /// tappable-but-broken.
  Future<bool> get supported async {
    final auth = _auth;
    if (auth == null) return false;
    try {
      final can = await auth.canCheckBiometrics;
      final isSupported = await auth.isDeviceSupported();
      return can && isSupported;
    } on PlatformException {
      return false;
    }
  }

  /// Turns the lock ON for the current user. Requires a successful
  /// biometric now (otherwise a thief could enable *and* immediately
  /// use the app). Returns true on success, false if the user
  /// cancelled or the hardware refused.
  Future<bool> enable() async {
    final userId = _currentUserId(ref);
    if (userId == null) return false;
    final ok = await _promptBiometric(reason: 'Enable TroSky app lock');
    if (!ok) return false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey(userId), true);
    state = AppLockState.unlocked;
    _armGrace();
    return true;
  }

  /// Turns the lock OFF. Also requires a successful biometric — the
  /// toggle is not a shortcut.
  Future<bool> disable() async {
    final userId = _currentUserId(ref);
    if (userId == null) return false;
    final ok = await _promptBiometric(reason: 'Disable TroSky app lock');
    if (!ok) return false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey(userId), false);
    state = AppLockState.disabled;
    return true;
  }

  /// Called by the gate widget on `AppLifecycleState.resumed` and on
  /// first paint. Prompts if the lock is enabled and the grace window
  /// has elapsed; otherwise a no-op.
  Future<void> maybePromptOnResume() async {
    if (state == AppLockState.disabled || state == AppLockState.unlocked) {
      return;
    }
    final ok = await _promptBiometric(reason: 'Unlock TroSky');
    if (ok) {
      state = AppLockState.unlocked;
      _armGrace();
    }
  }

  /// Called by the gate widget on `AppLifecycleState.inactive` /
  /// `paused`. Starts the grace timer; if the user returns within
  /// the window, no re-prompt.
  void noteBackgrounding() {
    if (state != AppLockState.unlocked) return;
    _armGrace();
  }

  /// Hard reset on sign-out. Never persists a "unlocked" flag that
  /// would survive the sign-out.
  void onSignOut() {
    _graceTimer?.cancel();
    _graceTimer = null;
    state = AppLockState.disabled;
  }

  Future<bool> _promptBiometric({required String reason}) async {
    final auth = _auth;
    if (auth == null) return false;
    try {
      return await auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false, // device credential (PIN/pattern) is a fallback
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException catch (e, _) {
      if (kDebugMode) {
        // ignore: avoid_print
        debugPrint('AppLock prompt failed: ${e.code}');
      }
      return false;
    }
  }

  Future<void> _hydrate(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_prefKey(userId)) ?? false;
    state = enabled ? AppLockState.locked : AppLockState.disabled;
  }

  void _armGrace() {
    _graceTimer?.cancel();
    _graceTimer = Timer(_resumeGrace, () {
      if (state == AppLockState.unlocked) state = AppLockState.locked;
    });
  }

  static String? _currentUserId(Ref ref) {
    final session = ref.read(sessionControllerProvider).value;
    return session is SessionAuthenticated ? session.user.id : null;
  }
}

final appLockProvider = NotifierProvider<AppLockController, AppLockState>(
  AppLockController.new,
);
