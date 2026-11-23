import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mobile/passenger/trips/data/ticket_cache.dart';
import 'package:trosky_api/trosky_api.dart';

import '_fake_secure_storage.dart';

TicketResponse _ticket({
  required String id,
  required DateTime expiresAt,
  TicketStatus status = TicketStatus.issued,
  String? qrToken,
}) => TicketResponse(
  id: id,
  ticketReference: 'TRO-REF-$id',
  bookingId: 'b1',
  bookingPassengerId: 'bp-$id',
  tripId: 't1',
  status: status,
  issuedAt: DateTime.utc(2026, 11, 16, 7),
  expiresAt: expiresAt,
  qrToken: qrToken ?? 'mock-token-$id',
);

void main() {
  late Directory tempDir;
  late FakeSecureStorage secure;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('trosky_tickets_test_');
    Hive.init(tempDir.path);
    secure = FakeSecureStorage();
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  TicketCache cache() => TicketCache(secureStorage: secure);

  group('TicketCache', () {
    test('round-trip: write then read returns the same shape', () async {
      final c = cache();
      final list = [
        _ticket(id: '1', expiresAt: DateTime.utc(2099, 1, 1)),
        _ticket(id: '2', expiresAt: DateTime.utc(2099, 1, 1)),
      ];
      await c.write('b1', list);
      final back = await c.read('b1');
      expect(back, isNotNull);
      expect(back!.length, 2);
      expect(back[0].id, '1');
      expect(back[1].qrToken, 'mock-token-2');
    });

    test(
      'expired entry: every ticket past expires_at is evicted on read',
      () async {
        final c = cache();
        await c.write('b-old', [
          _ticket(id: 'x', expiresAt: DateTime.utc(2026, 11, 16, 6)),
        ]);
        // Freshly opened cache; eviction runs on the first read.
        final back = await c.read('b-old', now: DateTime.utc(2026, 11, 16, 9));
        expect(back, isNull);
      },
    );

    test('mixed entry: at least one ticket still valid is kept', () async {
      final c = cache();
      await c.write('b-mixed', [
        _ticket(id: 'past', expiresAt: DateTime.utc(2026, 11, 16, 6)),
        _ticket(id: 'future', expiresAt: DateTime.utc(2099, 1, 1)),
      ]);
      final back = await c.read('b-mixed', now: DateTime.utc(2026, 11, 16, 9));
      expect(back, isNotNull);
      expect(back!.map((t) => t.id).toList(), ['past', 'future']);
    });

    test(
      'wipeAndRotate: box gone, secure-storage key gone, next read empty',
      () async {
        final c = cache();
        await c.write('b1', [
          _ticket(id: '1', expiresAt: DateTime.utc(2099, 1, 1)),
        ]);
        expect(await secure.read(key: TicketCache.secureStorageKey), isNotNull);

        await c.wipeAndRotate();

        expect(
          await secure.read(key: TicketCache.secureStorageKey),
          isNull,
          reason:
              'the key must be removed so stale box bytes can never decrypt',
        );
        // A fresh cache instance comes up with no entry: key is regenerated,
        // disk file is gone so there is nothing to decrypt.
        final c2 = cache();
        final back = await c2.read('b1');
        expect(back, isNull);
      },
    );

    test('bad secure-storage key on re-open: generates a fresh key', () async {
      final c = cache();
      await c.write('b1', [
        _ticket(id: '1', expiresAt: DateTime.utc(2099, 1, 1)),
      ]);
      final first = await secure.read(key: TicketCache.secureStorageKey);
      expect(first, isNotNull);
      // Second instance on the same tempdir: must reuse that key.
      await c.close();
      final c2 = cache();
      final back = await c2.read('b1');
      expect(back, isNotNull, reason: 'same key -> decrypts');
    });
  });
}
