import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_providers.g.dart';

/// The time now. Tests replace it to fix the time of day.
@Riverpod(keepAlive: true)
DateTime Function() clock(Ref ref) => DateTime.now;

/// For providers that must show their error at once. Riverpod retries a
/// failing provider on its own, which would keep a "Retry" from appearing
/// for seconds and leave timers running in tests.
Duration? noRetry(int retryCount, Object error) => null;
