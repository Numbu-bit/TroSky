// Encrypted Hive cache for rate-banner dismissals.
//
// A booking's rate banner (Trips tab) hides for 1 day after the user
// dismisses it, and disappears for good 7 days after the trip completes
// regardless. The timestamps are opaque — never render these to UI.

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';

class RateBannerCache {
  RateBannerCache({FlutterSecureStorage? secureStorage, Random? random})
    : _secure = secureStorage ?? const FlutterSecureStorage(),
      _random = random ?? Random.secure();

  static const String boxName = 'rate_banner_v1';
  static const String secureStorageKey = 'trosky.rate_banner.hive_key';

  final FlutterSecureStorage _secure;
  final Random _random;
  Box<String>? _box;

  Future<Box<String>> _open() async {
    final existing = _box;
    if (existing != null && existing.isOpen) return existing;
    final key = await _loadOrCreateKey();
    final box = await Hive.openBox<String>(
      boxName,
      encryptionCipher: HiveAesCipher(key),
    );
    _box = box;
    return box;
  }

  Future<List<int>> _loadOrCreateKey() async {
    final existing = await _secure.read(key: secureStorageKey);
    if (existing != null && existing.isNotEmpty) return base64Decode(existing);
    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    await _secure.write(key: secureStorageKey, value: base64Encode(bytes));
    return bytes;
  }

  /// Records "dismissed at [now]" for [bookingId]. Best-effort: a
  /// storage failure never blocks the UI (the banner just reappears
  /// on the next cycle).
  Future<void> dismiss(String bookingId, {DateTime? now}) async {
    try {
      final box = await _open();
      await box.put(
        bookingId,
        (now ?? DateTime.now()).toUtc().toIso8601String(),
      );
    } on Object {
      // Best-effort.
    }
  }

  /// Returns the timestamp the banner was last dismissed for
  /// [bookingId], or null if it was never dismissed.
  Future<DateTime?> lastDismissedAt(String bookingId) async {
    try {
      final box = await _open();
      final raw = box.get(bookingId);
      if (raw == null) return null;
      return DateTime.parse(raw);
    } on Object {
      return null;
    }
  }

  /// All dismissal timestamps keyed by booking id. Convenient for the
  /// provider that renders the row list.
  Future<Map<String, DateTime>> allDismissals() async {
    try {
      final box = await _open();
      final out = <String, DateTime>{};
      for (final key in box.keys.cast<String>()) {
        final raw = box.get(key);
        if (raw == null) continue;
        try {
          out[key] = DateTime.parse(raw);
        } on FormatException {
          await box.delete(key);
        }
      }
      return out;
    } on Object {
      return const {};
    }
  }
}

/// Pure eligibility rule: a banner is shown for a booking that is
/// completed, within [maxAge] of [now], and either never dismissed or
/// dismissed more than [reshowAfter] ago.
bool rateBannerEligible({
  required bool completed,
  required DateTime? completedAt,
  required DateTime? dismissedAt,
  required DateTime now,
  Duration maxAge = const Duration(days: 7),
  Duration reshowAfter = const Duration(days: 1),
}) {
  if (!completed || completedAt == null) return false;
  if (now.difference(completedAt) > maxAge) return false;
  if (dismissedAt == null) return true;
  return now.difference(dismissedAt) >= reshowAfter;
}
