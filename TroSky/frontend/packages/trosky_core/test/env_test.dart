import 'package:flutter_test/flutter_test.dart';
import 'package:trosky_core/trosky_core.dart';

void main() {
  test('no API_MODE and no API_BASE_URL means mock (dev loop)', () {
    final env = Env.parse(apiBaseUrl: '', wsBaseUrl: '', apiMode: '');
    expect(env.apiMode, ApiMode.mock);
  });

  test('no API_MODE but a real API_BASE_URL means live '
      '(release build with --dart-define-from-file that dropped API_MODE)', () {
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
  });

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

  // Step 21/A: fail-loud only triggers in `kReleaseMode`. In the unit
  // test harness that's false, so the dev-loop fallback still applies.
  // The release-mode throw is exercised in CI by `flutter build apk
  // --release` which would fail without proper defines.

  group('helpCentreUrl', () {
    test('defaults when not supplied', () {
      final env = Env.parse(apiBaseUrl: '', wsBaseUrl: '', apiMode: '');
      expect(env.helpCentreUrl, Env.defaultHelpCentreUrl);
    });

    test('a real https URL passes through', () {
      final env = Env.parse(
        apiBaseUrl: '',
        wsBaseUrl: '',
        apiMode: '',
        helpCentreUrl: 'https://help.trosky.africa/custom',
      );
      expect(env.helpCentreUrl, 'https://help.trosky.africa/custom');
    });

    test('a malformed URL throws', () {
      expect(
        () => Env.parse(
          apiBaseUrl: '',
          wsBaseUrl: '',
          apiMode: '',
          helpCentreUrl: 'not-a-url',
        ),
        throwsArgumentError,
      );
    });
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

  group('deployEnv (C4)', () {
    test('default is dev when not supplied (dev loop)', () {
      final env = Env.parse(apiBaseUrl: '', wsBaseUrl: '', apiMode: '');
      expect(env.deployEnv, DeployEnv.dev);
      expect(env.testerMenuAllowed, isTrue);
    });

    test('an unknown DEPLOY_ENV is refused', () {
      expect(
        () => Env.parse(
          apiBaseUrl: '',
          wsBaseUrl: '',
          apiMode: '',
          deployEnv: 'preview',
        ),
        throwsArgumentError,
      );
    });

    test('staging and demo flag testerMenuAllowed=true', () {
      for (final name in const ['staging', 'demo']) {
        final env = Env.parse(
          apiBaseUrl: 'https://trosky-api.onrender.com/api/v1',
          wsBaseUrl: 'wss://trosky-api.onrender.com/api/v1',
          apiMode: 'live',
          deployEnv: name,
        );
        expect(env.testerMenuAllowed, isTrue, reason: name);
      }
    });

    test('prod refuses mock mode', () {
      expect(
        () => Env.parse(
          apiBaseUrl: '',
          wsBaseUrl: '',
          apiMode: 'mock',
          deployEnv: 'prod',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('prod refuses http API_BASE_URL', () {
      expect(
        () => Env.parse(
          apiBaseUrl: 'http://api.trosky.africa/api/v1',
          wsBaseUrl: 'wss://api.trosky.africa/api/v1',
          apiMode: 'live',
          deployEnv: 'prod',
        ),
        throwsArgumentError,
      );
    });

    test('prod refuses placeholder hosts', () {
      for (final host in const [
        'https://api.example.com/api/v1',
        'https://localhost/api/v1',
        'https://10.0.2.2/api/v1',
      ]) {
        expect(
          () => Env.parse(
            apiBaseUrl: host,
            wsBaseUrl:
                'wss://${Uri.parse(host).host}${Uri.parse(host).path}',
            apiMode: 'live',
            deployEnv: 'prod',
          ),
          throwsArgumentError,
          reason: host,
        );
      }
    });

    test('prod refuses ws:// (not wss://)', () {
      expect(
        () => Env.parse(
          apiBaseUrl: 'https://api.trosky.africa/api/v1',
          wsBaseUrl: 'ws://api.trosky.africa/api/v1',
          apiMode: 'live',
          deployEnv: 'prod',
        ),
        throwsArgumentError,
      );
    });

    test('prod refuses empty WS_BASE_URL', () {
      expect(
        () => Env.parse(
          apiBaseUrl: 'https://api.trosky.africa/api/v1',
          wsBaseUrl: '',
          apiMode: 'live',
          deployEnv: 'prod',
        ),
        throwsArgumentError,
      );
    });

    test('prod refuses TESTER_MENU=true', () {
      expect(
        () => Env.parse(
          apiBaseUrl: 'https://api.trosky.africa/api/v1',
          wsBaseUrl: 'wss://api.trosky.africa/api/v1',
          apiMode: 'live',
          deployEnv: 'prod',
          testerMenu: 'true',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('prod accepts a clean live config', () {
      final env = Env.parse(
        apiBaseUrl: 'https://api.trosky.africa/api/v1',
        wsBaseUrl: 'wss://api.trosky.africa/api/v1',
        apiMode: 'live',
        deployEnv: 'prod',
      );
      expect(env.deployEnv, DeployEnv.prod);
      expect(env.testerMenuAllowed, isFalse);
    });
  });
}
