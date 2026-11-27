import 'package:flutter_test/flutter_test.dart';
import 'package:trosky_core/trosky_core.dart';

// A valid dev-config shortcut for cases that aren't testing the
// fail-loud rules themselves.
Env _dev({
  String apiBaseUrl = 'http://localhost:8000/api/v1',
  String wsBaseUrl = 'ws://localhost:8000/api/v1',
  String apiMode = 'mock',
  String deployEnv = 'dev',
  String? helpCentreUrl,
  String mapTileUrl = '',
  String? features,
  String? testerMenu,
}) => Env.parse(
  apiBaseUrl: apiBaseUrl,
  wsBaseUrl: wsBaseUrl,
  apiMode: apiMode,
  deployEnv: deployEnv,
  helpCentreUrl: helpCentreUrl,
  mapTileUrl: mapTileUrl,
  features: features,
  testerMenu: testerMenu,
);

void main() {
  group('fail-loud for every DeployEnv (Step 21/A2)', () {
    // Each required flag × each DeployEnv throws at parse time.

    test('DEPLOY_ENV empty throws', () {
      expect(
        () => Env.parse(
          apiBaseUrl: 'http://localhost:8000/api/v1',
          wsBaseUrl: 'ws://localhost:8000/api/v1',
          apiMode: 'mock',
          deployEnv: '',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('DEPLOY_ENV unknown throws', () {
      expect(
        () => Env.parse(
          apiBaseUrl: 'http://localhost:8000/api/v1',
          wsBaseUrl: 'ws://localhost:8000/api/v1',
          apiMode: 'mock',
          deployEnv: 'preview',
        ),
        throwsArgumentError,
      );
    });

    // API_MODE: required for every DeployEnv — no silent fallback.
    for (final env in const ['dev', 'staging', 'demo']) {
      test('API_MODE empty throws for deployEnv=$env', () {
        expect(
          () => Env.parse(
            apiBaseUrl: 'http://localhost:8000/api/v1',
            wsBaseUrl: 'ws://localhost:8000/api/v1',
            apiMode: '',
            deployEnv: env,
          ),
          throwsA(isA<StateError>()),
          reason: env,
        );
      });

      test('API_MODE unknown throws for deployEnv=$env', () {
        expect(
          () => Env.parse(
            apiBaseUrl: 'http://localhost:8000/api/v1',
            wsBaseUrl: 'ws://localhost:8000/api/v1',
            apiMode: 'staging',
            deployEnv: env,
          ),
          throwsArgumentError,
          reason: env,
        );
      });

      test('API_BASE_URL empty throws for deployEnv=$env', () {
        expect(
          () => Env.parse(
            apiBaseUrl: '',
            wsBaseUrl: 'ws://localhost:8000/api/v1',
            apiMode: 'mock',
            deployEnv: env,
          ),
          throwsA(isA<StateError>()),
          reason: env,
        );
      });

      test('API_BASE_URL malformed throws for deployEnv=$env', () {
        expect(
          () => Env.parse(
            apiBaseUrl: 'localhost:8000',
            wsBaseUrl: 'ws://localhost:8000/api/v1',
            apiMode: 'mock',
            deployEnv: env,
          ),
          throwsArgumentError,
          reason: env,
        );
      });

      test('WS_BASE_URL empty throws for deployEnv=$env', () {
        expect(
          () => Env.parse(
            apiBaseUrl: 'http://localhost:8000/api/v1',
            wsBaseUrl: '',
            apiMode: 'mock',
            deployEnv: env,
          ),
          throwsA(isA<StateError>()),
          reason: env,
        );
      });

      test('WS_BASE_URL malformed throws for deployEnv=$env', () {
        expect(
          () => Env.parse(
            apiBaseUrl: 'http://localhost:8000/api/v1',
            wsBaseUrl: 'http://not-ws/api',
            apiMode: 'mock',
            deployEnv: env,
          ),
          throwsArgumentError,
          reason: env,
        );
      });
    }

    // Prod: additionally covered below, but the general gate still
    // applies — a prod with API_MODE empty throws on the general gate
    // (not the prod-specific one), so the error path is the same.
    test('prod with API_MODE empty throws on the general gate', () {
      expect(
        () => Env.parse(
          apiBaseUrl: 'https://api.trosky.africa/api/v1',
          wsBaseUrl: 'wss://api.trosky.africa/api/v1',
          apiMode: '',
          deployEnv: 'prod',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('a valid dev config passes with everything required', () {
      final env = _dev();
      expect(env.apiMode, ApiMode.mock);
      expect(env.deployEnv, DeployEnv.dev);
      expect(env.apiBaseUrl, 'http://localhost:8000/api/v1');
      expect(env.wsBaseUrl, 'ws://localhost:8000/api/v1');
    });

    test('trailing slash dropped from API_BASE_URL', () {
      final env = _dev(
        apiBaseUrl: 'http://10.0.2.2:8000/api/v1/',
        apiMode: 'live',
      );
      expect(env.apiBaseUrl, 'http://10.0.2.2:8000/api/v1');
    });
  });

  group('helpCentreUrl', () {
    test('defaults when not supplied', () {
      final env = _dev();
      expect(env.helpCentreUrl, Env.defaultHelpCentreUrl);
    });

    test('a real https URL passes through', () {
      final env = _dev(helpCentreUrl: 'https://help.trosky.africa/custom');
      expect(env.helpCentreUrl, 'https://help.trosky.africa/custom');
    });

    test('a malformed URL throws', () {
      expect(() => _dev(helpCentreUrl: 'not-a-url'), throwsArgumentError);
    });
  });

  group('map tiles', () {
    test('default to OpenStreetMap', () {
      expect(_dev().mapTileUrl, Env.osmTileUrl);
    });

    test('MAP_TILE_URL replaces them', () {
      const url = 'https://tiles.example.com/{z}/{x}/{y}.png?key=abc';
      expect(_dev(mapTileUrl: url).mapTileUrl, url);
    });

    test('a URL without the placeholders is refused', () {
      for (final url in ['https://tiles.example.com/', 'tiles/{z}/{x}/{y}']) {
        expect(() => _dev(mapTileUrl: url), throwsArgumentError, reason: url);
      }
    });
  });

  group('features (decision 16)', () {
    test('subscriptions are on in mock mode and off in live mode', () {
      expect(_dev(apiMode: 'mock').has(Feature.subscriptions), isTrue);
      expect(_dev(apiMode: 'live').has(Feature.subscriptions), isFalse);
    });

    test('FEATURES overrides the defaults; empty turns everything off', () {
      expect(
        _dev(
          apiMode: 'live',
          features: 'subscriptions',
        ).has(Feature.subscriptions),
        isTrue,
      );
      expect(_dev(features: '').features, isEmpty);
      expect(_dev(features: ' subscriptions , ').features, {
        Feature.subscriptions,
      });
    });

    test('an unknown feature is refused', () {
      expect(() => _dev(features: 'subscription'), throwsArgumentError);
    });
  });

  group('deployEnv', () {
    test('dev / staging / demo allow the tester menu', () {
      for (final name in const ['dev', 'staging', 'demo']) {
        final env = _dev(
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
          apiBaseUrl: 'https://api.trosky.africa/api/v1',
          wsBaseUrl: 'wss://api.trosky.africa/api/v1',
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
            wsBaseUrl: 'wss://${Uri.parse(host).host}${Uri.parse(host).path}',
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
