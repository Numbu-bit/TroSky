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

/// A held, unpaid booking of the signed-in passenger whose hold hasn't run
/// out: the app reopens it instead of losing it (Part 2). Null offline or
/// when there is none.
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
        statuses: const [BookingStatus.pending, BookingStatus.paymentPending],
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

/// Held bookings already shown on Payment in this run, so Home reopens
/// each at most once. Added to just before Payment opens.
@Riverpod(keepAlive: true)
class ShownBookings extends _$ShownBookings {
  @override
  Set<String> build() => const {};

  void add(String bookingId) => state = {...state, bookingId};
}
