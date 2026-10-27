import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_core/trosky_core.dart';

import 'support/fake_adapter.dart';

/// A server that answers each ask [after] a while, or turns it down after a
/// second when it isn't [up] (Render's proxy answering 502). Without
/// [internet], every ask fails at once.
class _Server {
  _Server({
    this.after = const Duration(milliseconds: 300),
    this.up = true,
    this.internet = true,
  });

  Duration after;
  bool up;
  bool internet;

  /// The timeout of each ask.
  final List<Duration> asks = [];

  Future<bool> ping(Duration timeout) async {
    asks.add(timeout);
    if (!internet) return false;
    if (!up) {
      await Future<void>.delayed(const Duration(seconds: 1));
      return false;
    }
    if (after > timeout) {
      await Future<void>.delayed(timeout);
      return false;
    }
    await Future<void>.delayed(after);
    return true;
  }

  Future<bool> hasInternet() async => internet;
}

ServerWake _wake(FakeAsync async, _Server server) => ServerWake(
  ping: server.ping,
  hasInternet: server.hasInternet,
  now: async.getClock(DateTime.utc(2026, 10, 27)).now,
);

class _NoTokens implements SessionTokens {
  @override
  String? get accessToken => null;

  @override
  Future<Result<String>> refresh() async => const Err(NetworkFailure());
}

final _env = Env.parse(
  apiBaseUrl: 'https://api.test/api/v1',
  wsBaseUrl: '',
  apiMode: 'live',
);

void main() {
  group('ServerWake', () {
    test('a warm server is asked once, never shows as waking, and is not '
        'asked again for 10 minutes', () {
      fakeAsync((async) {
        final server = _Server();
        final wake = _wake(async, server);
        final states = <ServerState>[];
        wake.changes.listen(states.add);
        var ready = 0;

        unawaited(wake.ready().then((_) => ready++));
        async.elapse(const Duration(seconds: 1));
        expect(ready, 1);

        async.elapse(const Duration(minutes: 9));
        unawaited(wake.ready().then((_) => ready++));
        async.flushMicrotasks();
        expect(ready, 2);
        expect(server.asks, hasLength(1));
        expect(states, isEmpty);
        expect(wake.state, ServerState.awake);
      });
    });

    test('a sleeping server: waking after 2 s, and every request waits for '
        'the one ask', () {
      fakeAsync((async) {
        final server = _Server(after: const Duration(seconds: 88));
        final wake = _wake(async, server);
        final states = <ServerState>[];
        wake.changes.listen(states.add);
        var ready = 0;

        for (var i = 0; i < 3; i++) {
          unawaited(wake.ready().then((_) => ready++));
        }
        async.elapse(const Duration(seconds: 2));
        expect(wake.state, ServerState.waking);

        async.elapse(const Duration(seconds: 85));
        expect(ready, 0);
        async.elapse(const Duration(seconds: 1));
        expect(ready, 3);
        // The whole budget for the first ask: no request times out.
        expect(server.asks, [const Duration(minutes: 2)]);
        expect(states, [ServerState.waking, ServerState.awake]);
      });
    });

    test('no internet: offline at once, and the next request asks again', () {
      fakeAsync((async) {
        final server = _Server(internet: false);
        final wake = _wake(async, server);
        var ready = false;

        unawaited(wake.ready().then((_) => ready = true));
        async.flushMicrotasks();
        expect(ready, isTrue);
        expect(wake.state, ServerState.offline);

        server.internet = true;
        unawaited(wake.ready());
        async.elapse(const Duration(seconds: 1));
        expect(server.asks, hasLength(2));
        expect(wake.state, ServerState.awake);
      });
    });

    test('internet but no answer: asks every 3 s, then unreachable after 2 '
        'minutes', () {
      fakeAsync((async) {
        final server = _Server(up: false);
        final wake = _wake(async, server);
        var ready = false;

        unawaited(wake.ready().then((_) => ready = true));
        async.elapse(const Duration(seconds: 1));
        // The phone has internet, so it isn't offline: the server is still
        // starting.
        expect(wake.state, ServerState.waking);

        async.elapse(const Duration(seconds: 118));
        expect(ready, isFalse);
        async.elapse(const Duration(seconds: 2));
        expect(ready, isTrue);
        expect(wake.state, ServerState.unreachable);
        // One ask every 4 s (1 s to fail, 3 s apart); the last one gets the
        // time left.
        expect(server.asks, hasLength(30));
        expect(server.asks.last, const Duration(seconds: 4));
      });
    });

    test('after 10 minutes without an answer it asks again; any answer '
        'counts', () {
      fakeAsync((async) {
        final server = _Server();
        final wake = _wake(async, server);

        unawaited(wake.ready());
        async.elapse(const Duration(minutes: 9));
        wake.heard();
        async.elapse(const Duration(minutes: 9));
        unawaited(wake.ready());
        async.elapse(const Duration(seconds: 1));
        expect(server.asks, hasLength(1));

        async.elapse(const Duration(minutes: 10));
        unawaited(wake.ready());
        async.elapse(const Duration(seconds: 1));
        expect(server.asks, hasLength(2));
      });
    });

    test(
      'forApi asks /health/live next to the API, with the whole budget',
      () async {
        final adapter = FakeAdapter((_) async => const FakeReply(200));
        final wake = ServerWake.forApi(
          'https://trosky-api.onrender.com/api/v1',
          adapter: adapter,
        );
        addTearDown(wake.dispose);

        await wake.ready();

        final ask = adapter.requests.single;
        expect(
          ask.uri.toString(),
          'https://trosky-api.onrender.com/health/live',
        );
        // Real time: a millisecond or so has gone by.
        expect(ask.receiveTimeout!.inSeconds, inInclusiveRange(119, 120));
        expect(wake.state, ServerState.awake);
      },
    );
  });

  group('ServerWakeInterceptor', () {
    test('requests wait until the server answers', () async {
      final answer = Completer<bool>();
      var asks = 0;
      final wake = ServerWake(
        ping: (_) {
          asks++;
          return answer.future;
        },
        hasInternet: () async => true,
      );
      final adapter = FakeAdapter((_) async => const FakeReply(200, {}));
      final dio = createApiClient(
        env: _env,
        tokens: _NoTokens.new,
        wake: wake,
        adapter: adapter,
      );

      final requests = Future.wait([
        dio.get<Object?>('/a'),
        dio.post<Object?>('/b'),
      ]);
      await pumpEventQueue();
      expect(adapter.requests, isEmpty);
      expect(asks, 1);

      answer.complete(true);
      await requests;
      expect(adapter.requests.map((r) => r.path), ['/a', '/b']);
    });

    test("the server's own answers count, a 5xx from Render's proxy "
        "doesn't", () async {
      final wake = ServerWake(
        ping: (_) async => false,
        hasInternet: () async => false,
      );
      var status = 503;
      final adapter = FakeAdapter(
        (_) async => FakeReply(status, errorBody('X')),
      );
      final dio = createApiClient(
        env: _env,
        tokens: _NoTokens.new,
        wake: wake,
        adapter: adapter,
        retryDelays: const [],
      );

      await expectLater(dio.get<Object?>('/a'), throwsA(isA<DioException>()));
      expect(wake.state, ServerState.offline);

      status = 404;
      await expectLater(dio.get<Object?>('/a'), throwsA(isA<DioException>()));
      expect(wake.state, ServerState.awake);
    });
  });
}
