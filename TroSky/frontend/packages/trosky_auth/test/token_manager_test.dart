import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_core/trosky_core.dart';

TokenPairResponse _pair(String n) => TokenPairResponse(
  accessToken: 'access-$n',
  refreshToken: 'refresh-token-number-$n',
  expiresIn: 900,
  sessionId: 's1',
);

void main() {
  test('save keeps the refresh token in the store and the access token in '
      'memory only', () async {
    final store = InMemoryRefreshTokenStore();
    final tokens = TokenManager(
      store: store,
      refresh: (_) async => Ok(_pair('2')),
    );

    await tokens.save(_pair('1'));

    expect(store.token, 'refresh-token-number-1');
    expect(tokens.accessToken, 'access-1');
    expect(await tokens.hasSavedSession, isTrue);
  });

  test('refresh sends the saved token, then saves the rotated pair', () async {
    final store = InMemoryRefreshTokenStore('refresh-token-number-1');
    final sent = <String>[];
    final tokens = TokenManager(
      store: store,
      refresh: (token) async {
        sent.add(token);
        return Ok(_pair('2'));
      },
    );

    expect(await tokens.refresh(), const Ok('access-2'));
    expect(sent, ['refresh-token-number-1']);
    expect(store.token, 'refresh-token-number-2');
  });

  test('concurrent refreshes share one call', () async {
    final gate = Completer<void>();
    var calls = 0;
    final tokens = TokenManager(
      store: InMemoryRefreshTokenStore('refresh-token-number-1'),
      refresh: (_) async {
        calls++;
        await gate.future;
        return Ok(_pair('2'));
      },
    );

    final results = [for (var i = 0; i < 3; i++) tokens.refresh()];
    gate.complete();

    expect(await Future.wait(results), everyElement(const Ok('access-2')));
    expect(calls, 1);
  });

  test('a dead session clears the tokens and says so', () async {
    final store = InMemoryRefreshTokenStore('refresh-token-number-1');
    final reuse = AppFailure.fromResponse(
      statusCode: 401,
      body: {
        'error': {
          'code': 'REFRESH_TOKEN_REUSE_DETECTED',
          'message': 'reused',
          'details': <String, Object?>{},
          'request_id': 'r',
        },
      },
    );
    final tokens = TokenManager(store: store, refresh: (_) async => Err(reuse));
    final ended = <AppFailure>[];
    tokens.sessionEnded.listen(ended.add);

    final result = await tokens.refresh();
    await Future<void>.delayed(Duration.zero);

    expect(result.failureOrNull?.code, 'REFRESH_TOKEN_REUSE_DETECTED');
    expect(store.token, isNull);
    expect(ended.single.code, 'REFRESH_TOKEN_REUSE_DETECTED');
  });

  test('a network failure keeps the saved token for later', () async {
    final store = InMemoryRefreshTokenStore('refresh-token-number-1');
    final tokens = TokenManager(
      store: store,
      refresh: (_) async => const Err(NetworkFailure()),
    );

    final result = await tokens.refresh();

    expect(result.failureOrNull, isA<NetworkFailure>());
    expect(store.token, 'refresh-token-number-1');
  });

  test('no saved token: nothing to refresh', () async {
    var calls = 0;
    final tokens = TokenManager(
      store: InMemoryRefreshTokenStore(),
      refresh: (_) async {
        calls++;
        return Ok(_pair('2'));
      },
    );
    expect((await tokens.refresh()).failureOrNull?.code, 'NO_SESSION');
    expect(calls, 0);
  });
}
