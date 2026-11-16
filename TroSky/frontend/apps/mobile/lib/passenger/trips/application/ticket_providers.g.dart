// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ticket_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Fetched tickets for a booking. Empty list until confirmation.

@ProviderFor(bookingTickets)
final bookingTicketsProvider = BookingTicketsFamily._();

/// Fetched tickets for a booking. Empty list until confirmation.

final class BookingTicketsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<TicketResponse>>,
          List<TicketResponse>,
          FutureOr<List<TicketResponse>>
        >
    with
        $FutureModifier<List<TicketResponse>>,
        $FutureProvider<List<TicketResponse>> {
  /// Fetched tickets for a booking. Empty list until confirmation.
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
  $FutureProviderElement<List<TicketResponse>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<TicketResponse>> create(Ref ref) {
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

String _$bookingTicketsHash() => r'30890f2c75b53fff43379dd5a10d303cdccd7446';

/// Fetched tickets for a booking. Empty list until confirmation.

final class BookingTicketsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<TicketResponse>>, String> {
  BookingTicketsFamily._()
    : super(
        retry: null,
        name: r'bookingTicketsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Fetched tickets for a booking. Empty list until confirmation.

  BookingTicketsProvider call(String bookingId) =>
      BookingTicketsProvider._(argument: bookingId, from: this);

  @override
  String toString() => r'bookingTicketsProvider';
}
