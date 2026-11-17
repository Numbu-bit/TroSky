// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tracking_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Opens the realtime channel for one trip. Fresh per trip id; the
/// screen disposes it on unmount.

@ProviderFor(tripTrackingService)
final tripTrackingServiceProvider = TripTrackingServiceFamily._();

/// Opens the realtime channel for one trip. Fresh per trip id; the
/// screen disposes it on unmount.

final class TripTrackingServiceProvider
    extends
        $FunctionalProvider<
          TripTrackingService,
          TripTrackingService,
          TripTrackingService
        >
    with $Provider<TripTrackingService> {
  /// Opens the realtime channel for one trip. Fresh per trip id; the
  /// screen disposes it on unmount.
  TripTrackingServiceProvider._({
    required TripTrackingServiceFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'tripTrackingServiceProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$tripTrackingServiceHash();

  @override
  String toString() {
    return r'tripTrackingServiceProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<TripTrackingService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  TripTrackingService create(Ref ref) {
    final argument = this.argument as String;
    return tripTrackingService(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TripTrackingService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TripTrackingService>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TripTrackingServiceProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$tripTrackingServiceHash() =>
    r'24d8d707d61db4a716ea46ff4ca9585efb242eed';

/// Opens the realtime channel for one trip. Fresh per trip id; the
/// screen disposes it on unmount.

final class TripTrackingServiceFamily extends $Family
    with $FunctionalFamilyOverride<TripTrackingService, String> {
  TripTrackingServiceFamily._()
    : super(
        retry: null,
        name: r'tripTrackingServiceProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Opens the realtime channel for one trip. Fresh per trip id; the
  /// screen disposes it on unmount.

  TripTrackingServiceProvider call(String tripId) =>
      TripTrackingServiceProvider._(argument: tripId, from: this);

  @override
  String toString() => r'tripTrackingServiceProvider';
}

/// Optional ETA fetch. Independent of the realtime stream so a WS tick
/// doesn't trigger an extra HTTP request.

@ProviderFor(tripEta)
final tripEtaProvider = TripEtaFamily._();

/// Optional ETA fetch. Independent of the realtime stream so a WS tick
/// doesn't trigger an extra HTTP request.

final class TripEtaProvider
    extends
        $FunctionalProvider<
          AsyncValue<EtaResponse?>,
          EtaResponse?,
          FutureOr<EtaResponse?>
        >
    with $FutureModifier<EtaResponse?>, $FutureProvider<EtaResponse?> {
  /// Optional ETA fetch. Independent of the realtime stream so a WS tick
  /// doesn't trigger an extra HTTP request.
  TripEtaProvider._({
    required TripEtaFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'tripEtaProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$tripEtaHash();

  @override
  String toString() {
    return r'tripEtaProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<EtaResponse?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<EtaResponse?> create(Ref ref) {
    final argument = this.argument as String;
    return tripEta(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TripEtaProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$tripEtaHash() => r'e8880c7b8390dadd20e31692e4f4cad8f106090f';

/// Optional ETA fetch. Independent of the realtime stream so a WS tick
/// doesn't trigger an extra HTTP request.

final class TripEtaFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<EtaResponse?>, String> {
  TripEtaFamily._()
    : super(
        retry: null,
        name: r'tripEtaProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Optional ETA fetch. Independent of the realtime stream so a WS tick
  /// doesn't trigger an extra HTTP request.

  TripEtaProvider call(String tripId) =>
      TripEtaProvider._(argument: tripId, from: this);

  @override
  String toString() => r'tripEtaProvider';
}
