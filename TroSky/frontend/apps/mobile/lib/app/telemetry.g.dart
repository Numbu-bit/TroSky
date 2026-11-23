// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'telemetry.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(telemetry)
final telemetryProvider = TelemetryProvider._();

final class TelemetryProvider
    extends
        $FunctionalProvider<
          TelemetryService,
          TelemetryService,
          TelemetryService
        >
    with $Provider<TelemetryService> {
  TelemetryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'telemetryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$telemetryHash();

  @$internal
  @override
  $ProviderElement<TelemetryService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TelemetryService create(Ref ref) {
    return telemetry(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TelemetryService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TelemetryService>(value),
    );
  }
}

String _$telemetryHash() => r'acfe5d8971f522448a51adeb0116c67c28199ad7';
