// Encrypted share-token cache (step 21/close-stubs-C). Round-trips
// through the Hive box, evicts expired entries on read, and keeps
// the token out of logs via `maskedShareUrl`.

import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mobile/passenger/tracking/data/share_token_cache.dart';
import 'package:trosky_api/trosky_api.dart';

void main() {
  late Directory tmp;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('share_cache_test_');
    Hive.init(tmp.path);
    FlutterSecureStorage.setMockInitialValues({});
  });

  tearDown(() async {
    await Hive.close();
    try {
      await tmp.delete(recursive: true);
    } on Object {
      // Platform temp dirs may be locked briefly on Windows.
    }
  });

  test('round-trips an encrypted token through the box', () async {
    final cache = ShareTokenCache();
    final link = TripShareLinkResponse(
      url: 'https://trosky-api.onrender.com/share/abcd',
      token: 'super-secret-token',
      expiresAt: DateTime.now().toUtc().add(const Duration(hours: 12)),
    );
    await cache.write('b1', link);
    final back = await cache.read('b1');
    expect(back?.token, link.token);
    expect(back?.url, link.url);
    await cache.close();
  });

  test('read returns null for an expired entry and evicts it', () async {
    final cache = ShareTokenCache();
    final past = TripShareLinkResponse(
      url: 'https://x/share/ab',
      token: 't-past',
      expiresAt: DateTime.now().toUtc().subtract(const Duration(hours: 1)),
    );
    await cache.write('b2', past);
    final back = await cache.read('b2');
    expect(back, isNull);
    expect(await cache.read('b2'), isNull);
    await cache.close();
  });

  test('remove drops the cached token (used after revoke)', () async {
    final cache = ShareTokenCache();
    final link = TripShareLinkResponse(
      url: 'https://x/share/cd',
      token: 't-ok',
      expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
    );
    await cache.write('b3', link);
    expect(await cache.read('b3'), isNotNull);
    await cache.remove('b3');
    expect(await cache.read('b3'), isNull);
    await cache.close();
  });

  test('maskedShareUrl is stable + non-reversible', () {
    final a = maskedShareUrl('https://trosky-api.onrender.com/share/abcdef');
    final b = maskedShareUrl('https://trosky-api.onrender.com/share/abcdef');
    final c = maskedShareUrl('https://trosky-api.onrender.com/share/xxxxxx');
    expect(a, b, reason: 'same input → same mask');
    expect(a, isNot(c), reason: 'different inputs → different masks');
    expect(RegExp(r'^\.\.\./[0-9a-f]{8}$').hasMatch(a), isTrue);
    expect(a.contains('abcdef'), isFalse);
  });
}
