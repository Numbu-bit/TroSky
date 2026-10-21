// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'booking_watch.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The booking shown on Payment, kept up to date: polled every
/// [bookingPollEvery] while the driver hasn't answered, backing off after
/// errors, paused while the app is in the background and read again when
/// it comes back ([pause], [resume]). Disposed, and so stopped, when
/// Payment closes.

@ProviderFor(BookingWatchController)
final bookingWatchControllerProvider = BookingWatchControllerFamily._();

/// The booking shown on Payment, kept up to date: polled every
/// [bookingPollEvery] while the driver hasn't answered, backing off after
/// errors, paused while the app is in the background and read again when
/// it comes back ([pause], [resume]). Disposed, and so stopped, when
/// Payment closes.
final class BookingWatchControllerProvider
    extends $NotifierProvider<BookingWatchController, BookingWatch> {
  /// The booking shown on Payment, kept up to date: polled every
  /// [bookingPollEvery] while the driver hasn't answered, backing off after
  /// errors, paused while the app is in the background and read again when
  /// it comes back ([pause], [resume]). Disposed, and so stopped, when
  /// Payment closes.
  BookingWatchControllerProvider._({
    required BookingWatchControllerFamily super.from,
    required PaymentArgs super.argument,
  }) : super(
         retry: null,
         name: r'bookingWatchControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$bookingWatchControllerHash();

  @override
  String toString() {
    return r'bookingWatchControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  BookingWatchController create() => BookingWatchController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BookingWatch value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BookingWatch>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is BookingWatchControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$bookingWatchControllerHash() =>
    r'6093fd9ddf863c54a12a726f18d1ada6d15dc9ac';

/// The booking shown on Payment, kept up to date: polled every
/// [bookingPollEvery] while the driver hasn't answered, backing off after
/// errors, paused while the app is in the background and read again when
/// it comes back ([pause], [resume]). Disposed, and so stopped, when
/// Payment closes.

final class BookingWatchControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          BookingWatchController,
          BookingWatch,
          BookingWatch,
          BookingWatch,
          PaymentArgs
        > {
  BookingWatchControllerFamily._()
    : super(
        retry: null,
        name: r'bookingWatchControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The booking shown on Payment, kept up to date: polled every
  /// [bookingPollEvery] while the driver hasn't answered, backing off after
  /// errors, paused while the app is in the background and read again when
  /// it comes back ([pause], [resume]). Disposed, and so stopped, when
  /// Payment closes.

  BookingWatchControllerProvider call(PaymentArgs args) =>
      BookingWatchControllerProvider._(argument: args, from: this);

  @override
  String toString() => r'bookingWatchControllerProvider';
}

/// The booking shown on Payment, kept up to date: polled every
/// [bookingPollEvery] while the driver hasn't answered, backing off after
/// errors, paused while the app is in the background and read again when
/// it comes back ([pause], [resume]). Disposed, and so stopped, when
/// Payment closes.

abstract class _$BookingWatchController extends $Notifier<BookingWatch> {
  late final _$args = ref.$arg as PaymentArgs;
  PaymentArgs get args => _$args;

  BookingWatch build(PaymentArgs args);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<BookingWatch, BookingWatch>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<BookingWatch, BookingWatch>,
              BookingWatch,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
