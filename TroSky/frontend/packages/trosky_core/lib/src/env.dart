import 'package:flutter/foundation.dart';

/// Which repositories the app uses: built-in mock data, or the backend.
enum ApiMode { mock, live }

/// Which deployment this build is for. Separate from [ApiMode] because
/// some combinations (e.g. a prod build in mock mode, a dev build
/// pointing at the live staging API) are useful locally but must be
/// forbidden in a release APK heading for the Play Store.
///
/// The values are stable strings (`dev`, `staging`, `demo`, `prod`)
/// that match the env file names under `frontend/env/` and the
/// `--env` flag of `apps/mobile/tool/build_store.sh`.
enum DeployEnv {
  /// Loopback or on-device dev mode, with or without the mock backend.
  dev,

  /// Hosted staging backend (Render). May also include tester tools.
  staging,

  /// Mock-mode build shown without a live server (decision 17,
  /// env/README.md). `com.trosky.app.demo` on Android.
  demo,

  /// Store build heading for Play / App Store. Forbids mock mode,
  /// placeholder hosts, tester menus, and anything else that would
  /// embarrass us if a real user ran it.
  prod,
}

/// Known placeholder hosts that must never ship to a prod build —
/// typically carried over from an unedited `*.example.json` env file.
const Set<String> _placeholderApiHosts = {
  'api.example.com',
  'example.com',
  'localhost',
  '127.0.0.1',
  '10.0.2.2',
};

/// Parts of the app that can be switched on and off per build, with
/// `FEATURES` (see frontend/env/README.md).
enum Feature {
  /// The "Subscribe your commute" banner on Home (decision 16). The backend
  /// has no subscriptions yet (gap G14).
  subscriptions;

  /// On unless the build says otherwise: in mock mode only.
  static Set<Feature> defaultsFor(ApiMode mode) => switch (mode) {
    ApiMode.mock => {Feature.subscriptions},
    ApiMode.live => const {},
  };
}

/// Settings passed at build time with `--dart-define-from-file`
/// (see frontend/env/README.md).
///
/// Env parsing is fail-loud for every DeployEnv (step 21/A2): a build
/// with a required flag missing or unrecognised throws at startup
/// rather than silently defaulting. `flutter run` must pass
/// `--dart-define-from-file=env/dev.example.json` or equivalent.
class Env {
  const Env({
    required this.apiBaseUrl,
    required this.wsBaseUrl,
    required this.apiMode,
    required this.deployEnv,
    this.mapTileUrl = osmTileUrl,
    this.features = const {},
    this.helpCentreUrl = defaultHelpCentreUrl,
  });

  /// Reads `API_BASE_URL`, `WS_BASE_URL`, `API_MODE`, `DEPLOY_ENV`,
  /// `TESTER_MENU`, `MAP_TILE_URL`, `FEATURES`, and `HELP_CENTRE_URL`.
  ///
  /// Release builds (every APK/IPA) require every flag — the strict
  /// [parse] throws on the first missing one. In non-release (the dev
  /// `flutter run` loop and the test harness) a missing `DEPLOY_ENV`
  /// falls back to a safe dev config so `flutter test` doesn't need a
  /// `--dart-define-from-file`. A dev run with the env file passed
  /// still goes through the strict path and benefits from the same
  /// fail-loud errors on typos.
  factory Env.fromDefines() {
    const deployEnv = String.fromEnvironment('DEPLOY_ENV');
    if (deployEnv.isEmpty && !kReleaseMode) {
      // Dev / test fallback. Still goes through [parse] so any
      // partially-set defines (e.g. a bad MAP_TILE_URL) still throw.
      return Env.parse(
        apiBaseUrl: const String.fromEnvironment(
          'API_BASE_URL',
          defaultValue: 'http://localhost:8000/api/v1',
        ),
        wsBaseUrl: const String.fromEnvironment(
          'WS_BASE_URL',
          defaultValue: 'ws://localhost:8000/api/v1',
        ),
        apiMode: const String.fromEnvironment('API_MODE', defaultValue: 'mock'),
        deployEnv: 'dev',
        testerMenu: const bool.hasEnvironment('TESTER_MENU')
            ? const String.fromEnvironment('TESTER_MENU')
            : null,
        mapTileUrl: const String.fromEnvironment('MAP_TILE_URL'),
        helpCentreUrl: const bool.hasEnvironment('HELP_CENTRE_URL')
            ? const String.fromEnvironment('HELP_CENTRE_URL')
            : null,
        features: const bool.hasEnvironment('FEATURES')
            ? const String.fromEnvironment('FEATURES')
            : null,
      );
    }
    return Env.parse(
      apiBaseUrl: const String.fromEnvironment('API_BASE_URL'),
      wsBaseUrl: const String.fromEnvironment('WS_BASE_URL'),
      apiMode: const String.fromEnvironment('API_MODE'),
      deployEnv: deployEnv,
      testerMenu: const bool.hasEnvironment('TESTER_MENU')
          ? const String.fromEnvironment('TESTER_MENU')
          : null,
      mapTileUrl: const String.fromEnvironment('MAP_TILE_URL'),
      helpCentreUrl: const bool.hasEnvironment('HELP_CENTRE_URL')
          ? const String.fromEnvironment('HELP_CENTRE_URL')
          : null,
      // An empty FEATURES turns every feature off, so "not set" differs
      // from "set to nothing".
      features: const bool.hasEnvironment('FEATURES')
          ? const String.fromEnvironment('FEATURES')
          : null,
    );
  }

  /// Validates raw values. Live mode needs an http(s) `API_BASE_URL`.
  ///
  /// Fail-loud rule (step 21/A2, extending C4 to every deploy):
  /// - `DEPLOY_ENV` is required and must be one of [DeployEnv.values].
  /// - `API_MODE` is required and must be `live` or `mock`.
  /// - `API_BASE_URL` is required and must parse to an http(s) URL with
  ///   an authority.
  /// - `WS_BASE_URL` is required and must parse to a ws(s) URL with an
  ///   authority.
  /// - A supplied but malformed `HELP_CENTRE_URL` throws.
  /// - `DEPLOY_ENV=prod` additionally enforces: `API_MODE=live`,
  ///   https-only `API_BASE_URL` with a non-placeholder host, wss-only
  ///   `WS_BASE_URL`, and `TESTER_MENU` not enabled.
  ///
  /// There is no silent default for any required flag in any deploy —
  /// a staging build with `API_MODE` missing throws at parse time, so
  /// the PR #93 class of bug (silent fallback to mock on staging) can
  /// never recur. `flutter run` must now pass
  /// `--dart-define-from-file=env/dev.example.json` or equivalent.
  ///
  /// [mapTileUrl] defaults to [osmTileUrl]. [features] is a
  /// comma-separated list of [Feature] names; `null` (not set) means
  /// [Feature.defaultsFor] the mode.
  factory Env.parse({
    required String apiBaseUrl,
    required String wsBaseUrl,
    required String apiMode,
    required String deployEnv,
    String? testerMenu,
    String mapTileUrl = '',
    String? features,
    String? helpCentreUrl,
  }) {
    final base = apiBaseUrl.trim();
    final ws = wsBaseUrl.trim();
    final rawMode = apiMode.trim().toLowerCase();
    final rawDeploy = deployEnv.trim().toLowerCase();

    // DEPLOY_ENV is required for every build. No silent fallback.
    if (rawDeploy.isEmpty) {
      throw StateError(
        'DEPLOY_ENV is required. '
        'Expected one of ${DeployEnv.values.map((e) => e.name).join(" | ")}. '
        'Pass --dart-define-from-file=env/<env>.json at build time.',
      );
    }
    final deploy = DeployEnv.values.firstWhere(
      (e) => e.name == rawDeploy,
      orElse: () => throw ArgumentError.value(
        deployEnv,
        'DEPLOY_ENV',
        'Expected one of ${DeployEnv.values.map((e) => e.name).join(", ")}',
      ),
    );

    // API_MODE is required. Never silently fall back to mock/live based
    // on whether API_BASE_URL is empty — that was the root of PR #93.
    if (rawMode.isEmpty) {
      throw StateError(
        'API_MODE is required (got ""). '
        'Expected one of ${_knownApiModes.join(" | ")}. '
        'Pass --dart-define=API_MODE=live (or mock) in your env file.',
      );
    }
    final mode = switch (rawMode) {
      'mock' => ApiMode.mock,
      'live' => ApiMode.live,
      _ => throw ArgumentError.value(
        apiMode,
        'API_MODE',
        'Expected one of ${_knownApiModes.join(" | ")}',
      ),
    };

    // API_BASE_URL is required for every deploy. Shape validated as
    // http(s) with authority. Prod tightens to https-only below.
    if (base.isEmpty) {
      throw StateError(
        'API_BASE_URL is required. '
        'Pass --dart-define=API_BASE_URL=http(s)://host/api/v1 '
        'in your env file.',
      );
    }
    final apiUri = Uri.tryParse(base);
    if (apiUri == null ||
        !apiUri.hasAuthority ||
        !(apiUri.isScheme('http') || apiUri.isScheme('https'))) {
      throw ArgumentError.value(
        apiBaseUrl,
        'API_BASE_URL',
        'Must be an http(s) URL with a host, '
            'e.g. http://10.0.2.2:8000/api/v1',
      );
    }

    // WS_BASE_URL is required for every deploy. Shape validated as
    // ws(s) with authority. Prod tightens to wss-only below.
    if (ws.isEmpty) {
      throw StateError(
        'WS_BASE_URL is required. '
        'Pass --dart-define=WS_BASE_URL=ws(s)://host/api/v1 '
        'in your env file.',
      );
    }
    final wsUri = Uri.tryParse(ws);
    if (wsUri == null ||
        !wsUri.hasAuthority ||
        !(wsUri.isScheme('ws') || wsUri.isScheme('wss'))) {
      throw ArgumentError.value(
        wsBaseUrl,
        'WS_BASE_URL',
        'Must be a ws(s) URL with a host, '
            'e.g. ws://10.0.2.2:8000/api/v1',
      );
    }

    // DEPLOY_ENV=prod invariants. Enforced even outside kReleaseMode so
    // a developer who mis-flags their local run as prod gets the same
    // rejection instead of an inconsistent "almost-prod" state.
    if (deploy == DeployEnv.prod) {
      if (mode != ApiMode.live) {
        throw StateError(
          'DEPLOY_ENV=prod requires API_MODE=live (got "$apiMode").',
        );
      }
      final apiUri = Uri.tryParse(base);
      if (apiUri == null || !apiUri.isScheme('https')) {
        throw ArgumentError.value(
          apiBaseUrl,
          'API_BASE_URL',
          'DEPLOY_ENV=prod requires an https:// API_BASE_URL.',
        );
      }
      if (_placeholderApiHosts.contains(apiUri.host.toLowerCase())) {
        throw ArgumentError.value(
          apiBaseUrl,
          'API_BASE_URL',
          'DEPLOY_ENV=prod rejects placeholder host "${apiUri.host}" '
              '(likely copied from env/*.example.json).',
        );
      }
      final wsUri = Uri.tryParse(ws);
      if (wsUri == null || !wsUri.isScheme('wss')) {
        throw ArgumentError.value(
          wsBaseUrl,
          'WS_BASE_URL',
          'DEPLOY_ENV=prod requires a wss:// WS_BASE_URL (got "$wsBaseUrl").',
        );
      }
      if (wsUri.host.isEmpty ||
          _placeholderApiHosts.contains(wsUri.host.toLowerCase())) {
        throw ArgumentError.value(
          wsBaseUrl,
          'WS_BASE_URL',
          'DEPLOY_ENV=prod rejects placeholder WS host "${wsUri.host}".',
        );
      }
      if (_isTruthy(testerMenu)) {
        throw StateError(
          'DEPLOY_ENV=prod forbids TESTER_MENU=true. '
          'Remove it from the prod env file.',
        );
      }
    }

    return Env(
      apiBaseUrl: base.endsWith('/')
          ? base.substring(0, base.length - 1)
          : base,
      wsBaseUrl: ws,
      apiMode: mode,
      deployEnv: deploy,
      mapTileUrl: _tileUrl(mapTileUrl),
      features: features == null
          ? Feature.defaultsFor(mode)
          : _features(features),
      helpCentreUrl: _helpUrl(helpCentreUrl),
    );
  }

  /// Whether the build's tester menu (if the host app wires one) is
  /// allowed to be visible. True only when the compile-time
  /// `TESTER_MENU` flag is on AND the build's [deployEnv] is not
  /// [DeployEnv.prod]. Callers combine this with their own
  /// `const bool.fromEnvironment('TESTER_MENU')` constant so the
  /// release compiler can tree-shake tester code when the flag is off.
  bool get testerMenuAllowed => deployEnv != DeployEnv.prod;

  static const Set<String> _knownApiModes = {'mock', 'live'};

  static bool _isTruthy(String? raw) {
    if (raw == null) return false;
    final lower = raw.trim().toLowerCase();
    return lower == 'true' || lower == '1' || lower == 'yes';
  }

  /// Default help centre URL when the env file doesn't override it.
  /// Overridable per-env via `HELP_CENTRE_URL` in `env/<env>.json`.
  static const String defaultHelpCentreUrl = 'https://trosky.africa/help';

  static String _helpUrl(String? raw) {
    if (raw == null || raw.trim().isEmpty) return defaultHelpCentreUrl;
    final uri = Uri.tryParse(raw.trim());
    if (uri == null ||
        !uri.hasAuthority ||
        !(uri.isScheme('http') || uri.isScheme('https'))) {
      throw ArgumentError.value(
        raw,
        'HELP_CENTRE_URL',
        'Must be an http(s) URL.',
      );
    }
    return raw.trim();
  }

  /// OpenStreetMap's public tiles. For development only: their usage policy
  /// doesn't allow an app's production traffic (decision 13).
  static const String osmTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  static String _tileUrl(String raw) {
    final url = raw.trim();
    if (url.isEmpty) return osmTileUrl;
    final uri = Uri.tryParse(url);
    final placeholders = ['{z}', '{x}', '{y}'].every(url.contains);
    if (uri == null ||
        !uri.isScheme('https') && !uri.isScheme('http') ||
        !placeholders) {
      throw ArgumentError.value(
        raw,
        'MAP_TILE_URL',
        'Use an http(s) tile URL with {z}, {x} and {y}',
      );
    }
    return url;
  }

  static Set<Feature> _features(String raw) => {
    for (final name in raw.split(','))
      if (name.trim().isNotEmpty)
        Feature.values.firstWhere(
          (f) => f.name == name.trim(),
          orElse: () => throw ArgumentError.value(
            raw,
            'FEATURES',
            'Unknown feature "${name.trim()}". Known: '
                '${Feature.values.map((f) => f.name).join(', ')}',
          ),
        ),
  };

  /// E.g. `http://localhost:8000/api/v1`, without a trailing slash.
  final String apiBaseUrl;

  /// E.g. `ws://localhost:8000/api/v1`.
  final String wsBaseUrl;

  final ApiMode apiMode;

  /// Which deployment this build is for — dev, staging, demo, prod.
  final DeployEnv deployEnv;

  /// Map tiles, with `{z}`, `{x}` and `{y}` placeholders.
  final String mapTileUrl;

  /// The features switched on in this build.
  final Set<Feature> features;

  /// Help centre URL opened from Profile → Support → Help centre. Falls
  /// back to [defaultHelpCentreUrl] when the env file doesn't override.
  final String helpCentreUrl;

  bool has(Feature feature) => features.contains(feature);
}
