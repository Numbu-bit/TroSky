import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';
import 'package:trosky_api/trosky_api.dart';

/// Encrypted on-disk cache for the signed QR tokens. Treat its contents
/// as bearer tokens: never write them in a plaintext box, never log,
/// never emit in telemetry.
///
/// Storage:
///   - Hive box `tickets_v1` with AES encryption.
///   - Encryption key kept in `flutter_secure_storage` under
///     [secureStorageKey]. Generated on first access (32 random bytes,
///     base64). The key never leaves secure storage; rotating it drops
///     every cached ticket at once.
///   - Each entry is a JSON string of [TicketResponse] list, keyed by
///     booking id.
class TicketCache {
  TicketCache({FlutterSecureStorage? secureStorage, Random? random})
    : _secure = secureStorage ?? const FlutterSecureStorage(),
      _random = random ?? Random.secure();

  static const String boxName = 'tickets_v1';
  static const String secureStorageKey = 'trosky.tickets.hive_key';

  final FlutterSecureStorage _secure;
  final Random _random;

  Box<String>? _box;

  /// Opens the Hive box if it is not open yet.
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

  /// Reads the cached tickets for [bookingId], evicting any expired
  /// entries first. Returns null for a miss.
  Future<List<TicketResponse>?> read(String bookingId, {DateTime? now}) async {
    final box = await _open();
    await _evictExpired(box, now: now);
    final raw = box.get(bookingId);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      return decoded
          .cast<Map<String, dynamic>>()
          .map(TicketResponse.fromJson)
          .toList();
    } on FormatException {
      await box.delete(bookingId);
      return null;
    }
  }

  /// Writes [tickets] under [bookingId], replacing any previous entry.
  Future<void> write(String bookingId, List<TicketResponse> tickets) async {
    final box = await _open();
    final payload = jsonEncode([for (final t in tickets) t.toJson()]);
    await box.put(bookingId, payload);
  }

  Future<void> _evictExpired(Box<String> box, {DateTime? now}) async {
    final cutoff = (now ?? DateTime.now().toUtc()).toUtc();
    final expired = <String>[];
    for (final key in box.keys.cast<String>()) {
      final raw = box.get(key);
      if (raw == null) continue;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! List) {
          expired.add(key);
          continue;
        }
        final tickets = decoded.cast<Map<String, dynamic>>();
        final allExpired = tickets.every((t) {
          final exp = t['expires_at'];
          if (exp is! String) return true;
          final parsed = DateTime.tryParse(exp);
          return parsed == null || parsed.isBefore(cutoff);
        });
        if (allExpired) expired.add(key);
      } on FormatException {
        expired.add(key);
      }
    }
    if (expired.isNotEmpty) await box.deleteAll(expired);
  }

  /// Wipes every cached entry and rotates the secure-storage key, so no
  /// prior encrypted bytes on disk can be decrypted again. Call on sign
  /// out and from the tester-menu "Sign out & clear data" action.
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
      // Hive hasn't been initialised (unit tests, early boot before
      // runApp): nothing on disk to delete. Rotating the key still
      // invalidates any future reads.
    }
    await _secure.delete(key: secureStorageKey);
  }

  /// Visible for tests.
  Future<void> close() async {
    await _box?.close();
    _box = null;
  }
}
