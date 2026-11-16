// Introduced for Step 16 PR 2. First-party interface so analytics emit
// sites can land now; the console stub can be swapped for PostHog /
// Amplitude / Firebase later without touching the call sites.
//
// Payload rule: scalars only, no PII, no bearer tokens, no coordinates.
// Field validation lives next door in [TelemetryEvent.sanitised] so the
// stub catches a bad call during development.

import 'dart:developer' as developer;

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'telemetry.g.dart';

/// One analytics event: a snake_case name + a map of scalar params.
class TelemetryEvent {
  TelemetryEvent(this.name, [Map<String, Object?>? params])
    : params = Map.unmodifiable(params ?? const <String, Object?>{});

  final String name;
  final Map<String, Object?> params;

  /// Enforced in debug: drop any value that could be a token or PII. The
  /// production bar says payloads are scalars only, no names, phones,
  /// coordinates, tokens.
  static final Pattern _bannedKeys = RegExp(
    r'token|phone|name|email|lat|lng|coord|address',
    caseSensitive: false,
  );

  Map<String, Object?> get sanitised {
    final clean = <String, Object?>{};
    for (final entry in params.entries) {
      if (entry.key.contains(_bannedKeys)) continue;
      final value = entry.value;
      if (value is num || value is String || value is bool || value == null) {
        clean[entry.key] = value;
      }
    }
    return clean;
  }
}

/// Where emit sites hand events to. One method, so a stub for tests is
/// three lines.
abstract interface class TelemetryService {
  void emit(TelemetryEvent event);
}

/// Dev stub: prints via `dart:developer.log` under the "trosky.telemetry"
/// channel. Swap for PostHog / Amplitude later.
class ConsoleTelemetryService implements TelemetryService {
  const ConsoleTelemetryService();

  @override
  void emit(TelemetryEvent event) {
    developer.log('${event.name} ${event.sanitised}', name: 'trosky.telemetry');
  }
}

@Riverpod(keepAlive: true)
TelemetryService telemetry(Ref ref) => const ConsoleTelemetryService();
