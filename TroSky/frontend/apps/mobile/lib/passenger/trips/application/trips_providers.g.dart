// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trips_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// A tab of Trip History (`GET /bookings`), a page at a time.

@ProviderFor(TripsController)
final tripsControllerProvider = TripsControllerFamily._();

/// A tab of Trip History (`GET /bookings`), a page at a time.
final class TripsControllerProvider
    extends $AsyncNotifierProvider<TripsController, TripsPage> {
  /// A tab of Trip History (`GET /bookings`), a page at a time.
  TripsControllerProvider._({
    required TripsControllerFamily super.from,
    required TripsTab super.argument,
  }) : super(
         retry: noRetry,
         name: r'tripsControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$tripsControllerHash();

  @override
  String toString() {
    return r'tripsControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  TripsController create() => TripsController();

  @override
  bool operator ==(Object other) {
    return other is TripsControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$tripsControllerHash() => r'c79a13ac5cd094e36a8c9e8576c960e5fc141cf0';

/// A tab of Trip History (`GET /bookings`), a page at a time.

final class TripsControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          TripsController,
          AsyncValue<TripsPage>,
          TripsPage,
          FutureOr<TripsPage>,
          TripsTab
        > {
  TripsControllerFamily._()
    : super(
        retry: noRetry,
        name: r'tripsControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// A tab of Trip History (`GET /bookings`), a page at a time.

  TripsControllerProvider call(TripsTab tab) =>
      TripsControllerProvider._(argument: tab, from: this);

  @override
  String toString() => r'tripsControllerProvider';
}

/// A tab of Trip History (`GET /bookings`), a page at a time.

abstract class _$TripsController extends $AsyncNotifier<TripsPage> {
  late final _$args = ref.$arg as TripsTab;
  TripsTab get tab => _$args;

  FutureOr<TripsPage> build(TripsTab tab);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<TripsPage>, TripsPage>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<TripsPage>, TripsPage>,
              AsyncValue<TripsPage>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

/// The Trip History card (`GET /bookings/summary`, G25): this month.

@ProviderFor(bookingSummary)
final bookingSummaryProvider = BookingSummaryProvider._();

/// The Trip History card (`GET /bookings/summary`, G25): this month.

final class BookingSummaryProvider
    extends
        $FunctionalProvider<
          AsyncValue<BookingSummaryResponse>,
          BookingSummaryResponse,
          FutureOr<BookingSummaryResponse>
        >
    with
        $FutureModifier<BookingSummaryResponse>,
        $FutureProvider<BookingSummaryResponse> {
  /// The Trip History card (`GET /bookings/summary`, G25): this month.
  BookingSummaryProvider._()
    : super(
        from: null,
        argument: null,
        retry: noRetry,
        name: r'bookingSummaryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bookingSummaryHash();

  @$internal
  @override
  $FutureProviderElement<BookingSummaryResponse> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<BookingSummaryResponse> create(Ref ref) {
    return bookingSummary(ref);
  }
}

String _$bookingSummaryHash() => r'69372f705426a0945c14d8ef76821d4b30ec4bab';

/// `GET /bookings/{id}` and `GET /trips/{id}`.

@ProviderFor(bookingDetails)
final bookingDetailsProvider = BookingDetailsFamily._();

/// `GET /bookings/{id}` and `GET /trips/{id}`.

final class BookingDetailsProvider
    extends
        $FunctionalProvider<
          AsyncValue<BookingDetails>,
          BookingDetails,
          FutureOr<BookingDetails>
        >
    with $FutureModifier<BookingDetails>, $FutureProvider<BookingDetails> {
  /// `GET /bookings/{id}` and `GET /trips/{id}`.
  BookingDetailsProvider._({
    required BookingDetailsFamily super.from,
    required String super.argument,
  }) : super(
         retry: noRetry,
         name: r'bookingDetailsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$bookingDetailsHash();

  @override
  String toString() {
    return r'bookingDetailsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<BookingDetails> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<BookingDetails> create(Ref ref) {
    final argument = this.argument as String;
    return bookingDetails(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is BookingDetailsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$bookingDetailsHash() => r'f7f251173056e136dca75bda62ee07b150feb229';

/// `GET /bookings/{id}` and `GET /trips/{id}`.

final class BookingDetailsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<BookingDetails>, String> {
  BookingDetailsFamily._()
    : super(
        retry: noRetry,
        name: r'bookingDetailsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// `GET /bookings/{id}` and `GET /trips/{id}`.

  BookingDetailsProvider call(String bookingId) =>
      BookingDetailsProvider._(argument: bookingId, from: this);

  @override
  String toString() => r'bookingDetailsProvider';
}

/// How [bookingId] was paid: its successful (or refunded) payment from
/// `GET /payments`, newest first. Null when it isn't among the latest 50 or
/// can't be read; the cancel sheet then says it generally.

@ProviderFor(bookingPayment)
final bookingPaymentProvider = BookingPaymentFamily._();

/// How [bookingId] was paid: its successful (or refunded) payment from
/// `GET /payments`, newest first. Null when it isn't among the latest 50 or
/// can't be read; the cancel sheet then says it generally.

final class BookingPaymentProvider
    extends
        $FunctionalProvider<
          AsyncValue<PaymentResponse?>,
          PaymentResponse?,
          FutureOr<PaymentResponse?>
        >
    with $FutureModifier<PaymentResponse?>, $FutureProvider<PaymentResponse?> {
  /// How [bookingId] was paid: its successful (or refunded) payment from
  /// `GET /payments`, newest first. Null when it isn't among the latest 50 or
  /// can't be read; the cancel sheet then says it generally.
  BookingPaymentProvider._({
    required BookingPaymentFamily super.from,
    required String super.argument,
  }) : super(
         retry: noRetry,
         name: r'bookingPaymentProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$bookingPaymentHash();

  @override
  String toString() {
    return r'bookingPaymentProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<PaymentResponse?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PaymentResponse?> create(Ref ref) {
    final argument = this.argument as String;
    return bookingPayment(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is BookingPaymentProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$bookingPaymentHash() => r'87b485705c2a900a5bcd90584edd19a938689128';

/// How [bookingId] was paid: its successful (or refunded) payment from
/// `GET /payments`, newest first. Null when it isn't among the latest 50 or
/// can't be read; the cancel sheet then says it generally.

final class BookingPaymentFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<PaymentResponse?>, String> {
  BookingPaymentFamily._()
    : super(
        retry: noRetry,
        name: r'bookingPaymentProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// How [bookingId] was paid: its successful (or refunded) payment from
  /// `GET /payments`, newest first. Null when it isn't among the latest 50 or
  /// can't be read; the cancel sheet then says it generally.

  BookingPaymentProvider call(String bookingId) =>
      BookingPaymentProvider._(argument: bookingId, from: this);

  @override
  String toString() => r'bookingPaymentProvider';
}
