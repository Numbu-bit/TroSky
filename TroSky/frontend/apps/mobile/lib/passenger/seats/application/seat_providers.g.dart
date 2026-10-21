// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'seat_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The trip vehicle's seats and which are free (`GET /trips/{id}/seats`).

@ProviderFor(tripSeats)
final tripSeatsProvider = TripSeatsFamily._();

/// The trip vehicle's seats and which are free (`GET /trips/{id}/seats`).

final class TripSeatsProvider
    extends
        $FunctionalProvider<
          AsyncValue<TripSeatsResponse>,
          TripSeatsResponse,
          FutureOr<TripSeatsResponse>
        >
    with
        $FutureModifier<TripSeatsResponse>,
        $FutureProvider<TripSeatsResponse> {
  /// The trip vehicle's seats and which are free (`GET /trips/{id}/seats`).
  TripSeatsProvider._({
    required TripSeatsFamily super.from,
    required String super.argument,
  }) : super(
         retry: noRetry,
         name: r'tripSeatsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$tripSeatsHash();

  @override
  String toString() {
    return r'tripSeatsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<TripSeatsResponse> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<TripSeatsResponse> create(Ref ref) {
    final argument = this.argument as String;
    return tripSeats(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TripSeatsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$tripSeatsHash() => r'bae3bff14b1ff3e8ed38643abd40a3247271b6c6';

/// The trip vehicle's seats and which are free (`GET /trips/{id}/seats`).

final class TripSeatsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<TripSeatsResponse>, String> {
  TripSeatsFamily._()
    : super(
        retry: noRetry,
        name: r'tripSeatsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The trip vehicle's seats and which are free (`GET /trips/{id}/seats`).

  TripSeatsProvider call(String tripId) =>
      TripSeatsProvider._(argument: tripId, from: this);

  @override
  String toString() => r'tripSeatsProvider';
}

/// The price of a [FareQuoteRequest] right now (`GET /trips/{id}/fare-quote`):
/// what `POST /bookings` would charge. It falls as riders join, so the seat
/// screen fetches it again with the seat map.

@ProviderFor(fareQuote)
final fareQuoteProvider = FareQuoteFamily._();

/// The price of a [FareQuoteRequest] right now (`GET /trips/{id}/fare-quote`):
/// what `POST /bookings` would charge. It falls as riders join, so the seat
/// screen fetches it again with the seat map.

final class FareQuoteProvider
    extends
        $FunctionalProvider<
          AsyncValue<FareQuoteResponse>,
          FareQuoteResponse,
          FutureOr<FareQuoteResponse>
        >
    with
        $FutureModifier<FareQuoteResponse>,
        $FutureProvider<FareQuoteResponse> {
  /// The price of a [FareQuoteRequest] right now (`GET /trips/{id}/fare-quote`):
  /// what `POST /bookings` would charge. It falls as riders join, so the seat
  /// screen fetches it again with the seat map.
  FareQuoteProvider._({
    required FareQuoteFamily super.from,
    required FareQuoteRequest super.argument,
  }) : super(
         retry: noRetry,
         name: r'fareQuoteProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$fareQuoteHash();

  @override
  String toString() {
    return r'fareQuoteProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<FareQuoteResponse> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<FareQuoteResponse> create(Ref ref) {
    final argument = this.argument as FareQuoteRequest;
    return fareQuote(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is FareQuoteProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$fareQuoteHash() => r'dab367765fc05c03863a8b4069c70bbedb0cb032';

/// The price of a [FareQuoteRequest] right now (`GET /trips/{id}/fare-quote`):
/// what `POST /bookings` would charge. It falls as riders join, so the seat
/// screen fetches it again with the seat map.

final class FareQuoteFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<FareQuoteResponse>,
          FareQuoteRequest
        > {
  FareQuoteFamily._()
    : super(
        retry: noRetry,
        name: r'fareQuoteProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The price of a [FareQuoteRequest] right now (`GET /trips/{id}/fare-quote`):
  /// what `POST /bookings` would charge. It falls as riders join, so the seat
  /// screen fetches it again with the seat map.

  FareQuoteProvider call(FareQuoteRequest request) =>
      FareQuoteProvider._(argument: request, from: this);

  @override
  String toString() => r'fareQuoteProvider';
}

/// A held, unpaid booking of the signed-in passenger whose deadline hasn't
/// passed (waiting for the driver, or to be paid for): the app reopens it
/// instead of losing it (Part 2). Null offline or when there is none.

@ProviderFor(heldBooking)
final heldBookingProvider = HeldBookingProvider._();

/// A held, unpaid booking of the signed-in passenger whose deadline hasn't
/// passed (waiting for the driver, or to be paid for): the app reopens it
/// instead of losing it (Part 2). Null offline or when there is none.

final class HeldBookingProvider
    extends
        $FunctionalProvider<
          AsyncValue<BookingResponse?>,
          BookingResponse?,
          FutureOr<BookingResponse?>
        >
    with $FutureModifier<BookingResponse?>, $FutureProvider<BookingResponse?> {
  /// A held, unpaid booking of the signed-in passenger whose deadline hasn't
  /// passed (waiting for the driver, or to be paid for): the app reopens it
  /// instead of losing it (Part 2). Null offline or when there is none.
  HeldBookingProvider._()
    : super(
        from: null,
        argument: null,
        retry: noRetry,
        name: r'heldBookingProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$heldBookingHash();

  @$internal
  @override
  $FutureProviderElement<BookingResponse?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<BookingResponse?> create(Ref ref) {
    return heldBooking(ref);
  }
}

String _$heldBookingHash() => r'855cf5b7bba80cbcb679e0c9820c02085ce9f8a5';

/// Held bookings already shown on Payment in this run, so Home reopens
/// each at most once. Added to just before Payment opens.

@ProviderFor(ShownBookings)
final shownBookingsProvider = ShownBookingsProvider._();

/// Held bookings already shown on Payment in this run, so Home reopens
/// each at most once. Added to just before Payment opens.
final class ShownBookingsProvider
    extends $NotifierProvider<ShownBookings, Set<String>> {
  /// Held bookings already shown on Payment in this run, so Home reopens
  /// each at most once. Added to just before Payment opens.
  ShownBookingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'shownBookingsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$shownBookingsHash();

  @$internal
  @override
  ShownBookings create() => ShownBookings();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Set<String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Set<String>>(value),
    );
  }
}

String _$shownBookingsHash() => r'0118729c604e95e79e881db44e50f40a38ad387b';

/// Held bookings already shown on Payment in this run, so Home reopens
/// each at most once. Added to just before Payment opens.

abstract class _$ShownBookings extends $Notifier<Set<String>> {
  Set<String> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<Set<String>, Set<String>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Set<String>, Set<String>>,
              Set<String>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
