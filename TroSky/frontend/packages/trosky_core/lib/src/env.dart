import 'package:flutter/foundation.dart';

/// Which repositories the app uses: built-in mock data, or the backend.
enum ApiMode { mock, live }

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
/// Env parsing is fail-loud in release builds (step 21/A): a release
/// APK with a required flag missing or unrecognised throws at startup
/// rather than silently defaulting. The `flutter run` dev loop keeps
/// its empty→mock default so tests and local work don't need flags.
class Env {
  const Env({
    required this.apiBaseUrl,
    required this.wsBaseUrl,
    required this.apiMode,
    this.mapTileUrl = osmTileUrl,
    this.features = const {},
    this.helpCentreUrl = defaultHelpCentreUrl,
  });

  /// Reads `API_BASE_URL`, `WS_BASE_URL`, `API_MODE`, `MAP_TILE_URL`,
  /// `FEATURES`, and `HELP_CENTRE_URL`.
  factory Env.fromDefines() => Env.parse(
    apiBaseUrl: const String.fromEnvironment('API_BASE_URL'),
    wsBaseUrl: const String.fromEnvironment('WS_BASE_URL'),
    apiMode: const String.fromEnvironment('API_MODE'),
    mapTileUrl: const String.fromEnvironment('MAP_TILE_URL'),
    helpCentreUrl: const bool.hasEnvironment('HELP_CENTRE_URL')
        ? const String.fromEnvironment('HELP_CENTRE_URL')
        : null,
    // An empty FEATURES turns every feature off, so "not set" differs from
    // "set to nothing".
    features: const bool.hasEnvironment('FEATURES')
        ? const String.fromEnvironment('FEATURES')
        : null,
  );

  /// Validates raw values. Live mode needs an http(s) `API_BASE_URL`.
  ///
  /// Fail-loud in release (step 21/A):
  /// - Empty or unknown `API_MODE` throws.
  /// - Live mode with a bad `API_BASE_URL` throws (unchanged).
  /// - A supplied but malformed `HELP_CENTRE_URL` throws.
  ///
  /// [mapTileUrl] defaults to [osmTileUrl]. [features] is a comma-separated
  /// list of [Feature] names; `null` (not set) means
  /// [Feature.defaultsFor] the mode.
  factory Env.parse({
    required String apiBaseUrl,
    required String wsBaseUrl,
    required String apiMode,
    String mapTileUrl = '',
    String? features,
    String? helpCentreUrl,
  }) {
    final base = apiBaseUrl.trim();
    final rawMode = apiMode.trim().toLowerCase();
    // The brief's fail-loud rule: in a release APK, an empty or unknown
    // API_MODE throws at startup. The dev loop (debug/profile) still
    // falls back to mock when both the mode and the URL are empty so
    // `flutter run` without flags still works for tests.
    if (kReleaseMode &&
        (rawMode.isEmpty || !_knownApiModes.contains(rawMode))) {
      throw StateError(
        'API_MODE is required in release builds and must be one of '
        '${_knownApiModes.join(" | ")} (got "$apiMode"). '
        'Pass --dart-define-from-file=env/<env>.json at build time.',
      );
    }
    final mode = switch (rawMode) {
      'mock' => ApiMode.mock,
      'live' => ApiMode.live,
      '' when base.isEmpty => ApiMode.mock,
      '' => ApiMode.live,
      _ => throw ArgumentError.value(apiMode, 'API_MODE', 'Use mock or live'),
    };
    if (mode == ApiMode.live) {
      final uri = Uri.tryParse(base);
      if (uri == null ||
          !uri.hasAuthority ||
          !uri.isScheme('http') && !uri.isScheme('https')) {
        throw ArgumentError.value(
          apiBaseUrl,
          'API_BASE_URL',
          'Live mode needs an http(s) URL, e.g. http://10.0.2.2:8000/api/v1',
        );
      }
    }
    return Env(
      apiBaseUrl: base.endsWith('/')
          ? base.substring(0, base.length - 1)
          : base,
      wsBaseUrl: wsBaseUrl.trim(),
      apiMode: mode,
      mapTileUrl: _tileUrl(mapTileUrl),
      features: features == null
          ? Feature.defaultsFor(mode)
          : _features(features),
      helpCentreUrl: _helpUrl(helpCentreUrl),
    );
  }

  static const Set<String> _knownApiModes = {'mock', 'live'};

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

  /// Map tiles, with `{z}`, `{x}` and `{y}` placeholders.
  final String mapTileUrl;

  /// The features switched on in this build.
  final Set<Feature> features;

  /// Help centre URL opened from Profile → Support → Help centre. Falls
  /// back to [defaultHelpCentreUrl] when the env file doesn't override.
  final String helpCentreUrl;

  bool has(Feature feature) => features.contains(feature);
}
