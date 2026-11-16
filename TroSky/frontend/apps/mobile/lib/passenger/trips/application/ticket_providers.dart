import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_core/trosky_core.dart';

part 'ticket_providers.g.dart';

/// Fetched tickets for a booking. Empty list until confirmation.
@riverpod
Future<List<TicketResponse>> bookingTickets(Ref ref, String bookingId) async {
  final repo = ref.watch(ticketRepositoryProvider);
  final result = await repo.listForBooking(bookingId);
  return switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw failure,
  };
}
