// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trip_details_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// `GET /api/v1/trips/{tripId}`. Returns the fresh [TripDetailResponse]
/// for a trip we have a booking on. Errors throw to the UI so the
/// screen can render the right state (offline / not-found / server
/// error).

@ProviderFor(tripDetails)
final tripDetailsProvider = TripDetailsFamily._();

/// `GET /api/v1/trips/{tripId}`. Returns the fresh [TripDetailResponse]
/// for a trip we have a booking on. Errors throw to the UI so the
/// screen can render the right state (offline / not-found / server
/// error).

final class TripDetailsProvider
    extends
        $FunctionalProvider<
          AsyncValue<TripDetailResponse>,
          TripDetailResponse,
          FutureOr<TripDetailResponse>
        >
    with
        $FutureModifier<TripDetailResponse>,
        $FutureProvider<TripDetailResponse> {
  /// `GET /api/v1/trips/{tripId}`. Returns the fresh [TripDetailResponse]
  /// for a trip we have a booking on. Errors throw to the UI so the
  /// screen can render the right state (offline / not-found / server
  /// error).
  TripDetailsProvider._({
    required TripDetailsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'tripDetailsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$tripDetailsHash();

  @override
  String toString() {
    return r'tripDetailsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<TripDetailResponse> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<TripDetailResponse> create(Ref ref) {
    final argument = this.argument as String;
    return tripDetails(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TripDetailsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$tripDetailsHash() => r'0fc962d9e9ea45d261397932e5ad6d9aa51df711';

/// `GET /api/v1/trips/{tripId}`. Returns the fresh [TripDetailResponse]
/// for a trip we have a booking on. Errors throw to the UI so the
/// screen can render the right state (offline / not-found / server
/// error).

final class TripDetailsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<TripDetailResponse>, String> {
  TripDetailsFamily._()
    : super(
        retry: null,
        name: r'tripDetailsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// `GET /api/v1/trips/{tripId}`. Returns the fresh [TripDetailResponse]
  /// for a trip we have a booking on. Errors throw to the UI so the
  /// screen can render the right state (offline / not-found / server
  /// error).

  TripDetailsProvider call(String tripId) =>
      TripDetailsProvider._(argument: tripId, from: this);

  @override
  String toString() => r'tripDetailsProvider';
}
