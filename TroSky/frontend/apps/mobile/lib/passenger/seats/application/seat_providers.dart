import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_core/trosky_core.dart';

import '../../../app/app_providers.dart';

part 'seat_providers.g.dart';

/// The seat map is fetched again this often while it is on screen.
const Duration seatRefreshEvery = Duration(seconds: 10);

/// The trip vehicle's seats and which are free (`GET /trips/{id}/seats`).
@Riverpod(retry: noRetry)
Future<TripSeatsResponse> tripSeats(Ref ref, String tripId) async =>
    switch (await ref.read(routeRepositoryProvider).tripSeats(tripId)) {
      Ok(:final value) => value,
      Err(:final failure) => throw failure,
    };

/// What the seat screen prices: [seats] seats on [tripId] from
/// [originStopId] to [destinationStopId] (the route's ends when null).
@immutable
class FareQuoteRequest {
  const FareQuoteRequest(
    this.tripId, {
    this.originStopId,
    this.destinationStopId,
    this.seats = 1,
  });

  final String tripId;
  final String? originStopId;
  final String? destinationStopId;
  final int seats;

  @override
  bool operator ==(Object other) =>
      other is FareQuoteRequest &&
      other.tripId == tripId &&
      other.originStopId == originStopId &&
      other.destinationStopId == destinationStopId &&
      other.seats == seats;

  @override
  int get hashCode =>
      Object.hash(tripId, originStopId, destinationStopId, seats);
}

/// The price of a [FareQuoteRequest] right now (`GET /trips/{id}/fare-quote`):
/// what `POST /bookings` would charge. It falls as riders join, so the seat
/// screen fetches it again with the seat map.
@Riverpod(retry: noRetry)
Future<FareQuoteResponse> fareQuote(Ref ref, FareQuoteRequest request) async =>
    switch (await ref
        .read(routeRepositoryProvider)
        .fareQuote(
          request.tripId,
          originStopId: request.originStopId,
          destinationStopId: request.destinationStopId,
          seats: request.seats,
        )) {
      Ok(:final value) => value,
      Err(:final failure) => throw failure,
    };

/// A held, unpaid booking of the signed-in passenger whose deadline hasn't
/// passed (waiting for the driver, or to be paid for): Home shows it as a
/// card that leads back to Payment (decision 31). Null offline or when
/// there is none.
@Riverpod(retry: noRetry)
Future<BookingResponse?> heldBooking(Ref ref) async {
  final online = ref.watch(
    sessionControllerProvider.select(
      (s) => switch (s.value) {
        SessionAuthenticated(:final offline) => !offline,
        _ => false,
      },
    ),
  );
  if (!online) return null;
  final result = await ref
      .read(bookingRepositoryProvider)
      .list(
        statuses: const [
          BookingStatus.awaitingAcceptance,
          BookingStatus.pending,
          BookingStatus.paymentPending,
        ],
        upcoming: true,
        limit: 5,
      );
  final now = ref.read(clockProvider)().toUtc();
  return switch (result) {
    Ok(:final value) =>
      value.items.where((b) => b.expiresAt?.isAfter(now) ?? false).firstOrNull,
    Err() => null,
  };
}
