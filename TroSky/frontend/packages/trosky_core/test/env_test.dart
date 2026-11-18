import 'package:flutter_test/flutter_test.dart';
import 'package:trosky_core/trosky_core.dart';

void main() {
  test('no API_MODE and no API_BASE_URL means mock (dev loop)', () {
    final env = Env.parse(apiBaseUrl: '', wsBaseUrl: '', apiMode: '');
    expect(env.apiMode, ApiMode.mock);
  });

  test(
    'no API_MODE but a real API_BASE_URL means live '
    '(release build with --dart-define-from-file that dropped API_MODE)',
    () {
      // Pre-fix this would silently become mock and reject every real
      // credential as "invalid". Post-fix, a non-empty base URL is proof
      // the build was meant to talk to a backend.
      final env = Env.parse(
        apiBaseUrl: 'https://trosky-api.onrender.com/api/v1',
        wsBaseUrl: 'wss://trosky-api.onrender.com/api/v1',
        apiMode: '',
      );
      expect(env.apiMode, ApiMode.live);
      expect(env.apiBaseUrl, 'https://trosky-api.onrender.com/api/v1');
    },
  );

  test('live mode with a URL; the trailing slash is dropped', () {
    final env = Env.parse(
      apiBaseUrl: 'http://10.0.2.2:8000/api/v1/',
      wsBaseUrl: 'ws://10.0.2.2:8000/api/v1',
      apiMode: 'live',
    );
    expect(env.apiMode, ApiMode.live);
    expect(env.apiBaseUrl, 'http://10.0.2.2:8000/api/v1');
    expect(env.wsBaseUrl, 'ws://10.0.2.2:8000/api/v1');
  });

  test('live mode without a usable URL is refused', () {
    for (final url in ['', 'localhost:8000', 'ftp://x/api']) {
      expect(
        () => Env.parse(apiBaseUrl: url, wsBaseUrl: '', apiMode: 'live'),
        throwsArgumentError,
        reason: url,
      );
    }
  });

  test('an unknown API_MODE is refused', () {
    expect(
      () => Env.parse(apiBaseUrl: '', wsBaseUrl: '', apiMode: 'staging'),
      throwsArgumentError,
    );
  });

  group('map tiles', () {
    test('default to OpenStreetMap', () {
      final env = Env.parse(apiBaseUrl: '', wsBaseUrl: '', apiMode: '');
      expect(env.mapTileUrl, Env.osmTileUrl);
    });

    test('MAP_TILE_URL replaces them', () {
      const url = 'https://tiles.example.com/{z}/{x}/{y}.png?key=abc';
      final env = Env.parse(
        apiBaseUrl: '',
        wsBaseUrl: '',
        apiMode: '',
        mapTileUrl: url,
      );
      expect(env.mapTileUrl, url);
    });

    test('a URL without the placeholders is refused', () {
      for (final url in ['https://tiles.example.com/', 'tiles/{z}/{x}/{y}']) {
        expect(
          () => Env.parse(
            apiBaseUrl: '',
            wsBaseUrl: '',
            apiMode: '',
            mapTileUrl: url,
          ),
          throwsArgumentError,
          reason: url,
        );
      }
    });
  });

  group('features (decision 16)', () {
    Env parse(String mode, {String? features}) => Env.parse(
      apiBaseUrl: 'http://localhost:8000/api/v1',
      wsBaseUrl: '',
      apiMode: mode,
      features: features,
    );

    test('subscriptions are on in mock mode and off in live mode', () {
      expect(parse('mock').has(Feature.subscriptions), isTrue);
      expect(parse('live').has(Feature.subscriptions), isFalse);
    });

    test('FEATURES overrides the defaults; empty turns everything off', () {
      expect(
        parse('live', features: 'subscriptions').has(Feature.subscriptions),
        isTrue,
      );
      expect(parse('mock', features: '').features, isEmpty);
      expect(parse('mock', features: ' subscriptions , ').features, {
        Feature.subscriptions,
      });
    });

    test('an unknown feature is refused', () {
      expect(
        () => parse('mock', features: 'subscription'),
        throwsArgumentError,
      );
    });
  });
}
