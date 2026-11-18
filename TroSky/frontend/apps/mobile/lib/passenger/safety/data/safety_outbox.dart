// Encrypted Hive outbox for SOS alerts and incident reports.
//
// SOS CORRECTNESS: a user who taps "Hold to send SOS" and loses network
// mid-request (or has the app killed by LOW_MEMORY) must not lose the
// alert. On submit, the intended request is persisted first; the live
// repository call fires after, and on success the entry is cleared. On
// failure or app restart the outbox replays every unsent entry.
//
// Storage key: `safety_outbox_v1` Hive box, AES-encrypted with a key
// stored under `trosky.safety_outbox.hive_key` in flutter_secure_storage.
// Eviction: entries are cleared on successful send; stale entries older
// than 7 days are dropped on next open (SOS loses actionability after
// that long).
//
// Never log request bodies: SOS coords and Report descriptions are
// sensitive. Only ids and timestamps go to breadcrumbs.

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_core/trosky_core.dart';

/// Which kind of safety action is queued. `incident` also carries
/// `tripId` for the URL.
enum SafetyOutboxKind { sosTrip, sosOffTrip, incident }

/// One queued request. Opaque to the outbox; the sender rebuilds the
/// right DTO from [payload].
class SafetyOutboxEntry {
  SafetyOutboxEntry({
    required this.id,
    required this.kind,
    required this.payload,
    required this.enqueuedAt,
    this.tripId,
  });

  final String id;
  final SafetyOutboxKind kind;
  final String? tripId;
  final Map<String, dynamic> payload;
  final DateTime enqueuedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'trip_id': tripId,
    'payload': payload,
    'enqueued_at': enqueuedAt.toUtc().toIso8601String(),
  };

  factory SafetyOutboxEntry.fromJson(Map<String, dynamic> j) =>
      SafetyOutboxEntry(
        id: j['id'] as String,
        kind: SafetyOutboxKind.values.firstWhere(
          (k) => k.name == j['kind'],
          orElse: () => SafetyOutboxKind.incident,
        ),
        tripId: j['trip_id'] as String?,
        payload: Map<String, dynamic>.from(j['payload'] as Map),
        enqueuedAt: DateTime.parse(j['enqueued_at'] as String),
      );
}

class SafetyOutbox {
  SafetyOutbox({
    FlutterSecureStorage? secureStorage,
    Random? random,
    this.maxAge = const Duration(days: 7),
  }) : _secure = secureStorage ?? const FlutterSecureStorage(),
       _random = random ?? Random.secure();

  static const String boxName = 'safety_outbox_v1';
  static const String secureStorageKey = 'trosky.safety_outbox.hive_key';

  final FlutterSecureStorage _secure;
  final Random _random;
  final Duration maxAge;
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
    await _evictStale(box);
    return box;
  }

  Future<List<int>> _loadOrCreateKey() async {
    final existing = await _secure.read(key: secureStorageKey);
    if (existing != null && existing.isNotEmpty) return base64Decode(existing);
    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    await _secure.write(key: secureStorageKey, value: base64Encode(bytes));
    return bytes;
  }

  Future<void> _evictStale(Box<String> box, {DateTime? now}) async {
    final cutoff = (now ?? DateTime.now().toUtc()).subtract(maxAge);
    final drop = <String>[];
    for (final key in box.keys.cast<String>()) {
      final raw = box.get(key);
      if (raw == null) continue;
      try {
        final at = DateTime.parse(
          (jsonDecode(raw) as Map<String, dynamic>)['enqueued_at'] as String,
        );
        if (at.isBefore(cutoff)) drop.add(key);
      } on Object {
        drop.add(key);
      }
    }
    for (final k in drop) {
      await box.delete(k);
    }
  }

  /// Persists the entry so SOS survives an app kill mid-send. A storage
  /// failure never blocks the send — the live repository call still
  /// fires and the UI sees its result.
  Future<void> enqueue(SafetyOutboxEntry entry) async {
    try {
      final box = await _open();
      await box.put(entry.id, jsonEncode(entry.toJson()));
    } on Object {
      // Outbox is best-effort; never fail the SOS because persistence did.
    }
  }

  Future<void> ack(String id) async {
    try {
      final box = await _open();
      await box.delete(id);
    } on Object {
      // Nothing to do — the entry is lost forever but the alert was sent.
    }
  }

  Future<List<SafetyOutboxEntry>> pending() async {
    final box = await _open();
    final out = <SafetyOutboxEntry>[];
    for (final key in box.keys.cast<String>()) {
      final raw = box.get(key);
      if (raw == null) continue;
      try {
        out.add(
          SafetyOutboxEntry.fromJson(jsonDecode(raw) as Map<String, dynamic>),
        );
      } on Object {
        await box.delete(key);
      }
    }
    out.sort((a, b) => a.enqueuedAt.compareTo(b.enqueuedAt));
    return out;
  }

  /// Replays every pending entry via [repository]. Entries that succeed
  /// are acknowledged; failures stay queued for the next replay.
  Future<void> replay(SafetyRepository repository) async {
    for (final entry in await pending()) {
      final result = await _send(entry, repository);
      if (result is Ok) await ack(entry.id);
    }
  }

  Future<Result<Object>> _send(
    SafetyOutboxEntry entry,
    SafetyRepository repo,
  ) async {
    switch (entry.kind) {
      case SafetyOutboxKind.sosTrip:
        return repo.triggerTripSos(
          entry.tripId!,
          TriggerSosRequest.fromJson(entry.payload),
          idempotencyKey: entry.id,
        );
      case SafetyOutboxKind.sosOffTrip:
        return repo.triggerSos(
          TriggerSosRequest.fromJson(entry.payload),
          idempotencyKey: entry.id,
        );
      case SafetyOutboxKind.incident:
        return repo.reportIncident(
          entry.tripId!,
          ReportIncidentRequest.fromJson(entry.payload),
          idempotencyKey: entry.id,
        );
    }
  }
}
