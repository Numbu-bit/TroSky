import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_core/trosky_core.dart';

import '../../../app/app_providers.dart';
import '../../seats/application/seat_providers.dart';

part 'trips_providers.g.dart';

/// Bookings per page on Trip History.
const int bookingsPageSize = 20;

/// The two tabs of Trip History (P-15).
///
/// `GET /bookings?upcoming=` looks only at the trip, so a booking cancelled
/// for tomorrow's trip would count as upcoming: the tabs also filter by
/// status. Upcoming: still open, on a trip ahead or under way, soonest
/// first. Past: ended, newest booking first. (An open booking whose trip
/// ended without its passenger getting off is in neither; backend gap G35.)
enum TripsTab {
  upcoming(
    statuses: [
      BookingStatus.awaitingAcceptance,
      BookingStatus.pending,
      BookingStatus.paymentPending,
      BookingStatus.confirmed,
    ],
    ahead: true,
  ),
  past(
    statuses: [
      BookingStatus.completed,
      BookingStatus.cancelled,
      BookingStatus.expired,
      BookingStatus.refundPending,
      BookingStatus.refunded,
    ],
    ahead: null,
  );

  const TripsTab({required this.statuses, required this.ahead});

  final List<BookingStatus> statuses;

  /// `?upcoming=`: trips ahead (true), or both (null).
  final bool? ahead;
}

/// The loaded part of a [TripsTab].
@immutable
class TripsPage {
  const TripsPage({
    required this.bookings,
    required this.total,
    this.loadingMore = false,
    this.loadMoreError,
  });

  final List<BookingResponse> bookings;
  final int total;
  final bool loadingMore;
  final AppFailure? loadMoreError;

  bool get hasMore => bookings.length < total;

  TripsPage copyWith({bool? loadingMore, AppFailure? loadMoreError}) =>
      TripsPage(
        bookings: bookings,
        total: total,
        loadingMore: loadingMore ?? this.loadingMore,
        loadMoreError: loadMoreError,
      );
}

/// A tab of Trip History (`GET /bookings`), a page at a time.
@Riverpod(retry: noRetry)
class TripsController extends _$TripsController {
  @override
  Future<TripsPage> build(TripsTab tab) async {
    final result = await ref
        .read(bookingRepositoryProvider)
        .list(
          statuses: tab.statuses,
          upcoming: tab.ahead,
          limit: bookingsPageSize,
        );
    return switch (result) {
      Ok(:final value) => TripsPage(bookings: value.items, total: value.total),
      Err(:final failure) => throw failure,
    };
  }

  /// The next page. A failure stays on the state
  /// ([TripsPage.loadMoreError]); calling again retries.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    final result = await ref
        .read(bookingRepositoryProvider)
        .list(
          statuses: tab.statuses,
          upcoming: tab.ahead,
          limit: bookingsPageSize,
          offset: current.bookings.length,
        );
    // A refresh meanwhile started over: this page belongs to the old list.
    if (!ref.mounted || !identical(state.value?.bookings, current.bookings)) {
      return;
    }
    state = AsyncData(switch (result) {
      Ok(:final value) => TripsPage(
        bookings: [...current.bookings, ...value.items],
        total: value.total,
      ),
      Err(:final failure) => current.copyWith(loadMoreError: failure),
    });
  }
}

/// The Trip History card (`GET /bookings/summary`, G25): this month.
@Riverpod(retry: noRetry)
Future<BookingSummaryResponse> bookingSummary(Ref ref) async {
  final result = await ref.read(bookingRepositoryProvider).summary();
  return switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw failure,
  };
}

/// A booking with its trip, for Booking details (P-16).
@immutable
class BookingDetails {
  const BookingDetails({required this.booking, this.trip});

  final BookingResponse booking;

  /// `GET /trips/{id}`: vehicle, driver and arrival. Null when it failed;
  /// the screen then shows what the booking itself says.
  final TripDetailResponse? trip;
}

/// `GET /bookings/{id}` and `GET /trips/{id}`.
@Riverpod(retry: noRetry)
Future<BookingDetails> bookingDetails(Ref ref, String bookingId) async {
  final booking = await ref.read(bookingRepositoryProvider).get(bookingId);
  if (booking case Err(:final failure)) throw failure;
  final value = booking.valueOrNull!;
  final trip = await ref.read(routeRepositoryProvider).trip(value.tripId);
  return BookingDetails(booking: value, trip: trip.valueOrNull);
}

/// How [bookingId] was paid: its successful (or refunded) payment from
/// `GET /payments`, newest first. Null when it isn't among the latest 50 or
/// can't be read; the cancel sheet then says it generally.
@Riverpod(retry: noRetry)
Future<PaymentResponse?> bookingPayment(Ref ref, String bookingId) async {
  final result = await ref.read(paymentRepositoryProvider).list(limit: 50);
  return result.valueOrNull?.items
      .where(
        (p) =>
            p.bookingId == bookingId &&
            (p.status == PaymentStatus.successful ||
                p.status == PaymentStatus.refunded ||
                p.status == PaymentStatus.partiallyRefunded),
      )
      .firstOrNull;
}

/// After a booking changed (cancelled, paid, moved): read Trip History,
/// its card, the booking, how it was paid and Home's held booking again.
void refreshBookings(WidgetRef ref, String bookingId) {
  ref
    ..invalidate(tripsControllerProvider)
    ..invalidate(bookingSummaryProvider)
    ..invalidate(bookingDetailsProvider(bookingId))
    ..invalidate(bookingPaymentProvider(bookingId))
    ..invalidate(heldBookingProvider);
}
