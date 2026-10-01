/// Which repositories the app uses: built-in mock data, or the backend.
enum ApiMode { mock, live }

/// Settings passed at build time with `--dart-define-from-file`
/// (see frontend/env/README.md).
class Env {
  const Env({
    required this.apiBaseUrl,
    required this.wsBaseUrl,
    required this.apiMode,
  });

  /// Reads `API_BASE_URL`, `WS_BASE_URL` and `API_MODE`. Without an
  /// `API_MODE` the app runs on mock data.
  factory Env.fromDefines() => Env.parse(
    apiBaseUrl: const String.fromEnvironment('API_BASE_URL'),
    wsBaseUrl: const String.fromEnvironment('WS_BASE_URL'),
    apiMode: const String.fromEnvironment('API_MODE'),
  );

  /// Validates raw values. Live mode needs an http(s) `API_BASE_URL`.
  factory Env.parse({
    required String apiBaseUrl,
    required String wsBaseUrl,
    required String apiMode,
  }) {
    final mode = switch (apiMode.trim().toLowerCase()) {
      '' || 'mock' => ApiMode.mock,
      'live' => ApiMode.live,
      _ => throw ArgumentError.value(apiMode, 'API_MODE', 'Use mock or live'),
    };
    final base = apiBaseUrl.trim();
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
    );
  }

  /// E.g. `http://localhost:8000/api/v1`, without a trailing slash.
  final String apiBaseUrl;

  /// E.g. `ws://localhost:8000/api/v1`.
  final String wsBaseUrl;

  final ApiMode apiMode;
}
