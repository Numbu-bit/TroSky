import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_core/trosky_core.dart';

import '../../../app/telemetry.dart';
import '../data/ticket_cache.dart';

part 'ticket_providers.g.dart';

/// The encrypted on-disk cache. One instance per app lifetime.
@Riverpod(keepAlive: true)
TicketCache ticketCache(Ref ref) => TicketCache();

/// Why a tickets refresh failed. Mapped from the backend failure into
/// one of the five analytics reasons the Step 16 spec locked in.
enum TicketFetchFailure {
  network,
  timeout,
  server5xx,
  server4xx,
  decode;

  String get payload => switch (this) {
    TicketFetchFailure.network => 'network',
    TicketFetchFailure.timeout => 'timeout',
    TicketFetchFailure.server5xx => 'server_5xx',
    TicketFetchFailure.server4xx => 'server_4xx',
    TicketFetchFailure.decode => 'decode',
  };
}

/// The render-visible answer: a list of tickets, and whether the most
/// recent refresh failed while cache was shown (controls the "last
/// synced" banner).
class BookingTicketsView {
  const BookingTicketsView({
    required this.tickets,
    required this.staleBannerVisible,
  });

  final List<TicketResponse> tickets;

  /// True when we're showing cache because the last refresh failed.
  final bool staleBannerVisible;
}

/// Cache-first provider. Emits:
///   1. cached list immediately when fresh;
///   2. a background refresh fires on top; on success, cache is replaced
///      and a new state is emitted;
///   3. on refresh failure with cache: keep showing cache and flip
///      [BookingTicketsView.staleBannerVisible] on; emit
///      `ticket_fetch_failed` through telemetry once;
///   4. on no-cache + failure: throw, TicketScreen renders the offline
///      state.
@riverpod
Future<BookingTicketsView> bookingTickets(Ref ref, String bookingId) async {
  final repo = ref.watch(ticketRepositoryProvider);
  final cache = ref.watch(ticketCacheProvider);
  final telemetry = ref.watch(telemetryProvider);
  final cached = await cache.read(bookingId);
  final refresh = _refresh(repo, cache, bookingId);
  if (cached != null && cached.isNotEmpty) {
    unawaited(
      refresh.then((result) {
        switch (result) {
          case Ok(:final value):
            // ignore: unused_local_variable
            final _ = value;
          case Err(:final failure):
            telemetry.emit(
              TelemetryEvent('ticket_fetch_failed', {
                'reason': _failureReason(failure).payload,
              }),
            );
        }
      }),
    );
    return BookingTicketsView(tickets: cached, staleBannerVisible: false);
  }
  final result = await refresh;
  return switch (result) {
    Ok(:final value) => BookingTicketsView(
      tickets: value,
      staleBannerVisible: false,
    ),
    Err(:final failure) => () {
      telemetry.emit(
        TelemetryEvent('ticket_fetch_failed', {
          'reason': _failureReason(failure).payload,
        }),
      );
      throw failure;
    }(),
  };
}

Future<Result<List<TicketResponse>>> _refresh(
  TicketRepository repo,
  TicketCache cache,
  String bookingId,
) async {
  final result = await repo.listForBooking(bookingId);
  if (result case Ok(:final value) when value.isNotEmpty) {
    await cache.write(bookingId, value);
  }
  return result;
}

TicketFetchFailure _failureReason(AppFailure failure) {
  if (failure is NetworkFailure) return TicketFetchFailure.network;
  if (failure is TimeoutFailure) return TicketFetchFailure.timeout;
  final status = failure.statusCode;
  if (status != null && status >= 500) return TicketFetchFailure.server5xx;
  if (status != null && status >= 400) return TicketFetchFailure.server4xx;
  return TicketFetchFailure.decode;
}
