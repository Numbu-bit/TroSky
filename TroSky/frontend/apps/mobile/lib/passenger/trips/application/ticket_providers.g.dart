// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ticket_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The encrypted on-disk cache. One instance per app lifetime.

@ProviderFor(ticketCache)
final ticketCacheProvider = TicketCacheProvider._();

/// The encrypted on-disk cache. One instance per app lifetime.

final class TicketCacheProvider
    extends $FunctionalProvider<TicketCache, TicketCache, TicketCache>
    with $Provider<TicketCache> {
  /// The encrypted on-disk cache. One instance per app lifetime.
  TicketCacheProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'ticketCacheProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$ticketCacheHash();

  @$internal
  @override
  $ProviderElement<TicketCache> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TicketCache create(Ref ref) {
    return ticketCache(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TicketCache value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TicketCache>(value),
    );
  }
}

String _$ticketCacheHash() => r'9186dec6986d66f13a5355691ac49677bf339d92';

/// Cache-first provider. Emits:
///   1. cached list immediately when fresh;
///   2. a background refresh fires on top; on success, cache is replaced
///      and a new state is emitted;
///   3. on refresh failure with cache: keep showing cache and flip
///      [BookingTicketsView.staleBannerVisible] on; emit
///      `ticket_fetch_failed` through telemetry once;
///   4. on no-cache + failure: throw, TicketScreen renders the offline
///      state.

@ProviderFor(bookingTickets)
final bookingTicketsProvider = BookingTicketsFamily._();

/// Cache-first provider. Emits:
///   1. cached list immediately when fresh;
///   2. a background refresh fires on top; on success, cache is replaced
///      and a new state is emitted;
///   3. on refresh failure with cache: keep showing cache and flip
///      [BookingTicketsView.staleBannerVisible] on; emit
///      `ticket_fetch_failed` through telemetry once;
///   4. on no-cache + failure: throw, TicketScreen renders the offline
///      state.

final class BookingTicketsProvider
    extends
        $FunctionalProvider<
          AsyncValue<BookingTicketsView>,
          BookingTicketsView,
          FutureOr<BookingTicketsView>
        >
    with
        $FutureModifier<BookingTicketsView>,
        $FutureProvider<BookingTicketsView> {
  /// Cache-first provider. Emits:
  ///   1. cached list immediately when fresh;
  ///   2. a background refresh fires on top; on success, cache is replaced
  ///      and a new state is emitted;
  ///   3. on refresh failure with cache: keep showing cache and flip
  ///      [BookingTicketsView.staleBannerVisible] on; emit
  ///      `ticket_fetch_failed` through telemetry once;
  ///   4. on no-cache + failure: throw, TicketScreen renders the offline
  ///      state.
  BookingTicketsProvider._({
    required BookingTicketsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'bookingTicketsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$bookingTicketsHash();

  @override
  String toString() {
    return r'bookingTicketsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<BookingTicketsView> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<BookingTicketsView> create(Ref ref) {
    final argument = this.argument as String;
    return bookingTickets(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is BookingTicketsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$bookingTicketsHash() => r'274781622a4400dda7d0155f3ffdd9d0a9836aa6';

/// Cache-first provider. Emits:
///   1. cached list immediately when fresh;
///   2. a background refresh fires on top; on success, cache is replaced
///      and a new state is emitted;
///   3. on refresh failure with cache: keep showing cache and flip
///      [BookingTicketsView.staleBannerVisible] on; emit
///      `ticket_fetch_failed` through telemetry once;
///   4. on no-cache + failure: throw, TicketScreen renders the offline
///      state.

final class BookingTicketsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<BookingTicketsView>, String> {
  BookingTicketsFamily._()
    : super(
        retry: null,
        name: r'bookingTicketsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Cache-first provider. Emits:
  ///   1. cached list immediately when fresh;
  ///   2. a background refresh fires on top; on success, cache is replaced
  ///      and a new state is emitted;
  ///   3. on refresh failure with cache: keep showing cache and flip
  ///      [BookingTicketsView.staleBannerVisible] on; emit
  ///      `ticket_fetch_failed` through telemetry once;
  ///   4. on no-cache + failure: throw, TicketScreen renders the offline
  ///      state.

  BookingTicketsProvider call(String bookingId) =>
      BookingTicketsProvider._(argument: bookingId, from: this);

  @override
  String toString() => r'bookingTicketsProvider';
}
