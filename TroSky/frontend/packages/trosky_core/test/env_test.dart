import 'package:flutter_test/flutter_test.dart';
import 'package:trosky_core/trosky_core.dart';

void main() {
  test('no API_MODE means mock', () {
    final env = Env.parse(apiBaseUrl: '', wsBaseUrl: '', apiMode: '');
    expect(env.apiMode, ApiMode.mock);
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
}
