// Encrypted on-disk cache for the booking-scoped share-link tokens
// returned by `POST /bookings/{booking_id}/share` (step 21/close-
// stubs-C).
//
// The share token is bearer-like for the public link, so treat the
// cache as sensitive: encrypted Hive box, no plaintext logs ever,
// SHA-256 first-8-chars for breadcrumb correlation.
//
// Storage:
//   - Hive box `share_tokens_v1` with AES encryption.
//   - Encryption key kept in `flutter_secure_storage` under
//     [secureStorageKey]. Generated on first access (32 random
//     bytes, base64). Rotating it drops every cached token at once.
//   - Each entry is a JSON string of `TripShareLinkResponse`, keyed
//     by booking id. Expired entries are evicted on read.

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_auth/trosky_auth.dart';

/// Short, non-reversible digest of a URL, for breadcrumbs. 8 hex
/// chars of a 32-bit FNV-1a hash over the URL's bytes — enough to
/// correlate two log entries about the same link and short enough
/// that it's useless as a bearer token. We avoid pulling in `crypto`
/// for a single mask; the backend never reads this string.
String maskedShareUrl(String url) {
  var hash = 0x811c9dc5;
  for (final byte in utf8.encode(url)) {
    hash ^= byte;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return '.../${hash.toRadixString(16).padLeft(8, '0')}';
}

class ShareTokenCache {
  ShareTokenCache({
    FlutterSecureStorage secureStorage = troskySecureStorage,
    Random? random,
  }) : _secure = secureStorage,
       _random = random ?? Random.secure();

  static const String boxName = 'share_tokens_v1';
  static const String secureStorageKey = 'trosky.share_tokens.hive_key';

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
    if (existing != null && existing.isNotEmpty) {
      return base64Decode(existing);
    }
    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    await _secure.write(key: secureStorageKey, value: base64Encode(bytes));
    return bytes;
  }

  /// Reads the cached share link for [bookingId] if present AND not
  /// expired at [now]. Returns null for a miss or an expired token
  /// (the expired entry is evicted on this read).
  Future<TripShareLinkResponse?> read(String bookingId, {DateTime? now}) async {
    final box = await _open();
    final raw = box.get(bookingId);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final link = TripShareLinkResponse.fromJson(decoded);
      final cutoff = (now ?? DateTime.now().toUtc()).toUtc();
      if (!link.expiresAt.toUtc().isAfter(cutoff)) {
        await box.delete(bookingId);
        return null;
      }
      return link;
    } on FormatException {
      await box.delete(bookingId);
      return null;
    }
  }

  /// Writes [link] under [bookingId], replacing any previous entry.
  Future<void> write(String bookingId, TripShareLinkResponse link) async {
    final box = await _open();
    await box.put(bookingId, jsonEncode(link.toJson()));
  }

  /// Drops the cached link for [bookingId]. Called after
  /// `DELETE /bookings/{id}/share` succeeds.
  Future<void> remove(String bookingId) async {
    final box = await _open();
    await box.delete(bookingId);
  }

  /// Wipes every cached entry and rotates the secure-storage key, so
  /// no prior encrypted bytes on disk can be decrypted again. Call
  /// on sign out.
  Future<void> wipeAndRotate() async {
    final current = _box;
    if (current != null && current.isOpen) {
      await current.clear();
      await current.close();
    }
    _box = null;
    try {
      await Hive.deleteBoxFromDisk(boxName);
    } on Object {
      // Hive isn't initialised in some unit tests / early boot; the
      // key rotation still invalidates any future reads.
    }
    await _secure.delete(key: secureStorageKey);
  }

  /// Visible for tests.
  Future<void> close() async {
    await _box?.close();
    _box = null;
  }
}
